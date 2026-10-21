--!strict
-- What the screen says when a prey gets out of the jaws by its own trick (ROBLOX-101, Prey/PreyKinds.grip, kept by Prey/PreyWorld as `event`): a moth whose
-- scales came away in the fangs, a crane fly that left a leg. One short note each, shown as the notebook's notes are. Pure; checked in tests/garden_life.luau.
-- ROBLOX-105: and when a strike comes within something that is not food (Prey/PreyWorld.strikeAmbient: { kind = "refused", prey = kind }): the spider lets it
-- go, and the note says why in a few words, each reason from the kind's notebook page and its sources (docs/NOTEBOOK_SOURCES.md).
local PreyText = {}

PreyText.NOTES = {
	slip = "The moth slipped free, leaving scales in your fangs.",
	shed = "The crane fly left a leg in your fangs and got away.",
} :: { [string]: string }

-- (ROBLOX-105) Why a strike at each kind of thing that is not food came to nothing.
PreyText.REFUSED = {
	ladybird = "A foul fluid wells from the ladybird's leg joints. You let it go.",
	millipede = "The millipede coils tight, armour out, and smells foul. You let it go.",
	snail = "The snail is far too big, and it has drawn into its shell.",
	harvestman = "The harvestman gives off a foul smell and stalks on. You let it go.",
	ant = "The ant turns on you, jaws open. You let it go.", -- (ROBLOX-119: the meadow's ants)
	woodlouse = "The woodlouse's glands give off a secretion spiders avoid. You let it go.",
} :: { [string]: string }

-- (ROBLOX-120) The field cricket's song, captioned (the Captions setting) when the nearest singing cricket (Prey/PreyKinds.chirping) is within CHIRP_HEAR studs of the
-- spider; `direction` UI/WaspText.directionWord's. How loud it is to the spider: 1 at the cricket, nothing at CHIRP_HEAR.
PreyText.CHIRP_HEAR = 400
function PreyText.chirp(direction: string, loud: number): { text: string, alpha: number }
	return { text = `[a cricket chirping, {direction}]`, alpha = math.clamp(0.35 + loud, 0, 1) }
end

-- How long a note stays (seconds).
PreyText.SECONDS = 4

-- The note for an event ({ kind = "slip" | "shed" | "refused", prey = kind }), or nil for one this table does not know.
function PreyText.note(event: any): string?
	if type(event) ~= "table" then return nil end
	if event.kind == "refused" then return PreyText.REFUSED[event.prey] end
	return PreyText.NOTES[event.kind]
end

return PreyText
