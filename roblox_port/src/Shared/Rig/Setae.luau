--!strict
-- Where the spider's hairs (setae) go: pure layout from the appearance table, Vector3 only, so tests/run.luau checks it.
-- Body frame as in SpiderRig: +Y up, -Z forward. Deterministic: the same appearance always gives the same fuzz.
-- SpiderRig turns each entry into one thin anchored part.

local Setae = {}

export type Hair = { at: Vector3, dir: Vector3, length: number, white: boolean, grey: boolean }
export type LegHair = { segment: number, t: number, theta: number, length: number, white: boolean, grey: boolean }

-- Must match SpiderRig's body layout.
Setae.HEAD_CENTER = Vector3.new(0, 0.02, -0.20)
Setae.ABDOMEN_CENTER = Vector3.new(0, 0.04, 0.20)
local GOLDEN = 2.399963229728653
local EYES = {
	Vector3.new(-0.075, 0.09, -0.455), Vector3.new(0.075, 0.09, -0.455),
	Vector3.new(-0.165, 0.10, -0.40), Vector3.new(0.165, 0.10, -0.40),
	Vector3.new(-0.13, 0.17, -0.14), Vector3.new(0.13, 0.17, -0.14),
	Vector3.new(-0.11, 0.185, -0.27), Vector3.new(0.11, 0.185, -0.27),
}

-- A repeatable 0..1 value per index (no global RNG state).
local function hash(i: number, salt: number): number
	local x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end
Setae.hash = hash

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- Leans a hair from its surface normal toward the rear (+Z) along the surface.
local function lean(normal: Vector3, amount: number, i: number): Vector3
	local back = Vector3.new(0, 0, 1)
	local along = back - normal * back:Dot(normal)
	if along.Magnitude < 1e-4 then along = Vector3.new(0, 1, 0) - normal * normal.Y end
	if along.Magnitude < 1e-4 then return normal end
	local side = normal:Cross(along.Unit)
	local jitter = (hash(i, 3) - 0.5) * 0.7
	return (normal + along.Unit * amount + side * jitter).Unit
end

local function whiteOnAbdomen(look: any, x: number, z: number): boolean
	-- x, z: fractions of the abdomen's X/Z radii, the coordinates the markings use.
	local ar = look.abdomenRadii
	for _, s in look.spots do
		local dx = (x - s.x) * ar[1] / s.rx
		local dz = (z - s.z) * ar[3] / s.rz
		if dx * dx + dz * dz < 1.4 then return true end
	end
	return z < -0.58 and z > -0.78 and math.abs(x) < 0.72 -- the pale front band
end

local function ellipsoidHairs(out: { Hair }, look: any, center: Vector3, radii: Vector3, samples: number, salt: number, keep: (Vector3, Vector3) -> boolean, white: (Vector3) -> boolean)
	local f = look.fuzz
	for i = 0, samples - 1 do
		local y = 1 - 2 * (i + 0.5) / samples
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * GOLDEN
		local unit = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		if unit.Y > -0.25 then
			local at = center + Vector3.new(unit.X * radii.X, unit.Y * radii.Y, unit.Z * radii.Z)
			local normal = Vector3.new(unit.X / radii.X, unit.Y / radii.Y, unit.Z / radii.Z).Unit
			if keep(at, unit) then
				local length = f.length[1] + (f.length[2] - f.length[1]) * hash(i, salt)
				local dir = lean(normal, f.lieBack, i + salt * 1000)
				table.insert(out, { at = at - dir * length * 0.25, dir = dir, length = length, white = white(unit), grey = hash(i, salt + 11) < f.greyShare })
			end
		end
	end
end

function Setae.body(look: any): { Hair }
	local out: { Hair } = {}
	local f = look.fuzz
	if not f or not f.enabled then return out end
	local ar, hr = v3(look.abdomenRadii), v3(look.headRadii)
	ellipsoidHairs(out, look, Setae.ABDOMEN_CENTER, ar, f.abdomenSamples, 1, function(_at, unit)
		return unit.Z > -0.93 -- not where the abdomen meets the pedicel
	end, function(unit)
		return whiteOnAbdomen(look, unit.X, unit.Z)
	end)
	ellipsoidHairs(out, look, Setae.HEAD_CENTER, hr, f.headSamples, 2, function(at, unit)
		if unit.Z < -0.55 and unit.Y < 0.75 then return false end -- the eye face stays clear
		for _, e in EYES do
			if (at - e).Magnitude < 0.075 then return false end
		end
		return true
	end, function(unit)
		return math.abs(unit.X) > 0.82 and unit.Z < 0.1 and unit.Y < 0.45 -- pale cheeks
	end)
	-- Phidippus eyebrow tufts: long dark hairs above each side of the eye row, leaning forward and out.
	for _, side in { -1, 1 } do
		for k = 1, f.tuftHairs do
			local s = (k - 1) / math.max(1, f.tuftHairs - 1) - 0.5
			local at = Vector3.new(side * (0.12 + s * 0.03), 0.17, -0.34 + s * 0.04)
			local dir = Vector3.new(side * (0.35 + 0.15 * s), 1, -0.45 + 0.2 * hash(k, 9)).Unit
			table.insert(out, { at = at, dir = dir, length = f.tuftLength * (0.85 + 0.3 * hash(k, 7 + side)), white = false, grey = false })
		end
	end
	return out
end

-- Hairs on one leg: segment 1 femur, 2 tibia, 3 tarsus; t along it (0 base .. 1 tip); theta around it.
-- White over the leg's pale band (the middle bandFraction of each segment, as SpiderRig draws it), else dark.
function Setae.leg(look: any, legIndex: number): { LegHair }
	local out: { LegHair } = {}
	local f = look.fuzz
	if not f or not f.enabled then return out end
	local front = (legIndex - 1) % 4 == 0 -- the first legs carry a denser, longer fringe, as in Phidippus
	for segment = 1, 3 do
		local n = if front and segment < 3 then math.floor(f.legHairs[segment] * 1.6) else f.legHairs[segment]
		for k = 1, n do
			local i = legIndex * 100 + segment * 10 + k
			local t = (k - 0.5) / n
			local theta = k * GOLDEN + legIndex
			local white = math.abs(t - 0.5) < look.bandFraction * 0.6
			table.insert(out, { segment = segment, t = t, theta = theta, length = f.legLength * (0.7 + 0.6 * hash(i, 5)) * (if segment == 3 then 0.6 elseif front then 1.4 else 1), white = white, grey = hash(i, 13) < f.greyShare })
		end
	end
	return out
end

return Setae
