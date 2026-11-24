-- Lean, zero-cache Neovim 0.12 colorscheme loader for `github-light`.
local api = vim.api

---@class GithubLightPalette
---@field name string
---@field background "light" | "dark"
---@field terminal table<integer, string>
---@field groups table<string, vim.api.keyset.highlight>

local M = {}

--- Apply a resolved theme palette directly via `vim.api.nvim_set_hl`.
---@param palette? GithubLightPalette
function M.load(palette)
	local theme = palette or require("github_light.palette")

	if vim.g.colors_name then
		vim.cmd("hi clear")
	end
	if vim.fn.exists("syntax_on") == 1 then
		vim.cmd("syntax reset")
	end

	vim.o.termguicolors = true
	vim.o.background = theme.background
	vim.g.colors_name = theme.name

	for idx, color in pairs(theme.terminal) do
		vim.g["terminal_color_" .. idx] = color
	end

	for group, spec in pairs(theme.groups) do
		api.nvim_set_hl(0, group, spec)
	end
end

return M
