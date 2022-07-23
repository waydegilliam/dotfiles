local M = {}

M.winbar_filetype_exclude = { "", "NvimTree", "help" }

local function get_filename()
	return "%f"
end

M.setup = function()
	if vim.tbl_contains(M.winbar_filetype_exclude, vim.bo.filetype) then
		vim.opt_local.winbar = nil
		return
	end

	vim.opt_local.winbar = get_filename()
end

return M
