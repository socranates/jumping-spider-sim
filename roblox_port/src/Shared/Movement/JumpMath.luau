--!strict
-- Port of scripts/movement/jump_math.gd (spec 6.3, 27). Pure math, no Instances, so it runs in tests/run.luau too.
--
-- The motor flies a committed jump with semi-implicit Euler at a fixed 60 Hz tick:
--   v = v + g * dt, then p = p + v * dt.
-- After n ticks from launch velocity v0 at p0 that gives, exactly,
--   p_n = p0 + n * dt * v0 + g * dt^2 * n * (n + 1) / 2
-- so the launch velocity is solved in this discrete form, not with the continuous 0.5 * g * T^2.

local JumpMath = {}

-- Matches SurfaceProfile.STAND_MAX_DEG.
JumpMath.STAND_MAX_DEG = 45.0
JumpMath.MIN_LAUNCH_NORMAL_SPEED = 0.05
JumpMath.STAND_APPROACH_MIN = 0.05
JumpMath.LAND_APPROACH_MIN = 0.3

local UP = Vector3.new(0, 1, 0)

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function finiteVec(v: Vector3): boolean
	return finite(v.X) and finite(v.Y) and finite(v.Z)
end

export type Solution = {
	steps: number,
	duration: number,
	velocity: Vector3,
	speed: number,
	arrivalVelocity: Vector3,
	approach: number,
}

export type SolveResult = {
	valid: { Solution },
	reason: string, -- "ok", "no_durations", "too_far", "no_launch", "no_arrival"
	minSpeed: number,
}

-- Tick counts n whose duration n * dt lies inside [tMin, tMax]. nMax < nMin when none fits.
function JumpMath.stepRange(tMin: number, tMax: number, dt: number): (number, number)
	if not (finite(tMin) and finite(tMax) and finite(dt)) or dt <= 0 then
		return 1, 0
	end
	local nMin = math.ceil(tMin / dt - 1e-6)
	local nMax = math.floor(tMax / dt + 1e-6)
	return math.max(nMin, 1), nMax
end

function JumpMath.positionAfter(p0: Vector3, v0: Vector3, g: Vector3, dt: number, n: number): Vector3
	return p0 + v0 * (n * dt) + g * (dt * dt * n * (n + 1) * 0.5)
end

function JumpMath.velocityAfter(v0: Vector3, g: Vector3, dt: number, n: number): Vector3
	return v0 + g * (dt * n)
end

function JumpMath.launchVelocity(p0: Vector3, seat: Vector3, g: Vector3, dt: number, n: number): Vector3
	return (seat - p0 - g * (dt * dt * n * (n + 1) * 0.5)) / (n * dt)
end

-- Body-centre positions p_0 .. p_steps by repeated ticks, in the order the motor does them.
function JumpMath.path(p0: Vector3, v0: Vector3, g: Vector3, dt: number, steps: number): { Vector3 }
	local out = { p0 }
	local v, p = v0, p0
	for _ = 1, steps do
		v += g * dt
		p += v * dt
		table.insert(out, p)
	end
	return out
end

function JumpMath.isStanding(normal: Vector3): boolean
	if not finiteVec(normal) or normal:Dot(normal) < 1e-10 then
		return false
	end
	return normal.Unit:Dot(UP) >= math.cos(math.rad(JumpMath.STAND_MAX_DEG)) - 1e-6
end

function JumpMath.minApproach(targetNormal: Vector3): number
	return if JumpMath.isStanding(targetNormal) then JumpMath.STAND_APPROACH_MIN else JumpMath.LAND_APPROACH_MIN
end

-- Every launch solution for a landing seat, one per allowed whole-tick duration, filtered by the launch speed limit,
-- by leaving the launch surface and by arriving into the target fast enough. Sorted by speed, lowest first.
function JumpMath.solve(
	p0: Vector3,
	seat: Vector3,
	launchNormal: Vector3,
	targetNormal: Vector3,
	g: Vector3,
	dt: number,
	tMin: number,
	tMax: number,
	maxSpeed: number
): SolveResult
	local valid: { Solution } = {}
	local nMin, nMax = JumpMath.stepRange(tMin, tMax, dt)
	local minSpeed = math.huge
	local anySpeedOk, anyLaunchOk = false, false
	local need = JumpMath.minApproach(targetNormal)
	for n = nMin, nMax do
		local v0 = JumpMath.launchVelocity(p0, seat, g, dt, n)
		if finiteVec(v0) then
			local speed = v0.Magnitude
			minSpeed = math.min(minSpeed, speed)
			if speed <= maxSpeed then
				anySpeedOk = true
				if v0:Dot(launchNormal) >= JumpMath.MIN_LAUNCH_NORMAL_SPEED then
					anyLaunchOk = true
					local arrival = JumpMath.velocityAfter(v0, g, dt, n)
					local approach = -arrival:Dot(targetNormal)
					if approach >= need then
						table.insert(valid, {
							steps = n,
							duration = n * dt,
							velocity = v0,
							speed = speed,
							arrivalVelocity = arrival,
							approach = approach,
						})
					end
				end
			end
		end
	end
	table.sort(valid, function(a: Solution, b: Solution): boolean
		if math.abs(a.speed - b.speed) > 1e-9 then
			return a.speed < b.speed
		end
		return a.steps < b.steps
	end)
	local reason = "ok"
	if #valid == 0 then
		if nMax < nMin then
			reason = "no_durations"
		elseif not anySpeedOk then
			reason = "too_far"
		elseif not anyLaunchOk then
			reason = "no_launch"
		else
			reason = "no_arrival"
		end
	end
	return { valid = valid, reason = reason, minSpeed = minSpeed }
end

return JumpMath
