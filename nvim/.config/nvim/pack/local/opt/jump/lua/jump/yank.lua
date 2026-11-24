-- Remote yank and paste motions powered by Jump.
local jump = require("jump")
local targets = require("jump.targets")
local api = vim.api

local M = {}

---@param opts? JumpSetupOpts
---@return JumpOptions
local function resolve_opts(opts)
	local merged = setmetatable(vim.tbl_extend("force", {}, opts or {}), { __index = jump.opts })
	---@cast merged JumpOptions
	return merged
end

--- Order two jump targets so the earlier buffer position is returned first.
---@param a JumpTarget
---@param b JumpTarget
---@return JumpTarget, JumpTarget
local function order_bounds(a, b)
	if a.cursor.row < b.cursor.row or (a.cursor.row == b.cursor.row and a.cursor.col <= b.cursor.col) then
		return a, b
	end
	return b, a
end

--- Extract buffer text inclusive of both jump target positions.
---@param start_target JumpTarget
---@param end_target JumpTarget
---@return string[]
function M.get_text(start_target, end_target)
	start_target, end_target = order_bounds(start_target, end_target)
	return api.nvim_buf_get_text(
		start_target.buffer,
		start_target.cursor.row - 1,
		start_target.cursor.col,
		end_target.cursor.row - 1,
		end_target.cursor.col + 1,
		{}
	)
end

--- Write text lines to `register`.
---@param text string[]
---@param register string
function M.yank_to(text, register)
	vim.fn.setreg(register, text)
end

--- Paste `register` contents immediately after `target`.
---@param target JumpTarget
---@param register string
function M.paste_from(target, register)
	local text = vim.fn.getreg(register)
	if type(text) ~= "string" or text == "" then
		return
	end
	local replacement = vim.split(text, "\n", { trimempty = true })
	api.nvim_buf_set_text(
		target.buffer,
		target.cursor.row - 1,
		target.cursor.col + 1,
		target.cursor.row - 1,
		target.cursor.col + 1,
		replacement
	)
end

---@param opts? JumpSetupOpts
function M.yank_char1(opts)
	local resolved = resolve_opts(opts)
	if resolved.multi_windows then
		resolved.multi_windows = false
		vim.notify("Cannot use yank across multiple windows", vim.log.levels.WARN)
	end

	---@type JumpTarget[]
	local picked = {}
	for i, prompt in ipairs({ "Yank start pattern: ", "Yank end pattern: " }) do
		local c = jump.get_input_pattern(prompt, 1)
		if not c or c == "" then
			return
		end
		jump.hint_with_regex(targets.regex_by_case_searching(c, true, resolved), resolved, function(jt)
			picked[i] = jt
		end)
	end

	if not picked[1] or not picked[2] then
		return
	end

	local text = M.get_text(picked[1], picked[2])
	if #text == 0 or text[1] == "" then
		return
	end
	M.yank_to(text, resolved.yank_register)
end

---@param opts? JumpSetupOpts
function M.paste_char1(opts)
	local resolved = resolve_opts(opts)
	local c = jump.get_input_pattern("Paste 1 char: ", 1)
	if not c or c == "" then
		return
	end
	jump.hint_with_regex(targets.regex_by_case_searching(c, true, resolved), resolved, function(jt)
		targets.move_jump_target(jt, 0, resolved.hint_offset)
		M.paste_from(jt, resolved.yank_register)
	end)
end

return M
