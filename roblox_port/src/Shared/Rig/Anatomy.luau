--!strict
-- Where the parts of the body sit, worked out from the appearance table alone: pure, Vector3 only, so tests/look.luau checks
-- it. Body frame as in SpiderRig: +Y up, -Z forward. SpiderRig turns the layout into parts; Setae uses it to keep hairs off
-- the eyes and to grow the palps' fluff. Nothing here is placed by eye: eyes, cheeks and palps are found on the head's surface.

local Anatomy = {}

-- `kind`: "ame" (the principal eyes), "ale", "ple", "pme" or "tubercle" (a tarantula's bead). `margin` (ROBLOX-93): the eye's place on the head's (or the tubercle's) surface is found from
-- its offsets across and along, so it is only on the surface where those lie inside the ellipse the surface covers: `margin` is 1 minus the sum of their squared shares of
-- the radii, 0 at the rim (where the place is clamped) and 1 at the middle. The tests keep every eye of every look at 0.02 or more.
export type Eye = { name: string, side: number, kind: string, at: Vector3, radii: Vector3, reflectance: number, principal: boolean, margin: number }
export type Glint = { side: number, at: Vector3, radii: Vector3 }
export type Palp = { side: number, base: Vector3, tip: Vector3 }
export type Zone = { at: Vector3, radius: number }
-- One segment of a fang, an ellipsoid whose long axis (local Z) runs along `dir`; `index` counts from the chelicera (1) out to the tip.
export type Fang = { side: number, index: number, at: Vector3, dir: Vector3, radii: Vector3 }
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
	fangs: { Fang }, -- empty for an appearance without a `fang` table (ROBLOX-84)
	spinneret: Vector3,
	hairFree: { Zone },
	tubercle: { center: Vector3, radii: Vector3 }?, -- a tarantula's ocular tubercle, which carries its eyes
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

-- Does the segment from a to b come within `pad` studs of the eye (its ellipsoid, axes along the body frame's, each radius grown by `pad`)? The segment's closest point in the
-- ellipsoid's own space (every axis divided by its radius) is found exactly, not sampled: the squared distance there is a quadratic in the segment's parameter.
function Anatomy.touchesEye(eye: Eye, a: Vector3, b: Vector3, pad: number): boolean
	local r = eye.radii + Vector3.one * pad
	local u0 = Vector3.new((a.X - eye.at.X) / r.X, (a.Y - eye.at.Y) / r.Y, (a.Z - eye.at.Z) / r.Z)
	local d = Vector3.new((b.X - a.X) / r.X, (b.Y - a.Y) / r.Y, (b.Z - a.Z) / r.Z)
	local dd = d:Dot(d)
	local t = if dd > 1e-12 then math.clamp(-u0:Dot(d) / dd, 0, 1) else 0
	return (u0 + d * t).Magnitude < 1
end

function Anatomy.layout(look: any): Layout
	local hc, hr = v3(look.headCenter), v3(look.headRadii)
	local ac, ar = v3(look.abdomenCenter), v3(look.abdomenRadii)
	local e = look.eye
	local eyes: { Eye } = {}
	local glints: { Glint } = {}
	local zones: { Zone } = {}
	local function addEye(name: string, kind: string, side: number, anchor: Vector3, r: Vector3, out: number, reflectance: number, principal: boolean, margin: number): Vector3
		local n = Anatomy.normalAt(hc, hr, anchor)
		local at = anchor + n * (out * math.min(r.X, r.Y, r.Z))
		table.insert(eyes, { name = name, side = side, kind = kind, at = at, radii = r, reflectance = reflectance, principal = principal, margin = margin })
		table.insert(zones, { at = at, radius = math.max(r.X, r.Y, r.Z) * 1.15 + 0.012 })
		return at
	end
	local tub = look.tubercle
	if tub then
		-- A tarantula (ROBLOX-81): no big front pair; eight tiny eyes clustered on a small mound, their beads standing a little out of it, and one
		-- catchlight on the first bead of each side. Placed on the mound's surface like the others are on the head's.
		local tc, tr = v3(tub.center), v3(tub.radii)
		for _, side in { -1, 1 } do
			for n, spec in tub.eyes do
				local dx, dz = side * spec.x, spec.z
				local q = math.sqrt(math.max(1 - (dx / tr.X) ^ 2 - (dz / tr.Z) ^ 2, 0.05))
				local anchor = Vector3.new(tc.X + dx, tc.Y + tr.Y * q, tc.Z + dz)
				local at = anchor + Anatomy.normalAt(tc, tr, anchor) * (0.3 * spec.r)
				local r3 = Vector3.one * spec.r
				table.insert(eyes, { name = "Eye", side = side, kind = "tubercle", at = at, radii = r3, reflectance = tub.eyeReflectance, principal = false, margin = 1 - (dx / tr.X) ^ 2 - (dz / tr.Z) ^ 2 })
				table.insert(zones, { at = at, radius = spec.r * 1.15 + 0.012 })
				if n == 1 then
					local g = tub.glint
					table.insert(glints, { side = side, at = at + Vector3.new(side * g.dx, g.dy, -spec.r * 0.75), radii = Vector3.new(g.r, g.r, g.r * 0.45) })
				end
			end
		end
	end
	local frontSides: { number } = if tub then {} else { -1, 1 } -- (a tarantula's eyes are on its tubercle, above)
	for _, side in frontSides do
		-- Principal eyes on the front of the face, two catchlights each.
		local a = e.ame
		local ar3 = v3(a.radii)
		local ax, ay = side * a.x, a.y
		local anchor = Vector3.new(hc.X + ax, ay, Anatomy.frontZ(hc, hr, ax, ay - hc.Y))
		local at = addEye("PrincipalEye", "ame", side, anchor, ar3, a.out, a.reflectance, true, 1 - (ax / hr.X) ^ 2 - ((ay - hc.Y) / hr.Y) ^ 2)
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
		addEye("Eye", "ale", side, Vector3.new(hc.X + lx, ly, Anatomy.frontZ(hc, hr, lx, ly - hc.Y)), Vector3.one * l.r, l.out, l.reflectance, false, 1 - (lx / hr.X) ^ 2 - ((ly - hc.Y) / hr.Y) ^ 2)
		-- Posterior lateral and median eyes on the dome.
		for n, d in { e.ple, e.pme } do
			local dx, dz = side * d.x, d.z
			addEye("Eye", if n == 1 then "ple" else "pme", side, Vector3.new(hc.X + dx, Anatomy.topY(hc, hr, dx, dz - hc.Z), dz), Vector3.one * d.r, d.out, d.reflectance, false, 1 - (dx / hr.X) ^ 2 - ((dz - hc.Z) / hr.Z) ^ 2)
		end
	end
	local cheeks, jaws, palps = {}, {}, {}
	local ch, cl, pl = look.cheek, look.chelicerae, look.palp
	for _, side in { -1, 1 } do
		if ch then -- an appearance without pale cheeks (the ant-mimicking spider) has none
			local cx = Anatomy.sideX(hc, hr, ch.y - hc.Y, ch.z - hc.Z) - ch.inset
			table.insert(cheeks, { side = side, at = Vector3.new(side * cx, ch.y, ch.z), radii = v3(ch.radii) })
		end
		local jaw = Vector3.new(side * cl.x, cl.y, cl.z)
		table.insert(jaws, { side = side, at = jaw, radii = v3(cl.radii) })
		table.insert(zones, { at = jaw, radius = math.max(cl.radii[1], cl.radii[2], cl.radii[3]) * 1.1 + 0.01 })
		local px = side * pl.x
		local base = Vector3.new(px, pl.y, Anatomy.frontZ(hc, hr, px, pl.y - hc.Y))
		table.insert(palps, { side = side, base = base, tip = base + Vector3.new(side * pl.spread, -pl.drop, -pl.reach) })
	end
	-- Fangs (ROBLOX-84): each hangs from the lower front of its chelicera as a short chain of ellipsoids, every segment `length` studs long and
	-- turned to its own direction (x is mirrored for the left one; -Z forward, -Y down), so a chain of two curves in and a single one points
	-- straight out. Where the base is, how long and how thick are in the appearance's `fang` table.
	local fangs: { Fang } = {}
	local fg = look.fang
	if fg then
		for _, side in { -1, 1 } do
			local p = Vector3.new(side * fg.x, fg.y, fg.z)
			for index, seg in fg.segments do
				local dir = Vector3.new(side * seg.dir[1], seg.dir[2], seg.dir[3]).Unit
				table.insert(fangs, { side = side, index = index, at = p + dir * (seg.length * 0.5), dir = dir, radii = Vector3.new(seg.radius, seg.radius, seg.length * 0.5 + seg.radius * 0.35) })
				p += dir * seg.length
			end
		end
	end
	return {
		headCenter = hc, headRadii = hr, abdomenCenter = ac, abdomenRadii = ar,
		faceCenter = v3(look.face.center), faceRadii = v3(look.face.radii),
		pedicelCenter = v3(look.pedicel.center), pedicelRadii = v3(look.pedicel.radii),
		neck = v3(look.neck),
		eyes = eyes, glints = glints, cheeks = cheeks, jaws = jaws, palps = palps, fangs = fangs,
		spinneret = Vector3.new(0, ac.Y + 0.02, ac.Z + ar.Z - 0.005),
		hairFree = zones,
		tubercle = if tub then { center = v3(tub.center), radii = v3(tub.radii) } else nil,
	}
end

return Anatomy
