--!strict
-- The mating scene (ROBLOX-89): what happens between "the meter is full" and "they part", as a pure plan. About fifteen seconds, in four beats, with a camera that
-- eases into a two-shot and makes a slow quarter-orbit over it. Nothing here knows the engine, the clock or the player: it is a function of a seeded plan and the
-- scene's own time `t` (the pair's pause in the simulation, Predator/Mate.sceneTime, which a wasp visit holds as it holds every timer of the mate), so a scene seen
-- again is the same scene, a restored world cannot reroll it, and tests/mating.luau checks it without Roblox. The client draws it (camera, cues to both rigs,
-- captions, the locked controls) and the simulation owns the parting: Life/Mating.tick ends the pause, Life/Mating.skip cuts it short.
--
-- The beats (seconds): 0 to 3 she turns to face him (the female turns toward the male: the player's spider as the female, the mate as the female for a peacock player);
-- 3 to 7 the two touch palps and front legs (a drawn pose through rig:cue("meet") on both rigs: a gentle reach, no more); 7 to 11 they settle together, still, the
-- abdomens breathing (rig:cue("settle")); 11 to 15 one goes: the male rises and walks off toward the sill's edge and the sill is the player's again, or, for a male
-- player, the female turns away and settles and he goes on (she stays). The game is for children and shows nothing but this.
--
-- The controls are locked for the scene; a skip (a jump or cancel) is allowed from `skipAfter` seconds on, and the scene never outlasts `SECONDS`. Reduced Motion: a
-- static two-shot (no orbit), the reach and the settle held as poses, the turn away at once.
local Rules = require(script.Parent.Parent.Data.MatingRules)
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)

local MatingScene = {}

MatingScene.SECONDS = Rules.sceneSeconds
MatingScene.SKIP_AFTER = Rules.skipAfter
MatingScene.EASE_SECONDS = 0.8 -- the camera's ease into the two-shot (and out of it after the scene)
MatingScene.BEATS = {
	{ name = "turn", from = 0.0, to = 3.0 },
	{ name = "touch", from = 3.0, to = 7.0 },
	{ name = "settle", from = 7.0, to = 11.0 },
	{ name = "depart", from = 11.0, to = 15.0 },
}
-- The cues to the rigs. "meet" for the touch beat (4 s); "settle" from the third beat: the male's for the beat (it rises as it goes) and the female's through the
-- last (she stays). Seconds are the cue's whole length including its ease in and out.
MatingScene.MEET_AT, MatingScene.MEET_SECONDS = 3.0, 4.0
MatingScene.SETTLE_AT = 7.0
MatingScene.SETTLE_SECONDS = { male = 4.0, female = 8.0 }
-- The quarter-orbit of the camera about the pair: the sweep, centred on the view from the side (both spiders side by side, never one behind the other).
MatingScene.ORBIT_DEG = 90.0
-- The camera's distance from the pair's middle: at least this, or the pair's separation times SEP_K plus SEP_ADD (studs); and the height of the middle's mark above the
-- surface the pair stand on.
MatingScene.MIN_DISTANCE, MatingScene.SEP_K, MatingScene.SEP_ADD, MatingScene.LIFT = 4.2, 1.8, 2.6, 0.5
-- The female mate (a male player) turns away from the player in the last beat: how far and when.
MatingScene.TURN_AWAY_DEG, MatingScene.TURN_AWAY_AT, MatingScene.TURN_AWAY_SECONDS = 110.0, 11.0, 1.5

export type Plan = {
	seed: number, mateNo: number, day: number,
	playerSex: string, mateSex: string,
	dir: number, -- +1 or -1: which way the camera sweeps round the pair
	side: number, -- +1 or -1: which side of the pair it starts on
	jitterDeg: number, -- the sweep's centre, a few degrees off the side view
	elevationDeg: number, -- the camera's height above the pair's plane (slightly above)
	distanceK: number, -- about 1
	turnSign: number, -- +1 or -1: which way the female mate turns away
}

export type Pose = {
	t: number, beat: string, locked: boolean, canSkip: boolean,
	orbit: number, -- radians: the camera's turn about the pair from the side view
	turnAway: number, -- 0..1: how far the female mate has turned away (0 for a male mate)
	over: boolean,
}

export type Shot = { focus: Vector3, dir: Vector3, distance: number, up: Vector3, orbit: number, elevation: number }

local function smooth(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

local function sexOpposite(sex: string): string
	return if sex == "male" then "female" else "male"
end

-- The seeded plan of one scene: from the world's seed, the mate's number (Life/Mating's `mates`) and the day. The same mate on the same day is the same scene on
-- any return (nothing in it is saved: it is a function of numbers that are).
function MatingScene.plan(seed: number, mateNo: number, day: number, playerSex: string): Plan
	local g = PreyRandom.new((seed * 19349663 + mateNo * 83492791 + day * 73856093 + 7727) % 2147483647)
	g:next()
	g:next()
	local function draw(lo: number, hi: number): number return lo + (hi - lo) * g:next() end
	local function sign(): number return if g:next() < 0.5 then -1 else 1 end
	local plan: Plan = {
		seed = seed, mateNo = mateNo, day = day,
		playerSex = playerSex, mateSex = sexOpposite(playerSex),
		dir = sign(), side = sign(), jitterDeg = draw(-8, 8), elevationDeg = draw(28, 36), distanceK = draw(0.95, 1.05), turnSign = sign(),
	}
	return plan
end

-- The beat at scene time `t`: "turn", "touch", "settle", "depart", or "over" once the scene is done (and "" before it).
function MatingScene.beat(t: number): string
	if t < 0 then return "" end
	for _, b in MatingScene.BEATS do
		if t < b.to then return b.name end
	end
	return "over"
end

-- Whether the controls are still the scene's.
function MatingScene.locked(t: number): boolean
	return t >= 0 and t < MatingScene.SECONDS
end

-- Whether a skip is allowed at `t` (after SKIP_AFTER seconds, and while the scene plays).
function MatingScene.canSkip(t: number): boolean
	return t >= MatingScene.SKIP_AFTER - 1e-9 and t < MatingScene.SECONDS
end

-- The cues that fall due as the scene's clock passes from `from` (exclusive) to `to` (inclusive): { { name, seconds = { male, female } } }. The first call of a
-- scene is from -1, so a scene entered late (a restored world) gives the cues it has already passed all at once.
function MatingScene.cues(from: number, to: number): { { name: string, at: number, seconds: { male: number, female: number } } }
	local out = {}
	if from < MatingScene.MEET_AT and to >= MatingScene.MEET_AT then
		table.insert(out, { name = "meet", at = MatingScene.MEET_AT, seconds = { male = MatingScene.MEET_SECONDS, female = MatingScene.MEET_SECONDS } })
	end
	if from < MatingScene.SETTLE_AT and to >= MatingScene.SETTLE_AT then
		table.insert(out, { name = "settle", at = MatingScene.SETTLE_AT, seconds = { male = MatingScene.SETTLE_SECONDS.male, female = MatingScene.SETTLE_SECONDS.female } })
	end
	return out
end

-- The camera's turn about the pair at `t`, radians from the side view: the sweep of ORBIT_DEG centred a few degrees off it (`jitterDeg`), one way or the other
-- (`dir`), slow at the ends; under Reduced Motion none (the centre of the sweep, held).
function MatingScene.orbit(plan: Plan, t: number, reduced: boolean): number
	local centre = math.rad(plan.jitterDeg)
	if reduced then return centre end
	local u = smooth(t / MatingScene.SECONDS)
	return centre + plan.dir * math.rad(MatingScene.ORBIT_DEG) * (u - 0.5)
end

-- The female mate's turn away from the player, 0..1 (only when the mate is the female): from TURN_AWAY_AT over TURN_AWAY_SECONDS, at once under Reduced Motion.
function MatingScene.turnAway(plan: Plan, t: number, reduced: boolean): number
	if plan.mateSex ~= "female" or t < MatingScene.TURN_AWAY_AT then return 0 end
	if reduced then return 1 end
	return smooth((t - MatingScene.TURN_AWAY_AT) / MatingScene.TURN_AWAY_SECONDS)
end

function MatingScene.pose(plan: Plan, t: number, reduced: boolean): Pose
	return {
		t = t, beat = MatingScene.beat(t), locked = MatingScene.locked(t), canSkip = MatingScene.canSkip(t),
		orbit = MatingScene.orbit(plan, t, reduced), turnAway = MatingScene.turnAway(plan, t, reduced), over = t >= MatingScene.SECONDS,
	}
end

-- The two-shot at `t` for the spiders at `a` and `b` standing on a surface whose normal is `up`: the point the camera looks at (the pair's middle, a little up from
-- the surface), the unit direction from it to the camera (slightly above the pair's plane, at the orbit's angle from the side view), and the distance. Framing the
-- pair side by side at any separation: the distance grows with it. Pure; the camera (Client/SpiderCamera) turns it into a placed view, shortening it if something
-- stands in the way.
function MatingScene.shot(plan: Plan, t: number, reduced: boolean, a: Vector3, b: Vector3, up: Vector3): Shot
	local upU = if up.Magnitude > 1e-6 then up.Unit else Vector3.yAxis
	local delta = b - a
	local flat = delta - upU * delta:Dot(upU)
	local sep = flat.Magnitude
	local axis = if sep > 1e-4 then flat.Unit else (if math.abs(upU.Y) < 0.9 then upU:Cross(Vector3.yAxis).Unit else Vector3.xAxis)
	local perp = axis:Cross(upU) * plan.side -- the side of the pair, in the plane they stand on
	local orbit = MatingScene.orbit(plan, t, reduced)
	local turned = CFrame.fromAxisAngle(upU, orbit):VectorToWorldSpace(perp).Unit
	local e = math.rad(plan.elevationDeg)
	local dir = (turned * math.cos(e) + upU * math.sin(e)).Unit
	local focus = (a + b) * 0.5 + upU * MatingScene.LIFT
	local distance = math.max(MatingScene.MIN_DISTANCE, sep * MatingScene.SEP_K + MatingScene.SEP_ADD) * plan.distanceK
	return { focus = focus, dir = dir, distance = distance, up = upU, orbit = orbit, elevation = e }
end

return MatingScene
