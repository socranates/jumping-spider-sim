--!strict
-- Which spider the player is (ROBLOX-31): the daughter's first spider or the peacock spider. Pure, so tests/peacock.luau checks it.
-- The choice is remembered for the session in the Player attribute `Appearance`; the Workspace attribute `Appearance` can preselect
-- it for Studio and playtests. Anything that is not a known appearance is the default (the first spider).
local Appearances = require(script.Parent.Parent.Data.Appearances)

local SpiderChoice = {}

-- The spiders to choose between, in the order the crack's key cycles through them.
SpiderChoice.ORDER = { "first_spider", "maratus_volans_male" } :: { string }

local function known(id: any): boolean
	return type(id) == "string" and Appearances.profiles[id] ~= nil
end

-- The appearance to start with: the Player attribute if it names one, else the Workspace attribute, else the default.
function SpiderChoice.start(playerAttribute: any, workspaceAttribute: any): string
	if known(playerAttribute) then return playerAttribute :: string end
	if known(workspaceAttribute) then return workspaceAttribute :: string end
	return Appearances.default
end

-- The appearance after this one.
function SpiderChoice.next(id: string): string
	for i, name in SpiderChoice.ORDER do
		if name == id then return SpiderChoice.ORDER[i % #SpiderChoice.ORDER + 1] end
	end
	return Appearances.default
end

-- Does this appearance have a fan to display (and so a courtship dance)?
function SpiderChoice.canDance(id: string): boolean
	local look = Appearances.profiles[id]
	return look ~= nil and (look :: any).fan ~= nil
end

return SpiderChoice
