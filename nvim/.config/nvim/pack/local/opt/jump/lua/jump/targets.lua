-- Regex matchers and jump-target scanning/sorting/offsetting.
local hint = require("jump.hint")
local window = require("jump.window")
local api = vim.api

---@alias Generator fun(opts: JumpOptions): Locations

---@class Locations
---@field jump_targets JumpTarget[]
---@field indirect_jump_targets IndirectJumpTarget[]

---@class JumpTarget
---@field window integer
---@field buffer integer
---@field cursor CursorPos
---@field length integer Matched byte length for preview highlighting

---@class IndirectJumpTarget
---@field index integer
---@field score number

---@class Regex
---@field oneshot boolean
---@field match fun(s: string, wctx: WindowContext, lctx: LineContext, opts: JumpOptions): integer?, integer?

local M = {}

---@param s string
---@return boolean
local function starts_with_uppercase(s)
	if #s == 0 then
		return false
	end
	local f = s:sub(1, vim.str_byteindex(s, "utf-32", 1))
	return f ~= " " and f:upper() == f
end

---@param pat string
---@param plain? boolean
---@return Regex
local function regex_matcher(pat, plain)
	if plain then
		pat = vim.fn.escape(pat, "\\/.$^~[]")
	end
	local re = vim.regex(pat)
	return {
		oneshot = false,
		match = function(s)
			return re:match_str(s)
		end,
	}
end

--- Case-aware search regex respecting `opts.case_insensitive` and `'smartcase'`.
---@param pat string
---@param plain boolean
---@param opts JumpOptions
---@return Regex
function M.regex_by_case_searching(pat, plain, opts)
	local pat_case = ""
	if opts.case_insensitive and not (vim.o.smartcase and starts_with_uppercase(pat)) then
		pat_case = "\\c"
	end
	if plain then
		pat = vim.fn.escape(pat, "\\/.$^~[]")
	end
	return regex_matcher(pat .. pat_case, false)
end

---@return Regex
function M.regex_by_word_start()
	return regex_matcher("\\k\\+")
end

---@return Regex
function M.regex_by_camel_case()
	local parts = {
		"\\u\\l\\+",
		"\\u\\+\\ze\\u\\l",
		"\\u\\+",
		"\\l\\+",
		"#\\x\\+\\>",
		"\\<0[xX]\\x\\+\\>",
		"\\<0[oO][0-7]\\+\\>",
		"\\<0[bB][01]\\+\\>",
		"\\d\\+",
		"\\~",
		"!",
		"@",
		"#",
		"$",
	}
	return regex_matcher("\\%(\\%(" .. table.concat(parts, "\\)\\|\\%(") .. "\\)\\)")
end

---@return Regex
function M.by_line_start()
	return {
		oneshot = true,
		match = function(_, wctx, lctx)
			if window.is_active_line(wctx, lctx) then
				return nil, nil
			end
			return 0, 1
		end,
	}
end

---@return Regex
function M.regex_by_vertical()
	return {
		oneshot = true,
		match = function(s, wctx, lctx, opts)
			if wctx.cursor.row == lctx.row then
				if wctx.win_handle == api.nvim_get_current_win() then
					return nil, nil
				end
				if opts.direction == hint.HintDirection.AFTER_CURSOR then
					return 0, 1
				end
			end
			local col = window.cell_to_byte(s, wctx.col_first)
			if col < #s then
				return col, col + 1
			end
			return math.max(0, #s - 1), #s
		end,
	}
end

---@return Regex
function M.regex_by_line_start_skip_whitespace()
	local re = vim.regex("\\S")
	return {
		oneshot = true,
		match = function(s, wctx, lctx)
			if window.is_active_line(wctx, lctx) then
				return nil, nil
			end
			return re:match_str(s)
		end,
	}
end

---@return Regex
function M.regex_by_anywhere()
	return regex_matcher("\\v(<.|^$)|(.>|^$)|(\\l)\\zs(\\u)|(_\\zs.)|(#\\zs.)")
end

--- Sort indirect jump targets according to distance score and distribution order.
---@param indirect_jump_targets IndirectJumpTarget[]
---@param opts JumpOptions
function M.sort_indirect_jump_targets(indirect_jump_targets, opts)
	table.sort(indirect_jump_targets, function(a, b)
		if opts.reverse_distribution then
			return a.score > b.score
		end
		return a.score < b.score
	end)
end

--- Offset a jump target by `offset_row` lines and `offset_cell` display cells (tab-aware).
---@param jt JumpTarget
---@param offset_row? WindowRow
---@param offset_cell? WindowCell
function M.move_jump_target(jt, offset_row, offset_cell)
	local drow = offset_row or 0
	local dcell = offset_cell or 0

	if drow ~= 0 then
		local max_row = api.nvim_buf_line_count(jt.buffer)
		jt.cursor.row = math.max(1, math.min(max_row, jt.cursor.row + drow))
	end

	if dcell ~= 0 then
		local line = api.nvim_buf_get_lines(jt.buffer, jt.cursor.row - 1, jt.cursor.row, false)[1] or ""
		local cur_cell = api.nvim_win_call(jt.window, function()
			return vim.fn.virtcol({ jt.cursor.row, jt.cursor.col + 1 }) - 1
		end)
		local target_cell = math.max(0, cur_cell + dcell)
		jt.cursor.col = window.win_cell_to_byte(jt.window, jt.cursor.row, line, target_cell)
	end
end

---@param regex Regex
---@param wctx WindowContext
---@param lctx LineContext
---@param locations Locations
---@param opts JumpOptions
---@param win_bias number
local function scan_line(regex, wctx, lctx, locations, opts, win_bias)
	if lctx.line == "" and wctx.col_offset > 0 then
		return
	end

	local idx = 1
	while true do
		local s = lctx.line:sub(idx)
		local b, e = regex.match(s, wctx, lctx, opts)
		if b == nil or e == nil then
			break
		end

		local matched_length = e - b
		if b == e then
			e = e + 1
		end

		local col = idx + b
		if opts.hint_position == hint.HintPosition.MIDDLE then
			col = idx + math.floor((b + e) / 2)
		elseif opts.hint_position == hint.HintPosition.END then
			col = idx + e - 1
		end

		---@type JumpTarget
		local jt = {
			window = wctx.win_handle,
			buffer = wctx.buf_handle,
			cursor = {
				row = lctx.row,
				col = math.max(0, (col - 1) + lctx.col_bias),
			},
			length = math.max(0, matched_length),
		}

		local score = opts.distance_method(wctx.cursor, jt.cursor, opts.x_bias) + win_bias
		if score ~= 0 then
			local len = #locations.jump_targets + 1
			locations.jump_targets[len] = jt
			locations.indirect_jump_targets[len] = { index = len, score = score }
		end

		idx = idx + e
		if idx > #lctx.line or s == "" or regex.oneshot then
			break
		end
	end
end

--- Create a jump-target generator scanning visible windows and lines with `regex`.
---@param regex Regex
---@param win_ctxs? WindowContext[]
---@return Generator
function M.jump_target_generator(regex, win_ctxs)
	---@type Generator
	return function(opts)
		local all_win_ctxs = win_ctxs or window.get_windows_context(opts)
		if opts.current_line_only then
			all_win_ctxs = { all_win_ctxs[1] }
		end

		---@type Locations
		local locations = { jump_targets = {}, indirect_jump_targets = {} }
		local cur_win = api.nvim_get_current_win()

		for _, wctx in ipairs(all_win_ctxs) do
			window.clip_window_context(wctx, opts)
			local win_bias = math.abs(cur_win - wctx.win_handle) * 1000
			for _, lctx in ipairs(window.get_lines_context(wctx)) do
				window.clip_line_context(wctx, lctx, opts)
				scan_line(regex, wctx, lctx, locations, opts, win_bias)
			end
		end

		M.sort_indirect_jump_targets(locations.indirect_jump_targets, opts)
		return locations
	end
end

return M
