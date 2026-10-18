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

function Idle.pose(t: number, calm: number, cfg: any): Pose
	local b, k = cfg.breathe, cfg.tilt
	local breath = math.sin(TAU * t / b.period) * (0.85 + 0.15 * math.sin(TAU * t / (b.period * 2.7) + 0.6))
	local p = k.periods
	return {
		bodyLift = b.bodyLift * breath * calm,
		abdomenLift = b.lift * breath * calm,
		abdomenPitch = math.rad(b.pitchDeg) * breath * calm,
		headRoll = math.rad(k.rollDeg) * calm * (0.65 * math.sin(TAU * t / p[1]) + 0.35 * math.sin(TAU * t / p[2] + 1.1)),
		headYaw = math.rad(k.yawDeg) * calm * (0.7 * math.sin(TAU * t / p[3] + 0.4) + 0.3 * math.sin(TAU * t / p[4] + 2.0)),
		headPitch = math.rad(k.pitchDeg) * calm * math.sin(TAU * t / p[5] + 0.9),
	}
end

-- The largest angle each part of the pose can reach (for tests and for the docs).
function Idle.limits(cfg: any): Pose
	local b, k = cfg.breathe, cfg.tilt
	return {
		bodyLift = b.bodyLift, abdomenLift = b.lift, abdomenPitch = math.rad(b.pitchDeg),
		headRoll = math.rad(k.rollDeg), headYaw = math.rad(k.yawDeg), headPitch = math.rad(k.pitchDeg),
	}
end

-- Palp drumming in bursts while the spider stands still: the angle (radians, about the palp's base) of palp 1 and palp 2.
function Idle.palps(t: number, drum: number, palp: any): { number }
	local out = {}
	for k = 1, 2 do
		local burst = math.clamp((math.sin(t * 1.3 + 0.7 * k) - 0.55) / 0.3, 0, 1)
		local beat = math.max(0, math.sin(t * TAU * palp.drumHz + math.pi * k))
		out[k] = math.rad(palp.drumDeg) * drum * burst * beat
	end
	return out
end

-- Authored salticid-like stop/snap/settle accents, not a measured biological frequency.
-- Short asymmetric pulses separated by stillness, instead of continuous vibration.
function Idle.snap(t: number, moving: boolean): (number, number)
	local function pulse(period: number, offset: number): number
		local phase = (t + offset) % period
		if phase >= 0.19 then return 0 end
		if phase < 0.035 then return phase / 0.035 end
		return (1 - (phase - 0.035) / 0.155) ^ 2
	end
	local a, b = pulse(1.37, 0.31), pulse(2.11, 0.83)
	return math.rad(if moving then 3 else 5) * (a - b), 0.022 * a
end

return Idle
