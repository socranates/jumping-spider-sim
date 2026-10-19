--!strict
-- Where the rival spider can walk, and the ways between (ROBLOX-69). A graph of the windowsill's box faces made from the sill region's pieces alone (Region.pieces, ROBLOX-94):
-- every face of every box is a node; two faces that meet along a line (a box's own edge, convex, or a wall rising from a floor, concave) are
-- joined by that seam. The rival's own SpiderMotor walks any seam the way the player's does (a wall ahead becomes the support, an edge is wrapped), so a
-- route is only a list of seams to cross and where to head to cross them. Pure and Vector3-light: the CLI checks it on the boxes, and the
-- same module runs in the game. Nothing here knows about time, state or the engine.
--
-- Faces are looked up by their box, the axis and the side. A face is "stand-able" at the sample points where a body of the motor's radius fits
-- without touching another box. The crack (the crevice boxes) is forbidden: no route enters it, and the keep-out box around the retreat turns
-- every straight walk aside.
local Rules = require(script.Parent.Parent.Data.RivalRules)
local WorldMap = require(script.Parent.Parent.World.WorldMap)
local Region = require(script.Parent.Parent.World.Region)

local Route = {}

-- ROBLOX-94: the graph is the sill's, region 0 of the world: its boxes and the keep-out around its crack come from the region's generator (Region.pieces, Region.keepOut). It
-- becomes region-scoped, with seams to the neighbours, in the navigation round; until then there is one region and one crack.
local SILL = WorldMap.region(WorldMap.HOME) :: WorldMap.Region
local KEEP = Region.keepOut(SILL)[1]

local AXIS = { "X", "Y", "Z" }
local SEAT = 0.31 -- the motor's body centre above its support (SpiderMotor.HEIGHT)
local BODY = 0.2 -- a stand-able point keeps this much clear (the motor itself only casts rays, so less than its radius of 0.3 will do)
local EPS = 1e-4
local MIN_SEAM = 0.3 -- shorter seams are not used

export type Edge = {
	to: number,
	samples: { Vector3 }, -- surface points on the seam where a body can cross
	ahead: Vector3, -- on the face this edge leaves: the direction toward the seam
	convex: boolean,
}
export type Face = {
	id: number,
	piece: string,
	axis: number,
	sign: number,
	normal: Vector3,
	plane: number,
	lo: { number },
	hi: { number },
	area: number,
	forbidden: boolean,
	stand: { Vector3 }, -- surface points where a body fits
	edges: { Edge },
	corners: { Vector3 }?, -- surface points just outside the corners of boxes standing on this face (made when first asked)
}
-- A hop is a seam crossed (from one face to the next), or a `via`: a corner of a box standing on the face, rounded so the walk does not run into it.
export type Hop = { from: number, face: number, seam: Vector3, aim: Vector3, via: boolean? }

local boxes: { { id: string, lo: { number }, hi: { number } } } = {}
local faces: { Face } = {}
local built = false

local function comp(v: Vector3, axis: number): number
	return (v :: any)[AXIS[axis]]
end

local function vec(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function axisVec(axis: number, s: number): Vector3
	return if axis == 1 then vec(s, 0, 0) elseif axis == 2 then vec(0, s, 0) else vec(0, 0, s)
end

-- Whether a point is strictly inside any box (a hair of tolerance).
local function solid(p: Vector3): boolean
	for _, b in boxes do
		if p.X > b.lo[1] + EPS and p.X < b.hi[1] - EPS and p.Y > b.lo[2] + EPS and p.Y < b.hi[2] - EPS and p.Z > b.lo[3] + EPS and p.Z < b.hi[3] - EPS then
			return true
		end
	end
	return false
end

-- Whether a body of the motor's radius centred here touches no box.
local function bodyFits(c: Vector3, radius: number?): boolean
	local r = radius or BODY
	for _, b in boxes do
		local dx = math.max(b.lo[1] - c.X, 0, c.X - b.hi[1])
		local dy = math.max(b.lo[2] - c.Y, 0, c.Y - b.hi[2])
		local dz = math.max(b.lo[3] - c.Z, 0, c.Z - b.hi[3])
		if dx * dx + dy * dy + dz * dz < r * r then return false end
	end
	return true
end

-- The keep-out box: the retreat, grown by a margin. Nothing the rival does goes in.
function Route.inKeepOut(p: Vector3): boolean
	local lo, hi = KEEP.min, KEEP.max
	return p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y and p.Z >= lo.Z and p.Z <= hi.Z
end

local function forbiddenPiece(id: string): boolean
	return string.sub(id, 1, 8) == "crevice_" or id == "leaf_tip"
end

local function build()
	if built then return end
	built = true
	for _, piece in Region.pieces(SILL) do
		table.insert(boxes, { id = piece.id, lo = { piece.lo.X, piece.lo.Y, piece.lo.Z }, hi = { piece.hi.X, piece.hi.Y, piece.hi.Z } })
	end
	-- Faces: six to a box.
	for bi, b in boxes do
		for axis = 1, 3 do
			for _, sign in { -1, 1 } do
				local o1, o2 = (axis % 3) + 1, ((axis + 1) % 3) + 1
				local face: Face = {
					id = #faces + 1, piece = b.id, axis = axis, sign = sign, normal = axisVec(axis, sign),
					plane = if sign > 0 then b.hi[axis] else b.lo[axis], lo = { 0, 0, 0 }, hi = { 0, 0, 0 },
					area = (b.hi[o1] - b.lo[o1]) * (b.hi[o2] - b.lo[o2]), forbidden = forbiddenPiece(b.id), stand = {}, edges = {},
				}
				for k = 1, 3 do
					face.lo[k], face.hi[k] = b.lo[k], b.hi[k]
				end
				face.lo[axis], face.hi[axis] = face.plane, face.plane
				-- Where a body fits on this face: a grid over its rectangle, inset a little from the rim.
				local n = if face.area > 60 then 9 else 5
				for i = 0, n - 1 do
					for j = 0, n - 1 do
						local pt = { 0, 0, 0 }
						pt[axis] = face.plane
						local function at(k: number, t: number): number
							local inset = math.min(0.3, (b.hi[k] - b.lo[k]) / 2)
							return b.lo[k] + inset + (b.hi[k] - b.lo[k] - 2 * inset) * t
						end
						pt[o1] = at(o1, (i + 0.5) / n)
						pt[o2] = at(o2, (j + 0.5) / n)
						local surface = vec(pt[1], pt[2], pt[3])
						if bodyFits(surface + face.normal * SEAT) then table.insert(face.stand, surface) end
					end
				end
				-- Outer faces (the frames' backs, the floor's underside) are outside the sill: no route enters them.
				local mid = vec((face.lo[1] + face.hi[1]) / 2, (face.lo[2] + face.hi[2]) / 2, (face.lo[3] + face.hi[3]) / 2) + face.normal * SEAT
				local slo, shi = Rules.sillMin, Rules.sillMax
				if mid.X < slo.X or mid.X > shi.X or mid.Y < slo.Y or mid.Y > shi.Y or mid.Z < slo.Z or mid.Z > shi.Z then face.forbidden = true end
				table.insert(faces, face)
			end
		end
		local _ = bi
	end
	-- Seams between faces on different axes.
	for _, f in faces do
		local A = boxes[1]
		for _, b in boxes do
			if b.id == f.piece then A = b; break end
		end
		for _, g in faces do
			if g.axis ~= f.axis then
				local B = boxes[1]
				for _, b in boxes do
					if b.id == g.piece then B = b; break end
				end
				local a, b = f.axis, g.axis
				local c = 6 - a - b
				local cA, cB = f.plane, g.plane
				if cB >= A.lo[b] - EPS and cB <= A.hi[b] + EPS and cA >= B.lo[a] - EPS and cA <= B.hi[a] + EPS then
					local lo, hi = math.max(A.lo[c], B.lo[c]), math.min(A.hi[c], B.hi[c])
					if hi - lo >= MIN_SEAM then
						local convex = f.piece == g.piece
						local mid = { 0, 0, 0 }
						mid[a], mid[b], mid[c] = cA, cB, (lo + hi) / 2
						local corner = vec(mid[1], mid[2], mid[3]) + f.normal * 0.15 + g.normal * 0.15
						if not solid(corner) then
							-- From the seam into each face: a face meets a wall of another box on the wall's free side, and meets the rest of its own box
							-- away from the edge it turns over.
							local intoF = if convex then -g.normal else g.normal
							local intoG = if convex then -f.normal else f.normal
							local samples: { Vector3 } = {}
							for _, t in { 0.12, 0.3, 0.5, 0.7, 0.88 } do
								local pc = lo + (hi - lo) * t
								if pc - lo >= 0.2 and hi - pc >= 0.2 or t == 0.5 then
									local s = { 0, 0, 0 }
									s[a], s[b], s[c] = cA, cB, pc
									local seam = vec(s[1], s[2], s[3])
									-- (A crossing may be a narrow strip, such as the underside of the planter's rim: only the places right at the seam are tested.)
									if bodyFits(seam + intoF * 0.12 + f.normal * SEAT, 0.1) and bodyFits(seam + intoG * 0.12 + g.normal * SEAT, 0.1)
										and not Route.inKeepOut(seam) then
										table.insert(samples, seam)
									end
								end
							end
							if #samples > 0 then
								table.insert(f.edges, { to = g.id, samples = samples, ahead = -intoF, convex = convex })
							end
						end
					end
				end
			end
		end
	end
	-- The keep-out box is an obstacle like any box (the walk tests and the corners to round count it) but has no faces: nothing walks on it.
	local ko, ki = KEEP.min, KEEP.max
	table.insert(boxes, { id = "keepout", lo = { ko.X, ko.Y, ko.Z }, hi = { ki.X, ki.Y, ki.Z } })
end

function Route.faces(): { Face }
	build()
	return faces
end

-- The face a body stands on: its centre, the support's normal. Nil when it is on no known face (in the air, or on a face this graph lacks).
function Route.faceAt(center: Vector3, up: Vector3): number?
	build()
	local surface = center - up * SEAT
	local best, bestD = nil :: number?, 0.12
	for _, f in faces do
		if f.normal:Dot(up) > 0.98 then
			local d = math.abs(comp(surface, f.axis) - f.plane)
			if d < bestD then
				local inside = true
				for k = 1, 3 do
					if k ~= f.axis and (comp(surface, k) < f.lo[k] - 0.12 or comp(surface, k) > f.hi[k] + 0.12) then inside = false; break end
				end
				if inside then best, bestD = f.id, d end
			end
		end
	end
	return best
end

-- Whether two faces are the same or meet along a seam: the rival may strike from one onto the other.
function Route.adjacent(a: number?, b: number?): boolean
	if a == nil or b == nil then return false end
	if a == b then return true end
	build()
	for _, e in faces[a].edges do
		if e.to == b then return true end
	end
	return false
end

-- Whether a straight walk across a face of the box `own` from one surface point to another would run into a box standing on it (the body is a ball of
-- 0.3, kept 0.2 off; the stretch next to the end points is not tested, they are at seams and walls by design).
local function walkBlocked(a: Vector3, b: Vector3, normal: Vector3, own: string): boolean
	local d = b - a
	local len = d.Magnitude
	if len < 0.35 then return false end
	local dir = d / len
	local cut = math.min(0.4, len * 0.5)
	local pa = a + dir * cut + normal * SEAT
	local pb = b - dir * cut + normal * SEAT
	local seg = pb - pa
	for _, box in boxes do
		local tmin, tmax = 0.0, 1.0
		local hit = box.id ~= own
		for k = 1, 3 do
			local o, dk = comp(pa, k), comp(seg, k)
			local l, h = box.lo[k] - 0.35, box.hi[k] + 0.35
			if math.abs(dk) < 1e-9 then
				if o < l or o > h then hit = false; break end
			else
				local t1, t2 = (l - o) / dk, (h - o) / dk
				if t1 > t2 then t1, t2 = t2, t1 end
				tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
				if tmin > tmax then hit = false; break end
			end
		end
		-- Starting beside a box and not walking toward it is not blocked: the start is inside its margin for a stride only.
		if hit then
			local away = false
			if tmin <= 1e-6 then
				local n = { 0.0, 0.0, 0.0 }
				for k = 1, 3 do
					local o = comp(pa, k)
					if o < box.lo[k] then n[k] = o - box.lo[k] elseif o > box.hi[k] then n[k] = o - box.hi[k] end
				end
				away = (n[1] ~= 0 or n[2] ~= 0 or n[3] ~= 0) and seg.X * n[1] + seg.Y * n[2] + seg.Z * n[3] >= -1e-9
			end
			if not away then return true end
		end
	end
	return false
end

-- The places to round a box that stands on a face: just outside each of its corners (0.42 off, the walk test keeps 0.35), where a body fits.
local function cornersOf(f: Face): { Vector3 }
	if f.corners ~= nil then return f.corners :: { Vector3 } end
	local out: { Vector3 } = {}
	f.corners = out
	local o1, o2 = (f.axis % 3) + 1, ((f.axis + 1) % 3) + 1
	local level = f.plane + f.sign * SEAT
	local M = 0.42
	for _, b in boxes do
		if b.id ~= f.piece and level >= b.lo[f.axis] - 0.35 and level <= b.hi[f.axis] + 0.35
			and b.hi[o1] + M > f.lo[o1] and b.lo[o1] - M < f.hi[o1] and b.hi[o2] + M > f.lo[o2] and b.lo[o2] - M < f.hi[o2] then
			for _, c1 in { b.lo[o1] - M, b.hi[o1] + M } do
				for _, c2 in { b.lo[o2] - M, b.hi[o2] + M } do
					if c1 >= f.lo[o1] + 0.2 and c1 <= f.hi[o1] - 0.2 and c2 >= f.lo[o2] + 0.2 and c2 <= f.hi[o2] - 0.2 then
						local pt = { 0, 0, 0 }
						pt[f.axis], pt[o1], pt[o2] = f.plane, c1, c2
						local surface = vec(pt[1], pt[2], pt[3])
						local centre = surface + f.normal * SEAT
						if bodyFits(centre, 0.3) and not Route.inKeepOut(surface) and not Route.inKeepOut(centre) then
							table.insert(out, surface)
						end
					end
				end
			end
		end
	end
	return out
end

-- A binary min-heap of {priority, id}.
local function heapPush(h: { any }, pri: number, id: number)
	table.insert(h, { pri, id })
	local i = #h
	while i > 1 do
		local p = i // 2
		if h[p][1] <= h[i][1] then break end
		h[p], h[i] = h[i], h[p]
		i = p
	end
end
local function heapPop(h: { any }): (number, number)
	local top = h[1]
	local last = table.remove(h) :: any
	if #h > 0 then
		h[1] = last
		local i = 1
		while true do
			local l, r, m = i * 2, i * 2 + 1, i
			if l <= #h and h[l][1] < h[m][1] then m = l end
			if r <= #h and h[r][1] < h[m][1] then m = r end
			if m == i then break end
			h[m], h[i] = h[i], h[m]
			i = m
		end
	end
	return top[1], top[2]
end

-- The shortest way from a surface point on one face to a surface point on another, as the seams to cross and the corners to round. Nil when there
-- is none. `from` and `goal` are surface points (not body centres). The search is over crossings and corners, not faces: a face is walked
-- differently from where it is entered (a floor entered beside a box is not the floor entered on the far side of it), and a straight walk across
-- a face that a box stands on is not a walk at all.
function Route.plan(fromFace: number, from: Vector3, goalFace: number, goal: Vector3): { Hop }?
	build()
	local TURN = 0.6
	local BLOCKED = 25.0
	-- States: 1 is the start; the others are crossings (1), corners (2) and the goal (3), numbered as they are found.
	local stFace: { number } = { fromFace }
	local stPos: { Vector3 } = { from }
	local stPrev: { number } = { 0 }
	local stKind: { number } = { 0 }
	local stSeam: { Vector3 } = { from }
	local stAim: { Vector3 } = { from }
	local stDist: { number } = { 0 }
	local stCame: { number } = { 0 } -- the face a crossing chain started from (no turning straight back over the seam just crossed)
	local settled: { [number]: boolean } = {}
	local heap: { any } = {}
	heapPush(heap, 0, 1)
	local bestVia: { [number]: number } = {} -- the cheapest cost found for each crossing (a face and which of its seams) and corner
	local goalCost = math.huge
	local goalState = 0
	local function add(face: number, pos: Vector3, prev: number, kind: number, aim: Vector3, dist: number, came: number)
		table.insert(stFace, face)
		table.insert(stPos, pos)
		table.insert(stPrev, prev)
		table.insert(stKind, kind)
		table.insert(stSeam, pos)
		table.insert(stAim, aim)
		table.insert(stDist, dist)
		table.insert(stCame, came)
		heapPush(heap, dist, #stFace)
	end
	while #heap > 0 do
		local _, id = heapPop(heap)
		if not settled[id] then
			settled[id] = true
			if stKind[id] == 3 then goalState = id; break end
			local fid = stFace[id]
			local face = faces[fid]
			local here = stPos[id]
			local cost = stDist[id]
			if fid == goalFace then
				local nd = cost + (goal - here).Magnitude + (if walkBlocked(here, goal, face.normal, face.piece) then BLOCKED else 0)
				if nd < goalCost then
					goalCost = nd
					add(goalFace, goal, id, 3, goal, nd, stCame[id])
				end
			end
			-- Round the corner of a box standing on this face.
			for ci, c in cornersOf(face) do
				local key = -(fid * 256 + ci)
				local nd = cost + (c - here).Magnitude + 0.1
				local known = bestVia[key]
				if (known == nil or nd < known - 1e-9) and (c - here).Magnitude > 0.05 and not walkBlocked(here, c, face.normal, face.piece) then
					bestVia[key] = nd
					add(fid, c, id, 2, c + face.normal * SEAT, nd, stCame[id])
				end
			end
			-- Cross a seam.
			for ei, e in face.edges do
				local g = faces[e.to]
				if not g.forbidden and e.to ~= stCame[id] then
					local ordered = table.clone(e.samples)
					table.sort(ordered, function(p: Vector3, q: Vector3): boolean return (p - here).Magnitude < (q - here).Magnitude end)
					local best, bestD = ordered[1], (ordered[1] - here).Magnitude + BLOCKED
					for i = 1, math.min(#ordered, 3) do
						if not walkBlocked(here, ordered[i], face.normal, face.piece) then
							best, bestD = ordered[i], (ordered[i] - here).Magnitude
							break
						end
					end
					local nd = cost + bestD + TURN
					local key = fid * 64 + ei
					local known = bestVia[key]
					if known == nil or nd < known - 1e-9 then
						bestVia[key] = nd
						add(e.to, best, id, 1, best + e.ahead * 0.5, nd, fid)
					end
				end
			end
		end
	end
	if goalState == 0 then return nil end
	local hops: { Hop } = {}
	local at = stPrev[goalState]
	while stPrev[at] ~= 0 do
		local p = stPrev[at]
		if stKind[at] == 2 then
			table.insert(hops, 1, { from = stFace[at], face = stFace[at], seam = stSeam[at], aim = stAim[at], via = true })
		else
			table.insert(hops, 1, { from = stFace[p], face = stFace[at], seam = stSeam[at], aim = stAim[at] })
		end
		at = p
	end
	return hops
end

-- Where to head so a straight walk does not cross the keep-out box: the goal itself, or a corner of the box to round first.
function Route.aroundKeepOut(from: Vector3, goal: Vector3): Vector3
	local lo, hi = KEEP.min, KEEP.max
	-- The segment against the box, on the plane of the floor (the box is only a little taller than the spider).
	local function crosses(a: Vector3, b: Vector3): boolean
		local tmin, tmax = 0, 1
		for _, axis in { "X", "Z" } do
			local da = (b :: any)[axis] - (a :: any)[axis]
			local oa = (a :: any)[axis]
			local l, h = (lo :: any)[axis], (hi :: any)[axis]
			if math.abs(da) < 1e-9 then
				if oa < l or oa > h then return false end
			else
				local t1, t2 = (l - oa) / da, (h - oa) / da
				if t1 > t2 then t1, t2 = t2, t1 end
				tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
				if tmin > tmax then return false end
			end
		end
		return true
	end
	if Route.inKeepOut(from) or from.Y > hi.Y + 0.4 or goal.Y > hi.Y + 0.4 then return goal end
	if not crosses(from, goal) then return goal end
	local y = from.Y
	local best, bestLen = goal, math.huge
	for _, x in { lo.X - 0.05, hi.X + 0.05 } do
		for _, z in { lo.Z - 0.05, hi.Z + 0.05 } do
			local corner = vec(x, y, z)
			if not crosses(from, corner) and not crosses(corner, goal) then
				local len = (corner - from).Magnitude + (goal - corner).Magnitude
				if len < bestLen then best, bestLen = corner, len end
			end
		end
	end
	return best
end

export type Waypoint = { pos: Vector3, up: Vector3, face: number }

-- Places to patrol to, spread over every face the rival may walk: the tops of the boxes and their climbable sides (not undersides, not
-- the crack), a few on a big face, always a spot where a body fits.
function Route.waypoints(): { Waypoint }
	build()
	local out: { Waypoint } = {}
	for _, f in faces do
		if not f.forbidden and f.normal.Y > -0.5 and f.area >= 1.5 and #f.stand > 0 then
			local k = math.clamp(math.floor(f.area / 70) + 1, 1, 5)
			local picked: { Vector3 } = {}
			local pool: { Vector3 } = {}
			for _, s in f.stand do
				if not Route.inKeepOut(s + f.normal * SEAT) and not Route.inKeepOut(s) then table.insert(pool, s) end
			end
			if #pool > 0 then
				table.insert(picked, pool[math.ceil(#pool / 2)])
				while #picked < math.min(k, #pool) do
					local far, farD = pool[1], -1.0
					for _, s in pool do
						local nearest = math.huge
						for _, q in picked do nearest = math.min(nearest, (s - q).Magnitude) end
						if nearest > farD then far, farD = s, nearest end
					end
					table.insert(picked, far)
				end
				for _, s in picked do table.insert(out, { pos = s, up = f.normal, face = f.id }) end
			end
		end
	end
	return out
end

Route.SEAT = SEAT
Route.walkBlocked = walkBlocked

return Route
