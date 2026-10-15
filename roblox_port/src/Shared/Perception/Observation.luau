--!strict
-- Observation (spec 21.3): one piece of sensed evidence, as the sensor makes it and the memory keeps it. A port of the frozen
-- Godot scripts/perception/observation.gd (c87ce00), field for field. Observer, target (only when resolved), estimated position,
-- modality, confidence in [0, 1], the tick it was observed at (an integer action tick) and a category. It is never refreshed from
-- hidden truth: an observation is only ever made from what the observer could see at `observedTick`, and a later one is a new record.
--
-- Two modalities (spec 7):
--   PERIPHERAL  broad coverage, a coarse direction only, no position and no category beyond "movement". The target is not resolved.
--   INSPECTION  the forward cone: a position (to within the target's own size), a category that refines with continuous exposure
--               (movement, possible prey, fly-like prey: A-004), and the target once it is resolved.
-- Words for the categories belong to the presentation, never here. Pure: no engine services, so the plain Luau CLI runs it.
--
-- Naming: Godot's snake_case fields are camelCase here (track_id -> trackId, speed_wu_s -> speedWuS); the values are unchanged.
local Observation = {}
Observation.__index = Observation

Observation.PERIPHERAL = "peripheral_motion"
Observation.INSPECTION = "forward_inspection"

Observation.MOVEMENT = "movement"
Observation.POSSIBLE_PREY = "possible_prey"
Observation.FLY_LIKE_PREY = "fly_like_prey"
-- Refinement order: each is a finer guess than the one before it. No species is ever named (A-004).
Observation.CATEGORIES = table.freeze({ "movement", "possible_prey", "fly_like_prey" })

export type Observation = {
	observerId: string,
	-- The target's persistent id once the observer has resolved it (inspected it long enough), else "".
	targetId: string,
	-- Opaque id the sensor gives one thing it keeps sensing, so the memory can follow it. It is not the target's id.
	trackId: string,
	-- The estimate; meaningful only when hasPosition. A peripheral observation has none: only `direction`.
	estimatedPosition: Vector3,
	hasPosition: boolean,
	-- Unit direction from the observer to the thing, as sensed: exact enough to aim at for an inspection, quantised to a sector
	-- for a peripheral cue.
	direction: Vector3,
	modality: string,
	confidence: number,
	observedTick: number,
	category: string,
	-- Estimated size of the thing, WU (an inspection only). The memory uses it to judge whether a place could hide it.
	sizeWu: number,
	-- How large it looked, degrees of angle across.
	apparentSizeDeg: number,
	-- How fast it was seen moving, WU/s (an inspection only). A lost contact's plausible region grows at least this fast (A-027).
	speedWuS: number,
}

local function isFinite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function vectorIsFinite(v: Vector3): boolean
	return isFinite(v.X) and isFinite(v.Y) and isFinite(v.Z)
end

-- A new record with Godot's defaults (a peripheral movement cue straight ahead with nothing in it); `fields` overrides any of them.
function Observation.new(fields: { [string]: any }?): Observation
	local o = {
		observerId = "",
		targetId = "",
		trackId = "",
		estimatedPosition = Vector3.zero,
		hasPosition = false,
		direction = Vector3.new(0, 0, -1), -- Godot's Vector3.FORWARD (both engines look down -Z)
		modality = Observation.PERIPHERAL,
		confidence = 0.0,
		observedTick = 0,
		category = Observation.MOVEMENT,
		sizeWu = 0.0,
		apparentSizeDeg = 0.0,
		speedWuS = 0.0,
	}
	if fields then
		for k, v in fields do
			(o :: any)[k] = v
		end
	end
	return setmetatable(o, Observation) :: any
end

-- The place of a category in the refinement order: 0 movement, 1 possible prey, 2 fly-like prey; -1 for anything else (Godot's Array.find).
function Observation.rank(c: string): number
	local i = table.find(Observation.CATEGORIES, c)
	return if i then i - 1 else -1
end

-- Problems with the record, empty when it is fine: the invariants of spec 21.3 (no NaN or infinity, confidence in [0, 1], a known
-- modality and category, a position only for an inspection).
function Observation.problems(o: Observation): { string }
	local out: { string } = {}
	if o.observerId == "" then
		table.insert(out, "no observer")
	end
	if o.trackId == "" then
		table.insert(out, "no track")
	end
	if not (o.modality == Observation.PERIPHERAL or o.modality == Observation.INSPECTION) then
		table.insert(out, `unknown modality '{o.modality}'`)
	end
	if not table.find(Observation.CATEGORIES, o.category) then
		table.insert(out, `unknown category '{o.category}'`)
	end
	if not isFinite(o.confidence) or o.confidence < 0.0 or o.confidence > 1.0 then
		table.insert(out, `confidence {o.confidence} is not in [0, 1]`)
	end
	if o.observedTick < 0 then
		table.insert(out, "negative tick")
	end
	if not vectorIsFinite(o.direction) or math.abs(o.direction.Magnitude - 1.0) > 1e-3 then
		table.insert(out, "direction is not a unit vector")
	end
	if o.hasPosition and not vectorIsFinite(o.estimatedPosition) then
		table.insert(out, "estimated position is not finite")
	end
	if o.modality == Observation.PERIPHERAL and o.hasPosition then
		table.insert(out, "a peripheral observation carries no position")
	end
	if o.modality == Observation.PERIPHERAL and (o.category ~= Observation.MOVEMENT or o.targetId ~= "") then
		table.insert(out, "a peripheral observation has no category beyond movement and no resolved target")
	end
	if o.modality == Observation.INSPECTION and not o.hasPosition then
		table.insert(out, "an inspection carries a position")
	end
	if not isFinite(o.speedWuS) or o.speedWuS < 0.0 then
		table.insert(out, "speed is not a finite, non-negative number")
	end
	return out
end

function Observation.isValid(o: Observation): boolean
	return #Observation.problems(o) == 0
end

-- The spec's fields as a plain table; the position is nil unless the record carries one (a cue's record has no position to read).
function Observation.toDict(o: Observation): { [string]: any }
	return {
		observerId = o.observerId,
		targetId = o.targetId,
		trackId = o.trackId,
		estimatedPosition = if o.hasPosition then o.estimatedPosition else nil,
		direction = o.direction,
		modality = o.modality,
		confidence = o.confidence,
		observedTick = o.observedTick,
		category = o.category,
	}
end

return Observation
