--!strict
-- The client's frame, timed by part (ROBLOX-111): what the self-test prints when it samples the frame time, so a Studio run says where a slow frame's time goes.
--
-- The render step's function calls `lap(name)` after each of its parts: the time since the last lap (or the frame's `begin`) is charged to `name`, summed over the
-- frame (a part of the sim's tick runs as many times as the frame has ticks), and at `finish` each name's frame total goes into its mean and its worst. Off (the
-- default, and always for a player: only the self-test turns it on) every call returns at once, so the game pays a function call per lap and nothing else. The
-- clock is os.clock (the engine's high-resolution timer); what is not inside the render step (the engine's rendering and physics, other scripts) is the frame time
-- minus the sum, which the self-test prints beside it.
local FrameProfile = {}

export type Row = { name: string, mean: number, worst: number }

local state = {
	on = false,
	clock = os.clock,
	last = 0,
	began = 0,
	heap = 0, -- (the Lua heap at the last lap, KB: gcinfo)
	alloc = {} :: { [string]: number }, -- (KB allocated by each part over the sample: the heap's growth inside it, a step with a collection in it not counted)
	allocAll = 0,
	frames = 0,
	current = {} :: { [string]: number },
	total = {} :: { [string]: number },
	worst = {} :: { [string]: number },
	order = {} :: { string },
	lua = { total = 0, worst = 0 },
	counts = {} :: { [string]: number }, -- (a number a frame, summed: `count`)
	countOrder = {} :: { string },
}
FrameProfile.state = state

-- Begins counting from nothing (`clock`: a test's own; os.clock otherwise).
function FrameProfile.start(clock: (() -> number)?)
	state.on = true
	state.clock = clock or os.clock
	state.frames = 0
	table.clear(state.current); table.clear(state.total); table.clear(state.worst); table.clear(state.order)
	state.lua.total, state.lua.worst = 0, 0
	table.clear(state.counts); table.clear(state.countOrder)
	table.clear(state.alloc); state.allocAll = 0
end

-- Stops counting; what was counted stays for `rows`.
function FrameProfile.stop()
	state.on = false
end

function FrameProfile.on(): boolean
	return state.on
end

-- The render step's first line.
function FrameProfile.begin()
	if not state.on then return end
	local now = state.clock()
	state.last, state.began = now, now
	state.heap = gcinfo()
	table.clear(state.current)
end

-- The time since the last lap is this part's.
function FrameProfile.lap(name: string)
	if not state.on then return end
	local now = state.clock()
	local cur = state.current
	if cur[name] == nil and state.total[name] == nil then table.insert(state.order, name) end
	cur[name] = (cur[name] or 0) + (now - state.last)
	state.last = now
	local heap = gcinfo()
	local grew = heap - state.heap
	if grew > 0 then state.alloc[name] = (state.alloc[name] or 0) + grew; state.allocAll += grew end
	state.heap = heap
end

-- A number of this frame's (the parts a drawer moved), summed over the frames for its mean.
function FrameProfile.count(name: string, n: number)
	if not state.on then return end
	if state.counts[name] == nil then state.counts[name] = 0; table.insert(state.countOrder, name) end
	state.counts[name] += n
end

-- The render step's last line: the frame's parts into their means and worsts.
function FrameProfile.finish()
	if not state.on then return end
	FrameProfile.lap("other")
	state.frames += 1
	local sum = 0
	for name, t in state.current do
		state.total[name] = (state.total[name] or 0) + t
		state.worst[name] = math.max(state.worst[name] or 0, t)
		sum += t
	end
	state.lua.total += sum
	state.lua.worst = math.max(state.lua.worst, sum)
end

-- Every part counted, in the order first seen, with its mean per frame and its worst frame (milliseconds); and the frames and the whole render step's mean and worst.
function FrameProfile.rows(): ({ Row }, number, number, number)
	local out: { Row } = {}
	local n = math.max(state.frames, 1)
	for _, name in state.order do
		table.insert(out, { name = name, mean = (state.total[name] or 0) / n * 1000, worst = (state.worst[name] or 0) * 1000 })
	end
	return out, state.frames, state.lua.total / n * 1000, state.lua.worst * 1000
end

-- One line: "<part> <mean>/<worst>" for each part over 0.05 ms mean or 1 ms worst (the rest summed as "small"), the step's whole, in milliseconds a frame.
function FrameProfile.line(): string
	local rows, frames, mean, worst = FrameProfile.rows()
	table.sort(rows, function(a, b) return a.mean > b.mean end)
	local parts: { string } = {}
	local small = 0
	for _, row in rows do
		if row.mean >= 0.05 or row.worst >= 1 then
			table.insert(parts, string.format("%s %.2f/%.1f", row.name, row.mean, row.worst))
		else
			small += row.mean
		end
	end
	if small > 0 then table.insert(parts, string.format("small %.2f", small)) end
	-- the allocation: KB a frame, the parts that make over 1 KB a frame
	local n = math.max(frames, 1)
	local heavy: { string } = {}
	for _, name in state.order do
		local kb = (state.alloc[name] or 0) / n
		if kb >= 1 then table.insert(heavy, string.format("%s %.0f", name, kb)) end
	end
	local counts: { string } = {}
	for _, name in state.countOrder do table.insert(counts, string.format("%s %.0f", name, state.counts[name] / math.max(frames, 1))) end
	return string.format("%d frames, the render step %.2f ms a frame (worst %.1f): %s (mean/worst ms)%s; allocated %.0f KB a frame%s", frames, mean, worst,
		table.concat(parts, ", "), if #counts > 0 then "; a frame: " .. table.concat(counts, ", ") else "", state.allocAll / n,
		if #heavy > 0 then " (" .. table.concat(heavy, ", ") .. ")" else "")
end

return FrameProfile
