-- Prefix-free label generation, hint reduction, and window-scoped ephemeral rendering.
local api = vim.api

---@class Hint
---@field label string?
---@field jump_target JumpTarget

---@class WinRender
---@field wctx WindowContext
---@field hints Hint[]
---@field previews JumpTarget[]

---@class RenderState
---@field by_win table<integer, WinRender>
---@field opts JumpOptions
---@field dim boolean
---@field cursor_win? integer

---@class HintState
---@field buf_list integer[]
---@field all_ctxs WindowContext[]
---@field hints Hint[]

local M = {}

---@enum HintDirection
M.HintDirection = {
	BEFORE_CURSOR = 1,
	AFTER_CURSOR = 2,
}

---@enum HintPosition
M.HintPosition = {
	BEGIN = 1,
	MIDDLE = 2,
	END = 3,
}

---@alias HintType "overlay" | "inline"

---@type { OVERLAY: "overlay", INLINE: "inline" }
M.HintType = {
	OVERLAY = "overlay",
	INLINE = "inline",
}

---@enum HintPriority
M.HintPriority = {
	DIM = 65533,
	HINT = 65534,
	CURSOR = 65535,
}

--- Single namespace for window-scoped ephemeral decoration provider rendering.
M.NS = api.nvim_create_namespace("jump")

---@type RenderState?
local active_render = nil

---@type table<string, table<integer, string[]>>
local label_cache = {}

--- Split `keys` into individual UTF-8 key strings.
---@param keys string
---@return string[]
local function split_keys(keys)
	---@type string[]
	local out = {}
	local i = 1
	local len = #keys
	while i <= len do
		local char_end = i + vim.str_utf_end(keys, i)
		out[#out + 1] = keys:sub(i, char_end)
		i = char_end + 1
	end
	return out
end

--- Generate `n` unique, prefix-free labels over `keys`, assigning shortest labels first.
--- Cached by `(keys, n)` so repeated jumps avoid allocations.
---@param keys string
---@param n integer
---@return string[]
function M.generate_labels(keys, n)
	if n <= 0 then
		return {}
	end

	local by_keys = label_cache[keys]
	if by_keys and by_keys[n] then
		return by_keys[n]
	end

	local alphabet = split_keys(keys)
	local m = #alphabet
	if m == 0 then
		return {}
	end
	if m == 1 then
		return { alphabet[1] }
	end

	-- Maintain `front` (current shorter length) and `back` (expanded +1 length).
	-- Expanding from the tail of `front` preserves the shortest labels for the closest targets.
	---@type string[]
	local front = vim.list_slice(alphabet)
	---@type string[]
	local back = {}

	while #front + #back < n do
		if #front == 0 then
			front = back
			back = {}
		end
		local prefix = table.remove(front)
		for _, k in ipairs(alphabet) do
			back[#back + 1] = prefix .. k
		end
	end

	---@type string[]
	local labels = {}
	for _, label in ipairs(front) do
		labels[#labels + 1] = label
		if #labels == n then
			break
		end
	end
	for _, label in ipairs(back) do
		if #labels == n then
			break
		end
		labels[#labels + 1] = label
	end

	if not by_keys then
		by_keys = {}
		label_cache[keys] = by_keys
	end
	by_keys[n] = labels
	return labels
end

--- Manhattan distance weighted on row so hints pack tightly near the cursor line.
---@param a CursorPos
---@param b CursorPos
---@param x_bias number
---@return number
function M.manh_distance(a, b, x_bias)
	return (x_bias * math.abs(b.row - a.row)) + math.abs(b.col - a.col)
end

--- Left-to-right reading order distance.
---@param a CursorPos
---@param b CursorPos
---@return number
function M.readwise_distance(a, b)
	return (100 * math.abs(b.row - a.row)) + (b.col - a.col)
end

--- Reduce all hints by leading `key`, returning a terminal hint if matched plus remaining hints.
---@param hints Hint[]
---@param key string
---@return Hint?, Hint[]
function M.reduce_hints(hints, key)
	---@type Hint[]
	local next_hints = {}

	for _, h in ipairs(hints) do
		local label = h.label
		if label ~= nil then
			local snd_idx = vim.str_byteindex(label, "utf-32", 1)
			if label:sub(1, snd_idx) == key then
				local rest = label:sub(snd_idx + 1)
				if rest == "" then
					h.label = nil
					return h, {}
				end
				h.label = rest
				next_hints[#next_hints + 1] = h
			end
		end
	end

	return nil, next_hints
end

--- Associate jump targets with prefix-free labels according to indirect score order.
---@param jump_targets JumpTarget[]
---@param indirect_jump_targets IndirectJumpTarget[]?
---@param opts JumpOptions
---@return Hint[]
function M.create_hints(jump_targets, indirect_jump_targets, opts)
	---@type Hint[]
	local hints = {}
	local labels = M.generate_labels(opts.keys, #jump_targets)

	if indirect_jump_targets == nil then
		for i, jt in ipairs(jump_targets) do
			hints[i] = { label = labels[i], jump_target = jt }
		end
		return hints
	end

	for i, indirect in ipairs(indirect_jump_targets) do
		hints[indirect.index] = {
			label = labels[i],
			jump_target = jump_targets[indirect.index],
		}
	end

	return hints
end

--- Create a fresh hint state for all candidate windows.
---@param opts JumpOptions
---@return HintState
function M.create_hint_state(opts)
	local window = require("jump.window")
	local all_ctxs = window.get_windows_context(opts)
	---@type integer[]
	local buf_list = {}
	---@type table<integer, boolean>
	local seen = {}

	for _, wctx in ipairs(all_ctxs) do
		if not seen[wctx.buf_handle] then
			seen[wctx.buf_handle] = true
			buf_list[#buf_list + 1] = wctx.buf_handle
		end
		window.clip_window_context(wctx, opts)
	end

	return {
		all_ctxs = all_ctxs,
		buf_list = buf_list,
		hints = {},
	}
end

--- Paint the virtual cursor extmark (ephemeral) inside the active window.
---@param bufnr integer
local function render_virtual_cursor(bufnr)
	local cur_info = vim.fn.getcurpos()
	local cur_row = cur_info[2] - 1
	local cur_col = cur_info[3] - 1
	local cur_offset = cur_info[4]
	local virt_col = cur_info[5] - 1
	local cur_line = api.nvim_get_current_line()

	if cur_offset ~= 0 or #cur_line == cur_col then
		api.nvim_buf_set_extmark(bufnr, M.NS, cur_row, cur_col, {
			virt_text = { { "█", "Normal" } },
			virt_text_win_col = virt_col,
			priority = M.HintPriority.CURSOR,
			ephemeral = true,
		})
	else
		local char_end = cur_col + vim.str_utf_end(cur_line, cur_col + 1) + 1
		api.nvim_buf_set_extmark(bufnr, M.NS, cur_row, cur_col, {
			end_col = math.min(char_end, #cur_line),
			hl_group = "JumpCursor",
			priority = M.HintPriority.CURSOR,
			ephemeral = true,
		})
	end
end

-- Register a single decoration provider once; returns false immediately when Jump is idle.
api.nvim_set_decoration_provider(M.NS, {
	on_start = function()
		return active_render ~= nil
	end,
	on_win = function(_, winid, bufnr)
		if not active_render then
			return false
		end
		local wr = active_render.by_win[winid]
		if not wr or wr.wctx.buf_handle ~= bufnr then
			return false
		end

		local opts = active_render.opts
		if active_render.dim and opts.dim_unmatched then
			local wctx = wr.wctx
			local start_row = wctx.line_range[1] - 1
			local end_row = wctx.line_range[2] - 1
			local start_line = api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
			local end_line = api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ""
			api.nvim_buf_set_extmark(bufnr, M.NS, start_row, math.min(wctx.column_range[1], #start_line), {
				end_row = end_row,
				end_col = math.min(wctx.column_range[2], #end_line),
				hl_group = "JumpUnmatched",
				hl_eol = true,
				priority = M.HintPriority.DIM,
				ephemeral = true,
			})

			if opts.virtual_cursor and winid == active_render.cursor_win then
				render_virtual_cursor(bufnr)
			end
		end

		for _, jt in ipairs(wr.previews) do
			local row = jt.cursor.row - 1
			local col = jt.cursor.col
			api.nvim_buf_set_extmark(bufnr, M.NS, row, col, {
				end_row = row,
				end_col = col + jt.length,
				hl_group = "JumpPreview",
				hl_eol = true,
				priority = M.HintPriority.HINT,
				ephemeral = true,
			})
		end

		for _, h in ipairs(wr.hints) do
			local label = h.label
			if label ~= nil then
				if opts.uppercase_labels then
					label = label:upper()
				end

				---@type [string, string][]
				local virt_text = { { label, "JumpNextKey" } }
				if vim.fn.strdisplaywidth(label) ~= 1 then
					local snd_idx = vim.str_byteindex(label, "utf-32", 1)
					virt_text = {
						{ label:sub(1, snd_idx), "JumpNextKey1" },
						{ label:sub(snd_idx + 1), "JumpNextKey2" },
					}
				end

				api.nvim_buf_set_extmark(bufnr, M.NS, h.jump_target.cursor.row - 1, h.jump_target.cursor.col, {
					virt_text = virt_text,
					virt_text_pos = opts.hint_type,
					hl_mode = opts.hl_mode,
					priority = M.HintPriority.HINT,
					ephemeral = true,
				})
			end
		end

		return false
	end,
})

--- Update the active window-scoped render state for the decoration provider.
---@param hint_state HintState
---@param opts JumpOptions
---@param params? { dim?: boolean, hints?: Hint[], previews?: JumpTarget[] }
function M.set_render(hint_state, opts, params)
	params = params or {}
	---@type table<integer, WinRender>
	local by_win = {}

	for _, wctx in ipairs(hint_state.all_ctxs) do
		by_win[wctx.win_handle] = { wctx = wctx, hints = {}, previews = {} }
	end

	for _, h in ipairs(params.hints or {}) do
		local wr = by_win[h.jump_target.window]
		if wr then
			wr.hints[#wr.hints + 1] = h
		end
	end

	for _, jt in ipairs(params.previews or {}) do
		local wr = by_win[jt.window]
		if wr then
			wr.previews[#wr.previews + 1] = jt
		end
	end

	active_render = {
		by_win = by_win,
		opts = opts,
		dim = params.dim ~= false,
		cursor_win = api.nvim_get_current_win(),
	}
end

--- Clear the active render state so the decoration provider becomes a no-op.
function M.clear_render()
	active_render = nil
end

--- Inspect the active render state (primarily for unit tests).
---@return RenderState?
function M.get_render()
	return active_render
end

return M
