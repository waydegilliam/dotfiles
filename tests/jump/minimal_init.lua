-- Minimal init for headless Plenary/busted unit tests for jump.
local this_file = debug.getinfo(1, "S").source:sub(2)
local tests_dir = vim.fn.fnamemodify(this_file, ":p:h")
local repo_root = vim.fn.fnamemodify(tests_dir, ":h:h")
local plugin_root = repo_root .. "/nvim/.config/nvim/pack/local/opt/jump"

local plenary_candidates = {
	os.getenv("PLENARY_DIR"),
	vim.fn.stdpath("data") .. "/plugged/plenary.nvim",
	"/tmp/plenary.nvim",
}

---@type string?
local plenary_dir = nil
for _, candidate in ipairs(plenary_candidates) do
	if candidate and candidate ~= "" and vim.fn.isdirectory(candidate) == 1 then
		plenary_dir = candidate
		break
	end
end

if not plenary_dir then
	plenary_dir = "/tmp/plenary.nvim"
	vim.fn.system({ "git", "clone", "--depth=1", "https://github.com/nvim-lua/plenary.nvim", plenary_dir })
end

vim.opt.swapfile = false
vim.opt.rtp:prepend(plugin_root)
vim.opt.rtp:append(plenary_dir)
package.path = tests_dir .. "/?.lua;" .. package.path

vim.cmd("runtime plugin/plenary.vim")
vim.cmd("runtime plugin/jump.lua")
require("plenary.busted")
