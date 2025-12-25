local M = {}

local startup_buf = nil

local function center(str)
	local width = vim.api.nvim_win_get_width(0)
	local pad = math.floor((width - #str) / 2)
	return string.rep(" ", pad) .. str
end

function M.render()
	if not startup_buf or not vim.api.nvim_buf_is_valid(startup_buf) then
		return
	end

	local v = vim.version()
	local version_str = string.format("NVIM v%d.%d.%d", v.major, v.minor, v.patch)

	local plug_dir = vim.fn.expand("~/.local/share/nvim/plugged")
	local plugins = vim.fn.glob(plug_dir .. "/*", false, true)
	local plug_count = #plugins
	local plug_status = plug_count > 0 and string.format("Plugins: %d installed", plug_count)
		or "Plugins: run :PlugInstall"

	local content = { center(version_str), "", center(plug_status) }
	local height = vim.api.nvim_win_get_height(0)
	local top_pad = math.floor((height - #content) / 2)
	local lines = {}
	for _ = 1, top_pad do
		table.insert(lines, "")
	end
	for _, line in ipairs(content) do
		table.insert(lines, line)
	end

	vim.bo[startup_buf].modifiable = true
	vim.api.nvim_buf_set_lines(startup_buf, 0, -1, false, lines)
	vim.bo[startup_buf].modifiable = false
end

function M.setup()
	if vim.fn.argc() > 0 then
		return
	end

	startup_buf = vim.api.nvim_get_current_buf()
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.swapfile = false
	vim.wo.number = false
	vim.wo.relativenumber = false
	vim.wo.signcolumn = "no"
	vim.wo.cursorline = false

	M.render()

	vim.api.nvim_create_autocmd("BufEnter", {
		once = true,
		callback = function()
			M.restore_options()
		end,
	})
end

function M.restore_options()
	if startup_buf and vim.api.nvim_get_current_buf() ~= startup_buf then
		vim.wo.number = true
		vim.wo.signcolumn = "yes"
		vim.wo.cursorline = true
		startup_buf = nil
	end
end

return M
