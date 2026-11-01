local history = { windows = {}, index = 0, pending = {} }
local active_windows = {}
local watcher_generation = {}
local last_navigation

local function record(session_id, window_id)
	local current = history.windows[history.index]
	if not current or current.window_id ~= window_id then
		for index = #history.windows, history.index + 1, -1 do
			history.windows[index] = nil
		end
		history.index = history.index + 1
		history.windows[history.index] = { session_id = session_id, window_id = window_id }
	end
end

rex.action({
	name = "window_history_watch",
	title = "Track Window History",
	args = { event = "string", generation = "string?", session_id = "string?", window_id = "string?" },
	run = function(_, args)
		if args.generation ~= tostring(watcher_generation) then
			return { active = false }
		end
		if args.event == "start" then
			return { active = true }
		elseif args.event == "status" then
			return { active = true, history = history, last_navigation = last_navigation }
		elseif args.event == "seed" then
			active_windows[assert(args.session_id, "session_id is required")] =
				assert(args.window_id, "window_id is required")
		elseif args.event == "visit" then
			local session_id = assert(args.session_id, "session_id is required")
			local window_id = assert(args.window_id, "window_id is required")
			local previous_window_id = active_windows[session_id]
			active_windows[session_id] = window_id
			if history.pending[window_id] then
				history.pending[window_id] = history.pending[window_id] - 1
				if history.pending[window_id] == 0 then
					history.pending[window_id] = nil
				end
			else
				if history.index == 0 and previous_window_id then
					record(session_id, previous_window_id)
				end
				record(session_id, window_id)
			end
		elseif args.event == "destroy" then
			active_windows[assert(args.session_id, "session_id is required")] = nil
		else
			error("Unknown window history event: " .. args.event)
		end
		return { active = true }
	end,
})

local function navigate(ctx, direction)
	last_navigation = { ctx = ctx, direction = direction }
	local view, err = rex.session.view({})
	assert(view, err)
	if not view.active_window_id then
		return
	end
	record(ctx.session_id, view.active_window_id)
	local index = history.index + direction
	while index > 0 and index <= #history.windows do
		local entry = history.windows[index]
		local target_view = view
		if entry.session_id ~= ctx.session_id then
			target_view = rex.session.view({ session_id = entry.session_id })
		end
		local open = false
		if target_view then
			for _, window in ipairs(target_view.windows) do
				if window.window_id == entry.window_id then
					open = true
					break
				end
			end
		end
		if open and entry.window_id ~= view.active_window_id then
			local previous_index = history.index
			history.index = index
			if target_view.active_window_id ~= entry.window_id then
				history.pending[entry.window_id] = (history.pending[entry.window_id] or 0) + 1
				local result, focus_err = rex.session.focus_window(entry)
				if not result then
					history.index = previous_index
					history.pending[entry.window_id] = history.pending[entry.window_id] - 1
					if history.pending[entry.window_id] == 0 then
						history.pending[entry.window_id] = nil
					end
					error(focus_err)
				end
			end
			rex.client.queue("session.select", entry)
			return
		end
		index = index + direction
	end
end

rex.action({
	name = "window_history_back",
	title = "Go Back in Window History",
	category = "Tab",
	run = function(ctx)
		navigate(ctx, -1)
	end,
})

rex.action({
	name = "window_history_forward",
	title = "Go Forward in Window History",
	category = "Tab",
	run = function(ctx)
		navigate(ctx, 1)
	end,
})

local directory = debug.getinfo(1, "S").source:match("^@?(.*/)")
local executable = "rex"
local macos_executable = os.getenv("HOME")
	.. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
local binary = io.open(macos_executable, "r")
if binary then
	binary:close()
	executable = macos_executable
end
local watcher, err = rex.exec.start({
	executable,
	"do",
	directory .. "window-history-watch.lua",
	"--all",
	"--fail-fast",
	"generation=" .. tostring(watcher_generation),
}, {
	detach = true,
	stdout = false,
	stderr = false,
})
assert(watcher, err)
