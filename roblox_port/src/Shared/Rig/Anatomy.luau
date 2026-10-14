--!strict
-- Where the parts of the body sit, worked out from the appearance table alone: pure, Vector3 only, so tests/look.luau checks
-- it. Body frame as in SpiderRig: +Y up, -Z forward. SpiderRig turns the layout into parts; Setae uses it to keep hairs off
-- the eyes and to grow the palps' fluff. Nothing here is placed by eye: eyes, cheeks and palps are found on the head's surface.

local Anatomy = {}

export type Eye = { name: string, side: number, at: Vector3, radii: Vector3, reflectance: number, principal: boolean }
export type Glint = { side: number, at: Vector3, radii: Vector3 }
export type Palp = { side: number, base: Vector3, tip: Vector3 }
export type Zone = { at: Vector3, radius: number }
export type Layout = {
	headCenter: Vector3, headRadii: Vector3,
	abdomenCenter: Vector3, abdomenRadii: Vector3,
	faceCenter: Vector3, faceRadii: Vector3,
	pedicelCenter: Vector3, pedicelRadii: Vector3,
	neck: Vector3,
	eyes: { Eye },
	glints: { Glint },
	cheeks: { { side: number, at: Vector3, radii: Vector3 } },
	jaws: { { side: number, at: Vector3, radii: Vector3 } },
	palps: { Palp },
	spinneret: Vector3,
	hairFree: { Zone },
}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end
Anatomy.v3 = v3

-- z of an ellipsoid's front (-Z) surface at lateral offsets x, y from its centre.
function Anatomy.frontZ(c: Vector3, r: Vector3, x: number, y: number): number
	local q = 1 - (x / r.X) ^ 2 - (y / r.Y) ^ 2
	return c.Z - r.Z * math.sqrt(math.max(q, 0))
end

-- y of an ellipsoid's top surface at offsets x, z from its centre.
function Anatomy.topY(c: Vector3, r: Vector3, x: number, z: number): number
	local q = 1 - (x / r.X) ^ 2 - (z / r.Z) ^ 2
	return c.Y + r.Y * math.sqrt(math.max(q, 0))
end

-- x of an ellipsoid's +X side surface at offsets y, z from its centre.
function Anatomy.sideX(c: Vector3, r: Vector3, y: number, z: number): number
	local q = 1 - (y / r.Y) ^ 2 - (z / r.Z) ^ 2
	return c.X + r.X * math.sqrt(math.max(q, 0))
end

-- Outward unit normal of an ellipsoid at a point on its surface.
function Anatomy.normalAt(c: Vector3, r: Vector3, p: Vector3): Vector3
	local d = p - c
	return Vector3.new(d.X / (r.X * r.X), d.Y / (r.Y * r.Y), d.Z / (r.Z * r.Z)).Unit
end

-- The point of an ellipsoid in direction `dir` (unit-sphere coordinates) and its outward normal.
function Anatomy.ellipsoidPoint(c: Vector3, r: Vector3, dir: Vector3): (Vector3, Vector3)
	local u = dir.Unit
	local p = c + Vector3.new(u.X * r.X, u.Y * r.Y, u.Z * r.Z)
	return p, Anatomy.normalAt(c, r, p)
end

function Anatomy.layout(look: any): Layout
	local hc, hr = v3(look.headCenter), v3(look.headRadii)
	local ac, ar = v3(look.abdomenCenter), v3(look.abdomenRadii)
	local e = look.eye
	local eyes: { Eye } = {}
	local glints: { Glint } = {}
	local zones: { Zone } = {}
	local function addEye(name: string, side: number, anchor: Vector3, r: Vector3, out: number, reflectance: number, principal: boolean): Vector3
		local n = Anatomy.normalAt(hc, hr, anchor)
		local at = anchor + n * (out * math.min(r.X, r.Y, r.Z))
		table.insert(eyes, { name = name, side = side, at = at, radii = r, reflectance = reflectance, principal = principal })
		table.insert(zones, { at = at, radius = math.max(r.X, r.Y, r.Z) * 1.15 + 0.012 })
		return at
	end
	for _, side in { -1, 1 } do
		-- Principal eyes on the front of the face, two catchlights each.
		local a = e.ame
		local ar3 = v3(a.radii)
		local ax, ay = side * a.x, a.y
		local anchor = Vector3.new(hc.X + ax, ay, Anatomy.frontZ(hc, hr, ax, ay - hc.Y))
		local at = addEye("PrincipalEye", side, anchor, ar3, a.out, a.reflectance, true)
		for _, g in a.glints do
			local depth = math.sqrt(math.max(1 - (g.dx / ar3.X) ^ 2 - (g.dy / ar3.Y) ^ 2, 0))
			local gz = -ar3.Z * depth
			table.insert(glints, {
				side = side,
				at = at + Vector3.new(g.dx, g.dy, gz - g.r * 0.2),
				radii = Vector3.new(g.r, g.r, g.r * 0.45),
			})
		end
		-- Anterior lateral eyes at the sides of the face.
		local l = e.ale
		local lx, ly = side * l.x, l.y
		addEye("Eye", side, Vector3.new(hc.X + lx, ly, Anatomy.frontZ(hc, hr, lx, ly - hc.Y)), Vector3.one * l.r, l.out, l.reflectance, false)
		-- Posterior lateral and median eyes on the dome.
		for _, d in { e.ple, e.pme } do
			local dx, dz = side * d.x, d.z
			addEye("Eye", side, Vector3.new(hc.X + dx, Anatomy.topY(hc, hr, dx, dz - hc.Z), dz), Vector3.one * d.r, d.out, d.reflectance, false)
		end
	end
	local cheeks, jaws, palps = {}, {}, {}
	local ch, cl, pl = look.cheek, look.chelicerae, look.palp
	for _, side in { -1, 1 } do
		local cx = Anatomy.sideX(hc, hr, ch.y - hc.Y, ch.z - hc.Z) - ch.inset
		table.insert(cheeks, { side = side, at = Vector3.new(side * cx, ch.y, ch.z), radii = v3(ch.radii) })
		local jaw = Vector3.new(side * cl.x, cl.y, cl.z)
		table.insert(jaws, { side = side, at = jaw, radii = v3(cl.radii) })
		table.insert(zones, { at = jaw, radius = math.max(cl.radii[1], cl.radii[2], cl.radii[3]) * 1.1 + 0.01 })
		local px = side * pl.x
		local base = Vector3.new(px, pl.y, Anatomy.frontZ(hc, hr, px, pl.y - hc.Y))
		table.insert(palps, { side = side, base = base, tip = base + Vector3.new(side * pl.spread, -pl.drop, -pl.reach) })
	end
	return {
		headCenter = hc, headRadii = hr, abdomenCenter = ac, abdomenRadii = ar,
		faceCenter = v3(look.face.center), faceRadii = v3(look.face.radii),
		pedicelCenter = v3(look.pedicel.center), pedicelRadii = v3(look.pedicel.radii),
		neck = v3(look.neck),
		eyes = eyes, glints = glints, cheeks = cheeks, jaws = jaws, palps = palps,
		spinneret = Vector3.new(0, ac.Y + 0.02, ac.Z + ar.Z - 0.005),
		hairFree = zones,
	}
end

return Anatomy
