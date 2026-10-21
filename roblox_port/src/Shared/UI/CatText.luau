--!strict
-- The ranger's cat in words (ROBLOX-118; the cat is Predator/Cat): its death card, the notice when its pat only knocks the spider aside (the gentle rules), and the
-- captions of what the spider hears of it (the Captions setting, as the wasp's hum is captioned): the bell on its collar while it moves, its purr close by. A
-- jumping spider hears airborne sound (the notebook's cat page says how it is known), so the bell is the first anyone knows of it. Pure: tests/preserve.luau
-- checks the words, tests/quiet.luau their classes.
local CatText = {}

CatText.LINE = "The cat's paw came down."
CatText.SUB = "A cat pats at small things that move. Up out of its reach, in a gap, or keeping still, the spider would have lived."
CatText.NUDGED = "The cat's paw knocked you aside. It has lost interest, for now."
CatText.CAUSE = "cat" -- (the end of a life's cause, LifeSession)

-- The caption of what is heard now (`bell` and `purr`, 0..1, Predator/Cat.sound; `direction` UI/WaspText.directionWord's), or nil. The bell wins: it is the warning.
function CatText.caption(bell: number, purr: number, direction: string, nearer: boolean): { text: string, alpha: number }?
	if bell > 0.05 then
		return { text = `[a small bell, {direction}{if nearer then ", coming closer" else ""}]`, alpha = math.clamp(0.4 + bell, 0, 1) }
	end
	if purr > 0.05 then
		return { text = `[a low purr, {direction}]`, alpha = math.clamp(0.4 + purr, 0, 1) }
	end
	return nil
end

return table.freeze(CatText)
