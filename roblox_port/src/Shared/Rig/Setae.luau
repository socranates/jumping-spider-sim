--!strict
-- Where the spider's hairs (setae) go: pure layout from the appearance table, Vector3 only, so tests/run.luau and
-- tests/look.luau check it. Body frame as in SpiderRig: +Y up, -Z forward. Deterministic: the same appearance always gives
-- the same fuzz. SpiderRig turns each entry into one thin anchored part.
-- The coat is short and sleek and takes its colour from the daughter's pattern: black hairs on the black areas, white hairs
-- only inside the white spots and the band (the pale cheeks stay clean). Nothing grey or frosted is in the body coat; only
-- the face keeps a little silver (the tufts and the ruff) and the palps their fluff.
--   lock: short thin hairs lying nearly flat, combed toward the rear      pale: the same, white, inside a white spot or the band
--   fringe: short hairs along the sides, lifted a little, for a soft edge  guard: a few short hairs that stand up
--   tuft: the plumes at the upper sides of the head       ruff: pale hair low on each cheek
--   palp: the fluff on the pedipalps (rest pose; SpiderRig moves it with the palp)       leg: see Setae.leg

local Anatomy = require(script.Parent.Anatomy)

local Setae = {}

export type Hair = {
	at: Vector3, dir: Vector3, normal: Vector3, length: number, width: number, thick: number, transparency: number,
	kind: string, group: string, side: number, tone: string, white: boolean, grey: boolean, frost: boolean,
}
export type LegHair = { segment: number, t: number, theta: number, length: number, tone: string, white: boolean, grey: boolean, frost: boolean }
export type Patch = { x: number, z: number, rx: number, rz: number, angle: number }

local GOLDEN = 2.399963229728653

-- A repeatable 0..1 value per index (no global RNG state).
local function hash(i: number, salt: number): number
	local x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end
Setae.hash = hash

local function between(range: { number }, t: number): number
	return range[1] + (range[2] - range[1]) * t
end

-- ---------------------------------------------------------------- the pattern: where the white is
-- The white spots and the band as flat ellipses, in studs from the abdomen's centre (x across, z along): the same ones
-- SpiderRig draws as AbdomenSpot and FrontBand. `angle` turns an ellipse about the vertical (CFrame.Angles(0, angle, 0)).
function Setae.patches(look: any): { Patch }
	local ar = look.abdomenRadii
	local out: { Patch } = {}
	for _, s in look.spots do
		table.insert(out, { x = s.x * ar[1], z = s.z * ar[3], rx = s.rx, rz = s.rz, angle = s.angle })
	end
	local band = look.band
	for i = 0, band.count - 1 do
		table.insert(out, { x = (i - (band.count - 1) / 2) * band.step * ar[1], z = band.z * ar[3], rx = band.rx, rz = band.rz, angle = 0 })
	end
	return out
end

-- Is the offset (dx, dz) from the abdomen's centre inside the patch grown by `grow` studs (negative: shrunk)?
local function inside(p: Patch, dx: number, dz: number, grow: number): boolean
	local rx, rz = p.rx + grow, p.rz + grow
	if rx <= 0 or rz <= 0 then return false end
	local c, s = math.cos(p.angle), math.sin(p.angle)
	local ex, ez = dx - p.x, dz - p.z
	local u = ex * c - ez * s
	local v = ex * s + ez * c
	return (u / rx) ^ 2 + (v / rz) ^ 2 < 1
end

local function insideAny(patches: { Patch }, dx: number, dz: number, grow: number): boolean
	for _, p in patches do
		if inside(p, dx, dz, grow) then return true end
	end
	return false
end
Setae.insideAny = insideAny

-- ---------------------------------------------------------------- one hair
local function hair(at: Vector3, dir: Vector3, normal: Vector3, length: number, width: number, flat: number, transparency: number, kind: string, group: string, side: number, tone: string): Hair
	return {
		at = at, dir = dir, normal = normal, length = length, width = width, thick = width * flat, transparency = transparency,
		kind = kind, group = group, side = side, tone = tone, white = tone == "white", grey = tone == "grey", frost = tone == "frost",
	}
end

-- The way a hair lies: along the surface toward the rear (+Z), turned `yaw` radians to one side, raised `lift` radians off the
-- surface (0 lies flat, pi/2 stands up).
local function comb(normal: Vector3, lift: number, yaw: number): Vector3
	local back = Vector3.new(0, 0, 1)
	local along = back - normal * back:Dot(normal)
	if along.Magnitude < 1e-3 then along = Vector3.new(0, 1, 0) - normal * normal.Y end
	if along.Magnitude < 1e-3 then return normal end
	along = along.Unit
	local side = normal:Cross(along)
	return ((along * math.cos(yaw) + side * math.sin(yaw)) * math.cos(lift) + normal * math.sin(lift)).Unit
end

-- Where a hair of this class starts: a lying hair sits on the surface (half its thickness above it, so it neither sinks in
-- nor floats), a standing one is rooted a little inside.
local function rootOf(surface: Vector3, normal: Vector3, lift: number, thick: number): Vector3
	if lift < math.rad(25) then return surface + normal * (thick * 0.5 + 0.0012) end
	return surface - normal * 0.003
end

-- The hair's three points (root, middle, tip) must all be acceptable.
local function allClear(clear: (Vector3) -> boolean, root: Vector3, dir: Vector3, length: number): boolean
	return clear(root) and clear(root + dir * (length * 0.5)) and clear(root + dir * length)
end

-- One class of coat hairs (kind "lock", "guard" or "fringe") over an ellipsoid; `spec` is the class's table in
-- Appearances.fuzz. `keep(at, unit)` picks where hairs may grow, `clear(point)` rejects a hair that touches something it must
-- leave alone (a white patch, an eye). The colour is black or dark: a hair here is on a black area.
local function coat(out: { Hair }, kind: string, spec: any, center: Vector3, radii: Vector3, samples: number, salt: number, group: string, keep: (Vector3, Vector3) -> boolean, clear: (Vector3) -> boolean)
	for i = 0, samples - 1 do
		local y = 1 - 2 * (i + 0.5) / samples
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * GOLDEN
		local unit = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		if unit.Y > -0.25 then
			local surface = center + Vector3.new(unit.X * radii.X, unit.Y * radii.Y, unit.Z * radii.Z)
			local normal = Vector3.new(unit.X / radii.X, unit.Y / radii.Y, unit.Z / radii.Z).Unit
			if keep(surface, unit) then
				local length = between(spec.length, hash(i, salt))
				local lift = math.rad(between(spec.lift, hash(i, salt + 5)))
				local yaw = math.rad(spec.yaw) * (2 * hash(i, salt + 3) - 1)
				local dir = comb(normal, lift, yaw)
				local root = rootOf(surface, normal, lift, spec.width * spec.flat)
				if allClear(clear, root, dir, length) then
					local tone = if hash(i, salt + 11) < spec.black then "black" else "dark"
					table.insert(out, hair(root, dir, normal, length, spec.width, spec.flat, spec.transparency, kind, group, 0, tone))
				end
			end
		end
	end
end

-- White hairs inside the white spots and the band, lying on top of them (the markings are flat, raised discs): a spiral of
-- hair middles in each ellipse at `spec.density` hairs per square stud, every one kept only if the whole hair stays inside
-- the patch (shrunk by `spec.margin`), so the white keeps its edge.
local function pale(out: { Hair }, look: any, A: Anatomy.Layout, spec: any)
	local patches = Setae.patches(look)
	local ac, ar = A.abdomenCenter, A.abdomenRadii
	local n = 0
	for pi, patch in patches do
		local count = math.floor(math.pi * patch.rx * patch.rz * spec.density + 0.5)
		local c, s = math.cos(patch.angle), math.sin(patch.angle)
		for k = 1, count do
			n += 1
			local ring = if count == 1 then 0 else math.sqrt((k - 0.5) / count) * 0.75
			local ang = k * GOLDEN + pi
			local lu, lv = patch.rx * ring * math.cos(ang), patch.rz * ring * math.sin(ang)
			local mx, mz = patch.x + lu * c + lv * s, patch.z - lu * s + lv * c -- the hair's middle, offsets from the abdomen's centre
			local length = between(spec.length, hash(n, 41))
			local yaw = math.rad(spec.yaw) * (2 * hash(n, 43) - 1)
			local lift = math.rad(between(spec.lift, hash(n, 45)))
			local dir = comb(Vector3.yAxis, lift, yaw)
			local rx, rz = mx - dir.X * length * 0.5, mz - dir.Z * length * 0.5 -- its root
			-- the disc's top: SpiderRig lifts a marking 0.007 above the body and gives it a rounded 0.012 half-thickness
			local rho2 = (lu / patch.rx) ^ 2 + (lv / patch.rz) ^ 2
			local thick = spec.width * spec.flat
			local height = Anatomy.topY(ac, ar, rx, rz) + 0.007 + 0.012 * math.sqrt(math.max(0, 1 - rho2)) + thick * 0.5 + 0.0008
			local root = Vector3.new(ac.X + rx, height, ac.Z + rz)
			local ok = true
			for _, along in { 0, 0.5, 1 } do
				ok = ok and insideAny(patches, rx + dir.X * length * along, rz + dir.Z * length * along, -spec.margin)
			end
			if ok then
				table.insert(out, hair(root, dir, Vector3.yAxis, length, spec.width, spec.flat, spec.transparency, "pale", "abdomen", 0, "white"))
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
	local patches = Setae.patches(look)
	local ac, ar = A.abdomenCenter, A.abdomenRadii
	local hc, hr = A.headCenter, A.headRadii

	-- Black hairs keep off the white: no point of a hair may come within `f.clear` studs of a spot or the band, and none
	-- may lie on the pale cheek. (The pattern is on the upper surface; the lower flanks have none.)
	local function offWhiteAbdomen(p: Vector3): boolean
		if p.Y < ac.Y + 0.02 then return true end
		return not insideAny(patches, p.X - ac.X, p.Z - ac.Z, f.clear)
	end
	local function offCheek(p: Vector3): boolean
		local u = Vector3.new((p.X - hc.X) / hr.X, (p.Y - hc.Y) / hr.Y, (p.Z - hc.Z) / hr.Z)
		if math.abs(u.X) < 0.5 * u.Magnitude then return true end
		local dy = (u.Y / u.Magnitude - cy) / (cheek.radii[2] / hr.Y + f.clear / hr.Y)
		local dz = (u.Z / u.Magnitude - cz) / (cheek.radii[3] / hr.Z + f.clear / hr.Z)
		return dy * dy + dz * dz > 1.4
	end

	local coats: { { kind: string, spec: any } } = { { kind = "lock", spec = f.locks }, { kind = "guard", spec = f.guard } }
	if f.fringe then table.insert(coats, { kind = "fringe", spec = f.fringe }) end
	for n, entry in coats do
		local kind, spec = entry.kind, entry.spec
		local sideOnly: number = spec.side or 0 -- the fringe grows only at the sides, where it makes the outline
		coat(out, kind, spec, ac, ar, spec.abdomen, n, "abdomen", function(_at, unit)
			return unit.Z > -0.93 and math.abs(unit.X) >= sideOnly -- not where the abdomen meets the pedicel
		end, offWhiteAbdomen)
		coat(out, kind, spec, hc, hr, spec.head, n + 2, "head", function(at, unit)
			if math.abs(unit.X) < sideOnly then return false end
			if unit.Z < -0.55 and unit.Y < 0.75 then return false end -- the eye face stays clear
			for _, zone in A.hairFree do
				if (at - zone.at).Magnitude < zone.radius then return false end
			end
			return true
		end, offCheek)
	end
	pale(out, look, A, f.pale)

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
-- White over the leg's pale band (the middle bandFraction of each segment, as SpiderRig draws it), black everywhere else.
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
			local tone = if white then "white" elseif hash(i, 13) < f.legBlack then "black" else "dark"
			table.insert(out, {
				segment = segment, t = t, theta = theta,
				length = f.legLength * (0.7 + 0.6 * hash(i, 5)) * (if segment == 3 then 0.6 elseif front then 1.4 else 1),
				tone = tone, white = tone == "white", grey = false, frost = false,
			})
		end
	end
	return out
end

return Setae
