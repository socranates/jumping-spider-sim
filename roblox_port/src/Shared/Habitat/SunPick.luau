--!strict
-- Finds a sun that shines in through the window: behind the back wall (-Z), standing between a low and a middling height,
-- turned a little to one side so the patch of light and the mullions' shadows fall across the sill diagonally.
-- Which way Roblox's sun travels for a given ClockTime and GeographicLatitude is not something this code assumes: it asks
-- (`sample`), scans the day for both signs of the latitude, and takes the best match. Pure apart from `sample`, so
-- tests/world.luau drives it with invented suns.

local SunPick = {}

export type Target = {
	elevationDeg: number, minElevationDeg: number, maxElevationDeg: number,
	azimuthDeg: number, maxAzimuthDeg: number,
	clockFrom: number, clockTo: number, clockStep: number,
}
export type Result = {
	ok: boolean,
	clock: number, latitude: number,
	direction: Vector3, -- unit vector from the world toward the sun
	elevationDeg: number, azimuthDeg: number,
	reason: string,
}

-- Height above the horizon and angle from -Z (0 = straight out of the window, 90 = along the wall), in degrees.
function SunPick.angles(direction: Vector3): (number, number)
	local d = direction.Unit
	local elevation = math.deg(math.asin(math.clamp(d.Y, -1, 1)))
	local azimuth = math.deg(math.atan2(math.abs(d.X), -d.Z))
	return elevation, azimuth
end

local function result(ok: boolean, clock: number, latitude: number, direction: Vector3, reason: string): Result
	local elevation, azimuth = SunPick.angles(direction)
	return { ok = ok, clock = clock, latitude = latitude, direction = direction.Unit, elevationDeg = elevation, azimuthDeg = azimuth, reason = reason }
end

-- sample(clock, latitude): the unit vector toward the sun at that time. baseClock and baseLatitude are what to fall back on.
function SunPick.choose(sample: (number, number) -> Vector3, baseClock: number, baseLatitude: number, target: Target): Result
	local fallback = sample(baseClock, baseLatitude)
	-- A sampler that ignores the clock would make every time look the same; do not pretend to have chosen.
	if (sample(6, baseLatitude) - sample(12, baseLatitude)).Magnitude < 1e-6 then
		return result(false, baseClock, baseLatitude, fallback, "the sun direction does not change with the clock")
	end
	local latitudes = { baseLatitude }
	if baseLatitude ~= 0 then table.insert(latitudes, -baseLatitude) end
	local best: Result? = nil
	local bestCost = math.huge
	for _, latitude in latitudes do
		local steps = math.floor((target.clockTo - target.clockFrom) / target.clockStep + 0.5)
		for i = 0, steps do
			local clock = target.clockFrom + i * target.clockStep
			local direction = sample(clock, latitude)
			if direction.Magnitude > 1e-6 and direction.Z < 0 then
				local elevation, azimuth = SunPick.angles(direction)
				if elevation >= target.minElevationDeg and elevation <= target.maxElevationDeg and azimuth <= target.maxAzimuthDeg then
					local cost = ((elevation - target.elevationDeg) / 10) ^ 2 + ((azimuth - target.azimuthDeg) / 20) ^ 2 + 0.001 * math.abs(clock - 10)
					if cost < bestCost then
						bestCost = cost
						best = result(true, clock, latitude, direction, `clock {clock}, latitude {latitude}`)
					end
				end
			end
		end
	end
	if best then return best end
	return result(false, baseClock, baseLatitude, fallback, "no time of day puts the sun behind the window")
end

return SunPick
