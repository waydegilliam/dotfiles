-- Sourced via `packadd osc52`: initialize OSC 52 integration and register commands/maps.
local api = vim.api
local osc52 = require("osc52")

if not osc52.initialized then
	osc52.setup()
end

api.nvim_create_user_command("OSC52Copy", function(cmd)
	osc52.copy(cmd.args)
end, { nargs = 1 })

api.nvim_create_user_command("OSC52Visual", function()
	osc52.copy_visual()
end, { range = true })

api.nvim_create_user_command("OSC52Register", function(cmd)
	osc52.copy_register(cmd.reg)
end, { register = true })

vim.keymap.set("n", "<Plug>OSC52Operator", function()
	return osc52.operator()
end, { expr = true })

vim.keymap.set("x", "<Plug>OSC52Visual", ":OSC52Visual<CR>", { silent = true })
