-- Treesitter ancestor-node jumping powered by Jump.
local jump = require("jump")
local targets = require("jump.targets")
local api = vim.api

local M = {}

--- Collect deduplicated start/end jump targets for the cursor node and all ancestors.
---@param ignore_injections boolean
---@return Locations
function M.parse(ignore_injections)
	---@type Locations
	local locations = { jump_targets = {}, indirect_jump_targets = {} }
	local cur_win = api.nvim_get_current_win()
	local cur_buf = api.nvim_win_get_buf(cur_win)

	local parser = vim.treesitter.get_parser(cur_buf, nil, { error = false })
	if not parser then
		return locations
	end
	parser:parse()

	local node = vim.treesitter.get_node({ bufnr = cur_buf, ignore_injections = ignore_injections })
	if not node then
		return locations
	end

	---@type table<string, boolean>
	local seen = {}

	---@param row integer 0-based row from TSNode:range()
	---@param col integer 0-based byte col from TSNode:range()
	local function append(row, col)
		local one_based_row = row + 1
		local key = one_based_row .. ":" .. col
		if seen[key] then
			return
		end
		seen[key] = true

		local len = #locations.jump_targets + 1
		locations.jump_targets[len] = {
			buffer = cur_buf,
			cursor = { row = one_based_row, col = col },
			length = 0,
			window = cur_win,
		}
		locations.indirect_jump_targets[len] = { index = len, score = len }
	end

	while node ~= nil do
		local sr, sc, er, ec = node:range()
		append(sr, sc)
		append(er, ec)
		node = node:parent()
	end

	return locations
end

---@return Generator
function M.nodes()
	return function(opts)
		local locations = M.parse(opts.ignore_injections)
		targets.sort_indirect_jump_targets(locations.indirect_jump_targets, opts)
		return locations
	end
end

---@param opts? JumpSetupOpts
function M.hint_nodes(opts)
	local resolved = setmetatable(vim.tbl_extend("force", {}, opts or {}), { __index = jump.opts })
	---@cast resolved JumpOptions
	jump.hint_with(M.nodes(), resolved)
end

return M
