--!strict
-- The bestiary's prey behaviours (ROBLOX-101, W3b part A), kept out of the frozen fly model: Prey/Fly calls in here only for a profile whose body asks for it
-- (Data/Species: `hop`, `sidestep`, `dusk`/`day`, `slip_chance`, `shed_chance`), and Godot's profiles ask for none of them, so the house fly, the fruit fly,
-- the gnat and the aphid run exactly as before. Game rules, not measurements; every draw is the fly's own PreyRandom stream (recorded with it), so a rest
-- puts back a moth that has used its slip, or a crane fly with a leg gone, and replays the same.
--   the hop ......... a ballistic escape on the reaction model (the springtail's flick, the leafhopper's jump): a parabola from where it stands to a free perch
--                     of its kind (or, on level ground, a spot on the same surface) between the hop's `min` and `max`, away from the danger, swept for
--                     clearance before it leaves; in the air for `time`, as high as `apex`; it lands perched and may fly on (`fly_after`)
--   the sidestep .... (the leafhopper) alert and watched from its own side, it goes round its stem or leaf to the perch on the far side (`behind`), passing the
--                     perch's `round` point, in `time` seconds, and not again for `rest`
--   dusk ............ a director of a kind with a `dusk` profile swaps every fly of it to that profile from dusk through the night and back by day; the
--                     restlessness each fly drew is kept, its clock of restlessness starts again at the change (so they do not all take off at once)
--   the grip ........ the moth's slip (the first grip on it fails at `slip_chance`, once) and the crane fly's shed leg (once, at `shed_chance`, `shed_after`
--                     seconds into the struggle): the prey leaves the jaws and escapes as a torn-free fly does
--   the creep ....... (ROBLOX-105, the aphid: body.creep) now and then, perched and calm, it walks slowly over its plant's faces to another free perch of the
--                     same plant (World/Garden.plantPath: down its stem or round its rosette and out along the other leaf), at `speed`, every `every`
--                     seconds; startled on the way it freezes where it is; it never leaves its plant
local Species = require(script.Parent.Parent.Data.Species)
local Garden = require(script.Parent.Parent.World.Garden)
local PlantWalk = require(script.Parent.PlantWalk)

local K = {}

-- (ROBLOX-105) The aphid's creep (a profile with body.creep): carries on one under way (true while it moves or stands frozen on the way), or, perched, calm, not
-- walking or fidgeting and its time come, begins one to a free perch of its own plant within `reach` studs of walking (the stream draws the perch and the next
-- time). An aphid a ladybird is eating (`heldBy`) does not set off.
function K.creep(f: any, now: number, dt: number): boolean
	local c = f.creep
	local hover = f.profile.body.hover_wu
	if c ~= nil then
		if f.state ~= "PERCHED" and f.state ~= "ALERT" then f.creep = nil; return false end
		if f.state == "ALERT" then return true end -- (startled on the way: it freezes where it is)
		local p, n, dir, done = PlantWalk.advance(c, (f.creepSpeed or 0.1) * dt)
		f.position = p + n * hover
		f.normal = n
		if dir.Magnitude > 0.5 then f.heading = dir end
		if done then
			f.creep = nil
			f.normal = f.perch.normal
			f.position = f.graph:rest(f.perch)
			local t = f.heading - f.normal * f.heading:Dot(f.normal)
			if t.Magnitude > 1e-3 then f.heading = t.Unit end
			f.restSpot = f.position; f.homeHeading = f.heading; f.walkLeft = 0; f.fidgetUntil = 0; f.perchedSince = now
		end
		return true
	end
	local spec = f.profile.body.creep
	if spec == nil or f.state ~= "PERCHED" or f.walkLeft > 0 or now < f.fidgetUntil or f.heldBy ~= nil or f.perch == nil then return false end
	if f.creepNext == nil then f.creepNext = now + f.rng:draw(spec.every); return false end
	if now < f.creepNext then return false end
	f.creepNext = now + f.rng:draw(spec.every)
	local here = f.perch
	local name, plants = Garden.plantOf(here.id)
	if name == nil or plants == nil then return false end
	local plant = plants[name]
	local list = {}
	for _, other in f.graph.perches do
		if other ~= here and other.walker and other.valid and other.occupant == "" and other.reserved == "" and plant.nodes[other.id] ~= nil then
			local path = Garden.plantPath(plant, here.id, other.id)
			if path ~= nil then
				local w = PlantWalk.new(path, f.position - f.normal * hover, f.normal)
				if w.length <= spec.reach then table.insert(list, { perch = other, walk = w }) end
			end
		end
	end
	if #list == 0 then return false end
	local pick = list[1 + math.floor(f.rng:next() * #list) % #list]
	if here.occupant == f.id then here.occupant = "" end
	pick.perch.occupant = f.id
	f.perch = pick.perch
	f.creep = pick.walk
	f.creepSpeed = f.rng:draw(spec.speed)
	f.creeps = (f.creeps or 0) + 1
	f.glanceTarget = nil
	return true
end

-- The arc's points along the hop: s from 0 to 1.
local function arcPoint(from: Vector3, to: Vector3, apex: number, s: number): Vector3
	return from:Lerp(to, s) + Vector3.yAxis * (4 * apex * s * (1 - s))
end
K.arcPoint = arcPoint

-- Whether the whole arc is clear for the fly's graph (six chords).
local function arcClear(f: any, from: Vector3, to: Vector3, apex: number): boolean
	local prev = from
	for i = 1, 6 do
		local p = arcPoint(from, to, apex, i / 6)
		if not f.graph:clear(prev, p) then return false end
		prev = p
	end
	return true
end

local function begin(f: any, target: any, to: Vector3, normal: Vector3, now: number): boolean
	local h = f.profile.body.hop
	f.flight:release()
	f.side = nil
	if target ~= nil then
		if f.perch and f.perch.occupant == f.id then f.perch.occupant = "" end
		target.reserved = f.id
	end
	local d = (to - f.position).Magnitude
	f.hop = { from = f.position, to = to, apex = h.apex, t0 = now, time = h.time * (0.6 + 0.4 * math.clamp(d / h.max, 0, 1)), target = target, normal = normal }
	f.state = "HOP"; f.stateSince = now; f.goal = "flee"; f.goalSince = now; f.walkLeft = 0; f.pending = nil
	f.hops = (f.hops or 0) + 1
	return true
end

-- The escape hop, from where the fly is (perched, alert or in the jaws): true when one began.
function K.hop(f: any, now: number): boolean
	local h = f.profile.body.hop
	if h == nil or f.hop ~= nil then return false end
	local from = f.position
	local danger = if f.senses.hasLastSeen then f.senses.lastSeenPosition else from - f.heading
	local here = (from - danger).Magnitude
	local list = {}
	for _, c in f.graph.perches do
		if c ~= f.perch and c.valid and c.occupant == "" and c.reserved == "" then
			local rest = f.graph:rest(c)
			local d = (rest - from).Magnitude
			local away = (rest - danger).Magnitude
			if d >= h.min and d <= h.max and away > here then table.insert(list, { perch = c, rest = rest, score = away + c.shelter * 2 }) end
		end
	end
	table.sort(list, function(a: any, b: any) return a.score > b.score or (a.score == b.score and a.perch.id < b.perch.id) end)
	for i, c in list do
		if i > 4 then break end
		if arcClear(f, from, c.rest, h.apex) then return begin(f, c.perch, c.rest, c.perch.normal, now) end
	end
	-- level ground: a spot on the surface it stands on, away from the danger, half way between the hop's shortest and longest
	if f.normal:Dot(Vector3.yAxis) > 0.9 then
		local away = from - danger
		local base = if Vector3.new(away.X, 0, away.Z).Magnitude > 1e-3 then math.atan2(away.X, away.Z) else math.atan2(f.heading.X, f.heading.Z)
		local dist = (h.min + h.max) / 2
		for i = 0, 7 do
			local a = base + (if i % 2 == 0 then 1 else -1) * math.floor((i + 1) / 2) * math.pi / 4
			local spot = Vector3.new(from.X + math.sin(a) * dist, from.Y, from.Z + math.cos(a) * dist)
			local hit = f.graph.cast(spot + Vector3.yAxis * 0.6, spot - Vector3.yAxis * 1.0)
			if hit and hit.Normal:Dot(Vector3.yAxis) > 0.98 then
				local rest = hit.Position + Vector3.yAxis * f.graph.p.body.hover_wu
				if arcClear(f, from, rest, h.apex) then return begin(f, nil, rest, Vector3.yAxis, now) end
			end
		end
	end
	return false
end

-- One tick of a hop in the air; it lands at the end.
function K.step(f: any, now: number, _dt: number)
	local h = f.hop
	local s = math.clamp((now - h.t0) / h.time, 0, 1)
	local p = arcPoint(h.from, h.to, h.apex, s)
	local flat = Vector3.new(p.X - f.position.X, 0, p.Z - f.position.Z)
	if flat.Magnitude > 1e-4 then f.heading = flat.Unit end
	f.position = p
	if s < 1 then return end
	f.hop = nil
	local target = h.target
	if target ~= nil then
		if target.reserved == f.id then target.reserved = "" end
		if target.occupant == "" then target.occupant = f.id end
		f.perch = target
		f.position = f.graph:rest(target)
		f.normal = target.normal
	else
		f.position = h.to
		f.normal = h.normal
		if f.perch and f.perch.occupant == "" then f.perch.occupant = f.id end
	end
	-- a heading along the new normal has no turn to give: lay it flat on the surface
	local tangent = f.heading - f.normal * f.heading:Dot(f.normal)
	f.heading = if tangent.Magnitude > 1e-3 then tangent.Unit else (if math.abs(f.normal.Y) > 0.9 then Vector3.new(0, 0, -1) else Vector3.yAxis)
	f.state = "PERCHED"; f.stateSince = now; f.goal = "rest"; f.goalSince = now
	f:beginStay(now)
	local after = f.profile.body.hop.fly_after
	if after ~= nil and not f.profile.body.flightless and f.rng:next() < after then f:launch("move", now) end
end

-- A flier of the bestiary (flight.home_in) in the air with no perch within a flight (one that slipped the jaws far from its perches, carried there by the
-- spider): a leg of open flight toward the nearest free perch, at most four fifths of its longest flight, then it looks again. True when one began.
function K.homeIn(f: any, now: number): boolean
	local best: any, far = nil, math.huge
	for _, c in f.graph.perches do
		if c.valid and c.occupant == "" and c.reserved == "" then
			local d = (f.graph:rest(c) - f.position).Magnitude
			if d < far then best, far = c, d end
		end
	end
	if best == nil then return false end
	local p = f.profile.flight
	local to = f.graph:rest(best) + best.normal * p.approach_wu
	local dir = (to - f.position).Unit
	local step = math.min(far - p.approach_wu, p.max_flight_wu * 0.8)
	for _, rise in { 0, 2, 4 } do
		local point = f.position + dir * step + Vector3.yAxis * rise
		if f.graph:clear(f.position, point) then
			f.flight:begin({ f.position, point }, nil, "move", now)
			f.homing = (f.homing or 0) + 1
			return true
		end
	end
	return false
end

-- A fly standing on a surface with its heading along the surface's normal (a flight that ended square on to the wall, a fly spawned on the wall) has no way to
-- turn or walk and no frame to be drawn in: its heading is laid on the surface, head up a wall (along the world's up, or along -Z on a level face).
function K.upright(f: any)
	local up = if math.abs(f.normal.Y) > 0.9 then Vector3.new(0, 0, -1) else Vector3.yAxis
	f.heading = (up - f.normal * up:Dot(f.normal)).Unit
	f.homeHeading = f.heading
end

-- The sidestep (a profile with body.sidestep): carries on one under way, or begins one when the fly is alert, watched from its own side and the perch behind
-- is free. True while it is moving round.
function K.sidestep(f: any, now: number, _dt: number): boolean
	local s = f.side
	if s ~= nil then
		local t = math.clamp((now - s.t0) / s.time, 0, 1)
		local u = 1 - t
		f.position = s.from * (u * u) + s.ctrl * (2 * u * t) + s.to * (t * t)
		if t >= 1 then
			f.side = nil
			f.normal = s.normal
			f.restSpot = f.position; f.homeHeading = f.heading; f.walkLeft = 0; f.fidgetUntil = 0
		end
		return true
	end
	if f.state ~= "ALERT" or not f.senses.hasLastSeen or now < (f.sideNext or 0) then return false end
	local perch = f.perch
	if perch == nil or perch.behind == nil then return false end
	if (f.senses.lastSeenPosition - f.position):Dot(f.normal) <= 0 then return false end -- already on the far side from the spider
	local other: any = nil
	for _, c in f.graph.perches do if c.id == perch.behind then other = c; break end end
	if other == nil or not other.valid or other.occupant ~= "" or other.reserved ~= "" then return false end
	local spec = f.profile.body.sidestep
	if perch.occupant == f.id then perch.occupant = "" end
	other.occupant = f.id
	f.perch = other
	local to = f.graph:rest(other)
	local round: Vector3 = perch.round or (f.position + to) / 2
	f.side = { from = f.position, to = to, ctrl = round * 2 - (f.position + to) / 2, t0 = now, time = spec.time, normal = other.normal }
	f.sideNext = now + spec.time + spec.rest
	f.sidesteps = (f.sidesteps or 0) + 1
	return true
end

-- The profile of the same animal for the other part of the day, or nil when `p` is already the right one (or has none).
function K.counterpart(p: any, dusk: boolean): any
	local name = if dusk then p.body.dusk else p.body.day
	if name == nil then return nil end
	return (Species :: any)[name]
end

-- Dusk or day for a director of a kind with a dusk profile: swaps the director's profile (what it spawns) and every fly's.
function K.light(d: any, dusk: boolean)
	local to = K.counterpart(d.p, dusk)
	if to == nil then return end
	local from = d.p
	d.p = to
	for _, f in d.flies do
		if f.profile == from then
			local rate = from.behavior.restless_per_s
			f.restlessRate = if rate > 0 then f.restlessRate / rate * to.behavior.restless_per_s else to.behavior.restless_per_s
			f.profile = to
			f.perchedSince = d.now
		end
	end
	d.dusk = dusk
end

-- Whether an hour of the life clock is the moths' time: from `from` (dusk) through the night to `to` (dawn).
function K.isDusk(hour: number, from: number, to: number): boolean
	return hour >= from or hour < to
end

-- The grip on a struggling prey, each tick before the jaws' own step: a moth's first grip may slip, a crane fly may leave a leg. Returns "slip" or "shed" when
-- the prey got away (it is out of the jaws and `escape` has taken it), else nil.
function K.grip(feeding: any, escape: (any) -> ()): string?
	local f = feeding.held
	if f == nil or not feeding.struggling then return nil end
	local b = f.profile.body
	local what: string? = nil
	if b.slip_chance ~= nil and not f.slipDrawn then
		f.slipDrawn = true
		if f.rng:next() < b.slip_chance then what = "slip" end
	end
	if what == nil and b.shed_chance ~= nil and not f.shedDrawn then
		f.shedDrawn = true
		if f.rng:next() < b.shed_chance then f.shedAt = f.rng:draw(b.shed_after) end
	end
	if what == nil and f.shedAt ~= nil and feeding.elapsed >= f.shedAt then
		f.shedAt = nil
		f.legsLost = (f.legsLost or 0) + 1
		what = "shed"
	end
	if what == nil then return nil end
	feeding.held = nil
	feeding.struggling = false
	feeding.feeding = false
	feeding.note = if what == "slip" then "It slipped free." else "It left a leg and got away."
	escape(f)
	return what
end

return K
