--!strict
-- The ant-mimicking spider's antennae and walk as a pose (ROBLOX-54): pure and Vector3-free, display only. SpiderRig reads the pose, turns
-- the drawn body and raises legs I; nothing here moves the collider, the path, the speed, the senses, the jump or the silk. All
-- numbers are in Data/AntMimic (documented ones from Shamble et al. 2017, the rest marked artistic).
--
-- Standing still, legs I go up (above head height) and wave in phase like ant antennae; walking, all eight legs walk and the drawn body
-- yaws and sways along a sine of the distance walked, wavelength ten body lengths. A stop shorter than the mimic's mean stop (83.3 ms)
-- is not drawn as a pause. step(dt, standing, moving, distance) adds the dt it is handed, so slow motion slows the waving as it slows
-- everything else; the wobble depends on distance only.

local AntMimic = require(script.Parent.Parent.Data.AntMimic)

local AntMimicPose = {}
AntMimicPose.__index = AntMimicPose

export type Pose = {
	antennae: number, -- 0..1: legs I raised (0 they are legs)
	high: number, -- 0..1: the display pose (higher and wider)
	wave: number, -- 0..1: legs I swept from "up" toward "swept"; both legs share the one value (they move in phase)
	yaw: number, -- radians: the drawn body's turn about its up axis
	lateral: number, -- studs: the drawn body's sway to its right
	walking: boolean, -- drawn as walking (a stop shorter than the hold does not end it)
	shownSeconds: number, -- seconds the antennae have been fully up
}

local TAU = math.pi * 2

local function smooth(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

AntMimicPose.BODY_LENGTH = AntMimic.bodyLengthStuds -- the drawn body's length (studs) at full growth: a wavelength is ten of them

AntMimicPose.NONE = { antennae = 0, high = 0, wave = 0, yaw = 0, lateral = 0, walking = false, shownSeconds = 0 } :: Pose

export type State = typeof(setmetatable(
	{} :: {
		walked: number, still: number, walking: boolean, antennae: number, high: number, walkLevel: number, phase: number, shown: number,
		emphasis: boolean, reduced: boolean, bodyLength: number,
	},
	AntMimicPose
))

function AntMimicPose.new(): State
	return setmetatable({
		walked = 0, still = 0, walking = false, antennae = 0, high = 0, walkLevel = 0, phase = 0, shown = 0,
		emphasis = false, reduced = false, bodyLength = AntMimic.bodyLengthStuds,
	}, AntMimicPose)
end

-- The display key: legs I high and waving faster. Refused (false) unless the spider is standing still on a surface.
function AntMimicPose.start(self: State, standing: boolean, moving: boolean): boolean
	if self.emphasis or not standing or moving then return false end
	self.emphasis = true
	return true
end

function AntMimicPose.stop(self: State)
	self.emphasis = false
end

-- The display pose is on.
function AntMimicPose.displaying(self: State): boolean
	return self.emphasis
end

-- The pose after one step of dt seconds (the simulation's). standing: on a surface and not in a jump, on the line or resting; moving: walking
-- (or asked to); distance: studs the spider actually moved this step.
function AntMimicPose.step(self: State, dt: number, standing: boolean, moving: boolean, distance: number): Pose
	local a, w = AntMimic.antennae, AntMimic.walk
	if standing and not moving then self.still += dt else self.still = 0 end
	if not standing or moving then self.emphasis = false end
	-- Walking carries over a stop shorter than the mimic's mean stop; a spider that was not walking is not.
	local walking = standing and (moving or (self.walking and self.still < w.stopHoldSeconds))
	self.walking = walking
	if standing and moving and distance > 0 and distance <= w.teleportStuds then
		self.walked += distance
	end
	-- The antennae: up after a short stillness (at once for the display key), down quickly when it moves.
	local up = standing and not walking and (self.emphasis or self.still >= a.delaySeconds)
	if up then
		self.antennae = math.min(1, self.antennae + dt / a.riseSeconds)
	else
		self.antennae = math.max(0, self.antennae - dt / a.fallSeconds)
	end
	self.high = math.clamp(self.high + (if self.emphasis then dt else -dt) / a.riseSeconds, 0, 1)
	-- The drawn wobble eases in and out.
	if walking then
		self.walkLevel = math.min(1, self.walkLevel + dt / w.easeInSeconds)
	else
		self.walkLevel = math.max(0, self.walkLevel - dt / w.easeOutSeconds)
	end
	local shownA, shownHigh, shownWalk = smooth(self.antennae), smooth(self.high), smooth(self.walkLevel)
	local hz = a.waveHz + (a.highWaveHz - a.waveHz) * shownHigh
	self.phase = (self.phase + TAU * hz * dt) % TAU
	if self.antennae >= 0.999 then self.shown += dt else self.shown = 0 end
	local amp = if self.reduced then AntMimic.reducedMotion else 1
	local amount = a.waveAmount + (a.highWaveAmount - a.waveAmount) * shownHigh
	local wavelength = AntMimic.path.wavelengthBodyLengths.used * self.bodyLength
	local turn = TAU * self.walked / wavelength
	return {
		antennae = shownA,
		high = shownHigh,
		wave = if self.reduced then 0 else shownA * amount * (0.5 + 0.5 * math.sin(self.phase)),
		-- The path is x = A sin(s), so the heading follows its slope, cos(s): the body turns most where the sway crosses the middle.
		yaw = shownWalk * math.rad(w.yawDeg) * amp * math.cos(turn),
		lateral = shownWalk * w.lateralStuds * amp * math.sin(turn),
		walking = walking,
		shownSeconds = self.shown,
	}
end

return AntMimicPose
