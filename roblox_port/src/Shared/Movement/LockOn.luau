--!strict
-- Lock-on and the sidestep (ROBLOX-110). Nathan: "a lock on so you can track prey without the visual cues and the ability to side step".
-- A jumping spider turns its body to keep a prey in its principal eyes and sidles round it, stalking; this is that, for the player.
--
-- What can be locked is only what the spider's own perception has: a contact in its memory (Perception/ObservationMemory) that an inspection
-- has placed (hasPosition), live, or lost with its last-seen mark still good. Never the world's own list of things, so nothing hidden, never
-- seen or only cued (a bearing without a place) can be locked. Which one a press takes: the one in the principal eyes now nearest the middle of
-- the view (what the spider is looking at), else the nearest placed contact within `range` in front of the spider (within `frontDeg` of its
-- facing). Anything the spider sees can be locked (the rival, the mate, the wasp, a fly): a lock is attention, not a promise of a meal.
--
-- A lock ends on a second press, on Cancel (when Cancel has nothing else to do), when the memory forgets the contact (sight lost for the
-- memory's decay time, `memory_decay_s`, 6 s; the remembered spot looked at and found empty; the prey caught and eaten) or when the place it is
-- believed to be is beyond `releaseRange`. While it holds, the place it follows is the contact's: where it is being seen, or where it was last
-- seen once sight is lost (the mark never moves), so the lock never knows more than the spider does.
--
-- The sidestep: while locked, the left and right of the stick (A, D, the touch arrows) walk the spider round the locked thing at the distance it
-- had when the stick's forward and back were last let go, and forward and back close or open that distance; it walks at the motor's own creep
-- (salticids stalk slowly) and the motor keeps its body faced to the thing (SpiderMotor's `face`). The direction is worked out on the plane
-- the spider stands on, from its own up, so it is the same on a floor, a wall and a leaf's underside.
--
-- The camera (Client/SpiderCamera.setLock) keeps the locked thing framed: the orbit turns to look past the spider at it, the eye view's gaze
-- turns to it; eased, or under Reduced Motion held still and cut only when the thing has drifted `reducedCutDeg` from where the view would be.
-- Pure: tests/lock.luau checks all of it without Roblox.
local SupportMath = require(script.Parent.SupportMath)
local CameraMath = require(script.Parent.CameraMath)
local Observation = require(script.Parent.Parent.Perception.Observation)

local LockOn = {}

-- The game's own numbers (no Godot default is touched).
LockOn.game = {
	range = 12.0, -- WU: a press locks only onto something placed within this of the spider
	releaseRange = 16.0, -- WU: a lock ends when the thing is believed farther than this
	lookingDeg = 20.0, -- a contact in the principal eyes within this of the middle of the view is the one "looked at"
	frontDeg = 90.0, -- otherwise the nearest within this of the spider's facing
	minDistance = 0.9, -- WU, on the plane: forward stops closing here
	holdGain = 2.0, -- the pull back to the kept distance while circling, per WU of error (clamped to a full step)
	cameraRate = 5.0, -- 1/s: how fast the view turns to keep the thing framed
	reducedCutDeg = 25.0, -- Reduced Motion: the view stays still until the thing is this far from where it would be, then cuts
}

export type State = { trackId: string?, keep: number, point: Vector3?, released: string? }

function LockOn.new(): State
	return { trackId = nil, keep = 0, point = nil, released = nil }
end

-- A contact a lock may take or keep: placed by an inspection, and live, or lost with its mark still good.
function LockOn.lockable(c: any): boolean
	if c == nil or not c.hasPosition then return false end
	if c.state == "live" then return true end
	return c.state == "lost" and c.markValid == true
end

local function angleBetween(a: Vector3, b: Vector3): number
	if a.Magnitude < 1e-6 or b.Magnitude < 1e-6 then return math.pi end
	return math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))
end

-- The contact a press would lock now, or nil. `eye`: the spider's eyes; `heading`: its facing; `viewOrigin`, `viewDir`: the middle of the view
-- (the camera's centre ray). Only the memory's contacts are looked at.
function LockOn.pick(memory: any, eye: Vector3, heading: Vector3, viewOrigin: Vector3, viewDir: Vector3): any
	local g = LockOn.game
	local looked, lookedAngle = nil, math.rad(g.lookingDeg)
	local nearest, nearestD = nil, g.range
	for _, c in memory:contacts() do
		if LockOn.lockable(c) then
			local to = c.position - eye
			local d = to.Magnitude
			if d <= g.range then
				if c.state == "live" and c.modality == Observation.INSPECTION then
					local a = angleBetween(viewDir, c.position - viewOrigin)
					if a <= lookedAngle then looked, lookedAngle = c, a end
				end
				if d <= nearestD and angleBetween(heading, to) <= math.rad(g.frontDeg) then nearest, nearestD = c, d end
			end
		end
	end
	return looked or nearest
end

-- The spider's distance to a point on the plane it stands on (up `up`).
function LockOn.planar(pos: Vector3, up: Vector3, point: Vector3): number
	local d = point - pos
	return (d - up * d:Dot(up)).Magnitude
end

-- A press of the lock: releases a lock that holds ("released"), else locks what pick() gives ("locked"), else does nothing ("none": the caller
-- recentres then, on the keys that are also Recentre).
function LockOn.press(s: State, memory: any, pos: Vector3, up: Vector3, eye: Vector3, heading: Vector3, viewOrigin: Vector3, viewDir: Vector3): string
	if s.trackId ~= nil then
		LockOn.release(s, "pressed")
		return "released"
	end
	local c = LockOn.pick(memory, eye, heading, viewOrigin, viewDir)
	if c == nil then return "none" end
	s.trackId, s.point, s.released = c.trackId, c.position, nil
	s.keep = math.max(LockOn.planar(pos, up, c.position), LockOn.game.minDistance)
	return "locked"
end

function LockOn.release(s: State, why: string)
	if s.trackId == nil then return end
	s.trackId, s.point, s.released = nil, nil, why
end

-- Each tick, after the sensor: the lock's point now, or nil when there is none (and why it ended, in s.released).
function LockOn.update(s: State, memory: any, pos: Vector3): Vector3?
	local id = s.trackId
	if id == nil then return nil end
	local c = memory:getContact(id)
	if c == nil then LockOn.release(s, "forgotten"); return nil end
	if not LockOn.lockable(c) then LockOn.release(s, "empty"); return nil end
	if (c.position - pos).Magnitude > LockOn.game.releaseRange then LockOn.release(s, "range"); return nil end
	s.point = c.position
	return s.point
end

-- The sidestep: the walking direction on the plane of up `up` for the stick (r right, f forward) while locked on `target`, and the distance kept
-- from now on. Zero when the stick is idle. r circles the target at the kept distance (pulled back to it by holdGain); f closes or opens it, and
-- the distance it leaves when let go is the one kept.
function LockOn.strafe(pos: Vector3, up: Vector3, target: Vector3, keep: number, r: number, f: number): (Vector3, number)
	local g = LockOn.game
	local d = target - pos
	local planar = d - up * d:Dot(up)
	local dist = planar.Magnitude
	if math.abs(r) < 1e-3 and math.abs(f) < 1e-3 then return Vector3.zero, keep end
	if dist < 1e-3 then return Vector3.zero, keep end
	local toward = planar / dist
	local right = toward:Cross(up)
	local radial = f
	if math.abs(f) >= 1e-3 then
		keep = math.max(dist, g.minDistance)
		if f > 0 and dist <= g.minDistance then radial = 0 end
	else
		radial = math.clamp((dist - keep) * g.holdGain, -1, 1)
	end
	local w = right * r + toward * radial
	if w.Magnitude < 1e-4 then return Vector3.zero, keep end
	return w.Unit, keep
end

-- The orbit camera's yaw and elevation (CameraMath's: back direction (sin yaw cos e, sin e, cos yaw cos e)) that look from behind the pivot
-- at the target, the elevation lifted by the game's default so a thing level with the spider is seen over it. nil when they coincide.
function LockOn.orbitGoal(pivot: Vector3, target: Vector3): (number?, number?)
	local f = target - pivot
	if f.Magnitude < 1e-3 then return nil, nil end
	f = f.Unit
	local flat = Vector3.new(f.X, 0, f.Z)
	if flat.Magnitude < 1e-3 then return nil, nil end
	local yaw = math.atan2(-f.X, -f.Z)
	local elev = math.rad(CameraMath.DEFAULT_ELEVATION_DEG) - math.asin(math.clamp(f.Y, -1, 1))
	return yaw, math.clamp(elev, math.rad(CameraMath.MIN_ELEVATION_DEG), math.rad(CameraMath.MAX_ELEVATION_DEG))
end

local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- One frame of the orbit's follow: eased toward the goal, or (Reduced Motion) unchanged until either angle is reducedCutDeg off, then the goal.
function LockOn.followOrbit(yaw: number, elev: number, goalYaw: number, goalElev: number, dt: number, reduced: boolean): (number, number)
	local dy, de = wrap(goalYaw - yaw), goalElev - elev
	if reduced then
		local cut = math.rad(LockOn.game.reducedCutDeg)
		if math.abs(dy) > cut or math.abs(de) > cut then return yaw + dy, goalElev end
		return yaw, elev
	end
	local k = 1 - math.exp(-LockOn.game.cameraRate * dt)
	return yaw + dy * k, elev + de * k
end

-- One frame of the eye view's follow: the gaze turned toward `want` (both unit), eased, or cut under Reduced Motion as the orbit is.
function LockOn.followGaze(gaze: Vector3, want: Vector3, dt: number, reduced: boolean): Vector3
	local off = angleBetween(gaze, want)
	if reduced then
		return if off > math.rad(LockOn.game.reducedCutDeg) then want else gaze
	end
	local k = 1 - math.exp(-LockOn.game.cameraRate * dt)
	return SupportMath.rotateToward(gaze, want, off * k)
end

return LockOn
