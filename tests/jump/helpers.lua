local M = {}

--- Temporarily replace `vim.fn.getcharstr` with a deterministic sequence of keys.
--- Restores the original function even if `closure` raises an error.
---@param seq string[]
---@param closure fun(): any
---@return any
function M.override_keyseq(seq, closure)
	local mocked = vim.fn.getcharstr
	local idx = 0

	---@diagnostic disable-next-line: duplicate-set-field
	vim.fn.getcharstr = function()
		idx = idx + 1
		return seq[idx] or vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
	end

	local ok, result = pcall(closure)
	vim.fn.getcharstr = mocked

	if not ok then
		error(result)
	end
	return result
end

return M
