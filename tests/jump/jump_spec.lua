local jump = require("jump")
local jump_hint = require("jump.hint")
local jump_targets = require("jump.targets")
local helpers = require("helpers")

local api = vim.api
local eq = assert.are.same
local override_keyseq = helpers.override_keyseq

local test_count = 0

describe("Jump movement and safety:", function()
	before_each(function()
		vim.cmd.only({ mods = { silent = true } })
		vim.cmd.enew({ bang = true })
		api.nvim_buf_set_name(0, test_count .. "test_file")
		test_count = test_count + 1
		api.nvim_buf_set_lines(0, 0, -1, false, {
			"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxy",
		})
		jump.setup()
	end)

	it("initializes with local default keys", function()
		eq(true, jump.initialized)
		eq("etovxqpdygfblzhckisuran", jump.opts.keys)
	end)

	it("JumpChar1AC and JumpChar2AC jump to selected target", function()
		api.nvim_win_set_cursor(0, { 1, 1 })
		-- Default keys start with 'e', 't'; second 'c' gets 't'.
		override_keyseq({ "c", "t" }, function()
			jump.hint_char1({ direction = jump_hint.HintDirection.AFTER_CURSOR })
		end)
		eq(28, api.nvim_win_get_cursor(0)[2])

		api.nvim_win_set_cursor(0, { 1, 1 })
		override_keyseq({ "c", "d", "t" }, function()
			jump.hint_char2({ direction = jump_hint.HintDirection.AFTER_CURSOR })
		end)
		eq(28, api.nvim_win_get_cursor(0)[2])
	end)

	it("jumps from an empty line forward and backward", function()
		api.nvim_buf_set_lines(0, 0, -1, false, {
			"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxy",
			"",
			"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxy",
		})
		api.nvim_win_set_cursor(0, { 2, 0 })

		override_keyseq({ "c", "t" }, function()
			jump.hint_char1({ direction = jump_hint.HintDirection.AFTER_CURSOR })
		end)
		eq({ 3, 28 }, api.nvim_win_get_cursor(0))

		api.nvim_win_set_cursor(0, { 2, 0 })
		override_keyseq({ "c", "t" }, function()
			jump.hint_char1({ direction = jump_hint.HintDirection.BEFORE_CURSOR })
		end)
		eq({ 1, 28 }, api.nvim_win_get_cursor(0))
	end)

	it("JumpWord jumps to selected word and sole occurrence", function()
		api.nvim_buf_set_lines(0, 0, -1, false, {
			"alpha beta gamma",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })

		-- Closest word ('beta') gets 'e', second ('gamma') gets 't'.
		override_keyseq({ "t" }, function()
			jump.hint_words()
		end)
		eq({ 1, 11 }, api.nvim_win_get_cursor(0))

		api.nvim_buf_set_lines(0, 0, -1, false, {
			"alpha beta",
		})
		api.nvim_win_set_cursor(0, { 1, 6 })
		jump.hint_words({ direction = jump_hint.HintDirection.BEFORE_CURSOR })
		eq({ 1, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("JumpLine and JumpLineStart jump cleanly and skip the active line", function()
		api.nvim_buf_set_lines(0, 0, -1, false, {
			"first line",
			"second line",
			"third line",
		})
		api.nvim_win_set_cursor(0, { 1, 3 })

		override_keyseq({ "t" }, function()
			jump.hint_lines()
		end)
		eq({ 3, 0 }, api.nvim_win_get_cursor(0))

		api.nvim_buf_set_lines(0, 0, -1, false, {
			"first",
			"    indented",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		jump.hint_lines_skip_whitespace()
		eq({ 2, 4 }, api.nvim_win_get_cursor(0))
	end)

	it("executes :JumpWord and :JumpLine user commands cleanly", function()
		api.nvim_buf_set_lines(0, 0, -1, false, {
			"one two three",
			"four five six",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })

		override_keyseq({ "e" }, function()
			vim.cmd("JumpWord")
		end)
		eq({ 1, 4 }, api.nvim_win_get_cursor(0))

		vim.cmd("JumpLine")
		eq({ 2, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("scopes ephemeral rendering strictly to active split on shared buffers", function()
		local buf = api.nvim_get_current_buf()
		api.nvim_buf_set_lines(buf, 0, -1, false, {
			"alpha beta gamma delta",
		})
		local win1 = api.nvim_get_current_win()
		vim.cmd.vsplit()
		local win2 = api.nvim_get_current_win()
		api.nvim_set_current_win(win1)
		api.nvim_win_set_cursor(win1, { 1, 0 })

		local saw_win1 = false
		local saw_win2 = false
		local mocked = vim.fn.getcharstr
		---@diagnostic disable-next-line: duplicate-set-field
		vim.fn.getcharstr = function()
			local render = jump_hint.get_render()
			if render then
				saw_win1 = render.by_win[win1] ~= nil
				saw_win2 = render.by_win[win2] ~= nil
			end
			return api.nvim_replace_termcodes("<Esc>", true, false, true)
		end

		local ok, err = pcall(jump.hint_words)
		vim.fn.getcharstr = mocked
		assert.is_true(ok, tostring(err))

		eq(true, saw_win1)
		eq(false, saw_win2)
		assert.is_nil(jump_hint.get_render())
		-- Ephemeral decoration provider leaves zero persistent extmarks in the buffer.
		eq(0, #api.nvim_buf_get_extmarks(buf, jump_hint.NS, 0, -1, {}))
	end)

	it("cancels safely on unmatched keys without editing the buffer", function()
		local buf = api.nvim_get_current_buf()
		api.nvim_buf_set_lines(buf, 0, -1, false, {
			"alpha beta gamma delta",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		vim.diagnostic.enable(true, { bufnr = buf })

		-- 'D' is not in opts.keys; with passthrough_unmatched_keys = false it must NOT delete to EOL.
		override_keyseq({ "D" }, function()
			jump.hint_words()
		end)
		vim.cmd.redraw()

		eq({ "alpha beta gamma delta" }, api.nvim_buf_get_lines(buf, 0, -1, false))
		eq({ 1, 0 }, api.nvim_win_get_cursor(0))
		eq(true, vim.diagnostic.is_enabled({ bufnr = buf }))
		assert.is_nil(jump_hint.get_render())
	end)

	it("cleans up render state and restores diagnostics even when a callback throws", function()
		local buf = api.nvim_get_current_buf()
		api.nvim_buf_set_lines(buf, 0, -1, false, {
			"alpha beta gamma delta",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		vim.diagnostic.enable(true, { bufnr = buf })

		local ok = pcall(function()
			override_keyseq({ "e" }, function()
				jump.hint_with_regex(jump_targets.regex_by_word_start(), jump.opts, function()
					error("simulated callback failure")
				end)
			end)
		end)

		eq(false, ok)
		assert.is_nil(jump_hint.get_render())
		eq(true, vim.diagnostic.is_enabled({ bufnr = buf }))
	end)

	it(
		"supports operator-pending motions: exclusive JumpWord, inclusive JumpChar1 EOL, linewise JumpLine, and Esc cancel",
		function()
			vim.keymap.set("o", "<F2>", "<cmd>JumpWord<cr>")
			vim.keymap.set("o", "<F3>", "<cmd>JumpLine<cr>")
			vim.keymap.set("o", "<F4>", "<cmd>JumpChar1<cr>")

			local f2 = api.nvim_replace_termcodes("<F2>", true, false, true)
			local f3 = api.nvim_replace_termcodes("<F3>", true, false, true)
			local f4 = api.nvim_replace_termcodes("<F4>", true, false, true)
			local esc = api.nvim_replace_termcodes("<Esc>", true, false, true)

			-- 1. Exclusive df (JumpWord): deleting to 'gamma' leaves 'gamma' intact.
			api.nvim_buf_set_lines(0, 0, -1, false, { "alpha beta gamma" })
			api.nvim_win_set_cursor(0, { 1, 0 })
			override_keyseq({ "t" }, function()
				api.nvim_feedkeys("d" .. f2, "tx", false)
			end)
			eq({ "gamma" }, api.nvim_buf_get_lines(0, 0, -1, false))

			-- 2. Linewise dF (JumpLine): deletes full lines 1 and 2 from mid-line cursor.
			api.nvim_buf_set_lines(0, 0, -1, false, { "first line", "second line", "third line" })
			api.nvim_win_set_cursor(0, { 1, 4 })
			override_keyseq({ "e" }, function()
				api.nvim_feedkeys("d" .. f3, "tx", false)
			end)
			eq({ "third line" }, api.nvim_buf_get_lines(0, 0, -1, false))

			-- 3. Inclusive JumpChar1 targeting the very last character of a line deletes it too.
			api.nvim_buf_set_lines(0, 0, -1, false, { "abc z" })
			api.nvim_win_set_cursor(0, { 1, 0 })
			override_keyseq({ "z" }, function()
				api.nvim_feedkeys("d" .. f4, "tx", false)
			end)
			eq({ "" }, api.nvim_buf_get_lines(0, 0, -1, false))

			-- 4. Esc during operator-pending mode aborts without modifying buffer.
			api.nvim_buf_set_lines(0, 0, -1, false, { "alpha beta gamma" })
			api.nvim_win_set_cursor(0, { 1, 0 })
			override_keyseq({ esc }, function()
				api.nvim_feedkeys("d" .. f2, "tx", false)
			end)
			eq({ "alpha beta gamma" }, api.nvim_buf_get_lines(0, 0, -1, false))
			eq("n", api.nvim_get_mode().mode)

			vim.keymap.del("o", "<F2>")
			vim.keymap.del("o", "<F3>")
			vim.keymap.del("o", "<F4>")
		end
	)
end)
