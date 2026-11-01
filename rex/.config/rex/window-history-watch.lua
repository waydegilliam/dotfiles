local function send(args)
	args.generation = rex.args.generation
	local result, err = rex.invoke("window_history_watch", args)
	assert(result, err)
	if not result.active then
		rex.stop()
	end
end

local function seed(session_id)
	local view = rex.session.view({ session_id = session_id })
	if view and view.active_window_id then
		send({ event = "seed", session_id = session_id, window_id = view.active_window_id })
	end
end

local function start()
	send({ event = "start" })
	local result, err = rex.call("session.list")
	assert(result, err)
	for _, session in ipairs(result.sessions) do
		seed(session.session_id)
	end
end

rex.on("keymap_changed", start)
rex.on("session_created", function(_, ev)
	seed(ev.session.session_id)
end)
rex.on("active_window_changed", function(ctx, ev)
	if ev.window_id then
		send({ event = "visit", session_id = ctx.session_id, window_id = ev.window_id })
	end
end)
rex.on("session_destroyed", function(_, ev)
	send({ event = "destroy", session_id = ev.session_id })
end)

rex.after(0.2, start)
