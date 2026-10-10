extends RefCounted
## ObservationMemory (spec 7, 21.3): what the observer remembers of what it sensed. The SensorSystem hands it
## Observation records; it keeps one Contact per thing the sensor keeps sensing (a "track"), ages them, and says what
## is still sensed, what has been lost and what has gone. It never looks at the world: a contact changes only when an
## observation arrives, when time passes, or when the sensor reports that the remembered spot was inspected and is empty.
##
## A contact is LIVE while observations keep coming (a peripheral cue repeats every cue cooldown, an inspection every
## tick) and LOST once none has arrived for the hold time of its modality. A lost contact's confidence falls in a
## straight line from what it was at the loss to nothing over `decay_s` (several seconds), and the contact is forgotten
## at that point. A lost contact that was inspected has a mark (A-002): its last observed position, which never moves,
## because the only thing that can move a position is a new inspection.
##
## Which contact an observation belongs to is the sensor's decision, taken from evidence (A-027, scripts/perception/sensor_system.gd):
## a contact is the spider's hypothesis that some observations are of one visible thing, not the thing's identity in the world. The
## memory only keeps what it is told, and can fold a contact it knew only from cues into the lost contact it turned out to be (merge).
## The world id of a thing it is looking at is kept on the contact for as long as sight lasts (target_id) and dropped the moment sight
## is lost: nothing that is not live is linked to the world.
##
## What a peripheral cue may and may not do (spec 7: coarse directional evidence, no label): it starts a contact, and it
## keeps a contact that is only cues alive. It never gives a position, never changes the category, the confidence or the
## position of a contact that has been inspected, and never brings an inspected contact back from lost: that takes
## another inspection (a reacquisition). What the cue did say, a bearing, is kept apart (cue_tick, cue_direction) for the
## presentation's edge markers.

const Observation = preload("res://scripts/perception/observation.gd")
const PerceptionMath = preload("res://scripts/perception/perception_math.gd")

## A new contact, or a track picked up again after it had been forgotten.
signal contact_acquired(contact: Contact)
## The category a contact is believed to be refined (up) or fell back (down).
signal category_changed(contact: Contact, old_category: StringName, new_category: StringName)
## Sight of a contact ended: its hold time ran out with no new observation.
signal contact_lost(contact: Contact)
## A lost contact was observed again: the same track, its record updated.
signal contact_reacquired(contact: Contact)
## A contact left the memory: reason "expired" (its confidence reached nothing), "empty" (the sensor inspected the
## remembered spot and found nothing there) or "merged" (a contact known only from cues turned out to be a lost one: A-027).
signal contact_ended(contact: Contact, reason: String)


class Contact extends RefCounted:
	const LIVE := &"live"
	const LOST := &"lost"

	var track_id: String = ""
	var observer_id: String = ""
	## The world id of the thing this contact is live-linked to (spec 21.3: target, only when resolved), for validated interaction
	## and nothing else. Set while an inspection has resolved the thing, dropped the moment the contact is lost, and never used to
	## decide which contact an observation belongs to (A-027).
	var target_id: String = ""
	var state: StringName = LIVE
	## Modality of the latest evidence that updated the record (a cue on an inspected contact does not).
	var modality: StringName = Observation.PERIPHERAL
	var category: StringName = Observation.MOVEMENT
	## What the contact is believed to be worth now: the latest evidence's while live, falling after a loss.
	var confidence: float = 0.0
	var confidence_at_loss: float = 0.0
	## The last observed position: only an inspection gives one, and only another inspection changes it.
	var has_position: bool = false
	var position: Vector3 = Vector3.ZERO
	var position_tick: int = 0
	var size_wu: float = 0.0
	var apparent_size_deg: float = 0.0
	## How fast it was seen moving at the last inspection, WU/s.
	var speed_wu_s: float = 0.0
	## Latest direction from the observer of the evidence that updated the record (coarse for a cue).
	var direction: Vector3 = Vector3.FORWARD
	var first_tick: int = 0
	## Tick of the latest evidence that updated the record.
	var observed_tick: int = 0
	## The latest peripheral cue, apart from the record: its tick, its coarse bearing and how many there have been.
	var cue_tick: int = -1000000
	var cue_direction: Vector3 = Vector3.ZERO
	var cue_count: int = 0
	var lost_tick: int = 0
	var reacquisitions: int = 0
	## False once the mark was found to be wrong (the spot was inspected and is empty).
	var mark_valid: bool = true

	func is_live() -> bool:
		return state == LIVE

	## Live and being inspected: the position is where it is being seen now.
	func is_inspected_now() -> bool:
		return state == LIVE and modality == Observation.INSPECTION

	func has_mark() -> bool:
		return state == LOST and has_position and mark_valid

	func to_dict() -> Dictionary:
		return {
			"track_id": track_id, "target_id": target_id, "state": state, "modality": modality, "category": category,
			"confidence": confidence, "has_position": has_position, "position": position if has_position else null,
			"observed_tick": observed_tick, "position_tick": position_tick, "lost_tick": lost_tick,
		}


## Ticks a second lasts (the physics rate), the seconds a lost contact's confidence takes to fall to nothing, and how
## long a contact may go without new evidence before it counts as lost.
var hz: float = 60.0
var decay_s: float = 6.0
var hold_inspection_s: float = 0.15
var hold_peripheral_s: float = 1.0
## The tick the memory was last advanced to.
var now_tick: int = 0
## How many observations were ever ingested, by modality; for tests and the debug view.
var ingested: int = 0
var ingested_inspection: int = 0
var ingested_peripheral: int = 0

var _contacts: Dictionary = {}  # track_id -> Contact


func configure(p_hz: float, p_decay_s: float, p_hold_inspection_s: float, p_hold_peripheral_s: float) -> void:
	hz = maxf(p_hz, 1.0)
	decay_s = maxf(p_decay_s, 0.01)
	hold_inspection_s = maxf(p_hold_inspection_s, 0.0)
	hold_peripheral_s = maxf(p_hold_peripheral_s, 0.0)


func clear() -> void:
	_contacts.clear()


func get_contact(track_id: String) -> Contact:
	return _contacts.get(track_id)


func count() -> int:
	return _contacts.size()


## Every contact, oldest first.
func contacts() -> Array:
	var out: Array = _contacts.values()
	out.sort_custom(func(a: Contact, b: Contact) -> bool: return a.first_tick < b.first_tick)
	return out


func live_contacts() -> Array:
	return contacts().filter(func(c: Contact) -> bool: return c.state == Contact.LIVE)


func lost_contacts() -> Array:
	return contacts().filter(func(c: Contact) -> bool: return c.state == Contact.LOST)


## Lost contacts that were inspected and whose spot has not been found empty: the last-seen marks.
func marks() -> Array:
	return contacts().filter(func(c: Contact) -> bool: return c.has_mark())


## How much of a thing's earlier inspection still counts if it is seen again: 1 for a live contact, falling to 0 as
## the memory of a lost one fades, 0 for a track that is gone.
func familiarity(track_id: String) -> float:
	var c: Contact = _contacts.get(track_id)
	if c == null:
		return 0.0
	if c.state == Contact.LIVE:
		return 1.0
	return PerceptionMath.decayed_confidence(1.0, age_s(c), decay_s)


## Seconds since sight of a lost contact ended; 0 for a live one.
func age_s(c: Contact) -> float:
	return 0.0 if c.state == Contact.LIVE else float(now_tick - c.lost_tick) / hz


## Seconds since the evidence that last updated the record.
func observed_age_s(c: Contact) -> float:
	return float(now_tick - c.observed_tick) / hz


## Seconds since the latest peripheral cue (a very large number if there never was one).
func cue_age_s(c: Contact) -> float:
	return float(now_tick - c.cue_tick) / hz


## 0 for a live contact and for one just lost, 1 when its memory is gone (the mark is at its stalest).
func staleness_of(c: Contact) -> float:
	return 0.0 if c.state == Contact.LIVE else PerceptionMath.staleness(age_s(c), decay_s)


## Ticks a contact may go without evidence of this modality before it counts as lost. The sensor reads the same number to tell unbroken
## sight (the thing is still the same contact) from sight that was lost.
func hold_ticks(modality: StringName) -> int:
	return roundi((hold_inspection_s if modality == Observation.INSPECTION else hold_peripheral_s) * hz)


## Take in one observation. A record that is not valid (spec 21.3) is refused and returns null.
func ingest(obs: Observation) -> Contact:
	if obs == null or not obs.is_valid():
		return null
	ingested += 1
	var c: Contact = _contacts.get(obs.track_id)
	var fresh := c == null
	var was_lost := false
	if fresh:
		c = Contact.new()
		c.track_id = obs.track_id
		c.observer_id = obs.observer_id
		c.first_tick = obs.observed_tick
		c.category = obs.category
		_contacts[c.track_id] = c
	else:
		was_lost = c.state == Contact.LOST
	if obs.modality == Observation.PERIPHERAL:
		ingested_peripheral += 1
		c.cue_tick = obs.observed_tick
		c.cue_direction = obs.direction
		c.cue_count += 1
		if not fresh and c.has_position:
			return c  # a bearing says nothing new about something that was inspected (see the header)
	var old_category := c.category
	c.state = Contact.LIVE
	c.modality = obs.modality
	c.confidence = obs.confidence
	c.observed_tick = obs.observed_tick
	c.direction = obs.direction
	if obs.target_id != "":
		c.target_id = obs.target_id
	if obs.modality == Observation.INSPECTION:
		ingested_inspection += 1
		c.has_position = true
		c.position = obs.estimated_position
		c.position_tick = obs.observed_tick
		c.size_wu = obs.size_wu
		c.apparent_size_deg = obs.apparent_size_deg
		c.speed_wu_s = obs.speed_wu_s
		c.mark_valid = true
		c.category = obs.category
	if fresh:
		contact_acquired.emit(c)
	elif was_lost:
		c.reacquisitions += 1
		contact_reacquired.emit(c)
	if c.category != old_category:
		category_changed.emit(c, old_category, c.category)
	return c


## Moves time on to `tick`: live contacts that have had no evidence for their hold time become lost, lost contacts lose
## confidence, and those with none left are forgotten.
func advance(tick: int) -> void:
	now_tick = tick
	for id: String in _contacts.keys():
		var c: Contact = _contacts[id]
		if c.state == Contact.LIVE:
			if tick - c.observed_tick > hold_ticks(c.modality):
				c.state = Contact.LOST
				c.lost_tick = tick
				c.confidence_at_loss = c.confidence
				c.target_id = ""   # sight is over: the link to the world goes with it
				contact_lost.emit(c)
		if c.state == Contact.LOST:
			var age := float(tick - c.lost_tick) / hz
			c.confidence = PerceptionMath.decayed_confidence(c.confidence_at_loss, age, decay_s)
			if age >= decay_s - 1e-9:
				_contacts.erase(id)
				contact_ended.emit(c, "expired")


## The sensor found that a contact it knew only from cues (it has no position) is the lost contact `into_id`, seen again: the bearing
## of the latest cue and the count of cues go to that record, and the cue-only contact is dropped (reason "merged"). Returns false
## when either is missing or the one to fold has a position of its own (an inspected contact is never folded into another).
func merge(from_id: String, into_id: String) -> bool:
	var a: Contact = _contacts.get(from_id)
	var b: Contact = _contacts.get(into_id)
	if a == null or b == null or a == b or a.has_position:
		return false
	if a.cue_tick > b.cue_tick:
		b.cue_tick = a.cue_tick
		b.cue_direction = a.cue_direction
	b.cue_count += a.cue_count
	_contacts.erase(from_id)
	contact_ended.emit(a, "merged")
	return true


## The sensor looked at a lost contact's last observed position, clearly and for long enough, and nothing was there:
## the memory of the spot is wrong, so it is dropped. Returns false for a contact that is not lost.
func invalidate(track_id: String, reason: String = "empty") -> bool:
	var c: Contact = _contacts.get(track_id)
	if c == null or c.state != Contact.LOST:
		return false
	c.mark_valid = false
	c.confidence = 0.0
	_contacts.erase(track_id)
	contact_ended.emit(c, reason)
	return true


## The sensor resolved a capture by a live link or unique spatial bodily evidence.
func resolve_capture(track_id: String) -> bool:
	var c: Contact = _contacts.get(track_id)
	if c == null:
		return false
	_contacts.erase(track_id)
	contact_ended.emit(c, "captured")
	return true
