--!strict
-- What the screen says when a prey gets out of the jaws by its own trick (ROBLOX-101, Prey/PreyKinds.grip, kept by Prey/PreyWorld as `event`): a moth whose
-- scales came away in the fangs, a crane fly that left a leg. One short note each, shown as the notebook's notes are. Pure; checked in tests/garden_life.luau.
local PreyText = {}

PreyText.NOTES = {
	slip = "The moth slipped free, leaving scales in your fangs.",
	shed = "The crane fly left a leg in your fangs and got away.",
} :: { [string]: string }

-- How long a note stays (seconds).
PreyText.SECONDS = 4

-- The note for an event ({ kind = "slip" | "shed", prey = kind }), or nil for one this table does not know.
function PreyText.note(event: any): string?
	if type(event) ~= "table" then return nil end
	return PreyText.NOTES[event.kind]
end

return PreyText
