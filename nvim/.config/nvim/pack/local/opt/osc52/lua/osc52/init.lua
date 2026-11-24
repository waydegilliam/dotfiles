-- Modern Neovim 0.12 OSC 52 clipboard plugin tailored for Rex, SSH, and tmux.
local api = vim.api

---@class OSC52Env
---@field is_rex boolean
---@field is_ssh boolean
---@field is_tmux boolean
---@field has_local_clipboard boolean

---@class OSC52Options : OSC52SetupOpts
---@field max_length integer Maximum byte length to copy (0 = unlimited)
---@field silent boolean Suppress echo messages on copy
---@field trim boolean Strip common leading indent and outer whitespace
---@field tmux_passthrough boolean Wrap OSC 52 in tmux DCS passthrough (unneeded when tmux `set-clipboard on`)
---@field osc52 string Format string for the OSC 52 escape sequence
---@field auto_yank boolean Auto-emit OSC 52 on yank when inside Rex or SSH
---@field send fun(seq: string) Escape-sequence transport (defaults to `vim.api.nvim_ui_send`)

---@class OSC52SetupOpts
---@field max_length? integer
---@field silent? boolean
---@field trim? boolean
---@field tmux_passthrough? boolean
---@field osc52? string
---@field auto_yank? boolean
---@field send? fun(seq: string)

---@type OSC52Options
local defaults = {
	max_length = 0,
	silent = false,
	trim = false,
	tmux_passthrough = false,
	osc52 = "\027]52;c;%s\027\\",
	auto_yank = true,
	send = api.nvim_ui_send,
}

---@class OSC52Module
---@field opts OSC52Options
---@field initialized boolean
---@field mode "none" | "clipboard" | "autocmd"
local M = {
	opts = defaults,
	initialized = false,
	mode = "none",
}

---@param name string
---@return boolean
local function has_env(name)
	local val = vim.env[name]
	return type(val) == "string" and val ~= ""
end

--- Detect whether a native local system clipboard provider is usable in this environment.
---@return boolean
local function detect_local_clipboard()
	if vim.fn.has("mac") == 1 and vim.fn.executable("pbcopy") == 1 then
		return true
	end
	if has_env("WAYLAND_DISPLAY") and vim.fn.executable("wl-copy") == 1 then
		return true
	end
	if has_env("DISPLAY") and (vim.fn.executable("xclip") == 1 or vim.fn.executable("xsel") == 1) then
		return true
	end
	return false
end

--- Inspect the current terminal/remote environment.
---@return OSC52Env
function M.detect_env()
	local is_rex = has_env("REX_SESSION")
		or has_env("REX_BLOCK")
		or has_env("REX_SERVER")
		or vim.env.TERM_PROGRAM == "rex"
	local is_ssh = has_env("SSH_CLIENT") or has_env("SSH_TTY") or has_env("SSH_CONNECTION")
	local is_tmux = has_env("TMUX")
	return {
		is_rex = is_rex,
		is_ssh = is_ssh,
		is_tmux = is_tmux,
		has_local_clipboard = detect_local_clipboard(),
	}
end

---@param opts? OSC52SetupOpts
---@return OSC52Options
local function resolve_opts(opts)
	local merged = setmetatable(vim.tbl_extend("force", {}, opts or {}), { __index = M.opts })
	---@cast merged OSC52Options
	return merged
end

---@param msg string
---@param hl string
local function echo(msg, hl)
	api.nvim_echo({ { string.format("[osc52] %s", msg), hl } }, false, {})
end

--- Remove common leading indentation (matching line 1) and outer whitespace.
---@param text string
---@return string
function M.trim_text(text)
	local indent = text:match("^([ \t]+)")
	if indent and #indent > 0 then
		local pattern = "\n" .. string.rep("[ \t]", #indent)
		text = text:gsub(pattern, "\n")
	end
	return vim.trim(text)
end

--- Build the OSC 52 escape sequence for `text`.
---@param text string
---@param opts? OSC52SetupOpts
---@return string
function M.encode(text, opts)
	local resolved = resolve_opts(opts)
	local seq = string.format(resolved.osc52, vim.base64.encode(text))
	if resolved.tmux_passthrough and has_env("TMUX") then
		seq = "\027Ptmux;" .. seq:gsub("\027", "\027\027") .. "\027\\"
	end
	return seq
end

--- Copy `text` to the terminal clipboard via OSC 52.
---@param text string
---@param opts? OSC52SetupOpts
---@return boolean
function M.copy(text, opts)
	local resolved = resolve_opts(opts)
	if resolved.trim then
		text = M.trim_text(text)
	end

	if resolved.max_length > 0 and #text > resolved.max_length then
		echo(string.format("Selection is too big: length is %d, limit is %d", #text, resolved.max_length), "WarningMsg")
		return false
	end

	local ok, err = pcall(resolved.send, M.encode(text, resolved))
	if not ok then
		echo(string.format("Failed to copy selection: %s", tostring(err)), "ErrorMsg")
		return false
	end

	if not resolved.silent then
		echo(string.format("%d characters copied", #text), "Normal")
	end
	return true
end

--- Copy the contents of register `reg` (defaults to the unnamed register `"`).
---@param reg? string
---@param opts? OSC52SetupOpts
---@return boolean
function M.copy_register(reg, opts)
	local register = (reg and reg ~= "") and reg or '"'
	local text = vim.fn.getreg(register)
	if type(text) ~= "string" then
		return false
	end
	return M.copy(text, opts)
end

---@param pos1 integer[]
---@param pos2 integer[]
---@param regtype string
---@param opts? OSC52SetupOpts
---@return boolean
local function copy_region(pos1, pos2, regtype, opts)
	local lines = vim.fn.getregion(pos1, pos2, { type = regtype })
	local text = table.concat(lines, "\n")
	if regtype == "V" then
		text = text .. "\n"
	end
	return M.copy(text, opts)
end

--- Copy the last visual selection cleanly via `vim.fn.getregion` (no register clobbering).
---@param opts? OSC52SetupOpts
---@return boolean
function M.copy_visual(opts)
	local mode = vim.fn.visualmode()
	if mode == "" then
		mode = "v"
	end
	return copy_region(vim.fn.getpos("'<"), vim.fn.getpos("'>"), mode, opts)
end

---@type table<string, string>
local operator_modes = {
	char = "v",
	line = "V",
	block = "\022",
}

--- Operatorfunc callback used by `<Plug>OSC52Operator`.
---@param motion_type string
---@return boolean
function M.operator_callback(motion_type)
	local regtype = operator_modes[motion_type] or "v"
	return copy_region(vim.fn.getpos("'["), vim.fn.getpos("']"), regtype)
end

--- Expression mapping helper for `<Plug>OSC52Operator`.
---@return string
function M.operator()
	vim.go.operatorfunc = "v:lua.require'osc52'.operator_callback"
	return "g@"
end

--- Non-blocking fallback paste returning the unnamed register lines so `p` never hangs waiting
--- for an OSC 52 read response.
---@return string[], string
local function fallback_paste()
	local lines = vim.fn.getreg('"', 1, true)
	local regtype = vim.fn.getregtype('"')
	return lines, regtype
end

--- Configure `osc52` and automatically wire clipboard/yank integration for Rex and SSH.
---@param opts? OSC52SetupOpts
function M.setup(opts)
	local merged = setmetatable(vim.tbl_extend("force", {}, opts or {}), { __index = defaults })
	---@cast merged OSC52Options
	M.opts = merged
	M.initialized = true
	M.mode = "none"

	local augroup = api.nvim_create_augroup("OSC52Auto", { clear = true })
	if not M.opts.auto_yank then
		return
	end

	local env = M.detect_env()
	if not env.is_rex and not env.is_ssh then
		return
	end

	if not env.has_local_clipboard then
		-- Headless remote host (e.g. Linux Rex server or SSH): provide a native Neovim clipboard
		-- provider so `set clipboard=unnamedplus` and `"+y` work seamlessly with zero warnings.
		---@param lines string[]
		local function osc_copy(lines)
			M.copy(table.concat(lines, "\n"), { silent = true })
		end

		vim.g.clipboard = {
			name = "osc52",
			copy = {
				["+"] = osc_copy,
				["*"] = osc_copy,
			},
			paste = {
				["+"] = fallback_paste,
				["*"] = fallback_paste,
			},
			cache_enabled = true,
		}
		M.mode = "clipboard"
	else
		-- Local clipboard exists (e.g. macOS + Rex): keep native pbcopy/pbpaste for `p`, and also
		-- silently emit OSC 52 on yanks so any attached remote Rex client receives the clipboard.
		api.nvim_create_autocmd("TextYankPost", {
			group = augroup,
			callback = function()
				local ev = vim.v.event
				local contents = ev and ev.regcontents or nil
				if type(contents) == "table" and #contents > 0 then
					M.copy(table.concat(contents, "\n"), { silent = true })
				end
			end,
		})
		M.mode = "autocmd"
	end
end

return M
