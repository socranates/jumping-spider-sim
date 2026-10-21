--!strict
-- The live place's self-test (ROBLOX-104): a run of the real client inside a real Studio Play session, which prints what it finds to Output, so every publish can be
-- checked in the real engine by someone who can press Play but cannot play. It runs only in Studio and only when the Workspace attribute SelfTest is true (set from the
-- command bar before Play: workspace:SetAttribute("SelfTest", true)); the client asks for it in one line at its end and hands it the same hooks the test place's
-- playback gets. Off, nothing of it runs and nothing of it is loaded; a player can never reach it (start refuses outside Studio, whatever the attribute says).
--
-- It begins a new life itself (the start menu's "Begin a new life", the same choice a click makes), then walks the checks below, each in its own pcall so an error is a
-- FAIL and never the end of the run. Every line begins with [SELFTEST]:
--   PASS <name> / FAIL <name>: <why> / SKIP <name>: <why>   one per check
--   INFO <what>: <numbers>                                    the frame times and part counts (numbers, not a verdict), and what a check measured
--   ... <name> (<t> s in)                                      a heartbeat every HEARTBEAT_S seconds of waiting, so a hang shows where it hung
--   END pass=<n> fail=<m> skip=<k>                             always the last line
-- The checks: the intro of a new life (ROBLOX-109: playing after the new life, or begun through its hook in the test place, which has no start menu; its skip refused
-- before two seconds and taken after, the controls and the camera back, the spider standing out of the crack); the World folder and every region's folder; for every region, its boxes all there once the spider is held at its spawn (streaming, with a deadline), ground
-- under the spider there and the spider still there a second later, and the region the client's world reports; a walk on the sill; a let-down on the line from the outer
-- sill's front edge at about 0.75 studs a second, on the line all the way; the sill's flies, the bed's gnats, aphids, springtails and leafhoppers and the wall's moths made
-- and drawn under the fly's part budget; the lock (ROBLOX-110: Recentre locks onto a fly the spider sees, the body turns to it, the sidestep, and lets go); the woodlice made and drawn; the notebook opened and closed; the clock put to dusk and the moths flying; a rest in the crack,
-- its checkpoint kept and returned to; the music playing and the room tone silent; the frame time over five seconds on the sill and in the bed; the parts in the workspace.
-- ROBLOX-111: it is also the frame's profiler. Each frame sample prints the client's render step timed by part (Client/FrameProfile), the engine's memory and part
-- counts and a census of what is drawn; the bed is sampled again once its looks are made, then without the looks and without shadows; the let-down is profiled,
-- prints what the line did (SilkController's counts) and is judged in the game's time.
-- ROBLOX-115 (two worlds): it runs on the world the place runs (the Workspace attribute World). In the test garden, everything above; in the preserve, whose only
-- walkable place is the ranger hut's sill, the garden's checks (the line from the outer sill, the bed's prey and woodlice and frames, the wall's moths) give way to
-- the hut's sill (its boxes whole, the Decor without the test garden's view, the hut's look held whole at the tier's detail) and the backdrop near and far (the
-- looks planned at the sill hold the hut whole and the railway far; planned at the railway's crest, the railway whole and the hut back to its far look; then
-- planned at the sill again, as they were) and the trains (a pass's cars drawn on the line). The lock is taken with a controller's L2 tap too (ROBLOX-115).
-- ROBLOX-117: in the preserve also the garden's near detail (the patches drawn by the spider in the mulch within the budgets, the dew shown at dawn and gone by noon) and the
-- garden's rival and mate (each put where it comes into the garden, the spider beside its cell: it walks there, in the garden; both put back after).
-- ROBLOX-118: in the preserve also the ceiling and the upper walls (up the west wall past 1.3 m, round onto the ceiling's underside, hanging there), the back room (through the
-- doorway, its sofa, the television's unit, the games' shelf and the window sill hold a spider, the gap under the sofa a home), the eaves (along the gutter from region to region)
-- and the cat (held off the rest of the run: heard and moving on a walk of its day; at a stop on the floor it notices a spider walking in front of it and crouches to pat,
-- and gives up once the spider is up on the desk; on the sim, its pat lands as a death in the standard rules and a knock aside in the gentle ones).
-- Each Studio process writes its own log (%LOCALAPPDATA%\Roblox\logs); tools/studio/selftest.ps1 reads the newest for these lines.
-- The CLI suite tests/selftest.luau runs the same checks against the real client on the shim's box world, with a host of its own (simulated frames and clock), so the run is
-- proven to complete and print END before it ever reaches Studio. First run in Studio at v36 (33 of 34; the line failed, ROBLOX-111); ROBLOX-111's additions not yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldMap = require(Shared:WaitForChild("World"):WaitForChild("WorldMap"))
local Region = require(Shared:WaitForChild("World"):WaitForChild("Region"))
local Preserve = require(Shared:WaitForChild("World"):WaitForChild("Preserve"))
local Species = require(Shared:WaitForChild("Data"):WaitForChild("Species"))
local LookPlan = require(Shared:WaitForChild("World"):WaitForChild("LookPlan"))
local RivalSpider = require(Shared:WaitForChild("Predator"):WaitForChild("RivalSpider"))
local Mate = require(Shared:WaitForChild("Predator"):WaitForChild("Mate"))
local BugBodies = require(script.Parent.BugBodies)

local SelfTest = {}

SelfTest.PREFIX = "[SELFTEST]"
-- A heartbeat line at least this often (seconds) while a check waits.
SelfTest.HEARTBEAT_S = 5
-- How long the start may take to offer a new life (the server's save reply, the sill streaming in), and a region to arrive whole once the spider is held there.
SelfTest.LIFE_WAIT = 45
SelfTest.REGION_WAIT = 30
-- The most parts a drawn prey may have (the fly's budget, tests/flies.luau) and a drawn woodlouse (BugBodies.PARTS).
SelfTest.FLY_PARTS = 40
-- The let-down on the line (ROBLOX-99: SilkController.game, half Godot's 1.5) and the band a measure of it must fall in.
SelfTest.LOWER = 0.75
SelfTest.LOWER_BAND = { 0.6, 0.9 }
-- How long the frame time is sampled in each place, and how long the dusk's moths are given to take wing.
SelfTest.SAMPLE_S = 5
SelfTest.DUSK_WAIT = 30
-- ROBLOX-111: how long the looks near the bed are given to be made, and each of the bed's two comparisons (the looks out, the shadows off) is sampled.
SelfTest.SETTLE_WAIT = 20
SelfTest.AB_S = 3
-- Places on the map the checks use (the motor's body centre, Motor.HEIGHT above the support): the open sill floor, the crack, the outer sill's front edge and the bed's soil.
SelfTest.SILL = Vector3.new(-5, 0.31, -9)
SelfTest.CRACK = Vector3.new(-25.5, 0.31, 6)
SelfTest.EDGE = Vector3.new(2, 0.31, -23.2)
SelfTest.BED = Vector3.new(-20, -89.69, -30)
local HEIGHT = 0.31

-- The host: how the run is spawned, waits, reads the time, prints and samples frames. Studio's is the engine's task library, os.clock and print, and samples the render
-- step; the CLI suite sets its own (SelfTest.host) before the client loads.
export type Host = {
	spawn: (fn: () -> ()) -> (),
	wait: (seconds: number) -> (),
	clock: () -> number,
	print: (line: string) -> (),
	sample: ((seconds: number) -> string)?,
}
SelfTest.host = nil :: Host?

local function engineHost(): Host
	local t: any = task
	return {
		spawn = function(fn: () -> ()) t.spawn(fn) end,
		wait = function(seconds: number) t.wait(seconds) end,
		clock = os.clock,
		print = function(line: string) print(line) end,
		sample = nil,
	}
end

-- ---------------------------------------------------------------- the run's state and its words
type Run = { ctx: any, host: Host, pass: number, fail: number, skip: number, doing: string, began: number, beat: number, bedAt: number?, bedSettled: number? }

local function say(r: Run, text: string)
	r.host.print(SelfTest.PREFIX .. " " .. text)
end

-- A check's condition: false stops the check with this reason (a FAIL).
local function need(ok: any, why: string)
	if not ok then error(why, 0) end
end

-- A check that cannot be made here says why with this (a SKIP, not a FAIL).
local SKIP = "\0skip:"
local function skip(why: string)
	error(SKIP .. why, 0)
end

-- Waits `seconds`, in steps of at most a second, saying where it is every HEARTBEAT_S seconds.
local function pause(r: Run, seconds: number)
	local host = r.host
	local deadline = host.clock() + seconds
	repeat
		host.wait(math.clamp(deadline - host.clock(), 0, 1))
		local now = host.clock()
		if now - r.beat >= SelfTest.HEARTBEAT_S then
			r.beat = now
			say(r, string.format("... %s (%.0f s in)", r.doing, now - r.began))
		end
	until host.clock() >= deadline
end

-- Waits until `cond` holds (looked at every `step` seconds; a frame when 0) or `seconds` have passed; whether it held.
local function waitUntil(r: Run, seconds: number, cond: () -> boolean, step: number?): boolean
	local deadline = r.host.clock() + seconds
	while not cond() do
		if r.host.clock() >= deadline then return false end
		pause(r, step or 0.1)
	end
	return true
end

local function fmt(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

local function partsUnder(folder: Instance): number
	local n = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

-- ---------------------------------------------------------------- moving the spider
-- Puts the spider at `pos` on the surface whose outward normal is `up` (the test place's own place hook), facing `heading` when given.
local function put(r: Run, pos: Vector3, up: Vector3?, heading: Vector3?)
	local ctx = r.ctx
	ctx.place(pos, up)
	if heading ~= nil then
		ctx.motor:place(pos, up or Vector3.yAxis, heading)
		ctx.camera:snap()
	end
end

-- The outward normal of the surface a support point lies on: the first of the six axes whose ray back toward the point meets a box at the point.
local AXES = { Vector3.yAxis, -Vector3.zAxis, Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis, -Vector3.yAxis }
local function surfaceAt(r: Run, point: Vector3): Vector3?
	local params = r.ctx.motor.params
	for _, n in AXES do
		local hit = Workspace:Raycast(point + n * 0.5, -n, params)
		if hit ~= nil and (hit.Position - point).Magnitude < 0.1 then return n end
	end
	return nil
end

-- Holds the spider at `pos` (put back every frame, so it cannot fall through what has not streamed in yet) until the region is whole; whether it arrived in time.
local function holdUntilReady(r: Run, id: string, pos: Vector3, up: Vector3?): boolean
	local world = r.ctx.world
	return waitUntil(r, SelfTest.REGION_WAIT, function()
		if world:regionReady(id) then return true end
		put(r, pos, up)
		return false
	end, 0)
end

-- The pieces of a region that are not here (the first few, by name).
local function missing(r: Run, region: any): string
	local folder = r.ctx.world:folderOf(region)
	if folder == nil then return "its folder" end
	local out: { string } = {}
	for _, piece in Region.pieces(region) do
		if folder:FindFirstChild(piece.id) == nil then table.insert(out, piece.id) end
	end
	local n = #out
	while #out > 5 do table.remove(out) end
	return `{n} of {#Region.pieces(region)} pieces, among them {table.concat(out, ", ")}`
end

-- Every prey of a director is made and drawn: a folder of the fly's id under Flies, with parts, none over the budget. The number drawn.
local function drawn(r: Run, flies: { any }, what: string): number
	local folder = Workspace:FindFirstChild("Flies")
	need(folder ~= nil, "no Flies folder in the workspace")
	local n = 0
	for _, f in flies do
		local body = (folder :: Instance):FindFirstChild(f.id)
		need(body ~= nil, `{what} {f.id} is not drawn`)
		local parts = partsUnder(body :: Instance)
		need(parts > 0 and parts <= SelfTest.FLY_PARTS, `{what} {f.id} is drawn with {parts} parts (1 to {SelfTest.FLY_PARTS})`)
		n += 1
	end
	return n
end

local function rawSample(r: Run, seconds: number): string
	if r.host.sample ~= nil then return (r.host.sample :: any)(seconds) end
	local dts: { number } = {}
	local conn = RunService.RenderStepped:Connect(function(dt: number) table.insert(dts, dt) end)
	local ok, err = pcall(function(): any pause(r, seconds); return nil end)
	conn:Disconnect()
	if not ok then error(err, 0) end
	local sum, worst = 0, 0
	for _, dt in dts do sum += dt; worst = math.max(worst, dt) end
	local mean = if #dts > 0 then sum / #dts else 0
	return string.format("%d frames, mean %.1f ms (%.0f fps), worst %.1f ms, physics %.0f fps",
		#dts, mean * 1000, if mean > 0 then 1 / mean else 0, worst * 1000, (Workspace :: any):GetRealPhysicsFPS())
end

-- ROBLOX-111: what the engine says of itself, each in its own pcall (a name the engine does not have is "?"): the client's memory (MB), the Lua heap (MB), the
-- instances, the physics primitives and the moving ones, and the parts awake in the physics.
local function engineLine(): string
	local function ask(fn: () -> any): string
		local ok, v = pcall(fn)
		if not ok or v == nil then return "?" end
		if type(v) == "number" then return if v == math.floor(v) then string.format("%d", v) else string.format("%.1f", v) end
		return tostring(v)
	end
	local stats: any = nil
	pcall(function() stats = (game :: any):GetService("Stats") end)
	return string.format("memory %s MB, Lua heap %s MB, instances %s, primitives %s (moving %s), awake parts %s",
		ask(function() return stats:GetTotalMemoryUsageMb() end), ask(function() return (gcinfo() :: number) / 1024 end),
		ask(function() return stats.InstanceCount end), ask(function() return stats.PrimitivesCount end), ask(function() return stats.MovingPrimitivesCount end),
		ask(function() return (Workspace :: any):GetNumAwakeParts() end))
end

-- ROBLOX-111: what the renderer is given, by top-level child of the workspace: parts, and among them the see-through (Transparency between 0 and 1), the
-- shadow-casting and the meshed (a SpecialMesh: the ellipsoids); the folders with fewer than 20 parts summed as "the rest".
local function census(): string
	local rows: { string } = {}
	local all = { parts = 0, clear = 0, shadow = 0, mesh = 0 }
	local rest = { parts = 0, clear = 0, shadow = 0, mesh = 0 }
	for _, child in Workspace:GetChildren() do
		local c = { parts = 0, clear = 0, shadow = 0, mesh = 0 }
		local list = child:GetDescendants()
		table.insert(list, child)
		for _, d in list do
			if d:IsA("BasePart") then
				c.parts += 1
				local t = (d :: BasePart).Transparency
				if t > 0 and t < 1 then c.clear += 1 end
				if (d :: BasePart).CastShadow and t < 1 then c.shadow += 1 end
			elseif d:IsA("SpecialMesh") then
				c.mesh += 1
			end
		end
		for k, v in c do all[k] += v end
		if c.parts >= 20 then
			table.insert(rows, `{child.Name} {c.parts}/{c.clear}/{c.shadow}/{c.mesh}`)
		else
			for k, v in c do rest[k] += v end
		end
	end
	table.sort(rows)
	if rest.parts > 0 then table.insert(rows, `the rest {rest.parts}/{rest.clear}/{rest.shadow}/{rest.mesh}`) end
	return `{all.parts} parts, {all.clear} see-through, {all.shadow} casting shadows, {all.mesh} meshed (parts/see-through/shadow/meshed: {table.concat(rows, ", ")})`
end

-- The frame time over `seconds`, with the client's frame profiled by part (Client/FrameProfile, when the hooks carry it) and the engine's own numbers: three INFO
-- lines, `<what>`, `profile <where>` and `engine <where>`. The profile is off again after, whatever happens.
local function frameSample(r: Run, seconds: number, what: string, where: string)
	local prof = r.ctx.prof
	if prof ~= nil then prof.start() end
	local ok, line = pcall(rawSample, r, seconds)
	if prof ~= nil then prof.stop() end
	if not ok then error(line, 0) end
	say(r, `INFO {what}: {line}`)
	if prof ~= nil then say(r, `INFO profile {where}: {prof.line()}`) end
	say(r, `INFO engine {where}: {engineLine()}`)
end

-- ---------------------------------------------------------------- the checks
type Check = { name: string, fn: (r: Run) -> () }
local function checks(): { Check }
	local list: { Check } = {}
	local function add(name: string, fn: (r: Run) -> ()) table.insert(list, { name = name, fn = fn }) end
	local preserve = WorldMap.world() == "preserve" -- (ROBLOX-115: the preserve has its own checks where the garden's would be)

	add("new life", function(r)
		local ctx = r.ctx
		local menu, session = ctx.menu, ctx.session
		need(waitUntil(r, SelfTest.LIFE_WAIT, function() return menu:isShowing() or session.started end), `no start menu and no life after {SelfTest.LIFE_WAIT} s`)
		if menu:isShowing() then
			-- the start menu's "Begin a new life": the choice a click makes (CaughtPanel.choose, what the button's Activated calls)
			need(waitUntil(r, 10, function() return menu:choose("New") end), "the start menu would not take Begin a new life")
		elseif ctx.fresh ~= nil then
			-- the test place (no start menu, a life at once): a new life the way the menu's choice makes one
			need(waitUntil(r, 10, function() return ctx.fresh("main", false, nil) end), "a new life could not begin")
		end
		pause(r, 0.5)
		if ctx.cat ~= nil then ctx.cat.enabled = false end -- (ROBLOX-118: the cat is held off the run but for its own check)
		need(session.started and not menu:isShowing(), "the life did not begin")
		need(ctx.motor.mode == "attached", `the spider is not standing ({ctx.motor.mode})`)
	end)

	-- ROBLOX-109: the intro of a new life. From the start menu it is playing now (a save that has seen it does not play it: then it is begun here, as in the
	-- test place, through its hook, whatever was seen); the skip is what the skip key's action calls.
	add("intro", function(r)
		local ctx = r.ctx
		local title = ctx.title
		need(title ~= nil, "no title card in the hooks")
		if not title:holding() then need(title:beginIntro(true, false), "the intro would not begin") end
		need(title:holding(), "the intro is not holding")
		need(not title:skip(), "the skip was taken before two seconds")
		pause(r, 2.2)
		need(title:holding(), "the intro let go of the controls before its end")
		need(title:skip(), "the skip was refused after two seconds")
		pause(r, 0.6)
		need(not title:holding() and not title:playing(), "the intro is still playing after its skip")
		need(ctx.motor.mode == "attached", `the spider is not standing after the intro ({ctx.motor.mode})`)
		need(ctx.motor.pos.X >= -21.7, string.format("the spider is still in the crack (x %.2f)", ctx.motor.pos.X))
	end)

	add("world folders", function(r)
		local world = r.ctx.world
		need(Workspace:FindFirstChild(Region.WORLD_FOLDER) ~= nil and world.root.Name == Region.WORLD_FOLDER, "no World folder in the workspace")
		local absent: { string } = {}
		for _, region in WorldMap.regions() do
			if world:folderOf(region) == nil then table.insert(absent, region.id) end
		end
		need(#absent == 0, "no folder for " .. table.concat(absent, ", "))
	end)

	for _, region in WorldMap.regions() do
		add("region " .. region.id, function(r)
			local ctx = r.ctx
			local world, motor = ctx.world, ctx.motor
			local at = region.spawn.pos
			need(holdUntilReady(r, region.id, at + Vector3.yAxis * HEIGHT, nil), `not whole after {SelfTest.REGION_WAIT} s: missing {missing(r, region)}`)
			local up = surfaceAt(r, at)
			need(up ~= nil, `no surface at its spawn {fmt(at)}`)
			local u = up :: Vector3
			put(r, at + u * HEIGHT, u, region.spawn.heading)
			pause(r, 0.2)
			local hit = Workspace:Raycast(motor.pos + u * 0.2, -u * 1.0, motor.params)
			need(hit ~= nil, `no ground under the spider at {fmt(motor.pos)}`)
			local p0 = motor.pos
			pause(r, 1.0)
			need(motor.mode == "attached" and (motor.pos - p0).Magnitude < 0.25, `did not stay put: from {fmt(p0)} to {fmt(motor.pos)}, {motor.mode}`)
			need(world.region.id == region.id, `the client's world says {world.region.id}`)
		end)
	end

	add("walk on the sill", function(r)
		local ctx = r.ctx
		local motor = ctx.motor
		put(r, SelfTest.SILL, nil)
		pause(r, 0.5)
		local p0 = motor.pos
		local lowest, highest = p0.Y, p0.Y
		ctx.input:simulate("Forward", true)
		local deadline = r.host.clock() + 3
		while r.host.clock() < deadline do
			pause(r, 0)
			lowest, highest = math.min(lowest, motor.pos.Y), math.max(highest, motor.pos.Y)
		end
		ctx.input:simulate("Forward", false)
		pause(r, 0.2)
		local moved = (motor.pos - p0).Magnitude
		say(r, string.format("INFO walk: %.2f studs in 3 s, height %.2f to %.2f", moved, lowest, highest))
		need(moved > 1.5, string.format("walked only %.2f studs in 3 s", moved))
		need(lowest > 0.2 and highest < 0.45, string.format("left the floor: between y %.2f and %.2f", lowest, highest))
	end)

	-- (ROBLOX-115: the garden's checks are the test garden's; `garden` adds one only there)
	local function garden(name: string, fn: (r: Run) -> ()) if not preserve then add(name, fn) end end

	garden("the line", function(r)
		local ctx = r.ctx
		local motor = ctx.motor
		need(holdUntilReady(r, "outer_sill", SelfTest.EDGE, nil), "the outer sill is not whole")
		put(r, SelfTest.EDGE, Vector3.yAxis, -Vector3.zAxis)
		pause(r, 0.3)
		need(ctx.world.region.id == "outer_sill", `not on the outer sill ({ctx.world.region.id})`)
		ctx.input:simulate("Drop", true)
		local ok, err = pcall(function()
			need(waitUntil(r, 15, function() return motor:onLine() end, 0), "never got onto the line from the front edge")
			pause(r, 1.0) -- (the line's first slack is paid out at once: measured after it)
			need(motor:onLine(), "off the line a second after the drop")
			local y0, t0, x0 = motor.pos.Y, r.host.clock(), motor.pos.X
			local before = table.clone(motor.silk.stats) -- (ROBLOX-111: what the line does over the measure, SilkController's counts)
			local prof = ctx.prof
			if prof ~= nil then prof.start() end -- (and the frame by part while it lets down: the looks are planned again as it goes down)
			local deadline = t0 + 6
			local okLine, errLine = pcall(function()
				while r.host.clock() < deadline do
					pause(r, 0.25)
					need(motor:onLine(), string.format("left the line %.1f s into the let-down, at %s", r.host.clock() - t0, fmt(motor.pos)))
					need(math.abs(motor.pos.X - x0) < 1.0, string.format("swung %.2f studs off the line's fall", math.abs(motor.pos.X - x0)))
				end
			end)
			if prof ~= nil then prof.stop(); say(r, "INFO profile on the line: " .. prof.line()) end
			if not okLine then error(errLine, 0) end
			local wall = r.host.clock() - t0
			local fell = y0 - motor.pos.Y
			local st = motor.silk.stats
			local d: { [string]: number } = {}
			for k, v in st do d[k] = v - (before[k] or 0) end
			-- The game's time is the ticks the line ran (1/60 s each); the clock's is the wall's. They differ when the client ran fewer ticks than the frames' time
			-- (a frame over a quarter of a second, a menu, slow motion). The let-down is judged in the game's time: that is the dial (SilkController.game).
			local game = d.ticks / 60
			local rate = if game > 0 then fell / game else 0
			say(r, string.format("INFO line: let down at %.3f studs a second of the game's time (the game's %.2f), %.3f by the clock", rate, SelfTest.LOWER, fell / wall))
			say(r, string.format("INFO line ticks: %d ticks (%.2f s of the game) in %.2f s by the clock; line let out %.3f, the body fell %.3f (%.1f%% of it); sweeps stopped the body %d times (%.3f taken off), %d tangent touches let pass, %d push-outs (%.3f out, %.3f of it up)",
				d.ticks, game, wall, d.letOut, d.fell, if d.letOut > 0 then d.fell / d.letOut * 100 else 0, d.stops, d.stopped, d.grazes, d.pushes, d.pushed, if math.abs(d.pushedUp) < 5e-4 then 0 else d.pushedUp))
			need(rate > SelfTest.LOWER_BAND[1] and rate < SelfTest.LOWER_BAND[2], string.format("let down at %.3f studs a second of the game's time, not about %.2f", rate, SelfTest.LOWER))
		end)
		ctx.input:simulate("Drop", false)
		if not ok then error(err, 0) end
	end)

	add("prey on the sill", function(r)
		local ctx = r.ctx
		put(r, SelfTest.SILL, nil)
		pause(r, 1.0)
		local flies = ctx.prey.flies
		need(#flies >= 1, "the sill has no flies")
		local n = drawn(r, flies, "the sill's fly")
		say(r, `INFO prey on the sill: {n} flies drawn`)
	end)

	-- ROBLOX-110: the lock. The spider on the open sill is turned to the nearest of the sill's flies (the check's own setting-up), and the lock is then taken only from
	-- what its senses give it: Recentre locks onto it, the body turns to it, the sidestep walks the spider round it at a creep, and Recentre again lets go.
	add("lock", function(r)
		local ctx = r.ctx
		local motor, lock, lockOn, memory = ctx.motor, ctx.lock, ctx.lockOn, ctx.memory
		need(lock ~= nil and lockOn ~= nil, "no lock in the hooks")
		lockOn.release(lock, "selftest")
		-- A fly of the sill on a surface the spider can stand on, and a place 3 studs from it on the same surface in plain view of it: the spider is put there facing it.
		local nearest: any, best = nil, 0
		for _, f in ctx.prey.flies do
			if nearest ~= nil then break end
			local n = f.normal or Vector3.yAxis
			local under = Workspace:Raycast(f.position + n * 0.2, -n * 2, motor.params)
			if under ~= nil and under.Normal:Dot(n) > 0.95 then
				local tangent = n:Cross(if math.abs(n.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
				for _, side in { tangent, -tangent, n:Cross(tangent), -n:Cross(tangent) } do
					local at = under.Position + side * 3
					local ground = Workspace:Raycast(at + n * 0.5, -n * 1.0, motor.params)
					if ground ~= nil and ground.Normal:Dot(n) > 0.95 then
						local body = ground.Position + n * HEIGHT
						if Workspace:Raycast(body + n * 0.1, (f.position - body) * 0.97, motor.params) == nil then
							put(r, body, n, (f.position - body) - n * (f.position - body):Dot(n))
							nearest, best = f, (f.position - body).Magnitude
							break
						end
					end
				end
			end
		end
		if nearest == nil then skip("no fly of the sill with a place in plain view of it on its own surface") end
		local function sees(): boolean
			local o = motor:observer()
			local origin, dir = ctx.cam:aimRay()
			return lockOn.pick(memory, o.eye, o.heading, origin, dir) ~= nil
		end
		if not waitUntil(r, 6, sees, 0) then skip(`the spider saw nothing it could lock in 6 s (the fly {string.format("%.1f", best)} studs away, at {fmt(nearest.position)})`) end
		ctx.input:simulate("Recenter", true); pause(r, 0); ctx.input:simulate("Recenter", false)
		need(lock.trackId ~= nil and lock.point ~= nil, "Recentre did not lock onto what the spider sees")
		pause(r, 0.8)
		need(lock.trackId ~= nil, `the lock ended by itself at once ({tostring(lock.released)})`)
		local face = math.deg(math.acos(math.clamp(motor.heading:Dot((lock.point - motor.pos).Unit), -1, 1)))
		need(face < 25, string.format("the body is %.0f degrees from the locked thing", face))
		local p0 = motor.pos
		ctx.input:simulate("Right", true); pause(r, 1.0); ctx.input:simulate("Right", false)
		pause(r, 0.1)
		local moved = (motor.pos - p0).Magnitude
		say(r, string.format("INFO lock: %.1f studs away, facing it within %.0f degrees, a sidestep of %.2f studs in 1 s", best, face, moved))
		need(motor.mode == "attached" and moved > 0.2 and moved < 1.5, string.format("the sidestep moved the spider %.2f studs (%s)", moved, motor.mode))
		if lock.trackId ~= nil then
			ctx.input:simulate("Recenter", true); pause(r, 0); ctx.input:simulate("Recenter", false)
			need(lock.trackId == nil, "Recentre again did not let go")
		end
		-- (ROBLOX-115) a controller's L2: a tap locks onto what the spider sees, a tap again lets go
		if waitUntil(r, 3, sees, 0) then
			ctx.input:simulate("PadLock", true); pause(r, 0); ctx.input:simulate("PadLock", false)
			pause(r, 0)
			need(lock.trackId ~= nil, "an L2 tap did not lock onto what the spider sees")
			ctx.input:simulate("PadLock", true); pause(r, 0); ctx.input:simulate("PadLock", false)
			pause(r, 0)
			need(lock.trackId == nil, "an L2 tap again did not let go")
			say(r, "INFO lock: L2's tap locks and lets go")
		end
	end)

	garden("prey in the bed", function(r)
		local ctx = r.ctx
		need(holdUntilReady(r, "bed_a", SelfTest.BED, nil), "the bed is not whole")
		put(r, SelfTest.BED, nil)
		-- (ROBLOX-111: the looks' settling is timed from here: the first frame with no look being made)
		r.bedAt = r.host.clock()
		local looks = ctx.world.looks
		while r.host.clock() < (r.bedAt :: number) + 2.0 do
			pause(r, 0)
			if r.bedSettled == nil and looks ~= nil and #looks.jobs == 0 then r.bedSettled = r.host.clock() end
		end
		local bed = ctx.world.garden.bed_a
		need(bed ~= nil and bed.prey ~= nil, "the bed's prey was not made")
		local byKind: { [string]: number } = {}
		for _, f in bed.prey.flies do
			local kind = f.profile.body.prey_kind or "?"
			byKind[kind] = (byKind[kind] or 0) + 1
		end
		need((byKind.fungus_gnat or 0) > 0, "no gnats")
		need((byKind.aphid or 0) > 0, "no aphids")
		local kinds = bed.kinds
		need(kinds ~= nil and kinds.springtail ~= nil and #kinds.springtail.flies > 0, "no springtails")
		need(kinds.leafhopper ~= nil and #kinds.leafhopper.flies > 0, "no leafhoppers")
		drawn(r, bed.prey.flies, "the bed's")
		drawn(r, kinds.springtail.flies, "a springtail")
		drawn(r, kinds.leafhopper.flies, "a leafhopper")
		say(r, `INFO prey in the bed: {byKind.fungus_gnat} gnats, {byKind.aphid} aphids, {#kinds.springtail.flies} springtails, {#kinds.leafhopper.flies} leafhoppers, all drawn`)
	end)

	garden("woodlice", function(r)
		local ctx = r.ctx
		local bed = ctx.world.garden.bed_a
		need(bed ~= nil and bed.bugs ~= nil and #bed.bugs.lice > 0, "no woodlice in the bed")
		local folder = Workspace:FindFirstChild("Bugs")
		need(folder ~= nil, "no Bugs folder in the workspace")
		for _, w in bed.bugs.lice do
			local body = (folder :: Instance):FindFirstChild(w.id)
			need(body ~= nil, `woodlouse {w.id} is not drawn`)
			local parts = partsUnder(body :: Instance)
			need(parts > 0 and parts <= BugBodies.PARTS, `woodlouse {w.id} is drawn with {parts} parts (1 to {BugBodies.PARTS})`)
		end
		say(r, `INFO woodlice: {#bed.bugs.lice} made and drawn`)
	end)

	garden("frame time in the bed", function(r)
		frameSample(r, SelfTest.SAMPLE_S, "frame time in the bed", "in the bed")
		say(r, "INFO census in the bed: " .. census())
	end)

	-- ROBLOX-111: the bed's frame again once the looks near it are all made (no build pending), with how long that took from the spider's coming to the bed; then,
	-- to say whether the looks or their shadows are what the frame pays for, the same with the looks out of the workspace, and with the global shadows off (both
	-- put back at once, whatever happens).
	garden("frame time in the bed, settled", function(r)
		local looks = r.ctx.world.looks
		if looks == nil then skip("no looks are made in this place") end
		local settled = waitUntil(r, SelfTest.SETTLE_WAIT, function()
			if #looks.jobs == 0 then r.bedSettled = r.bedSettled or r.host.clock(); return true end
			r.bedSettled = nil
			return false
		end, 0)
		local at = r.bedAt or r.host.clock()
		say(r, string.format("INFO looks settled in the bed: %s %.2f s after the spider came, %d parts held of %d planned, %d plans, %d made and %d destroyed this session",
			if settled then "yes," else "NOT,", (r.bedSettled or r.host.clock()) - at, looks:parts(), looks.planned, looks.plans, looks.made, looks.destroyed))
		need(settled, `the looks were still being made after {SelfTest.SETTLE_WAIT} s`)
		local plans0, made0 = looks.plans, looks.made
		frameSample(r, SelfTest.SAMPLE_S, "frame time in the bed, settled", "in the bed, settled")
		say(r, string.format("INFO looks while settled: %d plans and %d parts made in the sample", looks.plans - plans0, looks.made - made0))
		local folder = looks.folder
		local ok, err = pcall(function()
			folder.Parent = nil
			frameSample(r, SelfTest.AB_S, "frame time in the bed without the looks", "in the bed without the looks")
		end)
		folder.Parent = Workspace
		if not ok then error(err, 0) end
		local Lighting = game:GetService("Lighting")
		local shadows = Lighting.GlobalShadows
		local ok2, err2 = pcall(function()
			Lighting.GlobalShadows = false
			frameSample(r, SelfTest.AB_S, "frame time in the bed without shadows", "in the bed without shadows")
		end)
		Lighting.GlobalShadows = shadows
		if not ok2 then error(err2, 0) end
	end)

	garden("moths on the wall", function(r)
		local ctx = r.ctx
		local wall = WorldMap.region("house_wall") :: any
		need(holdUntilReady(r, "house_wall", wall.spawn.pos + Vector3.yAxis * HEIGHT, nil), "the wall is not whole")
		local up = surfaceAt(r, wall.spawn.pos) or -Vector3.zAxis
		put(r, wall.spawn.pos + up * HEIGHT, up, wall.spawn.heading)
		ctx.life.clock.hour = 12
		pause(r, 2.0)
		local entry = ctx.world.garden.house_wall
		need(entry ~= nil and entry.kinds ~= nil and entry.kinds.moth ~= nil, "the wall's moths were not made")
		local moths = entry.kinds.moth.flies
		need(#moths > 0, "the wall has no moths")
		drawn(r, moths, "a moth")
		say(r, `INFO moths on the wall: {#moths} made and drawn`)
	end)

	garden("dusk: the moths fly", function(r)
		local ctx = r.ctx
		local life = ctx.life
		local entry = ctx.world.garden.house_wall
		need(entry ~= nil and entry.kinds ~= nil and entry.kinds.moth ~= nil, "the wall's moths were not made")
		local d = entry.kinds.moth
		local ok, err = pcall(function()
			life.clock.hour = 20 -- (the clock's own hour, as the world_client suite sets it; the dial is the region's)
			need(waitUntil(r, 3, function() return d.p == Species.moth_dusk_prototype end), "the moths did not take the dusk's profile at 20:00")
			local flew = waitUntil(r, SelfTest.DUSK_WAIT, function()
				for _, f in d.flies do
					if f:airborne() then return true end
				end
				return false
			end, 0)
			need(flew, `no moth took wing in {SelfTest.DUSK_WAIT} s of dusk`)
		end)
		life.clock.hour = 12
		if not ok then error(err, 0) end
	end)

	-- ROBLOX-115: the preserve's own checks: the ranger hut's sill, the backdrop near and far, the trains
	if preserve then
		add("the hut's sill", function(r)
			local ctx = r.ctx
			local world = ctx.world
			put(r, SelfTest.SILL, nil)
			pause(r, 0.5)
			need(world:regionReady("sill"), "the sill is not whole")
			need(world.region.id == "sill", `the client's world says {world.region.id}`)
			local decor = Workspace:FindFirstChild("Decor")
			need(decor ~= nil and decor:FindFirstChild("Wall") ~= nil, "no Decor with its window wall")
			need((decor :: Instance):FindFirstChild("View") == nil, "the Decor draws the test garden's view in the preserve")
			local looks = world.looks
			need(looks ~= nil, "no looks are made")
			need(waitUntil(r, SelfTest.SETTLE_WAIT, function() return #looks.jobs == 0 end, 0), `the looks were still being made after {SelfTest.SETTLE_WAIT} s`)
			local top = if looks.tier == "low" then "low" else "full"
			need(looks.plan.hut == top, `the hut is held {tostring(looks.plan.hut)}, not {top}`)
			local hut = looks.folder:FindFirstChild("hut")
			need(hut ~= nil and hut:FindFirstChild("Base") ~= nil, "the hut's look is not in the workspace")
			local named: { [string]: boolean } = {}
			for _, d in (hut :: Instance):GetDescendants() do named[d.Name] = true end
			need(named.NorthWest and named.Roof1 and named.OuterSill, "the hut's look has no north wall, roof or outer sill")
			say(r, `INFO the hut's sill: {partsUnder(hut :: Instance)} parts of the hut at the {looks.tier} tier; {looks:parts()} parts of the backdrop held of {looks.planned} planned`)
		end)

		add("the backdrop near and far", function(r)
			local ctx = r.ctx
			local world, motor = ctx.world, ctx.motor
			local looks = world.looks
			need(looks ~= nil, "no looks are made")
			local top = if looks.tier == "low" then "low" else "full"
			local function level(id: string): string return tostring(looks.plan[id]) end
			local function sets(id: string): string
				local look = looks.looks[id]
				if look == nil then return "none" end
				local out = {}
				for name in look.sets do table.insert(out, name) end
				table.sort(out)
				return table.concat(out, "+")
			end
			-- (all at once, between two frames: the client's own update would plan at the spider again at the next one)
			looks:update(motor.pos, world.region); looks:finish()
			local nearHut, nearRail = level("hut"), level("railway")
			local crest = Preserve.at(50, Preserve.RAILWAY.crest + 0.5, Preserve.RAILWAY.height)
			looks:update(crest, nil); looks:finish()
			local farHut, farRail, farHutSets, farRailSets, held = level("hut"), level("railway"), sets("hut"), sets("railway"), looks:parts()
			looks:update(motor.pos, world.region); looks:finish()
			local backHut, backSets = level("hut"), sets("hut")
			say(r, `INFO backdrop: at the sill the hut {nearHut} and the railway {nearRail}; at the railway's crest the railway {farRail} ({farRailSets}) and the hut {farHut} ({farHutSets}), {held} parts; back at the sill the hut {backHut} ({backSets})`)
			need(nearHut == top and nearRail == "far", `at the sill: the hut {nearHut} and the railway {nearRail}, not {top} and far`)
			need(farRail == top and farHut == "far" and farHutSets == "Far", `at the railway's crest: the railway {farRail} and the hut {farHut} ({farHutSets}), not {top} and far`)
			need(held <= (if top == "low" then 500 else 1500), `{held} parts held at the railway's crest`)
			need(backHut == top and string.find(backSets, "Base", 1, true) ~= nil and string.find(backSets, "Far", 1, true) == nil, `back at the sill the hut is {backHut} ({backSets})`)
		end)

		add("the trains", function(r)
			local world = r.ctx.world
			local train = world.train
			need(train ~= nil, "no trains in the preserve")
			local now = r.host.clock()
			-- (ROBLOX-118: the pass under way or the next one; the run is longer now, and the first may be long gone by the time this check comes)
			local k = 1
			while train.schedule.pass(k).finish < now and k < 50 do k += 1 end
			local first = train.schedule.pass(k)
			local nextPass = train.schedule.at(now) or first
			train:update(first.start + (first.finish - first.start) * 0.5)
			local shown, parts = train.shownCount, train:parts()
			train:update(now)
			say(r, string.format("INFO trains: the pass a %s of %d cars at %.0f to %.0f s; mid-pass %d cars (%d parts) drawn; the clock at %.0f s, the next at %.0f s",
				first.kind, first.cars, first.start, first.finish, shown, parts, now, nextPass.start))
			need(shown > 0, "no car of the train drawn mid-pass")
		end)

		-- ROBLOX-116: the ranger hut, walkable. The nursery's window shut (a walk at its gap stays inside), the ranger's moment when the spider is ready (the rule
		-- made true for a moment: past its first moult, hard, in the morning; an opening the progress record never keeps, put back at the end), the hut's inside
		-- walked from the sill down to the floor, the way out through the propped sash and down the logs to the bench and the ground, the hut garden's life, the
		-- homes, and the lamp at night.
		local function walkUntil(r: Run, seconds: number, cond: () -> boolean): (boolean, { [string]: boolean })
			local ctx = r.ctx
			local seen: { [string]: boolean } = {}
			ctx.input:simulate("Forward", true)
			local ok = waitUntil(r, seconds, function()
				seen[ctx.world.region.id] = true
				return cond()
			end, 0)
			ctx.input:simulate("Forward", false)
			pause(r, 0.2)
			return ok, seen
		end
		local function regions(seen: { [string]: boolean }): string
			local out = {}
			for id in seen do table.insert(out, id) end
			table.sort(out)
			return table.concat(out, ", ")
		end

		add("the nursery: the window shut", function(r)
			local ctx = r.ctx
			local hut, motor = ctx.world.hut, ctx.motor
			need(hut ~= nil, "no hut on this client")
			if hut.open then skip("this save's window is open already: the nursery is over") end
			need(hut.sash ~= nil and hut.sash.CanQuery, "no sash in the window's gap")
			put(r, Vector3.new(0, HEIGHT, -8), nil, -Vector3.zAxis)
			pause(r, 0.3)
			local least = motor.pos.Z
			local _, seen = walkUntil(r, 4, function() least = math.min(least, motor.pos.Z); return false end)
			say(r, string.format("INFO the nursery: a walk at the shut sash came to z %.2f (the sash's outer face is -13.5); regions %s", least, regions(seen)))
			need(least > -13.5 and not seen.hut_outer_sill, string.format("the spider got through the shut sash (z %.2f, %s)", least, regions(seen)))
		end)

		add("the nursery: the ranger props the window", function(r)
			local ctx = r.ctx
			local hut, life = ctx.world.hut, ctx.life
			need(hut ~= nil, "no hut on this client")
			if hut.open then skip("this save's window is open already") end
			local g, c = life.growth, life.clock
			local was = { stage = g.stage, soft = g.softHoursLeft, moulting = g.moultingHoursLeft, hour = c.hour }
			local t0 = r.host.clock()
			local ok, err = pcall(function()
				hut.trial = true
				g.stage, g.softHoursLeft, g.moultingHoursLeft = math.max(g.stage, 1), 0, 0
				c.hour = 11.5
				need(waitUntil(r, 3, function() return hut.moment ~= nil or hut.open end), "the ranger did not come in a ready spider's morning")
				need(waitUntil(r, 12, function() return hut.open end), "the window was not propped in twelve seconds")
			end)
			g.stage, g.softHoursLeft, g.moultingHoursLeft, c.hour = was.stage, was.soft, was.moulting, was.hour
			if not ok then error(err, 0) end
			need(hut.sash == nil and hut.wedge ~= nil, "the window is open but not wedged")
			need(not ctx.world:hutOpen(), "the self-test's opening reached the progress record")
			say(r, string.format("INFO the nursery: the ranger's moment took %.1f s; the wedge at x %.1f..%.1f", r.host.clock() - t0, hut.wedge.Position.X - hut.wedge.Size.X / 2, hut.wedge.Position.X + hut.wedge.Size.X / 2))
		end)

		add("the hut's inside", function(r)
			local ctx = r.ctx
			local world, motor = ctx.world, ctx.motor
			-- off the sill's front edge, down the apron under it to the floor
			put(r, Vector3.new(0, HEIGHT, 10.5), nil, Vector3.zAxis)
			pause(r, 0.3)
			local ok, seen = walkUntil(r, 30, function() return world.region.id == "hut_floor_b" and motor.mode == "attached" and math.abs(motor.pos.Y - (-70 + HEIGHT)) < 0.1 end)
			say(r, string.format("INFO the hut's inside: from the sill's front edge to %s at %s; regions %s", world.region.id, fmt(motor.pos), regions(seen)))
			need(ok, `did not reach the floor from the sill (at {fmt(motor.pos)}, in {world.region.id})`)
			-- the desk, the board and the shelf hold a spider
			for _, at in { { id = "hut_desk", pos = Vector3.new(80, 4 + HEIGHT, 45) }, { id = "hut_shelf", pos = Vector3.new(-132, 10 + HEIGHT, 160) }, { id = "hut_chair", pos = Vector3.new(86, -24 + HEIGHT, 108) } } do
				need(holdUntilReady(r, at.id, at.pos, nil), `{at.id} is not whole`)
				put(r, at.pos, nil)
				pause(r, 0.5)
				need(world.region.id == at.id and motor.mode == "attached" and (motor.pos - at.pos).Magnitude < 0.3, `{at.id}: did not stay put at {fmt(at.pos)} ({world.region.id}, {fmt(motor.pos)})`)
			end
		end)

		add("the way out", function(r)
			local ctx = r.ctx
			local world, motor, hut = ctx.world, ctx.motor, ctx.world.hut
			need(hut ~= nil and hut:passable(), "the window is shut")
			-- through the propped sash onto the outer sill
			put(r, Vector3.new(-3, HEIGHT, -9), nil, -Vector3.zAxis)
			pause(r, 0.3)
			local ok, seen = walkUntil(r, 8, function() return world.region.id == "hut_outer_sill" end)
			say(r, `INFO the way out: through the sash to {world.region.id} at {fmt(motor.pos)}; regions {regions(seen)}`)
			need(ok, `did not get through the propped sash (at {fmt(motor.pos)}, {world.region.id})`)
			-- over the outer sill's front edge and down the logs to the bench's seat
			need(holdUntilReady(r, "hut_bench", Vector3.new(-20, -40 + HEIGHT, -37), nil), "the bench is not whole")
			put(r, Vector3.new(-3, HEIGHT, -20), nil, -Vector3.zAxis)
			pause(r, 0.3)
			local ok2, seen2 = walkUntil(r, 40, function() return world.region.id == "hut_bench" and motor.mode == "attached" and math.abs(motor.pos.Y - (-40 + HEIGHT)) < 0.1 end)
			say(r, `INFO the way out: from the outer sill's edge to {world.region.id} at {fmt(motor.pos)}; regions {regions(seen2)}`)
			need(ok2, `did not come down to the bench's seat (at {fmt(motor.pos)}, {world.region.id})`)
			-- over the seat's front edge, under it to its west leg and down the leg to the ground
			need(holdUntilReady(r, "garden_a2", Vector3.new(-50, -84.6 + HEIGHT, -75), nil), "the garden by the bench is not whole")
			put(r, Vector3.new(-77, -40 + HEIGHT, -56), nil, -Vector3.zAxis)
			pause(r, 0.3)
			local ok3, seen3 = walkUntil(r, 40, function() return string.sub(world.region.id, 1, 7) == "garden_" and motor.mode == "attached" and motor.up.Y > 0.9 end)
			say(r, `INFO the way out: down the bench's leg to {world.region.id} at {fmt(motor.pos)}; regions {regions(seen3)}`)
			need(ok3, `did not come down the leg to the ground (at {fmt(motor.pos)}, {world.region.id})`)
		end)

		add("the hut garden", function(r)
			local ctx = r.ctx
			local world = ctx.world
			local function visit(id: string): any
				local region = WorldMap.region(id) :: any
				local at = region.spawn.pos + Vector3.yAxis * HEIGHT
				need(holdUntilReady(r, id, at, nil), `{id} is not whole`)
				put(r, at, nil, region.spawn.heading)
				pause(r, 1.5)
				return world.garden[id]
			end
			local c3 = visit("garden_c3")
			need(c3 ~= nil and c3.prey ~= nil, "the milkweed's gnats and aphids were not made")
			local byKind: { [string]: number } = {}
			for _, f in c3.prey.flies do
				local kind = f.profile.body.prey_kind or "?"
				byKind[kind] = (byKind[kind] or 0) + 1
			end
			need((byKind.fungus_gnat or 0) > 0 and (byKind.aphid or 0) > 0, `the milkweed's cell has {byKind.fungus_gnat or 0} gnats and {byKind.aphid or 0} aphids`)
			drawn(r, c3.prey.flies, "the milkweed's")
			need(c3.ambient ~= nil and c3.ambient.ladybird ~= nil, "no ladybird on the milkweed")
			local d4 = visit("garden_d4")
			need(d4 ~= nil and d4.kinds ~= nil and d4.kinds.leafhopper ~= nil and #d4.kinds.leafhopper.flies > 0, "no leafhoppers on the goldenrod")
			drawn(r, d4.kinds.leafhopper.flies, "a leafhopper")
			local d3 = visit("garden_d3")
			need(d3 ~= nil and d3.kinds ~= nil and d3.kinds.springtail ~= nil and #d3.kinds.springtail.flies > 0, "no springtails in the mulch")
			drawn(r, d3.kinds.springtail.flies, "a springtail")
			local a1 = visit("garden_a1")
			need(a1 ~= nil and a1.bugs ~= nil and #a1.bugs.lice > 0, "no woodlice by the trough")
			local folder = Workspace:FindFirstChild("Bugs")
			need(folder ~= nil, "no Bugs folder in the workspace")
			for _, w in a1.bugs.lice do need((folder :: Instance):FindFirstChild(w.id) ~= nil, `woodlouse {w.id} is not drawn`) end
			say(r, `INFO the hut garden: {byKind.fungus_gnat} gnats and {byKind.aphid} aphids on the milkweed with a ladybird, {#d4.kinds.leafhopper.flies} leafhoppers on the goldenrod, {#d3.kinds.springtail.flies} springtails in the mulch, {#a1.bugs.lice} woodlice by the trough, all drawn`)
		end)

		-- ROBLOX-117: the garden's near detail where the spider is (the patches: blades, chips, stones, the morning's dew), within the budgets at the client's tier
		add("the garden's near detail", function(r)
			local ctx = r.ctx
			local world = ctx.world
			local looks = world.looks
			need(looks ~= nil, "no looks on this client")
			local at = Vector3.new(22, -74.6 + HEIGHT, -246) -- (in the pollinator bed's mulch by the milkweed)
			need(holdUntilReady(r, "garden_c3", at, nil), "garden_c3 is not whole")
			put(r, at, nil, Vector3.new(1, 0, -0.3).Unit)
			pause(r, 1.5)
			looks:finish()
			local n, parts = 0, 0
			for id, level in looks.plan do
				if string.find(id, "~", 1, true) ~= nil then
					n += 1
					parts += LookPlan.count(LookPlan.lookup(WorldMap, id) :: any, level, looks.tier)
				end
			end
			local held = looks:parts()
			need(n > 0, "no patches drawn by the spider in the mulch")
			need(parts <= LookPlan.PATCH_SHARE[looks.tier] and held <= LookPlan.BUDGET[looks.tier], `{parts} parts of patches and {held} of looks, over the budget at {looks.tier}`)
			-- the morning's dew on them: shown at dawn, gone by noon
			local life = ctx.life
			local hour = life.clock.hour
			local drops, shown = 0, 0
			local ok, err = pcall(function()
				local function count(): (number, number)
					local d, v = 0, 0
					for _, part in looks.folder:GetDescendants() do
						if part:IsA("BasePart") and part:GetAttribute("Lag") ~= nil then
							d += 1
							if part.Transparency < 1 then v += 1 end
						end
					end
					return d, v
				end
				life.clock.hour = 6
				pause(r, 0.5)
				drops, shown = count()
				if looks.tier == "full" then need(drops > 0 and shown > 0, `no dew at dawn ({drops} drops, {shown} shown)`) end
				life.clock.hour = 12
				pause(r, 0.5)
				local _, noon = count()
				need(noon == 0, `dew still shown at noon ({noon})`)
			end)
			life.clock.hour = hour
			if not ok then error(err, 0) end
			say(r, `INFO the garden's near detail: {n} patches, {parts} parts of them, {held} parts of looks at {looks.tier}; dew at dawn on {shown} of {drops} drops`)
		end)

		-- ROBLOX-117: the rival and the mate come into the hut garden and roam it (never the hut): each put where it comes in, the spider beside its cell, a few seconds
		add("the garden's rival and mate", function(r)
			local ctx = r.ctx
			local life, world = ctx.life, ctx.world
			need(life.rival ~= nil, "no rival in this life")
			local saved = table.clone(life.rival)
			local savedMate = life.mate
			local ok, err = pcall(function()
				RivalSpider.renew(life.rival)
				local at, region = RivalSpider.arriveAt()
				need(region ~= nil and life.rival.region == region and string.sub(region :: string, 1, 7) == "garden_", `the rival comes in at {tostring(region)}`)
				life.rival.state = "patrol"
				local spot = Vector3.new(10, -74.6 + HEIGHT, -340) -- (in garden_d3, the mulch by the bee balm, beside the rival's cell)
				need(holdUntilReady(r, "garden_d3", spot, nil) and holdUntilReady(r, region :: string, at, nil), "the cells are not whole")
				put(r, spot, nil)
				pause(r, 4)
				local p = life.rival.position
				local here = WorldMap.at(p)
				need(life.rival.region ~= nil and string.sub(life.rival.region, 1, 7) == "garden_" and here ~= nil and string.sub(here.id, 1, 7) == "garden_",
					`the rival is not in the garden (at {fmt(p)}, {tostring(life.rival.region)})`)
				need(world:creatureLive(life.rival.region), "the rival's cell is not in play beside the spider")
				local moved = (p - at).Magnitude
				-- the mate
				local mate = Mate.new()
				local mat, mregion = Mate.arriveAt()
				mate.state = "wander"
				life.mate = mate
				need(holdUntilReady(r, mregion :: string, mat, nil), "the mate's cell is not whole")
				put(r, Vector3.new(150, -84.6 + HEIGHT, -130), nil) -- (on the lawn in the mate's own cell, well away from where it comes in)
				pause(r, 4)
				local mp = life.mate and life.mate.position or mat
				local mhere = WorldMap.at(mp)
				need(life.mate ~= nil and life.mate.region ~= nil and mhere ~= nil and string.sub(mhere.id, 1, 7) == "garden_", `the mate is not in the garden (at {fmt(mp)})`)
				say(r, `INFO the garden's rival and mate: the rival came in at {region} and walked {string.format("%.1f", moved)} studs, in {life.rival.region}; the mate came in at {mregion}, in {life.mate.region}`)
			end)
			for k in life.rival do life.rival[k] = nil end
			for k, v in saved do life.rival[k] = v end
			life.mate = savedMate
			if not ok then error(err, 0) end
		end)

		add("the hut's homes", function(r)
			local ctx = r.ctx
			local world = ctx.world
			local found = {}
			for _, id in { "hut_desk", "hut_board", "garden_a1", "garden_a3", "garden_d3" } do
				local region = WorldMap.region(id) :: any
				local t = region.retreats[1]
				local inside = Vector3.new((t.min.X + t.max.X) / 2, t.min.Y + HEIGHT, (t.min.Z + t.max.Z) / 2)
				local up = Vector3.yAxis
				if id == "hut_board" then inside, up = Vector3.new((t.min.X + t.max.X) / 2, (t.min.Y + t.max.Y) / 2, t.min.Z + HEIGHT), Vector3.zAxis end
				need(holdUntilReady(r, id, inside, up), `{id} is not whole`)
				put(r, inside, up)
				pause(r, 0.3)
				need(world:inRetreat(ctx.motor.pos) == t.id and ctx.motor.mode == "attached", `not resting-ready in {t.id} (at {fmt(ctx.motor.pos)}, {ctx.motor.mode})`)
				table.insert(found, t.id)
			end
			say(r, `INFO the hut's homes: {table.concat(found, ", ")}`)
		end)

		add("the hut by night: the lamp", function(r)
			local ctx = r.ctx
			local hut, life = ctx.world.hut, ctx.life
			need(hut ~= nil and hut.lamp ~= nil, "no lamp")
			local hour = life.clock.hour
			local ok, err = pcall(function()
				life.clock.hour = 22
				need(waitUntil(r, 3, function() return hut.lit end), "the lamp did not light at night")
				life.clock.hour = 12
				need(waitUntil(r, 3, function() return not hut.lit end), "the lamp did not go out by day")
			end)
			life.clock.hour = hour
			if not ok then error(err, 0) end
		end)

		-- ROBLOX-118: the ceiling and the walls up to it (nothing puts a spider back there now), the back room through the doorway with its sofa's home, the eaves outside,
		-- and the ranger's cat: heard, moving, noticing a spider that moves near it, and the way out of its reach (up high); its pat's outcome by the rules, on the sim.
		add("the ceiling and the upper walls", function(r)
			local ctx = r.ctx
			local world, motor = ctx.world, ctx.motor
			local R = { x0 = -146.5 }
			need(holdUntilReady(r, "hut_up_d", Vector3.new(R.x0 + HEIGHT, 50, 134), Vector3.xAxis), "the wall's upper cell is not whole")
			need(holdUntilReady(r, "hut_floor_d", Vector3.new(R.x0 + HEIGHT, 50, 134), Vector3.xAxis), "the wall's lower cell is not whole")
			put(r, Vector3.new(R.x0 + HEIGHT, 50, 134), Vector3.xAxis, Vector3.yAxis)
			pause(r, 0.3)
			local ok, seen = walkUntil(r, 12, function() return world.region.id == "hut_up_d" and motor.pos.Y > 66 end)
			say(r, `INFO the ceiling: up the west wall past WALL_TOP to {world.region.id} at {fmt(motor.pos)}; regions {regions(seen)}`)
			need(ok, `did not climb on past 1.3 m (at {fmt(motor.pos)}, {world.region.id})`)
			-- near the top of the wall, on round the corner onto the ceiling's underside
			put(r, Vector3.new(R.x0 + HEIGHT, 140, 134), Vector3.xAxis, Vector3.yAxis)
			pause(r, 0.3)
			local ok2 = walkUntil(r, 15, function() return motor.mode == "attached" and motor.up.Y < -0.9 end)
			need(ok2, `did not get onto the ceiling (at {fmt(motor.pos)}, up {fmt(motor.up)})`)
			local p0 = motor.pos
			pause(r, 1.0)
			need(motor.mode == "attached" and motor.up.Y < -0.9 and (motor.pos - p0).Magnitude < 0.3 and string.sub(world.region.id, 1, 7) == "hut_up_",
				`not hanging on the ceiling a second later ({motor.mode}, {fmt(motor.pos)}, {world.region.id})`)
			say(r, `INFO the ceiling: head down under the boards at {fmt(motor.pos)} in {world.region.id}`)
		end)

		add("the back room", function(r)
			local ctx = r.ctx
			local world, motor = ctx.world, ctx.motor
			need(holdUntilReady(r, "room_floor_g", Vector3.new(200, -70 + HEIGHT, 215), nil), "the back room's floor by the doorway is not whole")
			need(holdUntilReady(r, "hut_doorway", Vector3.new(160, -70 + HEIGHT, 215), nil), "the doorway is not whole")
			need(holdUntilReady(r, "hut_floor_i", Vector3.new(120, -70 + HEIGHT, 215), nil), "the hut's floor by the doorway is not whole")
			put(r, Vector3.new(120, -70 + HEIGHT, 215), nil, Vector3.xAxis)
			pause(r, 0.3)
			local ok, seen = walkUntil(r, 30, function() return world.region.id == "room_floor_g" and motor.pos.X > 180 end)
			say(r, `INFO the back room: through the doorway to {world.region.id} at {fmt(motor.pos)}; regions {regions(seen)}`)
			need(ok, `did not go through the doorway (at {fmt(motor.pos)}, {world.region.id})`)
			-- the sofa's seat, the television's unit and the games' shelf hold a spider; the gap under the sofa is a home
			for _, at in { { id = "room_sofa_w", pos = Vector3.new(262, -25 + HEIGHT, 215) }, { id = "room_tv", pos = Vector3.new(250, -20 + HEIGHT, 45) },
				{ id = "room_games", pos = Vector3.new(420, 50 + HEIGHT, 30) }, { id = "room_window", pos = Vector3.new(437, HEIGHT, 110) } } do
				need(holdUntilReady(r, at.id, at.pos, nil), `{at.id} is not whole`)
				put(r, at.pos, nil)
				pause(r, 0.5)
				need(world.region.id == at.id and motor.mode == "attached" and (motor.pos - at.pos).Magnitude < 0.3, `{at.id}: did not stay put at {fmt(at.pos)} ({world.region.id}, {fmt(motor.pos)})`)
			end
			local t = (WorldMap.region("room_floor_h") :: any).retreats[1]
			local inside = Vector3.new((t.min.X + t.max.X) / 2, t.min.Y + HEIGHT, (t.min.Z + t.max.Z) / 2)
			need(holdUntilReady(r, "room_floor_h", inside, nil), "the floor under the sofa is not whole")
			put(r, inside, nil)
			pause(r, 0.3)
			need(world:inRetreat(motor.pos) == "room_sofa_under" and motor.mode == "attached", `not resting-ready under the sofa (at {fmt(motor.pos)}, {motor.mode})`)
		end)

		add("the eaves", function(r)
			local ctx = r.ctx
			local world, motor = ctx.world, ctx.motor
			local mid, east = WorldMap.region("hut_eave_mid") :: any, WorldMap.region("hut_eave_e1") :: any
			need(holdUntilReady(r, "hut_eave_mid", mid.spawn.pos + Vector3.yAxis * HEIGHT, nil) and holdUntilReady(r, "hut_eave_e1", east.spawn.pos + Vector3.yAxis * HEIGHT, nil), "the eaves are not whole")
			put(r, mid.spawn.pos + Vector3.yAxis * HEIGHT, nil, Vector3.xAxis)
			pause(r, 0.3)
			local ok, seen = walkUntil(r, 20, function() return world.region.id == "hut_eave_e1" end)
			say(r, `INFO the eaves: along the gutter to {world.region.id} at {fmt(motor.pos)} ({string.format("%.0f", motor.pos.Y + 85)} cm over the ground); regions {regions(seen)}`)
			need(ok and motor.mode == "attached", `did not walk the gutter (at {fmt(motor.pos)}, {world.region.id}, {motor.mode})`)
		end)

		add("the cat", function(r)
			local ctx = r.ctx
			local cat, Cat, life, motor = ctx.cat, ctx.Cat, ctx.life, ctx.motor
			need(cat ~= nil and Cat ~= nil, "no cat in the preserve")
			local plan = Cat.plan(cat.seed, life.clock.day)
			local hour, day = life.clock.hour, life.clock.day
			local ok, err = pcall(function()
				-- heard and moving: in a walk of its day that starts in the hut's room, the spider on the hut's floor
				local walk = nil
				for _, s in plan do if s.kind == "walk" and (s.from == "bowls" or s.from == "door" or s.from == "chair") and s.t1 - s.t0 > 0.03 then walk = s; break end end
				need(walk ~= nil, "no walk from the hut's room in its day")
				put(r, Vector3.new(0, -70 + HEIGHT, 160), nil)
				life.clock.hour = walk.t0 + (walk.t1 - walk.t0) * 0.3
				pause(r, 0.2)
				local a = cat.pos
				local bell = cat:sound(motor.pos)
				pause(r, 1.0)
				local moved = (cat.pos - a).Magnitude
				say(r, string.format("INFO the cat: walking from the %s to the %s (%s), moved %.1f studs in a second; the bell %.2f at %.0f studs", tostring(walk.from), walk.spot, cat.pose, moved, bell, (Cat.head(cat) - motor.pos).Magnitude))
				need(moved > 5, string.format("the cat did not move (%.1f studs)", moved))
				need(bell > 0, "its bell was not heard")
				-- it notices a spider that moves in front of it, and gives up on one that gets up out of its reach
				local stop = nil
				for _, s in plan do if (s.spot == "rug" or s.spot == "door" or s.spot == "bowls") and s.kind ~= "walk" and s.t1 - s.t0 > 0.05 then stop = s; break end end
				need(stop ~= nil, "no stop on the floor in its day")
				life.clock.hour = (stop.t0 + stop.t1) / 2
				pause(r, 0.3)
				local front = Cat.chest(cat) + cat.heading * 20
				local at = Vector3.new(front.X, cat.surface + HEIGHT, front.Z)
				local region = WorldMap.at(at)
				need(region ~= nil and holdUntilReady(r, region.id, at, nil), "the floor in front of the cat is not whole")
				cat.enabled = true
				cat.cooldown = 0
				put(r, at, nil, -cat.heading)
				ctx.input:simulate("Forward", true)
				local noticed = waitUntil(r, 3, function() return cat.react ~= "none" end, 0)
				local crouched = noticed and waitUntil(r, 5, function() return cat.react == "crouch" or cat.react == "swat" end, 0)
				ctx.input:simulate("Forward", false)
				-- up out of its reach: on the desk's top
				put(r, Vector3.new(80, 4 + HEIGHT, 45), nil)
				local gaveUp = waitUntil(r, 8, function() return cat.react == "none" end, 0)
				cat.enabled = false
				say(r, `INFO the cat: at its {stop.spot} it noticed a spider moving in front of it ({noticed}), crouched to pat ({crouched}), gave up once it was up on the desk ({gaveUp}); notices {cat.notices}, pats {cat.pats}, swats {cat.swats}`)
				need(noticed, "it did not notice a spider moving in front of it")
				need(crouched, "it did not crouch to pat")
				need(gaveUp and cat.swats == 0, "it did not give up on a spider out of its reach")
				-- its pat by the rules (on the sim, so this life goes on): in Normal a pat that lands is a death, in the gentle rules a knock aside
				for _, gentle in { false, true } do
					local trial = Cat.new(cat.seed)
					trial.gentle = gentle
					local ph = (stop.t0 + stop.t1) / 2
					trial:step(1 / 60, day, ph, nil)
					local spot = Cat.chest(trial) + trial.heading * 8
					local p = Vector3.new(spot.X, trial.surface + HEIGHT, spot.Z)
					local kind = nil
					for i = 1, 60 * 8 do
						trial:step(1 / 60, day, ph, { pos = p + Vector3.new(math.sin(i * 0.2) * 1.5, 0, 0), speed = 2, hidden = false })
						for _, s in trial:drainSignals() do if s.kind == "struck" or s.kind == "nudged" then kind = s.kind end end
						if kind then break end
					end
					need(kind == (if gentle then "nudged" else "struck"), `in the {if gentle then "gentle" else "standard"} rules its pat was {tostring(kind)}`)
				end
			end)
			cat.enabled = false
			life.clock.hour, life.clock.day = hour, day
			if not ok then error(err, 0) end
		end)

		add("the nursery: the window put back", function(r)
			local hut = r.ctx.world.hut
			need(hut ~= nil, "no hut on this client")
			if not hut.trial then skip("the window was not opened by this run") end
			put(r, SelfTest.SILL, nil)
			pause(r, 0.3)
			hut:reshut()
			need(not hut.open and hut.sash ~= nil, "the window is not shut again")
		end)
	end

	add("notebook", function(r)
		local ctx = r.ctx
		put(r, SelfTest.SILL, nil)
		pause(r, 0.3)
		local panel = ctx.notebookPanel
		ctx.openNotebook("game")
		pause(r, 0.5)
		need(panel:isShowing(), "the notebook did not open")
		panel:close()
		pause(r, 0.3)
		need(not panel:isShowing(), "the notebook did not close")
	end)

	add("rest and checkpoint", function(r)
		local ctx = r.ctx
		local life, input = ctx.life, ctx.input
		put(r, SelfTest.SILL, nil)
		pause(r, 0.5)
		put(r, SelfTest.CRACK, nil)
		life.clock.hour = 12
		pause(r, 0.5)
		need(ctx.world:inRetreat(ctx.motor.pos) == "sill_crevice", "not in the crack")
		input:simulate("Feed", true); pause(r, 0); input:simulate("Feed", false)
		need(waitUntil(r, 2, function() return life.resting end), "no rest in the crack: " .. tostring(life.notice))
		local best = ctx.currentStore():loadBest()
		need(best.ok and best.record.world_map.retreat == "sill_crevice", "no checkpoint kept: " .. tostring(best.message))
		put(r, SelfTest.SILL, nil)
		pause(r, 1.0)
		need(not life.resting and ctx.world:inRetreat(ctx.motor.pos) == nil, "the rest did not end on leaving the crack")
		input:simulate("Reset", true); pause(r, 0); input:simulate("Reset", false)
		pause(r, 0.5)
		need(ctx.world:inRetreat(ctx.motor.pos) == "sill_crevice" and life.resting, `not back resting in the crack after the return (at {fmt(ctx.motor.pos)})`)
		put(r, SelfTest.SILL, nil)
		pause(r, 1.0)
	end)

	add("sound", function(r)
		local sound = r.ctx.soundscape
		local music = sound.music
		need(music ~= nil, "no music voice")
		need(music.Playing == true and music.Volume > 0, `the music is not playing (Playing {music.Playing}, Volume {music.Volume})`)
		need(sound.room.Volume == 0 or sound.room.Playing ~= true, `the room tone is not silent (Volume {sound.room.Volume})`)
		say(r, `INFO sound: music volume {string.format("%.3f", music.Volume)}, IsLoaded {tostring((music :: any).IsLoaded)}`)
	end)

	add("frame time on the sill", function(r)
		frameSample(r, SelfTest.SAMPLE_S, "frame time on the sill", "on the sill")
		say(r, "INFO census on the sill: " .. census())
	end)

	add("part counts", function(r)
		local rows: { string } = {}
		local total = 0
		for _, child in Workspace:GetChildren() do
			local n = partsUnder(child) + (if child:IsA("BasePart") then 1 else 0)
			if n > 0 then table.insert(rows, `{child.Name} {n}`) end
			total += n
		end
		table.sort(rows)
		say(r, `INFO parts at the {tostring(r.ctx.detail)} tier: {total} in the workspace ({table.concat(rows, ", ")})`)
		-- (ROBLOX-108: the looks outside the window are the client's own, made near the spider within a budget: Client/LookStream)
		local looks = r.ctx.world.looks
		if looks ~= nil then
			say(r, `INFO looks outside the window: {looks:parts()} parts held of {looks.planned} planned at the {looks.tier} tier, {looks.made} made and {looks.destroyed} destroyed this session, {looks.plans} plans`)
		end
	end)
	return list
end

-- ---------------------------------------------------------------- the run
-- The whole run: every check, then END. Never raises.
function SelfTest.run(ctx: any, host: Host)
	local now = host.clock()
	local r: Run = { ctx = ctx, host = host, pass = 0, fail = 0, skip = 0, doing = "start", began = now, beat = now }
	say(r, "BEGIN the live place's self-test (ROBLOX-104)")
	say(r, `INFO world: {WorldMap.world()} (revision {WorldMap.revision()})`)
	local ok, err = pcall(function()
		for _, c in checks() do
			r.doing = c.name
			local passed, why = pcall(function(): any c.fn(r); return nil end)
			for _, a in { "Forward", "Drop", "Feed", "Reset" } do pcall(function() ctx.input:simulate(a, false) end) end
			if passed then
				r.pass += 1
				say(r, "PASS " .. c.name)
			elseif type(why) == "string" and string.sub(why, 1, #SKIP) == SKIP then
				r.skip += 1
				say(r, "SKIP " .. c.name .. ": " .. string.sub(why, #SKIP + 1))
			else
				r.fail += 1
				say(r, "FAIL " .. c.name .. ": " .. tostring(why))
			end
		end
		-- home: the spider where a life begins
		local home = WorldMap.region(WorldMap.HOME) :: any
		pcall(function() put(r, home.spawn.pos + Vector3.yAxis * HEIGHT, nil) end)
	end)
	if not ok then
		r.fail += 1
		say(r, "FAIL the run itself: " .. tostring(err))
	end
	say(r, string.format("INFO took %.0f s", host.clock() - r.began))
	say(r, `END pass={r.pass} fail={r.fail} skip={r.skip}`)
end

-- The client's one line: runs the self-test in its own thread when this is Studio and the Workspace attribute SelfTest is true; refuses otherwise. Whether it began.
function SelfTest.start(ctx: any): boolean
	if not RunService:IsStudio() or Workspace:GetAttribute("SelfTest") ~= true then return false end
	local host = SelfTest.host or engineHost()
	host.spawn(function() SelfTest.run(ctx, host) end)
	return true
end

-- (skip is kept for a check that cannot be made in a place; none of today's needs it)
SelfTest.skip = skip

return SelfTest
