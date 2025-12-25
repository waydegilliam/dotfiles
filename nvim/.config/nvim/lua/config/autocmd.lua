-- Startup screen
vim.api.nvim_create_augroup("StartupScreen", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
	group = "StartupScreen",
	callback = function()
		require("config.ui.startup").setup()
	end,
})
vim.api.nvim_create_autocmd("VimResized", {
	group = "StartupScreen",
	callback = function()
		require("config.ui.startup").render()
	end,
})
vim.api.nvim_create_autocmd("BufEnter", {
	group = "StartupScreen",
	callback = function()
		require("config.ui.startup").restore_options()
	end,
})

-- Reload statusline on window/buffer change
vim.api.nvim_create_augroup("Statusline", { clear = true })
vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
	group = "Statusline",
	callback = function()
		require("config.ui.statusline").setup()
	end,
})

-- Reload winbar on window/buffer change
vim.api.nvim_create_augroup("Winbar", { clear = true })
vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
	group = "Winbar",
	callback = function()
		require("config.ui.winbar").setup()
	end,
})

-- Highlight yank
vim.api.nvim_create_augroup("HighlightYank", { clear = true })
vim.api.nvim_create_autocmd({ "TextYankPost" }, {
	group = "HighlightYank",
	callback = function()
		vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
	end,
})

-- Set tmux filetype for all tmux conf files
vim.api.nvim_create_augroup("TmuxConf", { clear = true })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = "TmuxConf",
	pattern = "*/.config/tmux/conf/*.conf",
	callback = function()
		vim.bo.filetype = "tmux"
	end,
})

-- Reload tabline on tab change
vim.api.nvim_create_augroup("Tabline", { clear = true })
vim.api.nvim_create_autocmd({ "TabEnter" }, {
	group = "Tabline",
	callback = function()
		require("config.ui.tabline").setup()
	end,
})

-- Set sh filetype for all .env files
vim.api.nvim_create_augroup("EnvFiletype", { clear = true })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = "EnvFiletype",
	pattern = { "*.env", ".env.*" },
	callback = function()
		vim.bo.filetype = "sh"
	end,
})

-- Set json filetype for all .geojson files
vim.api.nvim_create_augroup("GeojsonFiletype", { clear = true })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	group = "GeojsonFiletype",
	pattern = { "*.geojson" },
	callback = function()
		vim.bo.filetype = "json"
	end,
})

-- Yank all text to system clipboard if on SSH client
local SSH_CLIENT = os.getenv("SSH_CLIENT")
if SSH_CLIENT and SSH_CLIENT ~= "" then
	vim.api.nvim_create_augroup("OSCYankEverything", { clear = true })
	vim.api.nvim_create_autocmd({ "TextYankPost" }, {
		group = "OSCYankEverything",
		callback = function()
			vim.cmd('OSCYankRegister "')
		end,
	})
end
