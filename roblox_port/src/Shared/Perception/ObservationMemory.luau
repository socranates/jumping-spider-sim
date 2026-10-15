--!strict
-- ObservationMemory (spec 7, 21.3): what the observer remembers of what it sensed. A port of the frozen Godot
-- scripts/perception/observation_memory.gd (c87ce00), method for method. The sensor hands it Observation records; it keeps one Contact
-- per thing the sensor keeps sensing (a "track"), ages them, and says what is still sensed, what has been lost and what has gone. It
-- never looks at the world: a contact changes only when an observation arrives, when time passes, or when the sensor reports that the
-- remembered spot was inspected and is empty.
--
-- A contact is LIVE while observations keep coming (a peripheral cue repeats every cue cooldown, an inspection every tick) and LOST once
-- none has arrived for the hold time of its modality. A lost contact's confidence falls in a straight line from what it was at the loss to
-- nothing over `decayS` (6 s), and the contact is forgotten at that point. A lost contact that was inspected has a mark (A-002): its last
-- observed position, which never moves, because the only thing that can move a position is a new inspection.
--
-- Which contact an observation belongs to is the sensor's decision, taken from evidence (A-027, D-040): a contact is the spider's
-- hypothesis that some observations are of one visible thing, not the thing's identity in the world. The memory only keeps what it is
-- told, and can fold a contact it knew only from cues into the lost contact it turned out to be (merge). The world id of a thing it is
-- looking at is kept on the contact for as long as sight lasts (targetId) and dropped the moment sight is lost.
--
-- What a peripheral cue may and may not do (spec 7: coarse directional evidence, no label): it starts a contact, and it keeps a contact
-- that is only cues alive. It never gives a position, never changes the category, the confidence or the position of a contact that has
-- been inspected, and never brings an inspected contact back from lost: that takes another inspection (a reacquisition). What the cue
-- did say, a bearing, is kept apart (cueTick, cueDirection) for the presentation's edge markers.
--
-- Differences from Godot that change no decision: the five signals are Signal objects (memory.contactAcquired:connect(fn)); contacts
-- are walked oldest first (creation order) wherever Godot walks a dictionary, so announcements come in a fixed order.
local Observation = require(script.Parent.Observation)
local PerceptionMath = require(script.Parent.PerceptionMath)
local Signal = require(script.Parent.Signal)

local PERIPHERAL, INSPECTION = Observation.PERIPHERAL, Observation.INSPECTION

-- =============================================================================================== Contact

local Contact = {}
Contact.__index = Contact
Contact.LIVE = "live"
Contact.LOST = "lost"

export type Contact = {
	trackId: string,
	observerId: string,
	-- The world id of the thing this contact is live-linked to (spec 21.3: target, only when resolved), for validated interaction and
	-- nothing else. Set while an inspection has resolved the thing, dropped the moment the contact is lost, and never used to decide
	-- which contact an observation belongs to (A-027).
	targetId: string,
	state: string,
	-- Modality of the latest evidence that updated the record (a cue on an inspected contact does not).
	modality: string,
	category: string,
	-- What the contact is believed to be worth now: the latest evidence's while live, falling after a loss.
	confidence: number,
	confidenceAtLoss: number,
	-- The last observed position: only an inspection gives one, and only another inspection changes it.
	hasPosition: boolean,
	position: Vector3,
	positionTick: number,
	sizeWu: number,
	apparentSizeDeg: number,
	-- How fast it was seen moving at the last inspection, WU/s.
	speedWuS: number,
	-- Latest direction from the observer of the evidence that updated the record (coarse for a cue).
	direction: Vector3,
	firstTick: number,
	-- Tick of the latest evidence that updated the record.
	observedTick: number,
	-- The latest peripheral cue, apart from the record: its tick, its coarse bearing and how many there have been.
	cueTick: number,
	cueDirection: Vector3,
	cueCount: number,
	lostTick: number,
	reacquisitions: number,
	-- False once the mark was found to be wrong (the spot was inspected and is empty).
	markValid: boolean,
	-- Creation order: "oldest first" breaks ties with it.
	seq: number,
}

function Contact.new(): Contact
	return setmetatable({
		trackId = "",
		observerId = "",
		targetId = "",
		state = Contact.LIVE,
		modality = PERIPHERAL,
		category = Observation.MOVEMENT,
		confidence = 0.0,
		confidenceAtLoss = 0.0,
		hasPosition = false,
		position = Vector3.zero,
		positionTick = 0,
		sizeWu = 0.0,
		apparentSizeDeg = 0.0,
		speedWuS = 0.0,
		direction = Vector3.new(0, 0, -1),
		firstTick = 0,
		observedTick = 0,
		cueTick = -1000000,
		cueDirection = Vector3.zero,
		cueCount = 0,
		lostTick = 0,
		reacquisitions = 0,
		markValid = true,
		seq = 0,
	}, Contact) :: any
end

function Contact.isLive(c: Contact): boolean
	return c.state == Contact.LIVE
end

-- Live and being inspected: the position is where it is being seen now.
function Contact.isInspectedNow(c: Contact): boolean
	return c.state == Contact.LIVE and c.modality == INSPECTION
end

function Contact.hasMark(c: Contact): boolean
	return c.state == Contact.LOST and c.hasPosition and c.markValid
end

function Contact.toDict(c: Contact): { [string]: any }
	return {
		trackId = c.trackId,
		targetId = c.targetId,
		state = c.state,
		modality = c.modality,
		category = c.category,
		confidence = c.confidence,
		hasPosition = c.hasPosition,
		position = if c.hasPosition then c.position else nil,
		observedTick = c.observedTick,
		positionTick = c.positionTick,
		lostTick = c.lostTick,
	}
end

-- =============================================================================================== Memory

local ObservationMemory = {}
ObservationMemory.__index = ObservationMemory
ObservationMemory.Contact = Contact

export type ObservationMemory = {
	-- Ticks a second lasts (the physics rate), the seconds a lost contact's confidence takes to fall to nothing, and how long a contact
	-- may go without new evidence before it counts as lost.
	hz: number,
	decayS: number,
	holdInspectionS: number,
	holdPeripheralS: number,
	-- The tick the memory was last advanced to.
	nowTick: number,
	-- How many observations were ever ingested, by modality; for tests and the debug view.
	ingested: number,
	ingestedInspection: number,
	ingestedPeripheral: number,
	-- A new contact, or a track picked up again after it had been forgotten.
	contactAcquired: Signal.Signal,
	-- (contact, oldCategory, newCategory): the category a contact is believed to be refined (up) or fell back (down).
	categoryChanged: Signal.Signal,
	-- Sight of a contact ended: its hold time ran out with no new observation.
	contactLost: Signal.Signal,
	-- A lost contact was observed again: the same track, its record updated.
	contactReacquired: Signal.Signal,
	-- (contact, reason): a contact left the memory: "expired" (its confidence reached nothing), "empty" (the sensor inspected the
	-- remembered spot and found nothing there), "merged" (a contact known only from cues turned out to be a lost one) or "captured".
	contactEnded: Signal.Signal,
	_contacts: { [string]: Contact },
	_seq: number,
}

function ObservationMemory.new(): any
	return setmetatable({
		hz = 60.0,
		decayS = 6.0,
		holdInspectionS = 0.15,
		holdPeripheralS = 1.0,
		nowTick = 0,
		ingested = 0,
		ingestedInspection = 0,
		ingestedPeripheral = 0,
		contactAcquired = Signal.new(),
		categoryChanged = Signal.new(),
		contactLost = Signal.new(),
		contactReacquired = Signal.new(),
		contactEnded = Signal.new(),
		_contacts = {},
		_seq = 0,
	}, ObservationMemory)
end

function ObservationMemory.configure(self: any, hz: number, decayS: number, holdInspectionS: number, holdPeripheralS: number)
	self.hz = math.max(hz, 1.0)
	self.decayS = math.max(decayS, 0.01)
	self.holdInspectionS = math.max(holdInspectionS, 0.0)
	self.holdPeripheralS = math.max(holdPeripheralS, 0.0)
end

function ObservationMemory.clear(self: any)
	self._contacts = {}
end

function ObservationMemory.getContact(self: any, trackId: string): Contact?
	return self._contacts[trackId]
end

function ObservationMemory.count(self: any): number
	local n = 0
	for _ in self._contacts do
		n += 1
	end
	return n
end

-- Every contact, oldest first.
function ObservationMemory.contacts(self: any): { Contact }
	local out: { Contact } = {}
	for _, c in self._contacts do
		table.insert(out, c)
	end
	table.sort(out, function(a: Contact, b: Contact): boolean
		if a.firstTick ~= b.firstTick then
			return a.firstTick < b.firstTick
		end
		return a.seq < b.seq
	end)
	return out
end

local function filtered(list: { Contact }, keep: (Contact) -> boolean): { Contact }
	local out: { Contact } = {}
	for _, c in list do
		if keep(c) then
			table.insert(out, c)
		end
	end
	return out
end

function ObservationMemory.liveContacts(self: any): { Contact }
	return filtered(self:contacts(), function(c) return c.state == Contact.LIVE end)
end

function ObservationMemory.lostContacts(self: any): { Contact }
	return filtered(self:contacts(), function(c) return c.state == Contact.LOST end)
end

-- Lost contacts that were inspected and whose spot has not been found empty: the last-seen marks.
function ObservationMemory.marks(self: any): { Contact }
	return filtered(self:contacts(), function(c) return Contact.hasMark(c) end)
end

-- Seconds since sight of a lost contact ended; 0 for a live one.
function ObservationMemory.ageS(self: any, c: Contact): number
	if c.state == Contact.LIVE then
		return 0.0
	end
	return (self.nowTick - c.lostTick) / self.hz
end

-- How much of a thing's earlier inspection still counts if it is seen again: 1 for a live contact, falling to 0 as the memory of a lost one
-- fades, 0 for a track that is gone.
function ObservationMemory.familiarity(self: any, trackId: string): number
	local c = self._contacts[trackId]
	if c == nil then
		return 0.0
	end
	if c.state == Contact.LIVE then
		return 1.0
	end
	return PerceptionMath.decayedConfidence(1.0, self:ageS(c), self.decayS)
end

-- Seconds since the evidence that last updated the record.
function ObservationMemory.observedAgeS(self: any, c: Contact): number
	return (self.nowTick - c.observedTick) / self.hz
end

-- Seconds since the latest peripheral cue (a very large number if there never was one).
function ObservationMemory.cueAgeS(self: any, c: Contact): number
	return (self.nowTick - c.cueTick) / self.hz
end

-- 0 for a live contact and for one just lost, 1 when its memory is gone (the mark is at its stalest).
function ObservationMemory.stalenessOf(self: any, c: Contact): number
	if c.state == Contact.LIVE then
		return 0.0
	end
	return PerceptionMath.staleness(self:ageS(c), self.decayS)
end

-- Ticks a contact may go without evidence of this modality before it counts as lost. The sensor reads the same number to tell unbroken
-- sight (the thing is still the same contact) from sight that was lost.
function ObservationMemory.holdTicks(self: any, modality: string): number
	return math.round((if modality == INSPECTION then self.holdInspectionS else self.holdPeripheralS) * self.hz)
end

-- Take in one observation. A record that is not valid (spec 21.3) is refused and returns nil.
function ObservationMemory.ingest(self: any, obs: Observation.Observation?): Contact?
	if obs == nil or not Observation.isValid(obs) then
		return nil
	end
	self.ingested += 1
	local existing: Contact? = self._contacts[obs.trackId]
	local fresh = existing == nil
	local wasLost = false
	local c: Contact
	if existing == nil then
		c = Contact.new()
		c.trackId = obs.trackId
		c.observerId = obs.observerId
		c.firstTick = obs.observedTick
		c.category = obs.category
		self._seq += 1
		c.seq = self._seq
		self._contacts[c.trackId] = c
	else
		c = existing
		wasLost = c.state == Contact.LOST
	end
	if obs.modality == PERIPHERAL then
		self.ingestedPeripheral += 1
		c.cueTick = obs.observedTick
		c.cueDirection = obs.direction
		c.cueCount += 1
		if not fresh and c.hasPosition then
			return c -- a bearing says nothing new about something that was inspected (see the header)
		end
	end
	local oldCategory = c.category
	c.state = Contact.LIVE
	c.modality = obs.modality
	c.confidence = obs.confidence
	c.observedTick = obs.observedTick
	c.direction = obs.direction
	if obs.targetId ~= "" then
		c.targetId = obs.targetId
	end
	if obs.modality == INSPECTION then
		self.ingestedInspection += 1
		c.hasPosition = true
		c.position = obs.estimatedPosition
		c.positionTick = obs.observedTick
		c.sizeWu = obs.sizeWu
		c.apparentSizeDeg = obs.apparentSizeDeg
		c.speedWuS = obs.speedWuS
		c.markValid = true
		c.category = obs.category
	end
	if fresh then
		self.contactAcquired:emit(c)
	elseif wasLost then
		c.reacquisitions += 1
		self.contactReacquired:emit(c)
	end
	if c.category ~= oldCategory then
		self.categoryChanged:emit(c, oldCategory, c.category)
	end
	return c
end

-- The ids of the contacts, oldest first (the order Godot's dictionary keeps them in).
local function orderedIds(self: any): { string }
	local list: { Contact } = {}
	for _, c in self._contacts do
		table.insert(list, c)
	end
	table.sort(list, function(a: Contact, b: Contact): boolean
		return a.seq < b.seq
	end)
	local ids: { string } = {}
	for _, c in list do
		table.insert(ids, c.trackId)
	end
	return ids
end

-- Moves time on to `tick`: live contacts that have had no evidence for their hold time become lost, lost contacts lose confidence, and
-- those with none left are forgotten.
function ObservationMemory.advance(self: any, tick: number)
	self.nowTick = tick
	for _, id in orderedIds(self) do
		local c: Contact? = self._contacts[id]
		if c == nil then
			continue
		end
		if c.state == Contact.LIVE then
			if tick - c.observedTick > self:holdTicks(c.modality) then
				c.state = Contact.LOST
				c.lostTick = tick
				c.confidenceAtLoss = c.confidence
				c.targetId = "" -- sight is over: the link to the world goes with it
				self.contactLost:emit(c)
			end
		end
		if c.state == Contact.LOST then
			local age = (tick - c.lostTick) / self.hz
			c.confidence = PerceptionMath.decayedConfidence(c.confidenceAtLoss, age, self.decayS)
			if age >= self.decayS - 1e-9 then
				self._contacts[id] = nil
				self.contactEnded:emit(c, "expired")
			end
		end
	end
end

-- The sensor found that a contact it knew only from cues (it has no position) is the lost contact `intoId`, seen again: the bearing of
-- the latest cue and the count of cues go to that record, and the cue-only contact is dropped (reason "merged"). Returns false when either
-- is missing or the one to fold has a position of its own (an inspected contact is never folded into another).
function ObservationMemory.merge(self: any, fromId: string, intoId: string): boolean
	local a: Contact? = self._contacts[fromId]
	local b: Contact? = self._contacts[intoId]
	if a == nil or b == nil or a == b or a.hasPosition then
		return false
	end
	if a.cueTick > b.cueTick then
		b.cueTick = a.cueTick
		b.cueDirection = a.cueDirection
	end
	b.cueCount += a.cueCount
	self._contacts[fromId] = nil
	self.contactEnded:emit(a, "merged")
	return true
end

-- The sensor looked at a lost contact's last observed position, clearly and for long enough, and nothing was there: the memory of the
-- spot is wrong, so it is dropped. Returns false for a contact that is not lost.
function ObservationMemory.invalidate(self: any, trackId: string, reason: string?): boolean
	local c: Contact? = self._contacts[trackId]
	if c == nil or c.state ~= Contact.LOST then
		return false
	end
	c.markValid = false
	c.confidence = 0.0
	self._contacts[trackId] = nil
	self.contactEnded:emit(c, reason or "empty")
	return true
end

-- The sensor resolved a capture by a live link or unique spatial bodily evidence.
function ObservationMemory.resolveCapture(self: any, trackId: string): boolean
	local c: Contact? = self._contacts[trackId]
	if c == nil then
		return false
	end
	self._contacts[trackId] = nil
	self.contactEnded:emit(c, "captured")
	return true
end

return ObservationMemory
