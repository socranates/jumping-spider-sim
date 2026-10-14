--!strict
-- Where the spider's hairs (setae) go: pure layout from the appearance table, Vector3 only, so tests/run.luau and
-- tests/look.luau check it. Body frame as in SpiderRig: +Y up, -Z forward. Deterministic: the same appearance always gives
-- the same fuzz. SpiderRig turns each entry into one thin anchored part.
--   lock: wide flat locks over the head and abdomen, lying back like shingles (white over the white markings)
--   guard: longer, finer hairs standing off the pelt: the fuzzy edge     tuft: the plumes at the upper sides of the head
--   ruff: pale hair low on each cheek
--   palp: the fluff on the pedipalps (rest pose; SpiderRig moves it with the palp)       leg: see Setae.leg

local Anatomy = require(script.Parent.Anatomy)

local Setae = {}

export type Hair = {
	at: Vector3, dir: Vector3, normal: Vector3, length: number, width: number, thick: number, transparency: number,
	kind: string, group: string, side: number, tone: string, white: boolean, grey: boolean, frost: boolean,
}
export type LegHair = { segment: number, t: number, theta: number, length: number, tone: string, white: boolean, grey: boolean, frost: boolean }

local GOLDEN = 2.399963229728653

-- A repeatable 0..1 value per index (no global RNG state).
local function hash(i: number, salt: number): number
	local x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end
Setae.hash = hash

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

-- `dark` and `grey` are the shares of those tones; the rest is frosted. White is only ever over the white markings.
local function toneOf(dark: number, grey: number, r: number, white: boolean): string
	if white then return "white" end
	if r < dark then return "dark" end
	if r < dark + grey then return "grey" end
	return "frost"
end

local function hair(at: Vector3, dir: Vector3, normal: Vector3, length: number, width: number, flat: number, transparency: number, kind: string, group: string, side: number, tone: string): Hair
	return {
		at = at, dir = dir, normal = normal, length = length, width = width, thick = width * flat, transparency = transparency,
		kind = kind, group = group, side = side, tone = tone, white = tone == "white", grey = tone == "grey", frost = tone == "frost",
	}
end

-- One class of coat hairs (kind "lock" or "guard") over an ellipsoid; `spec` is the class's table in Appearances.fuzz.
local function coat(out: { Hair }, kind: string, spec: any, center: Vector3, radii: Vector3, samples: number, salt: number, group: string, keep: (Vector3, Vector3) -> boolean, white: (Vector3) -> boolean)
	for i = 0, samples - 1 do
		local y = 1 - 2 * (i + 0.5) / samples
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * GOLDEN
		local unit = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		if unit.Y > -0.25 then
			local at = center + Vector3.new(unit.X * radii.X, unit.Y * radii.Y, unit.Z * radii.Z)
			local normal = Vector3.new(unit.X / radii.X, unit.Y / radii.Y, unit.Z / radii.Z).Unit
			if keep(at, unit) then
				local length = spec.length[1] + (spec.length[2] - spec.length[1]) * hash(i, salt)
				local dir = lean(normal, spec.lieBack, i + salt * 1000)
				local tone = toneOf(spec.dark, spec.grey, hash(i, salt + 11), white(unit))
				table.insert(out, hair(at - dir * length * 0.25, dir, normal, length, spec.width, spec.flat, spec.transparency, kind, group, 0, tone))
			end
		end
	end
end

-- A fan of hairs growing from a point of the head: `spec` = { at (unit-sphere direction, mirrored), lean, fan, spread, ... }.
local function plume(out: { Hair }, A: Anatomy.Layout, side: number, spec: any, count: number, length: number, kind: string, salt: number, pick: (number) -> string)
	local p0, n0 = Anatomy.ellipsoidPoint(A.headCenter, A.headRadii, Vector3.new(side * spec.at[1], spec.at[2], spec.at[3]))
	local axis = Vector3.new(side * spec.lean[1], spec.lean[2], spec.lean[3]).Unit
	local u = axis:Cross(Vector3.zAxis)
	if u.Magnitude < 1e-3 then u = axis:Cross(Vector3.xAxis) end
	u = u.Unit
	local w = axis:Cross(u).Unit
	for k = 1, count do
		local ring = math.sqrt((k - 0.5) / count)
		local ang = k * GOLDEN + side
		local off = u * math.cos(ang) + w * math.sin(ang)
		local dir = (axis + off * (spec.fan * ring)).Unit
		local at = p0 + off * (spec.spread * ring) - n0 * 0.012
		local l = length * (0.82 + 0.36 * hash(k, salt + side))
		table.insert(out, hair(at, dir, n0, l, spec.width, spec.flat, spec.transparency, kind, "head", side, pick(k * 3 + side)))
	end
end

function Setae.body(look: any): { Hair }
	local out: { Hair } = {}
	local f = look.fuzz
	if not f or not f.enabled then return out end
	local A = Anatomy.layout(look)
	local cheek = look.cheek
	local cy = (cheek.y - A.headCenter.Y) / A.headRadii.Y
	local cz = (cheek.z - A.headCenter.Z) / A.headRadii.Z
	local coats: { { kind: string, spec: any } } = { { kind = "lock", spec = f.locks }, { kind = "guard", spec = f.guard } }
	for n, entry in coats do
		local kind, spec = entry.kind, entry.spec
		coat(out, kind, spec, A.abdomenCenter, A.abdomenRadii, spec.abdomen, n, "abdomen", function(_at, unit)
			return unit.Z > -0.93 -- not where the abdomen meets the pedicel
		end, function(unit)
			return whiteOnAbdomen(look, unit.X, unit.Z)
		end)
		coat(out, kind, spec, A.headCenter, A.headRadii, spec.head, n + 2, "head", function(at, unit)
			if unit.Z < -0.55 and unit.Y < 0.75 then return false end -- the eye face stays clear
			for _, zone in A.hairFree do
				if (at - zone.at).Magnitude < zone.radius then return false end
			end
			return true
		end, function(unit)
			-- the pale cheek patch: white hair over it
			local dy = (unit.Y - cy) / (cheek.radii[2] / A.headRadii.Y)
			local dz = (unit.Z - cz) / (cheek.radii[3] / A.headRadii.Z)
			return math.abs(unit.X) > 0.7 and dy * dy + dz * dz < 1.3
		end)
	end
	-- Tufts: dark and silvery plumes up and out at the upper sides of the head.
	for _, side in { -1, 1 } do
		plume(out, A, side, f.tuft, f.tuftHairs, f.tuftLength, "tuft", 7, function(i)
			local r = hash(i, 21)
			return if r < 0.15 then "frost" elseif r < 0.45 then "grey" else "dark"
		end)
	end
	-- Cheek ruff: pale hair low at the sides of the face, beside the jaws.
	local rf = f.ruff
	for _, side in { -1, 1 } do
		plume(out, A, side, { at = rf.at, lean = rf.lean, fan = 0.55, spread = 0.03, width = rf.width, flat = rf.flat, transparency = rf.transparency }, rf.hairs, rf.length, "ruff", 17, function(i)
			local r = hash(i, 23)
			return if r < rf.whiteShare then "white" elseif r < 0.85 then "frost" else "grey"
		end)
	end
	return out
end

-- Fluff on the pedipalps, in the body frame at rest (SpiderRig moves it with the palp it belongs to; side -1 is palp 1).
function Setae.palp(look: any): { Hair }
	local out: { Hair } = {}
	local f = look.fuzz
	if not f or not f.enabled then return out end
	local A = Anatomy.layout(look)
	local pl = look.palp
	local spec = pl.fluff
	for _, p in A.palps do
		local axis = p.tip - p.base
		local ax = axis.Unit
		local u = ax:Cross(Vector3.xAxis)
		if u.Magnitude < 1e-3 then u = ax:Cross(Vector3.yAxis) end
		u = u.Unit
		local w = ax:Cross(u).Unit
		for k = 1, spec.hairs do
			local t = 0.3 + 0.7 * (k - 0.5) / spec.hairs
			local theta = k * GOLDEN + p.side
			local radial = u * math.cos(theta) + w * math.sin(theta)
			local r = if t > 0.7 then pl.club[1] else pl.stalk * 0.5
			local dir = (radial + ax * 0.6).Unit
			local l = spec.length * (0.8 + 0.4 * hash(k, 31 + p.side))
			local rr = hash(k, 33 + p.side)
			local tone = if rr < 0.55 then "white" elseif rr < 0.75 then "frost" else "grey"
			table.insert(out, hair(p.base + axis * t + radial * (r * 0.8), dir, radial, l, spec.width, spec.flat, spec.transparency, "palp", "palp", p.side, tone))
		end
	end
	return out
end

-- Hairs on one leg: segment 1 femur, 2 tibia, 3 tarsus; t along it (0 base .. 1 tip); theta around it.
-- White over the leg's pale band (the middle bandFraction of each segment, as SpiderRig draws it), else dark, grey or frosted.
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
			local tone = toneOf(f.legDark, f.legGrey, hash(i, 13), white)
			table.insert(out, {
				segment = segment, t = t, theta = theta,
				length = f.legLength * (0.7 + 0.6 * hash(i, 5)) * (if segment == 3 then 0.6 elseif front then 1.4 else 1),
				tone = tone, white = tone == "white", grey = tone == "grey", frost = tone == "frost",
			})
		end
	end
	return out
end

return Setae
