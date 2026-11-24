-- Auto-sourced on startup: initialize Jump with local defaults and register all :Jump* commands.
local user_command = vim.api.nvim_create_user_command
local jump = require("jump")
local yank = require("jump.yank")
local treesitter = require("jump.treesitter")
local direction = require("jump.hint").HintDirection

if not jump.initialized then
	jump.setup()
end

---@param label string
---@param fn fun(opts?: JumpSetupOpts)
---@param include_current_line boolean
local function register_variants(label, fn, include_current_line)
	user_command(label, function()
		fn()
	end, {})

	user_command(label .. "BC", function()
		fn({ direction = direction.BEFORE_CURSOR })
	end, {})

	user_command(label .. "AC", function()
		fn({ direction = direction.AFTER_CURSOR })
	end, {})

	user_command(label .. "MW", function()
		fn({ multi_windows = true })
	end, {})

	if include_current_line then
		user_command(label .. "CurrentLine", function()
			fn({ current_line_only = true })
		end, {})

		user_command(label .. "CurrentLineBC", function()
			fn({ direction = direction.BEFORE_CURSOR, current_line_only = true })
		end, {})

		user_command(label .. "CurrentLineAC", function()
			fn({ direction = direction.AFTER_CURSOR, current_line_only = true })
		end, {})
	end
end

for label, fn in pairs({
	JumpChar1 = jump.hint_char1,
	JumpChar2 = jump.hint_char2,
	JumpWord = jump.hint_words,
	JumpPattern = jump.hint_patterns,
	JumpAnywhere = jump.hint_anywhere,
	JumpCamelCase = jump.hint_camel_case,
	JumpYankChar1 = yank.yank_char1,
	JumpPasteChar1 = yank.paste_char1,
}) do
	register_variants(label, fn, true)
end

for label, fn in pairs({
	JumpLine = jump.hint_lines,
	JumpVertical = jump.hint_vertical,
	JumpLineStart = jump.hint_lines_skip_whitespace,
}) do
	register_variants(label, fn, false)
end

user_command("JumpNodes", function()
	treesitter.hint_nodes()
end, {})
