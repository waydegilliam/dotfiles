local palette = require("github_light.palette")
local api = vim.api
local eq = assert.are.same

describe("github-light:", function()
	before_each(function()
		vim.cmd.colorscheme("github-light")
	end)

	it("loads via :colorscheme github-light with light background and termguicolors", function()
		eq("github-light", vim.g.colors_name)
		eq("light", vim.o.background)
		eq(true, vim.o.termguicolors)
	end)

	it("sets all 16 ANSI terminal colors", function()
		for i = 0, 15 do
			local color = vim.g["terminal_color_" .. i]
			assert.is_true(
				type(color) == "string" and color:match("^#%x%x%x%x%x%x$") ~= nil,
				"invalid terminal_color_" .. i
			)
		end
	end)

	it("applies core editor, syntax, diagnostic, treesitter, nvimtree, and gitsigns highlights", function()
		local normal = api.nvim_get_hl(0, { name = "Normal" })
		eq(0x1f2328, normal.fg)
		eq(0xffffff, normal.bg)

		local comment = api.nvim_get_hl(0, { name = "Comment" })
		eq(0x57606a, comment.fg)

		local diag_err = api.nvim_get_hl(0, { name = "DiagnosticError" })
		eq(0xd1242f, diag_err.fg)

		local ts_param = api.nvim_get_hl(0, { name = "@variable.parameter", link = false })
		assert.is_not_nil(ts_param.fg)

		local nvimtree = api.nvim_get_hl(0, { name = "NvimTreeNormal", link = false })
		eq(0xf6f8fa, nvimtree.bg)

		local gitsigns = api.nvim_get_hl(0, { name = "GitSignsAdd" })
		assert.is_not_nil(gitsigns.fg)

		-- Cleared semantic token group must remain empty so Treesitter variables take precedence.
		eq({}, api.nvim_get_hl(0, { name = "@lsp.type.variable" }))
	end)

	it("defines only valid hex colors and valid highlight links", function()
		for name, spec in pairs(palette.groups) do
			for _, field in ipairs({ "fg", "bg", "sp" }) do
				local val = spec[field]
				if val ~= nil then
					assert.is_true(
						type(val) == "string" and val:match("^#%x%x%x%x%x%x$") ~= nil,
						string.format("invalid %s color on %s: %s", field, name, tostring(val))
					)
				end
			end

			local link = spec.link
			if link ~= nil then
				assert.is_true(type(link) == "string", "non-string link on " .. name)
				if type(link) == "string" then
					assert.is_true(vim.fn.hlexists(link) == 1, string.format("dangling link on %s -> %s", name, link))
				end
			end
		end
	end)
end)
