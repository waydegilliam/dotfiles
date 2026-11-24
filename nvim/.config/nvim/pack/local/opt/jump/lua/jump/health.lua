local M = {}

--- Verify Jump configuration health (invoked by `:checkhealth jump`).
function M.check()
	local jump = require("jump")

	vim.health.start("jump")

	if not jump.initialized then
		vim.health.error("jump.setup() has not been called")
		return
	end
	vim.health.ok("Jump is initialized")

	---@type table<string, boolean>
	local existing_keys = {}
	local had_errors = false
	for i = 1, #jump.opts.keys do
		local key = jump.opts.keys:sub(i, i)
		if existing_keys[key] then
			vim.health.error(string.format("key '%s' appears more than once in opts.keys", key))
			had_errors = true
		else
			existing_keys[key] = true
		end
	end

	if not had_errors then
		vim.health.ok(string.format("Keys are unique (%d keys configured)", #jump.opts.keys))
	end
end

return M
