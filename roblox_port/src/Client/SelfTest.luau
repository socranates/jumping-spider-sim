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
-- The checks: the World folder and every region's folder; for every region, its boxes all there once the spider is held at its spawn (streaming, with a deadline), ground
-- under the spider there and the spider still there a second later, and the region the client's world reports; a walk on the sill; a let-down on the line from the outer
-- sill's front edge at about 0.75 studs a second, on the line all the way; the sill's flies, the bed's gnats, aphids, springtails and leafhoppers and the wall's moths made
-- and drawn under the fly's part budget; the woodlice made and drawn; the notebook opened and closed; the clock put to dusk and the moths flying; a rest in the crack,
-- its checkpoint kept and returned to; the music playing and the room tone silent; the frame time over five seconds on the sill and in the bed; the parts in the workspace.
-- Each Studio process writes its own log (%LOCALAPPDATA%\Roblox\logs); tools/studio/selftest.ps1 reads the newest for these lines.
-- The CLI suite tests/selftest.luau runs the same checks against the real client on the shim's box world, with a host of its own (simulated frames and clock), so the run is
-- proven to complete and print END before it ever reaches Studio. Nothing here has been run in Studio yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldMap = require(Shared:WaitForChild("World"):WaitForChild("WorldMap"))
local Region = require(Shared:WaitForChild("World"):WaitForChild("Region"))
local Species = require(Shared:WaitForChild("Data"):WaitForChild("Species"))
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
type Run = { ctx: any, host: Host, pass: number, fail: number, skip: number, doing: string, began: number, beat: number }

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

local function frameSample(r: Run, seconds: number): string
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

-- ---------------------------------------------------------------- the checks
type Check = { name: string, fn: (r: Run) -> () }
local function checks(): { Check }
	local list: { Check } = {}
	local function add(name: string, fn: (r: Run) -> ()) table.insert(list, { name = name, fn = fn }) end

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
		need(session.started and not menu:isShowing(), "the life did not begin")
		need(ctx.motor.mode == "attached", `the spider is not standing ({ctx.motor.mode})`)
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

	add("the line", function(r)
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
			local deadline = t0 + 6
			while r.host.clock() < deadline do
				pause(r, 0.25)
				need(motor:onLine(), string.format("left the line %.1f s into the let-down, at %s", r.host.clock() - t0, fmt(motor.pos)))
				need(math.abs(motor.pos.X - x0) < 1.0, string.format("swung %.2f studs off the line's fall", math.abs(motor.pos.X - x0)))
			end
			local rate = (y0 - motor.pos.Y) / (r.host.clock() - t0)
			say(r, string.format("INFO line: let down at %.3f studs a second (the game's %.2f)", rate, SelfTest.LOWER))
			need(rate > SelfTest.LOWER_BAND[1] and rate < SelfTest.LOWER_BAND[2], string.format("let down at %.3f studs a second, not about %.2f", rate, SelfTest.LOWER))
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

	add("prey in the bed", function(r)
		local ctx = r.ctx
		need(holdUntilReady(r, "bed_a", SelfTest.BED, nil), "the bed is not whole")
		put(r, SelfTest.BED, nil)
		pause(r, 2.0)
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

	add("woodlice", function(r)
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

	add("frame time in the bed", function(r)
		say(r, "INFO frame time in the bed: " .. frameSample(r, SelfTest.SAMPLE_S))
	end)

	add("moths on the wall", function(r)
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

	add("dusk: the moths fly", function(r)
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
		say(r, "INFO frame time on the sill: " .. frameSample(r, SelfTest.SAMPLE_S))
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
	end)
	return list
end

-- ---------------------------------------------------------------- the run
-- The whole run: every check, then END. Never raises.
function SelfTest.run(ctx: any, host: Host)
	local now = host.clock()
	local r: Run = { ctx = ctx, host = host, pass = 0, fail = 0, skip = 0, doing = "start", began = now, beat = now }
	say(r, "BEGIN the live place's self-test (ROBLOX-104)")
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
