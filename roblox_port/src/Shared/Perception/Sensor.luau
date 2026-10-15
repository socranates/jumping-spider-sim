--!strict
-- Sensor: the world half of Godot's SensorSystem (scripts/perception/sensor_system.gd, c87ce00). SensorCore keeps what needs no world (which
-- contact a sighting is filed under, how long a thing has been in view, the cue and its cooldown, the empty-spot check); this is what looks.
-- Each tick it reads the observer's eye and gaze (never the camera's), takes the percept of every perceivable thing and decides what the
-- senses could pick up of it:
--   * a thing inside the broad peripheral field that moves and can be seen through at least one of its sample points gives a PERIPHERAL cue:
--     a coarse bearing and nothing else, at most once per cue cooldown for each thing;
--   * a thing inside the narrow inspection cone along the gaze that can be seen, and looks big enough, is INSPECTED: its position is
--     estimated from the points that could be seen, and the longer it is held in the cone without a break the finer the category.
-- Line of sight is five rays from the eye to sample points of the thing; a point the world stands in front of does not count. Nothing about a
-- thing that cannot be seen reaches the memory: a hidden thing makes no observation, and the memory is never refreshed from where it
-- really is. The sensor also looks at the spots where lost contacts were last seen (SensorCore.checkSpots, through _allVisible below).
--
-- Ported method for method from _physics_process (in its order), _sense, _visible_points, _sample_points, _clear, _all_visible, could_sense,
-- describe_tracks, _record_cost, cost_percentile and reset. Not here: on_capture (the feeding chunk), Focus, and any presentation.
--
-- How a caller drives it: once at the START of every fixed tick (Godot's sensor runs at priority -10, before the motor and the things that
-- move, so it reads the world as the previous tick committed it):
--
--   sensor:step(delta, observer, percepts, cast)
--     observer  {eye, gaze, up, heading}: where the eyes are, the axis of the cone, the body's up and facing (the motor's observer())
--     percepts  one SensorCore.Percept for every perceivable thing that is there to be sensed (a thing that is not simply is not listed)
--     cast      (from, to) -> the position of the first WORLD hit on that segment, nil when it is clear. Only world geometry may stop it:
--               not the observer, not the things sensed (Sensor.workspaceCast makes one from a RaycastParams).
--
-- Rates (spec 20): the broad scan of everything runs at broad_query_hz; things already tracked (a live contact), things whose last position
-- is remembered as a mark, and things within close_check_range_wu of the eye are checked every tick. Tick numbering is Godot's: the tick
-- counts up first (SensorCore.beginTick), so the first broad scan is tick 1 and the next is due 6 ticks later.
--
-- Where the counts live: the sensor's own are fields here (broadScans, rays, checks, cost); the ones SensorCore keeps for the bookkeeping it
-- does are read from sensor.core (tick, cuesMade, inspectionsMade, spotChecksTotal and the cueEmitted signal).
local PerceptionMath = require(script.Parent.PerceptionMath)
local SensorCore = require(script.Parent.SensorCore)
local ObservationMemory = require(script.Parent.ObservationMemory)

local Contact = ObservationMemory.Contact

local Sensor = {}
Sensor.__index = Sensor

Sensor.SAMPLE_COUNT = 5
-- The sample points sit this share of a thing's radius off its centre.
Sensor.SAMPLE_SPREAD = 0.8
-- CPU time of the sensor tick in microseconds: a ring of the latest, for percentiles.
Sensor.COST_RING = 1200
-- T13a, the lateral eyes' motion sense (the spider-eye picture's shimmer): an entry stays this long after the thing was last seen moving.
Sensor.MOTION_HOLD_TICKS = 15

-- The observer the sensor reads (Godot: get_eye_position, get_gaze_direction, get_visual_up, get_heading_vector).
export type Observer = { eye: Vector3, gaze: Vector3, up: Vector3, heading: Vector3 }
-- The position of the first world hit on the segment from, to; nil when nothing of the world is in the way.
export type Cast = (Vector3, Vector3) -> Vector3?
-- What the last check of a thing found, for the developer view (Godot's Track.last_check): the fields appear as the check passes them.
export type Check = {
	inRange: boolean,
	distance: number,
	offAxisDeg: number?,
	visiblePoints: number?,
	inCone: boolean?,
	apparentDeg: number?,
}
-- T13a: a thing the eyes could see moving on its last check: the sensed direction from the eye, the distance, how big it looked, the tick.
export type Moving = { direction: Vector3, distance: number, apparent: number, tick: number }
export type TrackRow = {
	perceptId: string,
	trackId: string,
	exposureS: number,
	inRange: boolean?,
	distance: number?,
	offAxisDeg: number?,
	visiblePoints: number?,
	inCone: boolean?,
	apparentDeg: number?,
}

local EPS = 1e-6

-- Godot's Vector3.normalized(): a vector with no length stays zero.
local function normalized(v: Vector3): Vector3
	local m = v.Magnitude
	if m == 0 then
		return Vector3.zero
	end
	return v / m
end

function Sensor.new(memory: any, observerId: string?): any
	return setmetatable({
		memory = memory,
		core = SensorCore.new(memory, observerId),
		enabled = true,
		-- Statistics, for tests and the developer view.
		broadScans = 0,
		raysThisTick = 0,
		maxRaysInATick = 0,
		raysTotal = 0,
		checksThisTick = 0,
		checksTotal = 0,
		-- The memory-spot checks' rays (also counted in raysTotal); their number of checks is core.spotChecksTotal.
		spotRaysTotal = 0,
		-- CPU time of the ticks that did the work, microseconds: the total, the largest and a ring of the latest for percentiles.
		cpuUsTotal = 0,
		cpuTicks = 0,
		cpuUsMax = 0,
		-- What the observer's eyes, gaze and up were on the last tick (the developer view draws the cones from them).
		lastEye = Vector3.zero,
		lastAxis = Vector3.new(0, 0, -1),
		lastUp = Vector3.new(0, 1, 0),
		-- T13a, for the spider-eye picture only: nothing reads it to decide anything and it holds only what the sightline checks found.
		motionSeen = {} :: { [string]: Moving },
		_checks = {} :: { [string]: Check },
		_nextBroadTick = 0,
		_ring = {} :: { number },
		_costBase = 0,
	}, Sensor)
end

-- Takes the perception section of a species profile (Species.<id>.perception) and sets the memory's timing to match.
function Sensor.configureFrom(self: any, perception: { [string]: number })
	self.core:configureFrom(perception)
end

function Sensor.getTrack(self: any, perceptId: string): SensorCore.Track?
	return self.core:getTrack(perceptId)
end

-- The track a percept id is filed under, "" if it was never sensed. Tests and the developer view only.
function Sensor.trackIdFor(self: any, perceptId: string): string
	return self.core:trackIdFor(perceptId)
end

-- What the last check of a thing found (Godot: get_track(id).last_check); nil for a thing that has no track.
function Sensor.lastCheck(self: any, perceptId: string): Check?
	return self._checks[perceptId]
end

-- Forget everything about what is being tracked (the memory is cleared separately). The tick and the statistics go on.
function Sensor.reset(self: any)
	self.core:reset()
	self.motionSeen = {}
	self._checks = {}
	self._nextBroadTick = 0
end

-- ================================================================================================ the tick

-- One physics tick of the senses (Godot _physics_process): see the header for what the caller passes.
function Sensor.step(self: any, delta: number, observer: Observer, percepts: { SensorCore.Percept }, cast: Cast)
	self.raysThisTick = 0
	self.checksThisTick = 0
	if not self.enabled then
		return
	end
	local t0 = os.clock()
	local core = self.core
	local tick: number = core:beginTick(delta) -- the tick counts up and every track's gap since it was last inspected grows
	local eye, axis, up, forward = observer.eye, observer.gaze, observer.up, observer.heading
	self.lastEye, self.lastAxis, self.lastUp = eye, axis, up
	local broadDue = tick >= self._nextBroadTick
	if broadDue then
		self._nextBroadTick = tick + math.max(1, math.round(SensorCore.HZ / math.max(core.broadHz, 0.1)))
		self.broadScans += 1
	end
	local inspected: { SensorCore.Inspected } = {}
	local sightings: { SensorCore.Sighting } = {}
	local present: { [string]: boolean } = {}
	for _, p in percepts do
		present[p.id] = true
		local t = core:trackOf(p.id)
		local c: ObservationMemory.Contact? = if t.trackId ~= "" then core.memory:getContact(t.trackId) else nil
		local watching = c ~= nil and (c.state == Contact.LIVE or Contact.hasMark(c))
		if broadDue or watching or (p.position - eye).Magnitude <= core.closeRangeWu then
			self.checksThisTick += 1
			self.checksTotal += 1
			self:_sense(t, p, eye, axis, up, forward, cast, delta, inspected, sightings)
		end
	end
	core:fileSightings(sightings, delta)
	core:checkSpots(eye, axis, up, delta, inspected, function(from: Vector3, center: Vector3, radius: number, u: Vector3): boolean
		return self:_allVisible(cast, from, center, radius, u)
	end)
	core:endTick(present) -- the memory moves on to this tick, then the tracks of things that are no longer there go
	for id in self._checks do
		if not present[id] then
			self._checks[id] = nil
		end
	end
	for id, m in self.motionSeen do
		if not present[id] or tick - m.tick > Sensor.MOTION_HOLD_TICKS then
			self.motionSeen[id] = nil
		end
	end
	self.maxRaysInATick = math.max(self.maxRaysInATick, self.raysThisTick)
	self:_recordCost(math.floor((os.clock() - t0) * 1.0e6 + 0.5))
end

-- What the eyes make of one thing (Godot _sense): in range, inside the peripheral field, the sample points that could be seen, and then
-- either an inspection (in the cone and big enough to look at) or, if it moves, a cue.
function Sensor._sense(self: any, t: SensorCore.Track, p: SensorCore.Percept, eye: Vector3, axis: Vector3, up: Vector3, forward: Vector3, cast: Cast, delta: number, inspected: { SensorCore.Inspected }, sightings: { SensorCore.Sighting })
	local core = self.core
	local center = p.position
	local radius = math.max(p.radius, 0.01)
	local to = center - eye
	local dist = to.Magnitude
	local reach: number = core:reachWu()
	local check: Check = { inRange = dist <= reach, distance = dist }
	self._checks[p.id] = check
	if dist > reach or dist < SensorCore.MIN_DISTANCE then
		return
	end
	local dir = to / dist
	local offAxis = PerceptionMath.angleTo(axis, dir)
	check.offAxisDeg = math.deg(offAxis)
	if offAxis > math.rad(core.peripheralConeDeg) * 0.5 then
		return
	end
	local seen = self:_visiblePoints(cast, eye, center, radius, up)
	check.visiblePoints = #seen
	if #seen == 0 then
		return
	end
	local estimate = Vector3.zero
	for _, s in seen do
		estimate += s
	end
	estimate /= #seen
	local estDir = normalized(estimate - eye)
	local apparent = PerceptionMath.apparentSizeDeg(2.0 * radius, dist)
	local inCone = offAxis <= math.rad(core.coneDeg) * 0.5
	check.inCone = inCone
	check.apparentDeg = apparent
	local visibleFraction = #seen / Sensor.SAMPLE_COUNT
	local speed = p.velocity.Magnitude
	if speed >= core.motionMinSpeed then
		self.motionSeen[p.id] = { direction = estDir, distance = dist, apparent = apparent, tick = core.tick }
	end
	if inCone and apparent >= core.minApparentDeg then
		table.insert(sightings, { t = t, p = p, estimate = estimate, estDir = estDir, apparent = apparent, visibleFraction = visibleFraction })
		table.insert(inspected, { position = estimate, radius = radius })
	elseif speed >= core.motionMinSpeed and core.tick >= t.nextCueTick then
		core:cue(t, estDir, forward, up, dist)
	end
end

-- The sample points of a sphere of `radius` at `center` that the eye can see: the centre and four points a little off it, across the line of
-- sight and along it. An empty list means none could be seen.
function Sensor._visiblePoints(self: any, cast: Cast, eye: Vector3, center: Vector3, radius: number, up: Vector3): { Vector3 }
	local out: { Vector3 } = {}
	for _, s in Sensor.samplePoints(eye, center, radius, up) do
		if self:_clear(cast, eye, s, radius) then
			table.insert(out, s)
		end
	end
	return out
end

-- Godot _sample_points: the centre, then +side, -side, +vert, -vert at SAMPLE_SPREAD of the radius, side across the line of sight and
-- horizontal to the body (d x up; d x right when the thing is straight above or below) and vert across both.
function Sensor.samplePoints(eye: Vector3, center: Vector3, radius: number, up: Vector3): { Vector3 }
	local d = normalized(center - eye)
	local side = d:Cross(up)
	if side:Dot(side) < 1e-6 then
		side = d:Cross(Vector3.new(1, 0, 0))
	end
	side = normalized(side)
	local vert = normalized(side:Cross(d))
	local r = radius * Sensor.SAMPLE_SPREAD
	return { center, center + side * r, center - side * r, center + vert * r, center - vert * r }
end

-- True when the eye can see the sample point `to` of a thing of `radius`: the world stops the ray no further than a small allowance short of
-- it (PerceptionMath.sightTolerance, A-024). A world hit before the point is occlusion; it is not forgiven because the point is near. Every
-- ray is counted.
function Sensor._clear(self: any, cast: Cast, from: Vector3, to: Vector3, radius: number): boolean
	self.raysThisTick += 1
	self.raysTotal += 1
	local hit = cast(from, to)
	if hit == nil then
		return true
	end
	local length = (to - from).Magnitude
	return (hit - from).Magnitude >= length - PerceptionMath.sightTolerance(radius, length)
end

-- A remembered spot is called empty only when every sample point of it is in plain view (the first one the world hides ends the check).
-- The number of spot checks is counted by SensorCore.checkSpots; the rays they used are counted here and also in raysTotal.
function Sensor._allVisible(self: any, cast: Cast, eye: Vector3, center: Vector3, radius: number, up: Vector3): boolean
	local before: number = self.raysTotal
	local all = true
	for _, s in Sensor.samplePoints(eye, center, radius, up) do
		if not self:_clear(cast, eye, s, radius) then
			all = false
			break
		end
	end
	self.spotRaysTotal += self.raysTotal - before
	return all
end

-- ================================================================================================ questions

-- Whether the eye could sense a thing of `radius` at `center` right now: in range, inside the field of the peripheral eyes and at least one of
-- its sample points in plain view, which is exactly what a sensed thing has to pass. Changes no state of the senses; the rays are counted.
-- The prey population asks it before a replacement is let in (it must come in where the spider could not sense it).
function Sensor.couldSense(self: any, observer: Observer, center: Vector3, radius: number, cast: Cast): boolean
	local core = self.core
	local eye = observer.eye
	local to = center - eye
	local dist = to.Magnitude
	if dist > core:reachWu() then
		return false
	end
	if dist < SensorCore.MIN_DISTANCE then
		return true
	end
	if PerceptionMath.angleTo(observer.gaze, to / dist) > math.rad(core.peripheralConeDeg) * 0.5 then
		return false
	end
	return #self:_visiblePoints(cast, eye, center, math.max(radius, 0.01), observer.up) > 0
end

-- Developer view: what the last check of each thing found (distance, off-axis angle, how many points were seen, whether it was in the cone),
-- with the exposure so far. Truth-derived numbers, for developers only: nothing in the player's presentation reads this. Sorted by the
-- world's id.
function Sensor.describeTracks(self: any): { TrackRow }
	local core = self.core
	local out: { TrackRow } = {}
	for pid, t in core._tracks do
		local check: Check? = self._checks[pid]
		local row: TrackRow = {
			perceptId = pid,
			trackId = t.trackId,
			exposureS = if t.gapS <= core.graceS + EPS then t.exposure else 0.0,
		}
		if check ~= nil then
			row.inRange, row.distance, row.offAxisDeg = check.inRange, check.distance, check.offAxisDeg
			row.visiblePoints, row.inCone, row.apparentDeg = check.visiblePoints, check.inCone, check.apparentDeg
		end
		table.insert(out, row)
	end
	table.sort(out, function(a: TrackRow, b: TrackRow): boolean
		return a.perceptId < b.perceptId
	end)
	return out
end

-- ================================================================================================ cost

function Sensor._recordCost(self: any, us: number)
	self.cpuUsTotal += us
	self.cpuUsMax = math.max(self.cpuUsMax, us)
	self._ring[self.cpuTicks % Sensor.COST_RING + 1] = us
	self.cpuTicks += 1
end

-- Ticks measured since the window began (the start of the run, or the last resetCost()).
function Sensor.costTicks(self: any): number
	return self.cpuTicks - self._costBase
end

-- Percentile of the latest measured sensor ticks (since the window began), in microseconds.
function Sensor.costPercentile(self: any, q: number): number
	local n = math.min(self:costTicks(), Sensor.COST_RING)
	if n <= 0 then
		return 0
	end
	local xs: { number } = {}
	for i = 0, n - 1 do
		table.insert(xs, self._ring[(self.cpuTicks - 1 - i) % Sensor.COST_RING + 1])
	end
	table.sort(xs)
	return xs[math.clamp(math.ceil(q * n), 1, n)]
end

-- Begins a new measuring window (the totals, the largest and the percentiles start again).
function Sensor.resetCost(self: any)
	self.cpuUsTotal = 0
	self.cpuUsMax = 0
	self._costBase = self.cpuTicks
end

-- ================================================================================================ the engine's rays

-- A cast made of the engine's raycast: the position of the first hit on the segment, nil when it is clear. The caller decides what the rays
-- may meet in `params` (the sill: not the spider, not the things sensed, not anything drawn only).
function Sensor.workspaceCast(params: RaycastParams): Cast
	return function(from: Vector3, to: Vector3): Vector3?
		local hit = workspace:Raycast(from, to - from, params)
		return if hit ~= nil then hit.Position else nil
	end
end

return Sensor
