--!strict
-- SensorCore: the half of Godot's SensorSystem (scripts/perception/sensor_system.gd, c87ce00) that needs no world. The sensor turns world
-- truth into evidence and nothing more; this is what it does with the evidence once the eye has found it: which contact a sighting is filed
-- under (continuous sight, a lost contact it can only be, or a fresh one), how long a thing has been in view and so how finely it can be
-- classified, the peripheral cue, and the looking at remembered spots that drops a mark when the place is seen empty. Ported method for
-- method from _is_linked, _cue_contact, _file_sightings, _placed_and_unbroken, _inspection_contact, _lost_candidates, _inspect, _cue,
-- _check_spots, _forget_gone and the head and tail of _physics_process. NOT here (the next part of the port): the rays that decide what
-- was in plain view (_sense, _visible_points, _clear, _sample_points), the eye and gaze, the broad scan and its rates, Focus, the
-- developer overlay and the motion shimmer. Capture (on_capture) belongs to the feeding chunk. A caller does what _physics_process does:
--
--   core:beginTick(delta)                      -- tick += 1, every track's gap grows by delta
--   core:trackOf(id)                           -- once per percept that exists, sighted or not (creates its track)
--   core:cue(...)                              -- for each thing that gave a peripheral cue this tick
--   core:fileSightings(sightings, delta)       -- all of the tick's inspections together (the association rule needs them together)
--   core:checkSpots(eye, axis, up, delta, inspected, allVisible)
--   core:endTick(present)                      -- memory:advance(tick), then forget the tracks of things that left the world
--
-- Who is who (A-027, D-040). Three things are kept apart. The world's id for a thing is how the sensor finds it again each tick (the key of
-- _tracks); it is never the spider's idea of who the thing is. A contact (the memory's track id) is the spider's hypothesis that some
-- observations are of one visible thing. Familiarity is what earlier exposure to a contact taught, kept per contact (_kept) and faded with
-- the memory of it. A thing's evidence stays under one contact while sight of it is unbroken: the contact is live and the thing itself was
-- filed under it within the memory's hold time for that kind of evidence. Once sight has been lost the world id decides nothing: a new
-- inspection is compared with the lost contacts by where each was last observed, how long ago, how big it looked, what it can look like and
-- how fast it was seen moving, and is taken for a lost contact only when exactly one of them could be it and no other thing sighted in the
-- same tick could be it either (two look-alikes that come into view together are two fresh contacts, and the order the world lists them in
-- decides nothing); otherwise it is a fresh contact that starts again at "movement" and inherits no exposure. A bare cue has no place to
-- compare, so it is always a weak new contact; the inspection that follows it makes the comparison, and a cue-only contact that turns out
-- to be a lost one is folded into it.
local Observation = require(script.Parent.Observation)
local PerceptionMath = require(script.Parent.PerceptionMath)
local Signal = require(script.Parent.Signal)
local ObservationMemory = require(script.Parent.ObservationMemory)

local Contact = ObservationMemory.Contact
local EPS = 1e-6

local SensorCore = {}
SensorCore.__index = SensorCore

-- One game clock: the senses count in its ticks (SimClock.HZ), never in the engine's rate.
SensorCore.HZ = 60
SensorCore.MIN_DISTANCE = 0.05

-- What the sensor keeps for each thing it can sense, under the world's id for it. It is the channel to a visible thing, not an identity.
export type Track = {
	perceptId: string,
	-- The contact this thing's evidence is filed under while sight of it is unbroken. "" until the first observation (only a thing that has
	-- been sensed has one); it is replaced, not trusted, once sight of the thing has been lost.
	trackId: string,
	-- The tick of the last evidence of this thing that was filed under that contact.
	linkTick: number,
	-- Continuous exposure in the cone, seconds.
	exposure: number,
	-- Seconds since the last inspected tick.
	gapS: number,
	nextCueTick: number,
}

-- What may be sensed: the world's truth about a thing, which only the eye reads (Godot's Perceivable percept).
export type Percept = {
	id: string,
	position: Vector3,
	radius: number,
	velocity: Vector3,
	-- The finest category its appearance can ever be refined to (fly-like prey for something that looks like easy prey up close, movement
	-- for something that never looks like more). nil is fly-like prey.
	maxCategory: string?,
}

-- One thing in the inspection cone this tick, as the eye made it: where it was seen (the mean of the sample points in plain view), the
-- direction to there, how big it looked and how much of it was in view.
export type Sighting = {
	t: Track,
	p: Percept,
	estimate: Vector3,
	estDir: Vector3,
	apparent: number,
	visibleFraction: number,
	match: string?,
	candidates: { string }?,
}

-- A thing inspected this tick (position and radius), which the spot checks must not call an empty place.
export type Inspected = { position: Vector3, radius: number }

function SensorCore.new(memory: any, observerId: string?): any
	return setmetatable({
		memory = memory,
		observerId = observerId or "spider",
		-- Parameters: the species profile's perception section (configureFrom). The defaults are Godot's.
		coneDeg = 30.0,
		peripheralConeDeg = 300.0,
		sectorDeg = 22.5,
		rangeWu = 40.0,
		-- How far the eyes reach now, as a share of rangeWu (1 in daylight; the life clock lowers it at night).
		rangeScale = 1.0,
		easyS = 0.4,
		flyS = 1.0,
		easyApparentDeg = 3.0,
		minApparentDeg = 0.6,
		motionMinSpeed = 0.3,
		cueCooldownS = 0.8,
		broadHz = 10.0,
		closeRangeWu = 4.0,
		graceS = 0.15,
		decayS = 6.0,
		-- The association rule (A-027): the assumed top speed of anything unseen, and the size ratio that still counts as one thing.
		contactSpeedBound = 2.0,
		contactSizeRatio = 1.5,
		-- Statistics, for tests and the developer overlay.
		tick = 0,
		inspectionsMade = 0,
		cuesMade = 0,
		spotChecksTotal = 0,
		-- Emitted for every peripheral cue made (after the cooldown), for tests and the developer view.
		cueEmitted = Signal.new(),
		_tracks = {} :: { [string]: Track },
		_serial = 0,
		_spots = {} :: { [string]: { exposure: number, gap: number } },
		_kept = {} :: { [string]: number }, -- track id -> continuous exposure the contact had when sight of it last ended
	}, SensorCore)
end

-- Takes the perception section of a species profile (spec 21.1: Species.<id>.perception, snake_case as in the data) and sets the memory's
-- timing to match.
function SensorCore.configureFrom(self: any, p: { [string]: number })
	self.coneDeg = p.inspect_cone_degrees
	self.peripheralConeDeg = p.peripheral_cone_degrees
	self.sectorDeg = p.peripheral_sector_degrees
	self.rangeWu = p.sensor_range_wu
	self.easyS = p.easy_target_inspection_s
	self.flyS = p.fly_like_inspection_s
	self.easyApparentDeg = p.easy_apparent_size_deg
	self.minApparentDeg = p.min_apparent_size_deg
	self.motionMinSpeed = p.motion_min_speed_wu_s
	self.cueCooldownS = p.cue_cooldown_s
	self.broadHz = p.broad_query_hz
	self.closeRangeWu = p.close_check_range_wu
	self.graceS = p.exposure_grace_s
	self.decayS = p.memory_decay_s
	self.contactSpeedBound = p.contact_speed_bound_wu_s
	self.contactSizeRatio = p.contact_size_ratio
	if self.memory ~= nil then
		self:applyToMemory()
	end
end

-- The memory's timing follows the sensor's: a cue repeats every cooldown, so a peripheral contact is held a little longer than that; an
-- inspection comes every tick, so it is held for the exposure grace.
function SensorCore.applyToMemory(self: any)
	self.memory:configure(SensorCore.HZ, self.decayS, self.graceS, self.cueCooldownS + 0.2)
end

-- The range every check uses.
function SensorCore.reachWu(self: any): number
	return self.rangeWu * math.clamp(self.rangeScale, 0.0, 1.0)
end

function SensorCore.getTrack(self: any, perceptId: string): Track?
	return self._tracks[perceptId]
end

-- The track a percept id is filed under, "" if it was never sensed. Tests and the developer overlay only.
function SensorCore.trackIdFor(self: any, perceptId: string): string
	local t: Track? = self._tracks[perceptId]
	return if t == nil then "" else t.trackId
end

-- Forget everything about what is being tracked (the memory is cleared separately).
function SensorCore.reset(self: any)
	self._tracks = {}
	self._spots = {}
	self._kept = {}
end

function SensorCore.trackOf(self: any, perceptId: string): Track
	local t: Track? = self._tracks[perceptId]
	if t == nil then
		t = {
			perceptId = perceptId,
			trackId = "",
			linkTick = -1000000,
			exposure = 0.0,
			gapS = 1.0e9,
			nextCueTick = 0,
		}
		self._tracks[perceptId] = t
	end
	return t :: Track
end

-- The head of a physics tick: the clock moves on and every track's gap since it was last inspected grows. Returns the tick.
function SensorCore.beginTick(self: any, delta: number): number
	self.tick += 1
	for _, t in self._tracks do
		t.gapS += delta
	end
	return self.tick
end

-- The tail of a physics tick: the memory moves on to this tick, then the tracks of things that are no longer there are dropped.
function SensorCore.endTick(self: any, present: { [string]: boolean })
	self.memory:advance(self.tick)
	self:forgetGone(present)
end

-- Lifecycle (A-029): a thing that is no longer there to be sensed (its node left the world, or it gives no percept) loses its entry; the
-- contacts it made are not touched, they fade and expire on their own clocks. Exposure kept for a contact that is gone goes too.
function SensorCore.forgetGone(self: any, present: { [string]: boolean })
	for pid in self._tracks do
		if not present[pid] then
			self._tracks[pid] = nil
		end
	end
	for id in self._kept do
		if self.memory:getContact(id) == nil then
			self._kept[id] = nil
		end
	end
end

-- A new contact for a thing, with an opaque id; the thing is filed under it from now on.
function SensorCore.newContactFor(self: any, t: Track): string
	self._serial += 1
	t.trackId = `trk_{self._serial}`
	return t.trackId
end

-- True while this thing's evidence is a continuation of the contact it was last filed under (A-027): that contact is live and the thing
-- itself was filed under it within the memory's hold time for that kind of evidence. Sight that was lost for longer is not unbroken,
-- whatever the world's id says, and neither is sight of a thing whose contact someone else kept alive.
function SensorCore.isLinked(self: any, t: Track): boolean
	if t.trackId == "" then
		return false
	end
	local c: ObservationMemory.Contact? = self.memory:getContact(t.trackId)
	return c ~= nil and c.state == Contact.LIVE and self.tick - t.linkTick <= self.memory:holdTicks(c.modality)
end

-- The contact a cue is filed under: the one the thing is unbrokenly filed under, else a new one (a bearing cannot say which remembered
-- place this is).
function SensorCore.cueContact(self: any, t: Track): string
	return if self:isLinked(t) then t.trackId else self:newContactFor(t)
end

-- The sightings of this tick that are first looks after a loss of sight (or at a thing known only from cues) are compared with the lost
-- contacts together, not one after the other (A-027): a lost contact is taken by a sighting only when it is that sighting's one candidate
-- and no other sighting of the tick could be it either. Two look-alikes that come into view at once, both inside the region one lost contact
-- could have reached, are two fresh contacts, whichever of them the sensor happens to handle first; and the order the world lists its
-- things in, like the world's ids, decides nothing. Then each sighting is filed.
function SensorCore.fileSightings(self: any, sightings: { Sighting }, delta: number)
	if #sightings == 0 then
		return
	end
	local claims: { [string]: number } = {} -- lost contact id -> how many sightings of this tick could be it
	for _, s in sightings do
		s.match = ""
		s.candidates = {}
		if self:placedAndUnbroken(s.t) then
			continue
		end
		local found = self:lostCandidates(s.estimate, 2.0 * s.p.radius, s.p.maxCategory or Observation.FLY_LIKE_PREY)
		s.candidates = found
		for _, id in found do
			claims[id] = (claims[id] or 0) + 1
		end
	end
	for _, s in sightings do
		local found = s.candidates :: { string }
		if #found == 1 and claims[found[1]] == 1 then
			s.match = found[1]
		end
	end
	for _, s in sightings do
		self:inspect(s.t, s.p, s.estimate, s.estDir, s.apparent, s.visibleFraction, delta, s.match :: string)
	end
end

-- True while the thing's evidence is a continuation of a contact that already has a place: nothing to compare.
function SensorCore.placedAndUnbroken(self: any, t: Track): boolean
	return self:isLinked(t) and self.memory:getContact(t.trackId).hasPosition
end

-- The contact an inspection is filed under (A-027). Unbroken sight of a thing already being inspected: the same contact. Otherwise this is
-- the first inspection after a loss of sight, or of a thing known only from cues: if the comparison made with the other sightings of the
-- tick (fileSightings) found exactly one lost contact it could be, it is that one (a contact known only from cues is folded into it); if it
-- found none, or more than one, it is the contact the cues made or a new one, with nothing carried over.
function SensorCore.inspectionContact(self: any, t: Track, matched: string): string
	local linked = self:isLinked(t)
	if linked and self.memory:getContact(t.trackId).hasPosition then
		return t.trackId
	end
	if matched ~= "" then
		if linked then
			self.memory:merge(t.trackId, matched)
		end
		t.trackId = matched
		return matched
	end
	return if linked then t.trackId else self:newContactFor(t)
end

-- The lost contacts a new sighting could be (their track ids; empty when none). A contact could be it when the sighting is inside the region
-- its thing could have reached since it was last observed (a function of the time and the speed bound, never of where the thing went),
-- looks about as big, and is not finer in appearance than what was learned. Only a focused sighting is ever asked: a bearing cue says
-- nothing about which remembered place this is.
function SensorCore.lostCandidates(self: any, estimate: Vector3, sizeWu: number, cap: string): { string }
	local found: { string } = {}
	for _, m in self.memory:marks() do
		local elapsed = (self.tick - m.positionTick) / SensorCore.HZ
		local reach = PerceptionMath.plausibleRadius(m.sizeWu, sizeWu, elapsed, self.contactSpeedBound, m.speedWuS)
		if (estimate - m.position).Magnitude > reach then
			continue
		end
		if not PerceptionMath.sizesCompatible(m.sizeWu, sizeWu, self.contactSizeRatio) then
			continue
		end
		if not PerceptionMath.categoriesCompatible(m.category, cap) then
			continue
		end
		table.insert(found, m.trackId)
	end
	return found
end

-- One inspection of a thing in the cone: its exposure (a new stretch after a break longer than the grace starts from what the contact it
-- belongs to was taught, as much as the memory of it lasts), the category that exposure supports (never finer than the thing can look),
-- and the Observation the memory takes in.
function SensorCore.inspect(self: any, t: Track, p: Percept, estimate: Vector3, estDir: Vector3, apparent: number, visibleFraction: number, delta: number, matched: string)
	local cap = p.maxCategory or Observation.FLY_LIKE_PREY
	local id: string = self:inspectionContact(t, matched)
	if t.gapS > self.graceS + EPS then
		-- A new stretch of exposure. What an earlier one taught the contact it belongs to still counts, as much as the memory of it does: a
		-- new contact has been taught nothing.
		t.exposure = (self._kept[id] or 0.0) * self.memory:familiarity(id)
	end
	t.exposure += delta
	self._kept[id] = t.exposure
	t.gapS = 0.0
	local category = PerceptionMath.classify(t.exposure, apparent, self.easyS, self.flyS, self.easyApparentDeg, self.minApparentDeg)
	if Observation.rank(category) > Observation.rank(cap) then
		category = cap
	end
	local obs = Observation.new()
	obs.observerId = self.observerId
	obs.trackId = id
	obs.targetId = if Observation.rank(category) >= Observation.rank(Observation.POSSIBLE_PREY) then p.id else ""
	obs.modality = Observation.INSPECTION
	obs.hasPosition = true
	obs.estimatedPosition = estimate
	obs.direction = estDir
	obs.confidence = PerceptionMath.inspectionConfidence(t.exposure, PerceptionMath.requiredExposure(self.flyS, apparent, self.easyApparentDeg), visibleFraction)
	obs.observedTick = self.tick
	obs.category = category
	obs.sizeWu = 2.0 * p.radius
	obs.apparentSizeDeg = apparent
	obs.speedWuS = p.velocity.Magnitude
	if self.memory:ingest(obs) ~= nil then
		self.inspectionsMade += 1
		t.linkTick = self.tick
	end
end

-- A peripheral cue: a coarse bearing, low confidence, and nothing else. The caller has already decided that the thing moves, is in the
-- field and in sight, and that `self.tick >= t.nextCueTick` (at most one cue per cooldown for each thing).
function SensorCore.cue(self: any, t: Track, estDir: Vector3, forward: Vector3, up: Vector3, dist: number)
	t.nextCueTick = self.tick + math.round(self.cueCooldownS * SensorCore.HZ)
	local obs = Observation.new()
	obs.observerId = self.observerId
	obs.trackId = self:cueContact(t)
	obs.modality = Observation.PERIPHERAL
	obs.hasPosition = false
	obs.direction = PerceptionMath.quantizeDirection(estDir, forward, up, self.sectorDeg)
	obs.confidence = PerceptionMath.peripheralConfidence(dist, self:reachWu())
	obs.observedTick = self.tick
	obs.category = Observation.MOVEMENT
	if self.memory:ingest(obs) ~= nil then
		self.cuesMade += 1
		t.linkTick = self.tick
		self.cueEmitted:emit(obs)
	end
end

-- The remembered spots of lost contacts: inspecting one that is in plain view and empty drops its mark. A spot is looked at when it is in
-- the cone, close enough that the thing would look big enough, and entirely in plain view (`allVisible(eye, position, radius, up)`: the
-- rays, which the world half supplies) with nothing inspected there this tick; it must be looked at for the time an easy target needs
-- (a break up to the grace does not start it again).
function SensorCore.checkSpots(self: any, eye: Vector3, axis: Vector3, up: Vector3, delta: number, inspected: { Inspected }, allVisible: (Vector3, Vector3, number, Vector3) -> boolean)
	local half = math.rad(self.coneDeg) * 0.5
	local marks: { ObservationMemory.Contact } = self.memory:marks()
	for id in self._spots do
		local still = false
		for _, m in marks do
			if m.trackId == id then
				still = true
			end
		end
		if not still then
			self._spots[id] = nil
		end
	end
	for _, m in marks do
		local st = self._spots[m.trackId] or { exposure = 0.0, gap = 1.0e9 }
		st.gap += delta
		local to = m.position - eye
		local dist = to.Magnitude
		local size = math.max(m.sizeWu, 0.2)
		local apparent = PerceptionMath.apparentSizeDeg(size, dist)
		local plain = false
		if dist >= SensorCore.MIN_DISTANCE and dist <= self:reachWu() and PerceptionMath.angleTo(axis, to / dist) <= half and apparent >= self.minApparentDeg then
			self.spotChecksTotal += 1
			plain = allVisible(eye, m.position, size * 0.5, up)
			if plain then
				for _, q in inspected do
					if (q.position - m.position).Magnitude < size + q.radius then
						plain = false -- something is there: not an empty spot
					end
				end
			end
		end
		if plain then
			if st.gap > self.graceS + EPS then
				st.exposure = 0.0
			end
			st.exposure += delta
			st.gap = 0.0
			if st.exposure + EPS >= PerceptionMath.requiredExposure(self.easyS, apparent, self.easyApparentDeg) then
				self.memory:invalidate(m.trackId, "empty")
				self._spots[m.trackId] = nil
				continue
			end
		end
		self._spots[m.trackId] = st
	end
end

return SensorCore
