local api = vim.api
local hint = require("jump.hint")
local targets = require("jump.targets")

---@class JumpModule
---@field opts JumpOptions
---@field initialized boolean
local M = {
	opts = require("jump.defaults"),
	initialized = false,
}

local K_Esc = api.nvim_replace_termcodes("<Esc>", true, false, true)
local K_BS = api.nvim_replace_termcodes("<BS>", true, false, true)
local K_C_H = api.nvim_replace_termcodes("<C-H>", true, false, true)
local K_CR = api.nvim_replace_termcodes("<CR>", true, false, true)
local K_NL = api.nvim_replace_termcodes("<NL>", true, false, true)

--- Buffers whose diagnostics are suspended by an active Jump session.
---@type table<integer, boolean>
local suspended_diag_bufs = {}

--- Insert default Jump highlight groups.
function M.insert_highlights()
	local set = api.nvim_set_hl
	set(0, "JumpNextKey", { fg = "#ff007c", bold = true, ctermfg = 198, cterm = { bold = true }, default = true })
	set(0, "JumpNextKey1", { fg = "#00dfff", bold = true, ctermfg = 45, cterm = { bold = true }, default = true })
	set(0, "JumpNextKey2", { fg = "#2b8db3", ctermfg = 33, default = true })
	set(0, "JumpUnmatched", { fg = "#666666", sp = "#666666", ctermfg = 242, default = true })
	set(0, "JumpCursor", { link = "Cursor", default = true })
	set(0, "JumpPreview", { link = "IncSearch", default = true })
end

---@param opts? JumpSetupOpts
---@param default_motion_mode? JumpMotionMode
---@return JumpOptions
local function override_opts(opts, default_motion_mode)
	local merged = setmetatable(vim.tbl_extend("force", {}, opts or {}), { __index = M.opts })
	---@cast merged JumpOptions
	if merged.motion_mode == nil and default_motion_mode ~= nil then
		merged.motion_mode = default_motion_mode
	end
	if merged.multi_windows and merged.current_line_only then
		vim.notify("Cannot use current_line_only across multiple windows", vim.log.levels.WARN)
	end
	local mode = api.nvim_get_mode().mode
	if mode ~= "n" and mode ~= "nt" then
		merged.multi_windows = false
	end
	return merged
end

---@param msg string
---@param teasing boolean
local function eprintln(msg, teasing)
	if teasing then
		api.nvim_echo({ { msg, "Error" } }, true, {})
	end
end

---@param buf_list integer[]
---@param opts JumpOptions
local function suspend_diagnostics(buf_list, opts)
	if not opts.dim_unmatched then
		return
	end
	for _, buf in ipairs(buf_list) do
		if not suspended_diag_bufs[buf] and vim.diagnostic.is_enabled({ bufnr = buf }) then
			suspended_diag_bufs[buf] = true
			vim.diagnostic.enable(false, { bufnr = buf })
		end
	end
end

--- Abort an active operator-pending mode cleanly when a Jump session is cancelled.
local function abort_operator_pending()
	if api.nvim_get_mode().mode:sub(1, 2) == "no" then
		api.nvim_feedkeys(K_Esc, "n", false)
	end
end

--- Clear window-scoped overlays and restore any suspended diagnostics (idempotent).
---@param hint_state? HintState
function M.quit(hint_state)
	hint.clear_render()

	if hint_state then
		for _, buf in ipairs(hint_state.buf_list) do
			if suspended_diag_bufs[buf] then
				suspended_diag_bufs[buf] = nil
				if api.nvim_buf_is_valid(buf) then
					vim.diagnostic.enable(true, { bufnr = buf })
				end
			end
		end
	else
		for buf in pairs(suspended_diag_bufs) do
			suspended_diag_bufs[buf] = nil
			if api.nvim_buf_is_valid(buf) then
				vim.diagnostic.enable(true, { bufnr = buf })
			end
		end
	end

	vim.cmd.redraw()
end

--- Prompt for a search pattern with optional live window-scoped match preview.
---@param prompt string
---@param maxchar? integer
---@param opts? JumpOptions
---@return string?
function M.get_input_pattern(prompt, maxchar, opts)
	---@type HintState?
	local hs = nil
	if opts then
		hs = hint.create_hint_state(opts)
		suspend_diagnostics(hs.buf_list, opts)
		hint.set_render(hs, opts, { dim = true })
	end

	---@type string[]
	local pat_keys = {}
	---@type string?
	local pat = ""

	local ok_loop, err = pcall(function()
		while true do
			pat = table.concat(pat_keys)

			if opts and hs and #pat > 0 then
				local ok_re, re = pcall(targets.regex_by_case_searching, pat, false, opts)
				if ok_re then
					local generated = targets.jump_target_generator(re, hs.all_ctxs)(opts)
					hint.set_render(hs, opts, { dim = true, previews = generated.jump_targets })
				end
			elseif opts and hs then
				hint.set_render(hs, opts, { dim = true })
			end

			api.nvim_echo({}, false, {})
			vim.cmd.redraw()
			api.nvim_echo({ { prompt, "Question" }, { pat } }, false, {})

			local ok_key, key = pcall(vim.fn.getcharstr)
			if not ok_key or type(key) ~= "string" then
				pat = nil
				break
			end

			if key == K_Esc then
				pat = nil
				break
			elseif key == K_CR or key == K_NL then
				break
			elseif key == K_BS or key == K_C_H then
				pat_keys[#pat_keys] = nil
			else
				pat_keys[#pat_keys + 1] = key
			end

			if maxchar and #pat_keys >= maxchar then
				pat = table.concat(pat_keys)
				break
			end
		end
	end)

	api.nvim_echo({}, false, {})
	if not ok_loop then
		M.quit(hs)
		error(err)
	end

	if hs and not pat then
		M.quit(hs)
	else
		vim.cmd.redraw()
	end

	if not pat then
		abort_operator_pending()
	end

	return pat
end

--- Move cursor to a jump target, handling operator-pending motion forcing and jump list.
---@param jt JumpTarget
---@param opts JumpOptions
function M.move_cursor_to(jt, opts)
	targets.move_jump_target(jt, 0, opts.hint_offset)

	local mode = api.nvim_get_mode().mode
	if mode == "no" then
		if opts.motion_mode == "linewise" then
			vim.cmd("normal! V")
		elseif opts.motion_mode == "inclusive" then
			vim.cmd("normal! v")
		end
	end

	api.nvim_set_current_win(jt.window)
	if mode:sub(1, 2) ~= "no" then
		vim.cmd("normal! m'")
	end
	api.nvim_win_set_cursor(jt.window, { jt.cursor.row, jt.cursor.col })
end

---@param jump_target_gtr Generator
---@param opts JumpOptions
function M.hint_with(jump_target_gtr, opts)
	M.hint_with_callback(jump_target_gtr, opts, function(jt)
		M.move_cursor_to(jt, opts)
	end)
end

---@param regex Regex
---@param opts JumpOptions
---@param callback? fun(jt: JumpTarget)
function M.hint_with_regex(regex, opts, callback)
	local jump_target_gtr = targets.jump_target_generator(regex)
	M.hint_with_callback(jump_target_gtr, opts, callback or function(jt)
		M.move_cursor_to(jt, opts)
	end)
end

--- Advance the hint state machine by one keystroke.
---@param key string
---@param hint_state HintState
---@param callback fun(jt: JumpTarget)
---@param opts JumpOptions
---@return Hint?
function M.refine_hints(key, hint_state, callback, opts)
	local h, remaining = hint.reduce_hints(hint_state.hints, key)

	if h == nil then
		if #remaining == 0 then
			eprintln("no remaining sequence starts with " .. key, opts.teasing)
			return nil
		end

		hint_state.hints = remaining
		hint.set_render(hint_state, opts, { dim = true, hints = remaining })
		return nil
	end

	M.quit(hint_state)
	callback(h.jump_target)
	return h
end

---@param jump_target_gtr Generator
---@param opts JumpOptions
---@param callback fun(jt: JumpTarget)
function M.hint_with_callback(jump_target_gtr, opts, callback)
	if not M.initialized then
		vim.notify("Jump is not initialized; please call the setup function", vim.log.levels.ERROR)
		return
	end

	local hs = hint.create_hint_state(opts)

	local ok, err = pcall(function()
		local generated = jump_target_gtr(opts)
		local count = #generated.jump_targets

		---@type integer?
		local target_idx = nil
		if count == 0 then
			target_idx = 0
		elseif vim.v.count > 0 then
			target_idx = vim.v.count
		elseif count == 1 and opts.jump_on_sole_occurrence then
			target_idx = 1
		end

		if target_idx ~= nil then
			local jt = generated.jump_targets[target_idx]
			M.quit(hs)
			if jt then
				callback(jt)
			else
				eprintln(" -> there's no such thing we can see…", opts.teasing)
				abort_operator_pending()
			end
			return
		end

		hs.hints = hint.create_hints(generated.jump_targets, generated.indirect_jump_targets, opts)
		suspend_diagnostics(hs.buf_list, opts)
		hint.set_render(hs, opts, { dim = true, hints = hs.hints })
		vim.cmd.redraw()

		local quit_key = api.nvim_replace_termcodes(opts.quit_key, true, false, true)
		---@type Hint?
		local matched = nil

		while matched == nil do
			local ok_key, key = pcall(vim.fn.getcharstr)
			if not ok_key or type(key) ~= "string" then
				M.quit(hs)
				abort_operator_pending()
				break
			end

			local is_regular_key = key ~= "" and key:byte() ~= 128
			if is_regular_key and opts.keys:find(key, 1, true) then
				matched = M.refine_hints(key, hs, callback, opts)
				vim.cmd.redraw()
			else
				M.quit(hs)
				if opts.passthrough_unmatched_keys and key ~= quit_key then
					api.nvim_feedkeys(key, "", true)
				else
					abort_operator_pending()
				end
				break
			end
		end
	end)

	-- Guarantee overlay and diagnostic cleanup even if a callback or hook raised an error.
	M.quit(hs)
	if not ok then
		error(err)
	end
end

---@param opts? JumpSetupOpts
function M.hint_words(opts)
	M.hint_with_regex(targets.regex_by_word_start(), override_opts(opts, "exclusive"))
end

---@param opts? JumpSetupOpts
function M.hint_camel_case(opts)
	M.hint_with_regex(targets.regex_by_camel_case(), override_opts(opts, "exclusive"))
end

---@param opts? JumpSetupOpts
---@param pattern? string
function M.hint_patterns(opts, pattern)
	if not M.initialized then
		vim.notify("Jump is not initialized; please call the setup function", vim.log.levels.ERROR)
		return
	end

	local resolved = override_opts(opts, "inclusive")
	---@type string?
	local pat = pattern
	if not pat then
		vim.cmd.redraw()
		vim.fn.inputsave()
		pat = M.get_input_pattern("Jump pattern: ", nil, resolved)
		vim.fn.inputrestore()
		if not pat then
			return
		end
	end

	if #pat == 0 then
		eprintln("-> empty pattern", resolved.teasing)
		abort_operator_pending()
		return
	end

	M.hint_with_regex(targets.regex_by_case_searching(pat, false, resolved), resolved)
end

---@param opts? JumpSetupOpts
function M.hint_char1(opts)
	local resolved = override_opts(opts, "inclusive")
	local c = M.get_input_pattern("Jump 1 char: ", 1)
	if not c then
		return
	end
	M.hint_with_regex(targets.regex_by_case_searching(c, true, resolved), resolved)
end

---@param opts? JumpSetupOpts
function M.hint_char2(opts)
	local resolved = override_opts(opts, "inclusive")
	local c = M.get_input_pattern("Jump 2 char: ", 2)
	if not c then
		return
	end
	M.hint_with_regex(targets.regex_by_case_searching(c, true, resolved), resolved)
end

---@param opts? JumpSetupOpts
function M.hint_lines(opts)
	M.hint_with_regex(targets.by_line_start(), override_opts(opts, "linewise"))
end

---@param opts? JumpSetupOpts
function M.hint_vertical(opts)
	M.hint_with_regex(targets.regex_by_vertical(), override_opts(opts, "exclusive"))
end

---@param opts? JumpSetupOpts
function M.hint_lines_skip_whitespace(opts)
	M.hint_with_regex(targets.regex_by_line_start_skip_whitespace(), override_opts(opts, "linewise"))
end

---@param opts? JumpSetupOpts
function M.hint_anywhere(opts)
	M.hint_with_regex(targets.regex_by_anywhere(), override_opts(opts, "inclusive"))
end

--- Setup Jump with optional user overrides and register highlights.
---@param opts? JumpSetupOpts
function M.setup(opts)
	local merged = setmetatable(vim.tbl_extend("force", {}, opts or {}), { __index = require("jump.defaults") })
	---@cast merged JumpOptions
	M.opts = merged
	M.initialized = true

	M.insert_highlights()
	if M.opts.create_hl_autocmd then
		api.nvim_create_autocmd("ColorScheme", {
			group = api.nvim_create_augroup("JumpInitHighlight", { clear = true }),
			callback = function()
				M.insert_highlights()
			end,
		})
	end
end

return M
