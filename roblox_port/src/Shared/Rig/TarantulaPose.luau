--!strict
-- The tarantulas' threat display and silk mat as a pose (ROBLOX-82): pure and Vector3-free, display only. Nothing here moves the body, the
-- collider, the senses, the jump or the silk; SpiderRig reads the pose, rears the drawn prosoma, lifts legs I and the pedipalps, turns the drawn
-- body and swings the spinnerets. All numbers are in Data/Tarantula (all artistic: no paper measures this).
--
-- A loop of phases (rear up, hold the threat posture, settle, turn about while the spinnerets sweep, hold, turn back) played from the time
-- it is given: step(dt, standing, moving) adds the dt it is handed, so slow motion slows the pose as it slows everything else. Walking,
-- a jump, leaving the surface or stop() end it at once; the pose then eases out over Tarantula.fadeOutSeconds from where it was, which is
-- how the legs go back to the motor. The same shape as PeacockDance.

local Tarantula = require(script.Parent.Parent.Data.Tarantula)

local TarantulaPose = {}
TarantulaPose.__index = TarantulaPose

-- Angles in radians. rear and palps are positive for up (the prosoma's front, the palps' tips); yaw is the body's turn about its up axis;
-- sweep is signed (the spinnerets' swing); legs and presence run 0..1; tremor is -1..1 (times the profile's size).
export type Pose = {
	phase: string, -- the phase of the loop, "none" when no pose shows
	presence: number, -- 0..1: how much of the pose shows (ramps in and out)
	rear: number,
	legs: number, -- legs I raised into the threat posture
	palps: number,
	yaw: number,
	sweep: number,
	tremor: number,
}

local TAU = math.pi * 2

local function smooth(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

TarantulaPose.NONE = { phase = "none", presence = 0, rear = 0, legs = 0, palps = 0, yaw = 0, sweep = 0, tremor = 0 } :: Pose

-- Which phase a loop time falls in: its index, the seconds into it and the loop time it starts at.
function TarantulaPose.phaseAt(t: number): (number, number, number)
	local phases = Tarantula.phases
	local u = t % Tarantula.loopSeconds
	local start = 0
	for i, p in phases do
		if u < start + p.seconds then return i, u - start, start end
		start += p.seconds
	end
	return #phases, phases[#phases].seconds, start - phases[#phases].seconds
end

-- The seconds each phase starts at, in order (so the levels below read by phase).
local function starts(): { [string]: number }
	local out: { [string]: number } = {}
	local at = 0
	for _, p in Tarantula.phases do
		out[p.id] = at
		at += p.seconds
	end
	return out
end
local START = starts()
local function seconds(id: string): number
	for _, p in Tarantula.phases do
		if p.id == id then return p.seconds end
	end
	return 0
end

-- The levels (0..1) at a loop time: `rise` (the prosoma, legs I and the palps up), `turn` (the body's pivot) and `swing` (the spinnerets' stroke).
local function levelsAt(u: number): (number, number, number)
	local rear, settle, turn, back = seconds("rear"), seconds("settle"), seconds("turn"), seconds("return")
	local rise = 0
	if u < START.threat then
		rise = smooth(u / rear)
	elseif u < START.settle then
		rise = 1
	elseif u < START.turn then
		rise = 1 - smooth((u - START.settle) / settle)
	end
	local pivot = 0
	if u >= START.turn and u < START.mat then
		pivot = smooth((u - START.turn) / turn)
	elseif u >= START.mat and u < START["return"] then
		pivot = 1
	elseif u >= START["return"] then
		pivot = 1 - smooth((u - START["return"]) / back)
	end
	local swing = 0
	if u >= START.turn then
		local ease = Tarantula.sweepEaseSeconds
		swing = math.min(smooth((u - START.turn) / ease), smooth((Tarantula.loopSeconds - u) / ease))
	end
	return rise, pivot, swing
end

-- The whole pose at a loop time, before presence. reduced: ReducedMotion (every angle halved, no tremble).
function TarantulaPose.rawPose(t: number, reduced: boolean): Pose
	local i, _, _ = TarantulaPose.phaseAt(t)
	local u = t % Tarantula.loopSeconds
	local rise, pivot, swing = levelsAt(u)
	local amp = if reduced then Tarantula.reducedMotion else 1
	local holding = u >= START.threat and u < START.settle
	local strokeT = u - START.turn
	return {
		phase = Tarantula.phases[i].id, presence = 1,
		rear = rise * math.rad(Tarantula.rearDeg) * amp,
		legs = rise,
		palps = rise * math.rad(Tarantula.palpDeg) * amp,
		yaw = pivot * math.rad(Tarantula.pivotDeg) * amp,
		sweep = swing * math.rad(Tarantula.sweepDeg) * amp * math.sin(TAU * Tarantula.sweepHz * strokeT),
		tremor = if reduced or not holding then 0 else math.sin(TAU * Tarantula.tremorHz * t) * smooth((u - START.threat) / 0.3) * smooth((START.settle - u) / 0.3),
	}
end

local function scaled(p: Pose, k: number): Pose
	return {
		phase = p.phase, presence = k, rear = p.rear * k, legs = p.legs * k, palps = p.palps * k, yaw = p.yaw * k, sweep = p.sweep * k, tremor = p.tremor * k,
	}
end

export type State = typeof(setmetatable(
	{} :: { t: number, active: boolean, presence: number, raw: Pose?, reduced: boolean },
	TarantulaPose
))

function TarantulaPose.new(): State
	return setmetatable({ t = 0, active = false, presence = 0, raw = nil :: Pose?, reduced = false }, TarantulaPose)
end

-- The display key: begin the loop from its start. Refused (false) when the spider is not standing still on a surface, or it is already on.
function TarantulaPose.start(self: State, standing: boolean, moving: boolean): boolean
	if self.active or not standing or moving then return false end
	self.t, self.active = 0, true
	return true
end

-- End the pose at once; it eases out over Tarantula.fadeOutSeconds from where it was.
function TarantulaPose.stop(self: State)
	self.active = false
end

-- The pose is on (it has not been ended).
function TarantulaPose.displaying(self: State): boolean
	return self.active
end

-- Showing at all (on, or still easing out).
function TarantulaPose.showing(self: State): boolean
	return self.active or self.presence > 0
end

-- One step of dt seconds (the simulation's, so slow motion slows the pose). standing: on a surface and not in a jump, on the line or resting;
-- moving: walking (or asked to).
function TarantulaPose.step(self: State, dt: number, standing: boolean, moving: boolean): Pose
	if self.active and (not standing or moving) then self.active = false end
	if self.active then
		self.t += dt
		self.presence = math.min(1, self.presence + dt / Tarantula.rampInSeconds)
		self.raw = TarantulaPose.rawPose(self.t, self.reduced)
	else
		self.presence = math.max(0, self.presence - dt / Tarantula.fadeOutSeconds)
		if self.presence == 0 then self.raw = nil end
	end
	local raw = self.raw
	if raw == nil then return TarantulaPose.NONE end
	return scaled(raw, smooth(self.presence))
end

return TarantulaPose
