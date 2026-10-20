--!strict
-- The mate (ROBLOX-79): a spider of the opposite sex that comes onto the sill when the played spider is full-grown and well fed, is courted by the
-- player, mates and walks off. It is not prey (the player's strike drives it off, it is never caught or eaten), it is not a rival (it never attacks),
-- and the wasp ignores it. It is the shape of the rival: a plain record in LifeLoop's checkpoint graph (life.mate), a step that decides what it is doing
-- from a snapshot of the player (no clock, no engine, no hidden tracking), arrival rules like the rival's (Data/MatingRules), and legs that are the
-- rival's own (Predator/MateDrive, which gives RivalDrive a record in the rival's vocabulary). It keeps out of the retreat for the same reason.
--
-- ROBLOX-89: the pair's pause is the mating scene (Life/MatingScene, drawn by the client). `scene` is true from the moment the meter fills until the scene is over:
-- the whole pause, and for a male mate the walk off the sill that is its last beat. Nothing else reads it but the checkpoint (no rest is kept inside the scene) and
-- the client (the camera, the locked controls, the captions: `Mate.sceneTime` is the scene's clock, which a wasp visit holds like every other timer of the mate).
--
-- States: away (not on the sill: not arrived yet, driven off, gone for the day or for good), wander (walking the sill, in no hurry), approach (it has
-- seen the spider and walks up to it), attend (it stands facing the spider, close), pair (the pause together once the courtship meter is full), leaving
-- (walking to the edge: driven off, the evening, or after mating). The courtship meter lives here (m.meter, 0 to 1) and is the player's to fill.
--
-- The snapshot `s` (the player's place and what it is doing, and the day) is built by the caller each tick; Life/Mating.tick does it for the game and
-- adds `mayArrive`, which says whether the cycle wants a mate on the sill now.
local Rules = require(script.Parent.Parent.Data.MatingRules)
local PreyMath = require(script.Parent.Parent.Prey.PreyMath)
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)
local WorldMap = require(script.Parent.Parent.World.WorldMap)

local Mate = {}

local STATES: { [string]: boolean } = { away = true, wander = true, approach = true, attend = true, pair = true, leaving = true }
local REASONS: { [string]: boolean } = { [""] = true, driven = true, dusk = true, rest = true, mated = true, sex = true, rejected = true, cut = true }
-- ROBLOX-106: the courtship's record while it goes on, in the standard rules (Mate.track): seconds of the court, seconds courting well, the distance summed over those,
-- seconds near it but not facing it, the breaks, and whether it was courting well last tick. All optional (a record from before has none).
local COURT = { "court_t", "court_ok", "court_near", "court_away", "court_breaks" }
Mate.STATES = STATES

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function vec3(v: any): boolean
	return (typeof(v) == "Vector3" or type(v) == "table") and finite(v.X) and finite(v.Y) and finite(v.Z) and v.Magnitude <= 1000
end

function Mate.new(): any
	local at = Rules.arriveAt
	return {
		state = "away", position = at, previous = at, up = Vector3.yAxis, heading = -Vector3.xAxis,
		leg = 0, elapsed = 0, meter = 0, lost = 0, sex = "male", scale = 1, reason = "", scene = false,
	}
end

-- How long the pair are together before the mate leaves: a male mate for the first three beats of the scene, a female mate through all four.
function Mate.pairLength(m: any): number
	return if m.sex == "female" then Rules.stayPairSeconds else Rules.pairSeconds
end

-- The scene's clock in seconds (0 to Rules.sceneSeconds) while the mating scene plays, or nil when it does not.
function Mate.sceneTime(m: any): number?
	if m == nil or m.scene ~= true then return nil end
	if m.state == "pair" then return m.elapsed end
	if m.state == "leaving" then return Mate.pairLength(m) + m.elapsed end
	return nil
end

function Mate.opposite(sex: string): string
	return if sex == "male" then "female" else "male"
end

-- The size of this mate relative to the played spider's look: a male slimmer and smaller, a female larger, each varying a little by a seeded draw from its
-- number (the same world, the same mate: the same size, on any return to a rest).
function Mate.scaleFor(seed: number, n: number, sex: string): number
	local g = PreyRandom.new((seed * 73856093 + n * 19349663 + 5821) % 2147483647)
	g:next()
	local u = g:next()
	return (Rules.scale[sex] or 1) * (1 + (u - 0.5) * 2 * Rules.scaleSpread)
end

-- On the sill (anything but away).
function Mate.present(m: any): boolean
	return m ~= nil and m.state ~= "away"
end

-- Walking, at the rival's pace; or standing (the courtship states, a wasp visit).
function Mate.walking(m: any): boolean
	return m.state == "wander" or m.state == "approach" or m.state == "leaving"
end

-- Can the player court it now? It is on the sill and not on its way out or together already.
function Mate.courtable(m: any): boolean
	return m ~= nil and (m.state == "wander" or m.state == "approach" or m.state == "attend")
end

-- The mating scene is playing, or the pair are together (ROBLOX-91: the rival is paused for it, and so is the arrival of a new one).
function Mate.sceneActive(m: any): boolean
	return m ~= nil and (m.scene == true or m.state == "pair")
end

-- Is the player courting it now (ROBLOX-91)? It can be courted and the courtship meter is rising or falling (it is not empty), or the spider is within courting range of it
-- (Rules.nearWu). The rival keeps away from a courting pair: Predator/RivalSpider pauses it, like the wasp's visit, so a lunge cannot land on a spider standing still for the meter.
function Mate.courting(m: any, position: Vector3): boolean
	if m == nil or not Mate.courtable(m) then return false end
	return m.meter > 0 or (m.position - position).Magnitude <= Rules.nearWu
end

local function clearCourt(m: any)
	for _, k in COURT do m[k] = nil end
	m.court_on = nil
end

local function leave(m: any, reason: string)
	m.state, m.elapsed, m.meter, m.reason, m.lost, m.scene = "leaving", 0, 0, reason, 0, false
	clearCourt(m)
	m.cut = nil
end

-- ROBLOX-106: the mate refuses the spider (`reason` "rejected") or flees a rival cutting in ("cut"): out of the pair, off the sill for the day, as a driven-off mate.
function Mate.refuse(m: any, reason: string)
	leave(m, reason)
end

-- ROBLOX-106: one tick of the courtship's record (the standard rules; Mate.step calls it when the snapshot says `nature`). `ok`: courting well this tick (close, in sight,
-- facing, still); `facing`; `dist` to the spider. The record starts with the court and is cleared when the meter is empty and the spider is not courting.
function Mate.track(m: any, ok: boolean, facing: boolean, dist: number, dt: number)
	if not ok and m.meter <= 0 then
		if m.court_t ~= nil then clearCourt(m) end
		return
	end
	if m.court_t == nil then
		for _, k in COURT do m[k] = 0 end
		m.court_on = false
	end
	m.court_t += dt
	if ok then
		m.court_ok += dt
		m.court_near += dist * dt
	else
		if m.court_on == true then m.court_breaks += 1 end
		if dist <= Rules.nearWu and not facing then m.court_away += dt end
	end
	m.court_on = ok
end

-- ROBLOX-106: the courtship's quality, 0 to 1 (MatingRules.game), from its record: breaks, distance, facing and length. 1 for a mate with no record.
function Mate.quality(m: any): number
	local g = Rules.game
	if m.court_t == nil or m.court_t <= 0 then return 1.0 end
	local still = 1 / (1 + g.breakCost * (m.court_breaks or 0))
	local mean = if (m.court_ok or 0) > 1e-6 then m.court_near / m.court_ok else Rules.attendWu
	local near = 1 - g.farCost * math.clamp((mean - Rules.attendWu) / (Rules.nearWu - Rules.attendWu), 0, 1)
	local face = 1 - g.awayCost * math.clamp((m.court_away or 0) / m.court_t, 0, 1)
	local long = math.clamp(Rules.courtSeconds * 1.5 / m.court_t, g.longFloor, 1)
	return still * near * face * long
end

local function gone(m: any)
	m.state, m.elapsed, m.meter, m.lost, m.scene = "away", 0, 0, 0, false
	clearCourt(m)
	m.cut = nil
end

-- The pause is over (its time, or a rest during it): it leaves, mated. A male mate's walk off the sill is still the scene's last beat.
local function parted(m: any)
	leave(m, "mated")
	m.scene = m.sex ~= "female" and Rules.sceneSeconds > Rules.pairSeconds
end

-- The player skips the scene (a jump or cancel after Rules.skipAfter seconds of it; `force` for a wasp visit, which cannot wait): the pair part at once and the mate
-- walks off. Returns "mated" for a pause cut short, and "" when there is nothing to part (a male mate already walking just ends the scene's last beat).
function Mate.skip(m: any, force: boolean?): string
	if m == nil or m.scene ~= true then return "" end
	if m.state == "pair" then
		if force ~= true and m.elapsed < Rules.skipAfter - 1e-9 then return "" end
		leave(m, "mated")
		return "mated"
	end
	if m.state == "leaving" and (force == true or Mate.sceneTime(m) :: number >= Rules.skipAfter - 1e-9) then m.scene = false end
	return ""
end

-- Whether the player is facing it: the mate within Rules.faceDeg of where the player looks, in the plane the player stands on.
function Mate.facing(m: any, s: any): boolean
	local delta = m.position - s.position
	local up = s.up or Vector3.yAxis
	local flat = delta - up * delta:Dot(up)
	if flat.Magnitude < 0.05 then return true end
	return s.heading:Dot(flat.Unit) >= math.cos(math.rad(Rules.faceDeg))
end

-- The conditions of courting this tick: close, in sight, facing it, standing still; `dance` is whether the display the peacock spider owes is being given
-- (always true for a spider that owes none).
function Mate.conditions(m: any, s: any, sees: boolean): (boolean, boolean)
	local dist = (m.position - s.position).Magnitude
	local still = s.grounded ~= false and not s.moving and not s.airborne and not s.onLine
	local ok = dist <= Rules.nearWu and sees and Mate.facing(m, s) and still
	local dance = (not s.needsDance) or s.dancing == true
	return ok, dance
end

-- One fixed tick. Returns the event of this tick: "" (nothing), "arrived", "noticed" (it has seen the spider), "driven" (struck at or jumped at: it
-- leaves for the day), "courted" (the meter is full: they are together), "mated" (the pause is over: it leaves) or "gone" (it is off the sill; m.reason
-- says why: driven, dusk, rest, mated or sex). The mate does not move itself: the drive does (MateDrive); a mate with no drive stands where it is put.
function Mate.step(m: any, dt: number, s: any): string
	if dt <= 0 or dt ~= dt then return "" end
	dt = math.min(dt, 0.05)
	m.previous = m.position
	local st = m.state
	if st == "away" then
		if not s.mayArrive or s.day < Rules.firstDay or s.hour < Rules.arriveHour or s.hour >= Rules.arriveUntil then return "" end
		if s.resting or s.wasp then return "" end
		if (s.position - Rules.arriveAt).Magnitude < Rules.arriveDistance then return "" end
		m.state, m.elapsed, m.meter, m.lost, m.reason = "wander", 0, 0, 0, ""
		m.position, m.previous, m.up, m.heading, m.leg = Rules.arriveAt, Rules.arriveAt, Vector3.yAxis, -Vector3.xAxis, (s.day or 0) * 7
		return "arrived"
	end
	-- The player rests: it is gone without being seen to go. (A pair that is together finishes first: the mating is not cut short.)
	if s.resting then
		if st == "pair" then
			parted(m)
			return "mated"
		end
		gone(m)
		m.reason = if st == "leaving" and m.reason == "mated" then "mated" else "rest"
		return "gone"
	end
	-- A wasp visit holds everything still (like the rival): no time passes for it and the meter is not touched.
	if s.wasp then return "" end
	m.elapsed += dt
	local delta = s.position - m.position
	local dist = delta.Magnitude
	if st == "leaving" then
		if m.scene == true and Mate.pairLength(m) + m.elapsed >= Rules.sceneSeconds then m.scene = false end -- (the scene's last beat is over)
		local out = (m.position - Rules.exitAt)
		if m.elapsed >= Rules.leaveSeconds or Vector3.new(out.X, 0, out.Z).Magnitude <= Rules.exitRadius then
			gone(m)
			return "gone"
		end
		return ""
	end
	if st == "pair" then
		if m.elapsed >= Mate.pairLength(m) then
			parted(m)
			return "mated"
		end
		return ""
	end
	-- The player became the same sex as the mate (the spider was changed in the Settings): it has no business here.
	if s.sex ~= nil and s.sex == m.sex then
		leave(m, "sex")
		return ""
	end
	-- The evening, or the hours before the morning (only a restored record can have it here at night).
	if s.hour >= Rules.leaveHour or s.hour < Rules.arriveHour then
		leave(m, "dusk")
		return ""
	end
	-- A jump at it, or a strike at it: driven off for the day. It is never caught.
	local struck = false
	if s.striking and not s.holding and s.previous ~= nil then
		local _, d = PreyMath.sweepClosest(s.previous, s.position, m.previous, m.position)
		struck = d < Rules.strikeWu
	end
	if struck or (s.airborne and dist < Rules.jumpAtWu) then
		leave(m, "driven")
		return "driven"
	end
	-- What it sees: the drive's decision (ten times a second, at any height) or, with no drive, distance and the sight query.
	local D = s.drive
	local sees: boolean
	if D then sees = D.sees == true else sees = dist < 8 and not (s.blocked ~= nil and s.blocked(m.position, s.position)) end
	if s.safe then sees = false end -- the retreat is private: it neither notices nor courts a spider in the crack
	local event = ""
	if st == "wander" then
		if sees then
			m.state, m.lost = "approach", 0
			event = "noticed"
		end
	else
		if sees then m.lost = 0 else m.lost += dt end
		if m.lost >= Rules.loseSeconds or dist > Rules.loseWu * 3 then
			m.state, m.lost = "wander", 0
		elseif st == "approach" and dist <= Rules.attendWu then
			m.state = "attend"
		elseif st == "attend" and dist > Rules.loseWu then
			m.state = "approach"
		end
	end
	-- The meter.
	local ok, dance = Mate.conditions(m, s, sees)
	if s.nature == true then Mate.track(m, ok, Mate.facing(m, s), dist, dt) end -- (ROBLOX-106)
	if ok and dance then
		m.meter = math.min(1, m.meter + dt / Rules.courtSeconds)
	elseif not ok then
		m.meter = math.max(0, m.meter - dt * Rules.decayPerSecond)
	end
	if m.meter >= 1 - 1e-9 then
		m.meter, m.state, m.elapsed, m.scene = 1, "pair", 0, true
		return "courted"
	end
	return event
end

-- What the spider's senses make of it: a moving thing on the sill, like the rival and unlike prey (never a target).
function Mate.percept(m: any): any
	if m == nil or m.state == "away" then return nil end
	return { id = "mate_spider", position = m.position, radius = 0.4, velocity = (m.position - m.previous) * 60, maxCategory = "movement" }
end

-- Whether a record is good (nil is: a life that has had no mate). It is on the sill, never in the crack, when it is on the sill. ROBLOX-94: `region` is the region it
-- belongs to (the sill's unless given): where it may stand is that region's bounds, outside that region's retreats.
function Mate.valid(m: any, region: string?): boolean
	if m == nil then return true end
	if type(m) ~= "table" or not STATES[m.state] then return false end
	for _, k in { "elapsed", "lost" } do
		local n = m[k]
		if n ~= nil and (not finite(n) or n < 0) then return false end
	end
	if m.meter ~= nil and (not finite(m.meter) or m.meter < 0 or m.meter > 1) then return false end
	if m.leg ~= nil and (not finite(m.leg) or m.leg < 0 or m.leg > 1e9 or m.leg % 1 ~= 0) then return false end
	if m.sex ~= nil and m.sex ~= "male" and m.sex ~= "female" then return false end
	if m.scale ~= nil and (not finite(m.scale) or m.scale < 0.5 or m.scale > 2) then return false end
	if m.reason ~= nil and (type(m.reason) ~= "string" or not REASONS[m.reason]) then return false end
	if m.scene ~= nil and type(m.scene) ~= "boolean" then return false end
	-- (ROBLOX-106: the courtship's record and the rival's level, optional)
	for _, k in COURT do
		local n = m[k]
		if n ~= nil and (not finite(n) or n < 0 or n > 1e6) then return false end
	end
	if m.court_breaks ~= nil and m.court_breaks % 1 ~= 0 then return false end
	if m.court_on ~= nil and type(m.court_on) ~= "boolean" then return false end
	if m.cut ~= nil and (not finite(m.cut) or m.cut < 0 or m.cut > 1) then return false end
	local atRest = m.state == "away" -- (the scene is the pause, or the walk off after it: never away)
	if m.scene == true and (atRest or not (m.state == "pair" or (m.state == "leaving" and m.reason == "mated"))) then return false end -- (the scene is the pause, or the walk off after it)
	for _, k in { "position", "previous", "heading", "up" } do
		if m[k] ~= nil and not vec3(m[k]) then return false end
	end
	if m.up ~= nil and math.abs(m.up.Magnitude - 1) > 0.05 then return false end
	if not atRest then
		local p, id = m.position, region or WorldMap.HOME
		if p == nil or not WorldMap.inBounds(p, id) or WorldMap.inRetreat(Vector3.new(p.X, p.Y, p.Z), id) ~= nil then return false end
	end
	return true
end

return Mate
