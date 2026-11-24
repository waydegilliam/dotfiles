local osc52 = require("osc52")
local api = vim.api
local eq = assert.are.same

---@param seq string
---@return string
local function decode_osc52(seq)
	local b64 = seq:match("^\027%]52;c;([A-Za-z0-9+/=]*)\027\\$")
	assert.is_not_nil(b64, "invalid OSC 52 sequence: " .. vim.inspect(seq))
	return vim.base64.decode(assert(b64))
end

describe("osc52:", function()
	---@type string[]
	local sent = {}
	---@type table<string, string?>
	local saved_env = {}
	local env_keys =
		{ "REX_SESSION", "REX_BLOCK", "REX_SERVER", "TERM_PROGRAM", "SSH_CLIENT", "SSH_TTY", "SSH_CONNECTION", "TMUX" }

	before_each(function()
		vim.cmd.enew({ bang = true })
		sent = {}
		saved_env = {}
		for _, k in ipairs(env_keys) do
			saved_env[k] = vim.env[k]
			vim.env[k] = nil
		end
		vim.g.clipboard = nil
		osc52.setup({
			silent = true,
			auto_yank = false,
			send = function(seq)
				sent[#sent + 1] = seq
			end,
		})
	end)

	after_each(function()
		for _, k in ipairs(env_keys) do
			vim.env[k] = saved_env[k]
		end
		vim.g.clipboard = nil
	end)

	it("encodes UTF-8 and multiline text as standard OSC 52 with ST terminator", function()
		local payload = "hello world\nline 2 — café"
		assert.is_true(osc52.copy(payload))
		eq(1, #sent)
		eq(payload, decode_osc52(sent[1]))
	end)

	it("wraps OSC 52 in tmux DCS passthrough only when opted in under TMUX", function()
		vim.env.TMUX = "/tmp/tmux-1000/default,123,0"

		-- Default: plain OSC 52 (for `set -g set-clipboard on`).
		local plain = osc52.encode("hi")
		eq("hi", decode_osc52(plain))

		-- Opt-in DCS passthrough doubles ESC bytes inside `\027Ptmux;...\027\\`.
		local wrapped = osc52.encode("hi", { tmux_passthrough = true })
		eq("\027Ptmux;\027\027]52;c;aGk=\027\027\\\027\\", wrapped)
	end)

	it("trims common indentation when trim = true and enforces max_length", function()
		local indented = "    foo\n      bar\n    baz\n"
		eq("foo\n  bar\nbaz", osc52.trim_text(indented))

		assert.is_true(osc52.copy(indented, { trim = true }))
		eq("foo\n  bar\nbaz", decode_osc52(sent[1]))

		sent = {}
		assert.is_false(osc52.copy("123456", { max_length = 5 }))
		eq(0, #sent)
	end)

	it(
		"supports :OSC52Copy, :OSC52Register, :OSC52Visual, and <Plug>OSC52Operator without clobbering registers",
		function()
			-- :OSC52Copy
			vim.cmd("OSC52Copy direct-text")
			eq("direct-text", decode_osc52(sent[#sent]))

			-- :OSC52Register
			vim.fn.setreg("a", "from-reg-a")
			vim.cmd("OSC52Register a")
			eq("from-reg-a", decode_osc52(sent[#sent]))

			-- Preserve unnamed register across visual & operator copies.
			vim.fn.setreg('"', "keep-unnamed")
			api.nvim_buf_set_lines(0, 0, -1, false, { "alpha beta gamma" })
			api.nvim_win_set_cursor(0, { 1, 6 })

			-- Visual copy of "beta" via :OSC52Visual
			local esc = api.nvim_replace_termcodes("<Esc>", true, false, true)
			api.nvim_feedkeys("viw" .. esc, "nx", false)
			vim.cmd("OSC52Visual")
			eq("beta", decode_osc52(sent[#sent]))
			eq("keep-unnamed", vim.fn.getreg('"'))

			-- Operator copy of "alpha" via <Plug>OSC52Operator + iw
			vim.keymap.set("n", "<F5>", "<Plug>OSC52Operator", { remap = true })
			api.nvim_win_set_cursor(0, { 1, 0 })
			local f5 = api.nvim_replace_termcodes("<F5>", true, false, true)
			api.nvim_feedkeys(f5 .. "iw", "tx", false)
			eq("alpha", decode_osc52(sent[#sent]))
			eq("keep-unnamed", vim.fn.getreg('"'))
			vim.keymap.del("n", "<F5>")
		end
	)

	it("detects Rex and SSH environments accurately", function()
		local local_env = osc52.detect_env()
		eq(false, local_env.is_rex)
		eq(false, local_env.is_ssh)

		vim.env.REX_SESSION = "sess_123"
		eq(true, osc52.detect_env().is_rex)
		vim.env.REX_SESSION = nil

		vim.env.TERM_PROGRAM = "rex"
		eq(true, osc52.detect_env().is_rex)
		vim.env.TERM_PROGRAM = nil

		vim.env.SSH_TTY = "/dev/pts/0"
		eq(true, osc52.detect_env().is_ssh)
	end)

	it("auto-emits silent OSC 52 on TextYankPost when inside Rex with local clipboard", function()
		vim.env.REX_BLOCK = "block:01abc"
		osc52.setup({
			auto_yank = true,
			send = function(seq)
				sent[#sent + 1] = seq
			end,
		})

		local env = osc52.detect_env()
		if env.has_local_clipboard then
			eq("autocmd", osc52.mode)
			api.nvim_buf_set_lines(0, 0, -1, false, { "rex yank line" })
			api.nvim_win_set_cursor(0, { 1, 0 })
			vim.cmd("normal! yy")
			eq(1, #sent)
			eq("rex yank line", decode_osc52(sent[1]))
		else
			eq("clipboard", osc52.mode)
			assert.is_not_nil(vim.g.clipboard)
			vim.g.clipboard.copy["+"]({ "headless rex line" })
			eq(1, #sent)
			eq("headless rex line", decode_osc52(sent[1]))
		end
	end)

	it("registers non-blocking vim.g.clipboard provider on headless Rex/SSH hosts", function()
		local orig_detect = osc52.detect_env
		osc52.detect_env = function()
			return { is_rex = true, is_ssh = false, is_tmux = false, has_local_clipboard = false }
		end

		local ok, err = pcall(function()
			osc52.setup({
				auto_yank = true,
				send = function(seq)
					sent[#sent + 1] = seq
				end,
			})

			eq("clipboard", osc52.mode)
			assert.is_not_nil(vim.g.clipboard)
			vim.g.clipboard.copy["+"]({ "line one", "line two" })
			eq(1, #sent)
			eq("line one\nline two", decode_osc52(sent[1]))

			vim.fn.setreg('"', "local-paste")
			local lines = vim.g.clipboard.paste["+"]()
			eq({ "local-paste" }, lines)
		end)

		osc52.detect_env = orig_detect
		assert.is_true(ok, tostring(err))
	end)
end)
