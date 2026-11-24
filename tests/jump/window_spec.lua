local jump_hint = require("jump.hint")
local jump_window = require("jump.window")
local jump_targets = require("jump.targets")
local jump_defaults = require("jump.defaults")
local api = vim.api
local eq = assert.are.same

describe("Jump window and offsets:", function()
	before_each(function()
		vim.cmd.enew({ bang = true })
	end)

	it("cell_to_byte handles multibyte wide characters", function()
		local line = "abcd测试ABCD"

		eq("d测试ABCD", line:sub(jump_window.cell_to_byte(line, 3) + 1))
		eq("ABCD", line:sub(jump_window.cell_to_byte(line, 7) + 1))
		eq("ABCD", line:sub(jump_window.cell_to_byte(line, 8) + 1))
		eq("", line:sub(jump_window.cell_to_byte(line, 99) + 1))
	end)

	it("clips window context for direction and current_line_only", function()
		api.nvim_buf_set_lines(0, 0, -1, false, {
			"line one",
			"line two here",
			"line three",
		})
		api.nvim_win_set_cursor(0, { 2, 5 })

		---@type JumpOptions
		local opts_after = vim.tbl_extend("force", {}, jump_defaults, {
			direction = jump_hint.HintDirection.AFTER_CURSOR,
		})
		local ctx_after = jump_window.get_windows_context(opts_after)[1]
		jump_window.clip_window_context(ctx_after, opts_after)
		eq(2, ctx_after.line_range[1])
		eq(5, ctx_after.column_range[1])

		---@type JumpOptions
		local opts_line = vim.tbl_extend("force", {}, jump_defaults, {
			current_line_only = true,
		})
		local ctx_line = jump_window.get_windows_context(opts_line)[1]
		jump_window.clip_window_context(ctx_line, opts_line)
		eq({ 2, 2 }, ctx_line.line_range)
		eq({ 0, 13 }, ctx_line.column_range)
	end)

	it("batches visible lines and skips folded lines", function()
		local buf = api.nvim_get_current_buf()
		api.nvim_buf_set_lines(buf, 0, -1, false, {
			"line 1",
			"fold start",
			"fold mid",
			"fold end",
			"line 5",
		})
		vim.wo.foldenable = true
		vim.wo.foldmethod = "manual"
		vim.cmd("2,4fold")

		local wctx = jump_window.get_windows_context(jump_defaults)[1]
		local lines = jump_window.get_lines_context(wctx)
		eq(3, #lines)
		eq({ row = 1, line = "line 1", col_bias = 0 }, lines[1])
		eq({ row = 2, line = "", col_bias = 0 }, lines[2])
		eq({ row = 5, line = "line 5", col_bias = 0 }, lines[3])
	end)

	it("move_jump_target computes tab-accurate column offsets", function()
		local buf = api.nvim_get_current_buf()
		local win = api.nvim_get_current_win()
		vim.bo[buf].tabstop = 4
		api.nvim_buf_set_lines(buf, 0, -1, false, { "\tabcd" })

		---@type JumpTarget
		local jt = { window = win, buffer = buf, cursor = { row = 1, col = 1 }, length = 1 }
		-- From 'a' (byte 1, cell 4), +2 cells lands on 'c' (byte 3).
		jump_targets.move_jump_target(jt, 0, 2)
		eq(3, jt.cursor.col)

		-- From 'c' (byte 3, cell 6), -3 cells lands inside the tab (byte 0).
		jump_targets.move_jump_target(jt, 0, -3)
		eq(0, jt.cursor.col)
	end)
end)
