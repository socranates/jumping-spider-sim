--!strict
-- Idle motion for the drawn spider (display only, never fed back into movement): a slow breathing bob, a small curious head
-- tilt and the palps' drumming. Pure functions of time so tests/look.luau can check them. All knobs: Appearances.idle / .palp.
-- `calm` is 0..1: SpiderRig eases it up after the spider has stood still for a moment and back to 0 as soon as it moves.

local Idle = {}

export type Pose = {
	bodyLift: number, -- studs: the whole body rises with a breath
	abdomenLift: number, -- studs: the abdomen rises a little more
	abdomenPitch: number, -- radians, rear end up
	headRoll: number, headYaw: number, headPitch: number, -- radians
}

local TAU = math.pi * 2

-- One breath, -1 to 1: a sine of the period with a slow wobble in its depth. The body's lift, the abdomen's pitch and its scale (ROBLOX-87) all follow it.
function Idle.breath(t: number, period: number): number
	return math.sin(TAU * t / period) * (0.85 + 0.15 * math.sin(TAU * t / (period * 2.7) + 0.6))
end

-- The abdomen's scale (ROBLOX-87): 1 plus `breathe.scale` of a breath, as much as `amount` (0..1: standing is 1, moving `breathe.movingShare`, Reduced Motion 0).
-- Appearances without `breathe.scale` (the peacock spider's fan, the ant mimic) do not pulse.
function Idle.abdomenScale(t: number, amount: number, cfg: any): number
	local b = cfg.breathe
	return 1 + (b.scale or 0) * Idle.breath(t, b.period) * amount
end

-- The pose at time t. `out` (ROBLOX-93): a pose to fill and return instead of making a new one, so the rig, which asks every frame, makes no table of it.
function Idle.pose(t: number, calm: number, cfg: any, out: Pose?): Pose
	local b, k = cfg.breathe, cfg.tilt
	local breath = Idle.breath(t, b.period)
	local p = k.periods
	local pose: Pose = out or { bodyLift = 0, abdomenLift = 0, abdomenPitch = 0, headRoll = 0, headYaw = 0, headPitch = 0 }
	pose.bodyLift = b.bodyLift * breath * calm
	pose.abdomenLift = b.lift * breath * calm
	pose.abdomenPitch = math.rad(b.pitchDeg) * breath * calm
	pose.headRoll = math.rad(k.rollDeg) * calm * (0.65 * math.sin(TAU * t / p[1]) + 0.35 * math.sin(TAU * t / p[2] + 1.1))
	pose.headYaw = math.rad(k.yawDeg) * calm * (0.7 * math.sin(TAU * t / p[3] + 0.4) + 0.3 * math.sin(TAU * t / p[4] + 2.0))
	pose.headPitch = math.rad(k.pitchDeg) * calm * math.sin(TAU * t / p[5] + 0.9)
	return pose
end

-- The largest angle each part of the pose can reach (for tests and for the docs).
function Idle.limits(cfg: any): Pose
	local b, k = cfg.breathe, cfg.tilt
	return {
		bodyLift = b.bodyLift, abdomenLift = b.lift, abdomenPitch = math.rad(b.pitchDeg),
		headRoll = math.rad(k.rollDeg), headYaw = math.rad(k.yawDeg), headPitch = math.rad(k.pitchDeg),
	}
end

-- Palp drumming in bursts while the spider stands still: the angle (radians, about the palp's base) of palp k (1 or 2). The rig asks for each palp on its own,
-- every frame (ROBLOX-93: no table made of the pair); `Idle.palps` is the pair, for the tests and the docs.
function Idle.palp(t: number, drum: number, palp: any, k: number): number
	local burst = math.clamp((math.sin(t * 1.3 + 0.7 * k) - 0.55) / 0.3, 0, 1)
	local beat = math.max(0, math.sin(t * TAU * palp.drumHz + math.pi * k))
	return math.rad(palp.drumDeg) * drum * burst * beat
end
function Idle.palps(t: number, drum: number, palp: any): { number }
	return { Idle.palp(t, drum, palp, 1), Idle.palp(t, drum, palp, 2) }
end

-- Authored salticid-like stop/snap/settle accents, not a measured biological frequency.
-- Short asymmetric pulses separated by stillness, instead of continuous vibration.
local function pulse(t: number, period: number, offset: number): number
	local phase = (t + offset) % period
	if phase >= 0.19 then return 0 end
	if phase < 0.035 then return phase / 0.035 end
	return (1 - (phase - 0.035) / 0.155) ^ 2
end
function Idle.snap(t: number, moving: boolean): (number, number)
	local a, b = pulse(t, 1.37, 0.31), pulse(t, 2.11, 0.83)
	return math.rad(if moving then 3 else 5) * (a - b), 0.022 * a
end

return Idle
