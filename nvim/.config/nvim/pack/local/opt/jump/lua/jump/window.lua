-- Batched window/viewport context and display-cell coordinate helpers.
---@alias WindowRow integer 1-based line row
---@alias WindowCol integer 0-based byte column
---@alias WindowCell integer 0-based displayed screen cell column
---@alias WindowChar integer 0-based character index

---@class CursorPos
---@field row WindowRow
---@field col WindowCol

---@class LineContext
---@field row WindowRow
---@field line string
---@field col_bias WindowCol Byte offset of the left-clipped slice within the buffer line

---@class WindowContext
---@field win_handle integer
---@field buf_handle integer
---@field cursor CursorPos
---@field line_range [WindowRow, WindowRow] [top-inclusive, bottom-inclusive]
---@field column_range [WindowCol, WindowCol] [left-inclusive, right-exclusive)
---@field win_width WindowCell? Visible text width in cells (nil when 'wrap' is enabled)
---@field col_offset WindowCell Horizontal scroll offset (leftcol)
---@field col_first WindowCell Cursor cell column relative to col_offset

local M = {}
local api = vim.api

--- Convert a 0-based display cell column within `line` to a 0-based byte offset.
---@param line string
---@param cell WindowCell
---@return WindowCol
function M.cell_to_byte(line, cell)
	if cell <= 0 or #line == 0 then
		return 0
	end

	local line_width = vim.fn.strdisplaywidth(line)
	if line_width <= cell then
		return #line
	end

	-- Fast path: single-byte ASCII line with no wide chars or tabs.
	if line_width == #line then
		return cell
	end

	local byte_idx = 1
	local width = 0
	local len = #line
	while byte_idx <= len and width < cell do
		local char_end = byte_idx + vim.str_utf_end(line, byte_idx)
		width = width + vim.fn.strdisplaywidth(line:sub(byte_idx, char_end))
		byte_idx = char_end + 1
	end
	return byte_idx - 1
end

--- Convert a 0-based display cell column on a window line to a 0-based byte offset,
--- accounting for tabs, conceal, and multibyte characters via Neovim's C-native virtcol2col.
---@param win_handle integer
---@param row WindowRow
---@param line string
---@param cell WindowCell
---@return WindowCol
function M.win_cell_to_byte(win_handle, row, line, cell)
	if cell <= 0 or #line == 0 then
		return 0
	end
	local col_1based = vim.fn.virtcol2col(win_handle, row, cell + 1)
	if col_1based <= 0 then
		return M.cell_to_byte(line, cell)
	end
	return math.min(col_1based - 1, #line)
end

---@param win_handle integer
---@param buf_handle integer
---@return WindowContext
local function window_context(win_handle, buf_handle)
	local win_info = vim.fn.getwininfo(win_handle)[1]
	local win_view = api.nvim_win_call(win_handle, vim.fn.winsaveview)
	local cursor_pos = api.nvim_win_get_cursor(win_handle)
	---@type CursorPos
	local cursor = { row = cursor_pos[1], col = cursor_pos[2] }

	local bottom_line = api.nvim_buf_get_lines(buf_handle, win_info.botline - 1, win_info.botline, false)[1] or ""
	---@type WindowCell?
	local win_width = not vim.wo[win_handle].wrap and (win_info.width - win_info.textoff) or nil

	local cursor_line = api.nvim_buf_get_lines(buf_handle, cursor.row - 1, cursor.row, false)[1] or ""
	local col_first = vim.fn.strdisplaywidth(cursor_line:sub(1, cursor.col)) - win_view.leftcol

	return {
		win_handle = win_handle,
		buf_handle = buf_handle,
		cursor = cursor,
		line_range = { win_info.topline, win_info.botline },
		column_range = { 0, #bottom_line },
		win_width = win_width,
		col_offset = win_view.leftcol,
		col_first = col_first,
	}
end

--- Collect contexts for all candidate windows (current window is always index 1).
---@param opts JumpOptions
---@return WindowContext[]
function M.get_windows_context(opts)
	local cur_win = api.nvim_get_current_win()
	local contexts = { window_context(cur_win, api.nvim_win_get_buf(cur_win)) }

	if not opts.multi_windows then
		return contexts
	end

	for _, w in ipairs(opts.windows_list()) do
		if w ~= cur_win and api.nvim_win_is_valid(w) and api.nvim_win_get_config(w).focusable then
			local b = api.nvim_win_get_buf(w)
			if not vim.list_contains(opts.excluded_filetypes, vim.bo[b].filetype) then
				contexts[#contexts + 1] = window_context(w, b)
			end
		end
	end

	return contexts
end

--- Collect all visible, unfolded lines of a window in 1 batched buffer read and 1 win_call.
---@param win_ctx WindowContext
---@return LineContext[]
function M.get_lines_context(win_ctx)
	local top, bot = win_ctx.line_range[1], win_ctx.line_range[2]
	local raw_lines = api.nvim_buf_get_lines(win_ctx.buf_handle, top - 1, bot, false)
	---@type LineContext[]
	local lines = {}

	api.nvim_win_call(win_ctx.win_handle, function()
		local lnr = top
		while lnr <= bot do
			local fold_end = vim.fn.foldclosedend(lnr)
			if fold_end == -1 then
				lines[#lines + 1] = {
					row = lnr,
					line = raw_lines[lnr - top + 1] or "",
					col_bias = 0,
				}
			else
				-- Treat folded region as a single empty line so column 0 remains targetable.
				lines[#lines + 1] = { row = lnr, line = "", col_bias = 0 }
				lnr = fold_end
			end
			lnr = lnr + 1
		end
	end)

	return lines
end

---@param win_ctx WindowContext
---@param line_ctx LineContext
---@return boolean
function M.is_active_line(win_ctx, line_ctx)
	return win_ctx.win_handle == api.nvim_get_current_win() and win_ctx.cursor.row == line_ctx.row
end

--- Clip window line/column bounds for `current_line_only` and `direction`.
---@param win_ctx WindowContext
---@param opts JumpOptions
function M.clip_window_context(win_ctx, opts)
	local hint = require("jump.hint")
	local row = win_ctx.cursor.row
	local line = api.nvim_buf_get_lines(win_ctx.buf_handle, row - 1, row, false)[1] or ""

	if opts.current_line_only then
		win_ctx.line_range = { row, row }
		win_ctx.column_range = { 0, #line }
	end

	if opts.direction == hint.HintDirection.BEFORE_CURSOR then
		win_ctx.line_range[2] = row
		win_ctx.column_range[2] = #line > 0 and (win_ctx.cursor.col + 1) or win_ctx.cursor.col
	elseif opts.direction == hint.HintDirection.AFTER_CURSOR then
		win_ctx.line_range[1] = row
		win_ctx.column_range[1] = win_ctx.cursor.col
	end
end

--- Clip a line horizontally to the visible viewport and cursor direction bounds.
---@param win_ctx WindowContext
---@param line_ctx LineContext
---@param opts JumpOptions
function M.clip_line_context(win_ctx, line_ctx, opts)
	local hint = require("jump.hint")
	local line = line_ctx.line

	local left_byte = M.cell_to_byte(line, win_ctx.col_offset)
	local right_byte = win_ctx.win_width ~= nil and M.cell_to_byte(line, win_ctx.col_offset + win_ctx.win_width)
		or #line
	local shifted = line:sub(left_byte + 1, right_byte)
	local col_bias = left_byte

	if line_ctx.row == win_ctx.cursor.row then
		if opts.direction == hint.HintDirection.AFTER_CURSOR then
			shifted = shifted:sub(1 + win_ctx.cursor.col - col_bias)
			col_bias = win_ctx.cursor.col
		elseif opts.direction == hint.HintDirection.BEFORE_CURSOR then
			shifted = shifted:sub(1, 1 + win_ctx.cursor.col - col_bias)
		end
	end

	line_ctx.line = shifted
	line_ctx.col_bias = col_bias
end

return M
