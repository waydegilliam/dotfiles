---@alias JumpMotionMode "exclusive" | "inclusive" | "linewise"

---@class JumpOptions
---@field keys string
---@field quit_key string
---@field reverse_distribution boolean
---@field x_bias number
---@field distance_method fun(a: CursorPos, b: CursorPos, x_bias: number): number
---@field teasing boolean
---@field virtual_cursor boolean
---@field jump_on_sole_occurrence boolean
---@field case_insensitive boolean
---@field create_hl_autocmd boolean
---@field current_line_only boolean
---@field dim_unmatched boolean
---@field hl_mode "replace" | "combine" | "blend"
---@field uppercase_labels boolean
---@field multi_windows boolean
---@field windows_list fun(): integer[]
---@field ignore_injections boolean
---@field hint_position HintPosition
---@field hint_offset WindowCell
---@field hint_type HintType
---@field excluded_filetypes string[]
---@field passthrough_unmatched_keys boolean
---@field yank_register string
---@field direction? HintDirection
---@field motion_mode? JumpMotionMode

---@class JumpSetupOpts
---@field keys? string
---@field quit_key? string
---@field reverse_distribution? boolean
---@field x_bias? number
---@field distance_method? fun(a: CursorPos, b: CursorPos, x_bias: number): number
---@field teasing? boolean
---@field virtual_cursor? boolean
---@field jump_on_sole_occurrence? boolean
---@field case_insensitive? boolean
---@field create_hl_autocmd? boolean
---@field current_line_only? boolean
---@field dim_unmatched? boolean
---@field hl_mode? "replace" | "combine" | "blend"
---@field uppercase_labels? boolean
---@field multi_windows? boolean
---@field windows_list? fun(): integer[]
---@field ignore_injections? boolean
---@field hint_position? HintPosition
---@field hint_offset? WindowCell
---@field hint_type? HintType
---@field excluded_filetypes? string[]
---@field passthrough_unmatched_keys? boolean
---@field yank_register? string
---@field direction? HintDirection
---@field motion_mode? JumpMotionMode

local hint = require("jump.hint")

---@type JumpOptions
local M = {
	keys = "etovxqpdygfblzhckisuran",
	quit_key = "<Esc>",
	reverse_distribution = false,
	x_bias = 10,
	distance_method = hint.manh_distance,
	teasing = true,
	virtual_cursor = false,
	jump_on_sole_occurrence = true,
	case_insensitive = true,
	create_hl_autocmd = true,
	current_line_only = false,
	dim_unmatched = true,
	hl_mode = "combine",
	uppercase_labels = false,
	multi_windows = false,
	windows_list = function()
		return vim.api.nvim_tabpage_list_wins(0)
	end,
	ignore_injections = false,
	hint_position = hint.HintPosition.BEGIN,
	hint_offset = 0,
	hint_type = hint.HintType.OVERLAY,
	excluded_filetypes = {},
	passthrough_unmatched_keys = false,
	yank_register = "",
}

return M
