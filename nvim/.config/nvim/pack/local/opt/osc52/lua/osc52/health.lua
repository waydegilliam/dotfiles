local M = {}

--- Verify OSC 52 clipboard configuration (invoked by `:checkhealth osc52`).
function M.check()
	local osc52 = require("osc52")

	vim.health.start("osc52")

	if not osc52.initialized then
		vim.health.error("osc52.setup() has not been called")
		return
	end
	vim.health.ok("osc52 is initialized")

	local env = osc52.detect_env()
	vim.health.info(
		string.format(
			"Environment: rex=%s, ssh=%s, tmux=%s, local_clipboard=%s",
			tostring(env.is_rex),
			tostring(env.is_ssh),
			tostring(env.is_tmux),
			tostring(env.has_local_clipboard)
		)
	)
	vim.health.ok(string.format("Auto-yank integration mode: %s", osc52.mode))

	if env.is_tmux and osc52.opts.tmux_passthrough then
		vim.health.info("tmux DCS passthrough enabled (requires `set -g allow-passthrough on` in tmux.conf)")
	end
end

return M
