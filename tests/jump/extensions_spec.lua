local jump = require("jump")
local jump_yank = require("jump.yank")
local jump_ts = require("jump.treesitter")
local api = vim.api
local eq = assert.are.same

describe("Jump yank and treesitter extensions:", function()
	before_each(function()
		vim.cmd.enew({ bang = true })
		jump.setup()
	end)

	it("registers JumpYankChar1, JumpPasteChar1, and JumpNodes user commands", function()
		local cmds = api.nvim_get_commands({})
		assert.is_not_nil(cmds.JumpYankChar1)
		assert.is_not_nil(cmds.JumpPasteChar1)
		assert.is_not_nil(cmds.JumpNodes)
	end)

	it("jump.yank extracts text for forward and reversed bounds and pastes into buffer", function()
		local buf = api.nvim_get_current_buf()
		api.nvim_buf_set_lines(buf, 0, -1, false, {
			"hello world",
		})

		---@type JumpTarget
		local t_start = { window = 0, buffer = buf, cursor = { row = 1, col = 0 }, length = 1 }
		---@type JumpTarget
		local t_end = { window = 0, buffer = buf, cursor = { row = 1, col = 4 }, length = 1 }

		eq({ "hello" }, jump_yank.get_text(t_start, t_end))
		eq({ "hello" }, jump_yank.get_text(t_end, t_start))

		jump_yank.yank_to({ "!" }, "a")
		---@type JumpTarget
		local t_paste = { window = 0, buffer = buf, cursor = { row = 1, col = 10 }, length = 1 }
		jump_yank.paste_from(t_paste, "a")
		eq({ "hello world!" }, api.nvim_buf_get_lines(buf, 0, -1, false))
	end)

	it("jump.treesitter returns empty locations gracefully when buffer has no parser", function()
		local buf = api.nvim_get_current_buf()
		vim.bo[buf].filetype = ""
		api.nvim_buf_set_lines(buf, 0, -1, false, { "plain text without parser" })
		api.nvim_win_set_cursor(0, { 1, 0 })

		local locations = jump_ts.parse(false)
		eq(0, #locations.jump_targets)
		eq(0, #locations.indirect_jump_targets)
	end)

	it("jump.treesitter extracts unique ancestor node targets on a Lua buffer", function()
		local buf = api.nvim_get_current_buf()
		vim.bo[buf].filetype = "lua"
		api.nvim_buf_set_lines(buf, 0, -1, false, {
			"local function greet(name)",
			"  return 'hi ' .. name",
			"end",
		})
		api.nvim_win_set_cursor(0, { 2, 18 })

		local locations = jump_ts.parse(false)
		assert.is_true(#locations.jump_targets > 0)

		---@type table<string, boolean>
		local seen = {}
		for _, jt in ipairs(locations.jump_targets) do
			local key = jt.cursor.row .. ":" .. jt.cursor.col
			assert.is_nil(seen[key], "duplicate treesitter target at " .. key)
			seen[key] = true
		end
	end)
end)
