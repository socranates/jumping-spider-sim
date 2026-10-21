--!strict
-- The male rival's contest display (ROBLOX-127): how a male jumping spider meets another spider, drawn on top of the rival's rules. Pure, Vector3-free and
-- display only: nothing here moves the rival, its collider, its senses, its timing or any outcome (Predator/RivalSpider and RivalDrive decide all of that as
-- before); SpiderRig reads the pose (look.contest) and the client hands it the rival's state each frame.
--
-- What the sources describe (DOC): male contests open at a distance with the males facing each other, the body raised and legs I held up and forward (Phidippus
-- clarus, Elias et al. 2008, PMC2598435: a hunched posture, the front legs curled in front, then approaches or retreats with legs I stretched out); in Cosmophasis
-- umbratica (Lim & Li 2004) the males close by short skittering with legs I raised in two positions and the chelicerae held open, the basal segments 30 to 90 degrees
-- apart, lunge, and grapple (hooking and pushing down each other's legs, locked chelicerae) only in the contests that go that far; the one pushed back, and in a
-- mismatched pair the smaller, decamps (both papers; in P. clarus the bigger male mostly won because its rival retreated). Phidippus males also zigzag in display
-- (Edwards 1981, Psyche 88:199, of courting P. mystaceus). The game's ritual, mapped onto the rival's states (ART: which state shows which act, every number):
--   "faceoff"  stalking within FACE_WU of the spider: body raised, legs I up and forward, palps up, the chelicerae a little open, and stop-and-go sideways skitters
--              (the zigzag: the drawn body steps a little to one side or the other in seeded bursts and pauses; the simulation's path is the drive's, untouched)
--   "spread"   stalking within SPREAD_WU, and the windup: legs I high and spread wide, the chelicerae open, a tremor in the raised legs, the skitters
--   "grapple"  the lunge (the escalation, when neither has backed down): legs I forward and down to hook, the chelicerae wide
--   "retreat"  recovering after the spider got clear of its lunge, sprang clear of the spider's strike, bit back, or tore free: legs I lowered, the body low and turned a
--              little away, when it is the smaller of the two; the bigger holds its ground, legs I half up (`hold`)
--   "none"     anything else (patrol, far off, held, carried, gone): the pose eases out and the motor's legs are the rig's again
-- The skitters' rhythm and the side the retreat turns to are drawn from the rival's own seeded stream (the world's seed, the day, its contests and its patrol
-- leg, all kept in its record, and the display's own count of bouts): the same rival in the same moment shows the same display, and a return to a rest rerolls nothing
-- of the simulation (the display keeps no record; it starts again from rest).
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)

local RivalDisplay = {}

export type Pose = {
	phase: string, presence: number,
	rear: number, legs: number, palps: number, yaw: number, sweep: number, tremor: number, -- (the tarantula's pose's fields, as SpiderRig reads them)
	reach: number, hook: number, spread: number, lateral: number, lower: number,
}

RivalDisplay.FACE_WU = 6.0 -- studs: within this, a stalking rival faces off (its sight is 8)
RivalDisplay.SPREAD_WU = 4.4 -- within this, the full display (the windup begins at 3.2, RivalRules.reachWu)
RivalDisplay.RETREAT_SECONDS = 3.0 -- as long as the rival's recover lasts
RivalDisplay.RISE = 1 / 0.35 -- how fast a level goes up (per second) and comes down
RivalDisplay.FALL = 1 / 0.5
RivalDisplay.SKITTER = { step = { 0.18, 0.42 }, pause = { 0.25, 0.70 }, amplitude = 0.11, yawDeg = 12 } -- a burst's seconds, a pause's, how far the drawn body steps (studs at scale 1), the turn with it
RivalDisplay.REAR_DEG = 9 -- the prosoma raised in the face-off and the display
RivalDisplay.PALPS_DEG = 16
RivalDisplay.TURN_AWAY_DEG = 28 -- the retreat's turn
RivalDisplay.TREMOR_HZ = 7

-- The levels each phase asks for: legs I raised (legs), how high and spread (reach), hooked (hook), the chelicerae (spread), the body raised (rear, a share of REAR_DEG),
-- the palps (palps, a share of PALPS_DEG), the crouch (lower) and whether the skitters run (skitter).
RivalDisplay.TARGETS = {
	none = { legs = 0, reach = 0, hook = 0, spread = 0, rear = 0, palps = 0, lower = 0, skitter = 0 },
	faceoff = { legs = 0.85, reach = 0, hook = 0, spread = 0.35, rear = 0.8, palps = 0.6, lower = 0, skitter = 1 },
	spread = { legs = 1, reach = 1, hook = 0, spread = 1, rear = 1, palps = 1, lower = 0, skitter = 1 },
	grapple = { legs = 1, reach = 0, hook = 1, spread = 1, rear = 0.3, palps = 0.4, lower = 0, skitter = 0 },
	retreat = { legs = 0, reach = 0, hook = 0, spread = 0, rear = 0, palps = 0, lower = 1, skitter = 0 },
	hold = { legs = 0.55, reach = 0, hook = 0, spread = 0.3, rear = 0.5, palps = 0.4, lower = 0, skitter = 0 },
} :: { [string]: { [string]: number } }

-- The rival's events after which it backs off (RivalSpider.step's and RivalGrip.step's): its lunge missed, the spider sprang clear or bit back, or it tore free.
RivalDisplay.BACKS_OFF = { missed = true, sprang = true, counter = true, tore = true, touch = true } :: { [string]: boolean }

export type State = {
	phase: string, t: number, bout: number, rng: any?, key: string,
	skitterSide: number, skitterFrom: number, skitterTo: number, skitterT: number, skitterLeft: number, moving: boolean,
	retreatLeft: number, awaySide: number,
	levels: { [string]: number }, lateral: number, yaw: number, presence: number,
	pose: Pose,
}

function RivalDisplay.new(): State
	return {
		phase = "none", t = 0, bout = 0, rng = nil, key = "",
		skitterSide = 1, skitterFrom = 0, skitterTo = 0, skitterT = 0, skitterLeft = 0, moving = false,
		retreatLeft = 0, awaySide = 1,
		levels = { legs = 0, reach = 0, hook = 0, spread = 0, rear = 0, palps = 0, lower = 0, skitter = 0 },
		lateral = 0, yaw = 0, presence = 0,
		pose = { phase = "none", presence = 0, rear = 0, legs = 0, palps = 0, yaw = 0, sweep = 0, tremor = 0, reach = 0, hook = 0, spread = 0, lateral = 0, lower = 0 },
	}
end

-- The phase the rival's state asks for. `i`: state (the rival's), distance (studs, to the spider), event (this tick's, "" for none), smaller (the rival is the smaller
-- of the two, by drawn body length).
function RivalDisplay.phaseFor(d: State, i: any): string
	local s = i.state
	if s == "lunge" then return "grapple" end
	if d.retreatLeft > 0 and (s == "recover" or s == "patrol") then return if i.smaller then "retreat" else "hold" end
	if s == "windup" then return "spread" end
	if s == "stalk" and type(i.distance) == "number" then
		if i.distance <= RivalDisplay.SPREAD_WU then return "spread" end
		if i.distance <= RivalDisplay.FACE_WU then return "faceoff" end
	end
	return "none"
end

-- The seeded stream of one bout of display (a face-off that begins after none): the world's seed, the day, the rival's contests and patrol leg, the bout.
function RivalDisplay.stream(seed: number, day: number, contests: number, leg: number, bout: number): any
	return PreyRandom.mixed(seed, day, contests, leg, bout, 127)
end

local function smooth(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

-- One frame. `dt` is the frame's simulated time (0 when paused: nothing moves). `i` = { state, distance, event, smaller, seed, day, contests, leg, reduced }.
-- Returns the pose (the same table each time) for rig.threat.
function RivalDisplay.step(d: State, dt: number, i: any): Pose
	dt = math.max(0, dt)
	if RivalDisplay.BACKS_OFF[i.event or ""] then
		d.retreatLeft = RivalDisplay.RETREAT_SECONDS
		local g = RivalDisplay.stream(i.seed or 0, i.day or 0, i.contests or 0, i.leg or 0, d.bout + 1000)
		d.awaySide = if g:next() < 0.5 then -1 else 1
	end
	d.retreatLeft = math.max(0, d.retreatLeft - dt)
	local phase = RivalDisplay.phaseFor(d, i)
	if phase ~= d.phase then
		if (phase == "faceoff" or phase == "spread") and (d.phase == "none" or d.phase == "retreat" or d.phase == "hold") then
			-- a new bout of display: its own stream, from where the rival is in its record
			d.bout += 1
			d.rng = RivalDisplay.stream(i.seed or 0, i.day or 0, i.contests or 0, i.leg or 0, d.bout)
			d.skitterLeft, d.moving = 0, false
		end
		d.phase = phase
	end
	d.t += dt
	local target = RivalDisplay.TARGETS[phase]
	for k, v in target do
		local now = d.levels[k] or 0
		local rate = if v > now then RivalDisplay.RISE else RivalDisplay.FALL
		d.levels[k] = now + math.clamp(v - now, -rate * dt, rate * dt)
	end
	-- The skitters: a burst to a new side, then a pause; the drawn body steps there and back on the seeded rhythm.
	local sk = RivalDisplay.SKITTER
	if d.levels.skitter > 0 and d.rng ~= nil and not i.reduced then
		d.skitterLeft -= dt
		if d.skitterLeft <= 0 then
			local g = d.rng
			if d.moving then
				d.moving = false
				d.skitterFrom = d.skitterTo
				d.skitterLeft = sk.pause[1] + (sk.pause[2] - sk.pause[1]) * g:next()
			else
				d.moving = true
				d.skitterSide = -d.skitterSide
				d.skitterFrom = d.lateral / sk.amplitude
				d.skitterTo = d.skitterSide * (0.45 + 0.55 * g:next())
				d.skitterT = sk.step[1] + (sk.step[2] - sk.step[1]) * g:next()
				d.skitterLeft = d.skitterT
			end
		end
		local u = if d.moving and d.skitterT > 0 then smooth(1 - d.skitterLeft / d.skitterT) else 1
		local at = d.skitterFrom + (d.skitterTo - d.skitterFrom) * u
		d.lateral = at * sk.amplitude * d.levels.skitter
		d.yaw = (if d.moving then -d.skitterSide else 0) * math.rad(sk.yawDeg) * d.levels.skitter * math.sin(math.pi * u)
	else
		-- (no skitter: the step eases back to the middle; Reduced Motion has none at all)
		d.lateral = if i.reduced then 0 else d.lateral * math.max(0, 1 - 4 * dt)
		d.yaw = 0
	end
	local away = d.awaySide * math.rad(RivalDisplay.TURN_AWAY_DEG) * d.levels.lower
	local L = d.levels
	local presence = math.max(L.legs, L.reach, L.hook, L.spread, L.rear, L.palps, L.lower, math.abs(d.lateral) / RivalDisplay.SKITTER.amplitude)
	local p = d.pose
	p.phase = if presence > 0 then phase else "none"
	p.presence = presence
	p.legs, p.reach, p.hook, p.spread, p.lower = L.legs, L.reach, L.hook, L.spread, L.lower
	p.rear = math.rad(RivalDisplay.REAR_DEG) * L.rear
	p.palps = math.rad(RivalDisplay.PALPS_DEG) * L.palps
	p.yaw = d.yaw + away
	p.lateral = d.lateral
	p.sweep = 0
	p.tremor = if i.reduced then 0 else math.sin(math.pi * 2 * RivalDisplay.TREMOR_HZ * d.t) * L.reach
	return p
end

return RivalDisplay
