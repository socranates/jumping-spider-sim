--!strict
-- A walk along a list of points on surfaces (ROBLOX-105, W3b part B): the aphid's creep from one of its perches to another and the ladybird's rounds over a
-- plant (World/Garden.plantPath), and the snail's crawl over the soil and up the wall's foot. A walk is plain data (the points, their surfaces' normals, how far
-- along it is), so a rest records it and puts it back where it was. Pure: no engine, no random draw.
local PlantWalk = {}

export type Walk = { points: { Vector3 }, normals: { Vector3 }, lengths: { number }, length: number, s: number }

-- A walk over `path` ({ pos, normal } each), from `from` (a place on the first point's surface) when given.
function PlantWalk.new(path: { any }, from: Vector3?, fromNormal: Vector3?): Walk
	local points, normals = {}, {}
	if from ~= nil and (path[1] == nil or (path[1].pos - from).Magnitude > 1e-4) then
		table.insert(points, from)
		table.insert(normals, fromNormal or (if path[1] ~= nil then path[1].normal else Vector3.yAxis))
	end
	for _, p in path do
		if #points == 0 or (points[#points] - p.pos).Magnitude > 1e-6 then
			table.insert(points, p.pos)
			table.insert(normals, p.normal)
		end
	end
	local lengths, total = {}, 0
	for i = 2, #points do
		local d = (points[i] - points[i - 1]).Magnitude
		table.insert(lengths, d)
		total += d
	end
	return { points = points, normals = normals, lengths = lengths, length = total, s = 0 }
end

-- Where the walk is at distance `s` along it: the point on the surface, the surface's normal there (turning from one face's to the next's along each leg) and
-- the direction of travel.
function PlantWalk.at(w: Walk, s: number): (Vector3, Vector3, Vector3)
	local pts, nrm = w.points, w.normals
	if #pts == 1 then return pts[1], nrm[1], Vector3.zero end
	local left = math.clamp(s, 0, w.length)
	for i, d in w.lengths do
		if left <= d or i == #w.lengths then
			local t = if d > 1e-9 then math.clamp(left / d, 0, 1) else 1
			local n = nrm[i]:Lerp(nrm[i + 1], t)
			if n.Magnitude < 1e-6 then n = nrm[i + 1] end
			local dir = if d > 1e-9 then (pts[i + 1] - pts[i]) / d else Vector3.zero
			return pts[i]:Lerp(pts[i + 1], t), n.Unit, dir
		end
		left -= d
	end
	return pts[#pts], nrm[#nrm], Vector3.zero
end

-- Moves the walk on by `distance`; returns the place, the normal, the direction (laid on the surface) and whether it has arrived.
function PlantWalk.advance(w: Walk, distance: number): (Vector3, Vector3, Vector3, boolean)
	w.s = math.min(w.length, w.s + math.max(0, distance))
	local p, n, dir = PlantWalk.at(w, w.s)
	local flat = dir - n * dir:Dot(n)
	return p, n, (if flat.Magnitude > 1e-6 then flat.Unit else Vector3.zero), w.s >= w.length - 1e-9
end

-- What is wrong with a walk put back from a record (nil for a good one).
function PlantWalk.problem(w: any): string?
	if type(w) ~= "table" or type(w.points) ~= "table" or type(w.normals) ~= "table" or type(w.lengths) ~= "table" then return "a walk with no points" end
	if #w.points < 1 or #w.normals ~= #w.points or #w.lengths ~= #w.points - 1 then return "a walk whose points do not match" end
	if type(w.s) ~= "number" or w.s ~= w.s or type(w.length) ~= "number" or w.s < 0 or w.s > w.length + 1e-6 then return "a walk out of its length" end
	return nil
end

return PlantWalk
