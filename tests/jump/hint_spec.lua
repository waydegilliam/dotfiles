local jump_hint = require("jump.hint")
local eq = assert.are.same

describe("Jump prefix-free label generator and hint reduction:", function()
	it("generates exact count of unique, prefix-free, shortest-first labels and caches results", function()
		local keys = "asd"

		for _, count in ipairs({ 1, 3, 4, 9, 15, 40 }) do
			local labels = jump_hint.generate_labels(keys, count)
			eq(count, #labels)

			---@type table<string, boolean>
			local seen = {}
			local prev_len = 0
			for _, label in ipairs(labels) do
				assert.is_nil(seen[label], "duplicate label: " .. label)
				seen[label] = true
				assert.is_true(#label >= prev_len, "labels must be ordered shortest-first")
				prev_len = #label
			end

			for i, a in ipairs(labels) do
				for j, b in ipairs(labels) do
					if i ~= j then
						assert.is_false(b:sub(1, #a) == a, string.format("label '%s' is a prefix of '%s'", a, b))
					end
				end
			end
		end

		-- Cache returns the exact same table reference for identical (keys, n).
		local first = jump_hint.generate_labels(keys, 15)
		local second = jump_hint.generate_labels(keys, 15)
		assert.is_true(first == second)
	end)

	it("reduces multi-key hints step by step to a terminal match", function()
		---@type JumpTarget
		local jt1 = { window = 0, buffer = 0, cursor = { row = 1, col = 0 }, length = 1 }
		---@type JumpTarget
		local jt2 = { window = 0, buffer = 0, cursor = { row = 1, col = 5 }, length = 1 }
		---@type JumpTarget
		local jt3 = { window = 0, buffer = 0, cursor = { row = 2, col = 0 }, length = 1 }

		---@type Hint[]
		local hints = {
			{ label = "a", jump_target = jt1 },
			{ label = "sa", jump_target = jt2 },
			{ label = "sd", jump_target = jt3 },
		}

		local matched, remaining = jump_hint.reduce_hints(hints, "s")
		assert.is_nil(matched)
		eq(2, #remaining)
		eq("a", remaining[1].label)
		eq("d", remaining[2].label)

		local final_match, empty = jump_hint.reduce_hints(remaining, "d")
		assert.is_not_nil(final_match)
		if final_match then
			eq(jt3, final_match.jump_target)
		end
		eq(0, #empty)
	end)
end)
