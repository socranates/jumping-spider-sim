--!strict
-- The peacock spider's courtship dance as a pose (ROBLOX-29): pure, Vector3-free, display only. Nothing here moves the body, the
-- collider, the senses, the jump or the silk; SpiderRig reads the pose and bends the drawn abdomen, fan, palps and legs III.
-- All numbers are in Data/Peacock (documented ones from Girard et al. 2011, the rest marked artistic).
--
-- A dance is a loop of phases (approach with bobbing and a rumble-rump, the fan raised with legs III up, the fan dance with the leg
-- wave, a freeze with fan-flapping, a second dance, the fold) played from the time it is given: step(dt, standing, moving) adds
-- the dt it is handed, so slow motion slows the dance as it slows everything else. Walking, a jump, leaving the surface or stop()
-- end it at once; the pose then eases out over Peacock.fadeOutSeconds from where it was.

local Peacock = require(script.Parent.Parent.Data.Peacock)

local PeacockDance = {}
PeacockDance.__index = PeacockDance

-- Every angle is in radians. Sway and shiver are signed; fanOpen, legsRaise and legsWave run 0..1 (legsWave: 0 erect, 1 swept down).
export type Pose = {
	phase: string, -- the phase of the loop, "none" when no dance shows
	presence: number, -- 0..1: how much of the pose shows (ramps in and out)
	abdomenPitch: number, -- rear end up
	abdomenSway: number, -- side to side with the fan up
	shiver: number, -- the 12.1 Hz tremble of a rumble-rump
	fanOpen: number,
	palp: number, -- both pedipalps, in unison
	legsRaise: number,
	legsWave: number,
	rumble: number, -- 0..1: a rumble-rump is on (for the felt caption, not for the picture)
}

local TAU = math.pi * 2

local function smooth(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

PeacockDance.NONE = {
	phase = "none", presence = 0, abdomenPitch = 0, abdomenSway = 0, shiver = 0, fanOpen = 0, palp = 0, legsRaise = 0, legsWave = 0, rumble = 0,
} :: Pose

-- Which phase a loop time falls in: its index, the seconds into it and the loop time it starts at.
function PeacockDance.phaseAt(t: number): (number, number, number)
	local phases = Peacock.phases
	local u = t % Peacock.loopSeconds
	local start = 0
	for i, p in phases do
		if u < start + p.seconds then return i, u - start, start end
		start += p.seconds
	end
	return #phases, phases[#phases].seconds, start - phases[#phases].seconds
end

local LEVELS = { "pitch", "open", "legs", "sway", "wave", "flap", "bob", "palp" }

-- The levels (0..1) at a loop time: the previous phase's, eased toward this phase's over its `ease`.
local function levelsAt(t: number): ({ [string]: number }, string)
	local phases = Peacock.phases
	local i, u = PeacockDance.phaseAt(t)
	local cur, prev = phases[i], phases[if i == 1 then #phases else i - 1]
	local k = smooth(u / math.max(math.min(cur.ease or Peacock.ease, cur.seconds), 1e-6))
	local out: { [string]: number } = {}
	for _, name in LEVELS do
		local a, b = (prev :: any)[name] :: number, (cur :: any)[name] :: number
		out[name] = a + (b - a) * k
	end
	return out, cur.id
end

-- 0..1: a rumble-rump is on at this loop time (it starts `rumble` seconds into its phase and lasts Peacock.rumble.seconds).
local function rumbleAt(t: number): number
	local u = t % Peacock.loopSeconds
	local start = 0
	local r = Peacock.rumble
	for _, p in Peacock.phases do
		local at = p.rumble
		if at then
			local from, to = start + at, start + at + r.seconds
			if u >= from and u <= to then
				return math.min(smooth((u - from) / r.edgeSeconds), smooth((to - u) / r.edgeSeconds))
			end
		end
		start += p.seconds
	end
	return 0
end

-- 0..1: inside a bobbing bout (bouts and rests repeat through the loop; the phase's `bob` level says where they show).
local function bobBoutAt(t: number): number
	local b = Peacock.rates.bob
	local u = t % (b.boutSeconds + b.restSeconds)
	if u >= b.boutSeconds then return 0 end
	return math.min(smooth(u / 0.1), smooth((b.boutSeconds - u) / 0.1))
end

-- The whole pose at a loop time, before presence. reduced: ReducedMotion (half amplitudes, no tremble).
function PeacockDance.rawPose(t: number, reduced: boolean): Pose
	local L, id = levelsAt(t)
	local a, r = Peacock.amplitude, Peacock.rates
	local amp = if reduced then Peacock.reducedMotion else 1
	local rumble = rumbleAt(t)
	local bob = L.bob * bobBoutAt(t) * math.sin(TAU * r.bob.hz * t) * math.rad(a.bobDeg) * amp
	local flap = L.flap * a.flapDepth * amp * (0.5 + 0.5 * math.sin(TAU * r.fanFlap.hz * t))
	return {
		phase = id, presence = 1,
		abdomenPitch = L.pitch * math.rad(a.raiseDeg) + bob,
		abdomenSway = L.sway * math.rad(Peacock.fanArcDeg.used / 2) * math.sin(TAU * r.fanDance.hz * t) * amp,
		shiver = if reduced then 0 else rumble * math.rad(a.shiverDeg) * math.sin(TAU * Peacock.rumble.bumpsHz * t),
		fanOpen = L.open * (1 - flap),
		palp = L.palp * math.rad(a.palpDeg) * amp * (0.5 + 0.5 * math.sin(TAU * r.palpFlicker.hz * t)),
		legsRaise = L.legs,
		legsWave = L.wave * amp * (0.5 + 0.5 * math.sin(TAU * r.legWave.hz * t + 1.2)),
		rumble = rumble,
	}
end

local function scaled(p: Pose, k: number): Pose
	return {
		phase = p.phase, presence = k,
		abdomenPitch = p.abdomenPitch * k, abdomenSway = p.abdomenSway * k, shiver = p.shiver * k, fanOpen = p.fanOpen * k,
		palp = p.palp * k, legsRaise = p.legsRaise * k, legsWave = p.legsWave * k, rumble = p.rumble * k,
	}
end

export type Dance = typeof(setmetatable(
	{} :: { t: number, active: boolean, presence: number, raw: Pose?, reduced: boolean },
	PeacockDance
))

function PeacockDance.new(): Dance
	return setmetatable({ t = 0, active = false, presence = 0, raw = nil :: Pose?, reduced = false }, PeacockDance)
end

-- Begin the loop from its start. Refused (false) when the spider is not standing still on a surface.
function PeacockDance.start(self: Dance, standing: boolean, moving: boolean): boolean
	if self.active or not standing or moving then return false end
	self.t, self.active = 0, true
	return true
end

-- End the dance at once; the pose eases out over Peacock.fadeOutSeconds from where it was.
function PeacockDance.stop(self: Dance)
	self.active = false
end

-- Showing at all (dancing, or still easing out).
function PeacockDance.showing(self: Dance): boolean
	return self.active or self.presence > 0
end

-- One step of dt seconds (the simulation's, so slow motion slows the dance). standing: on a surface and not in a jump; moving: walking.
function PeacockDance.step(self: Dance, dt: number, standing: boolean, moving: boolean): Pose
	if self.active and (not standing or moving) then self.active = false end
	if self.active then
		self.t += dt
		self.presence = math.min(1, self.presence + dt / Peacock.rampInSeconds)
		self.raw = PeacockDance.rawPose(self.t, self.reduced)
	else
		self.presence = math.max(0, self.presence - dt / Peacock.fadeOutSeconds)
		if self.presence == 0 then self.raw = nil end
	end
	local raw = self.raw
	if raw == nil then return PeacockDance.NONE end
	return scaled(raw, smooth(self.presence))
end

return PeacockDance
