--!strict
-- The robin in words (ROBLOX-120; the robin is Predator/Bird): its death card, the notice when its bill misses (the gentle rules), and the captions of what tells of it
-- first (the Captions setting, as the cat's bell is captioned): its call as it comes in and goes, and its shadow sweeping over the ground. Pure: tests/preserve.luau
-- checks the words, tests/quiet.luau their classes.
local BirdText = {}

BirdText.LINE = "The robin's bill came down."
BirdText.SUB = "It stood still with its head cocked, watching what moved in the open. Under cover, or keeping still, the spider would have lived."
BirdText.MISSED = "The robin stabbed at you and missed."
BirdText.CAUSE = "bird" -- (the end of a life's cause, LifeSession)
BirdText.SHADOW = "[a shadow sweeps over the ground]"

-- The caption of what is heard or seen of it now, or nil: its call (`call` 0..1, Predator/Bird.call; `direction` UI/WaspText.directionWord's) or its shadow passing
-- (`shadow`: the seconds since one passed near, nil if none lately).
function BirdText.caption(call: number, direction: string, shadow: number?): { text: string, alpha: number }?
	if shadow ~= nil and shadow < 2.0 then return { text = BirdText.SHADOW, alpha = 1 } end
	if call > 0.05 then
		return { text = `[a robin calls, {direction}: pick, tut-tut-tut]`, alpha = math.clamp(0.4 + call, 0, 1) }
	end
	return nil
end

return table.freeze(BirdText)
