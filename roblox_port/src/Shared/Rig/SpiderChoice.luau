--!strict
-- Which spider the player is (ROBLOX-31, ROBLOX-64): the first spider, the peacock spider or the ant-mimicking spider. Pure, so tests/peacock.luau checks it.
-- The choice is remembered for the session in the Player attribute `Appearance`; the Workspace attribute `Appearance` can preselect
-- it for Studio and playtests. Anything that is not a known appearance is the default (the first spider).
local Appearances = require(script.Parent.Parent.Data.Appearances)

local SpiderChoice = {}

-- The spiders to choose between, in the order the crack's key cycles through them.
SpiderChoice.ORDER = { "first_spider", "maratus_volans_male", "myrmarachne_formicaria_female" } :: { string }

-- Only a spider in ORDER can be the player: the brown rival's look (Data/Appearances.rival_spider) is drawn for the other spider and is never
-- offered by the cycle or accepted from an attribute or a save.
local function known(id: any): boolean
	if type(id) ~= "string" or Appearances.profiles[id] == nil then return false end
	for _, name in SpiderChoice.ORDER do
		if name == id then return true end
	end
	return false
end

-- The appearance to start with: the Player attribute if it names one, else the Workspace attribute, else the default.
function SpiderChoice.start(playerAttribute: any, workspaceAttribute: any): string
	if known(playerAttribute) then return playerAttribute :: string end
	if known(workspaceAttribute) then return workspaceAttribute :: string end
	return Appearances.default
end

-- Is this spider not the player's to be yet (ROBLOX-71)? Nothing is locked while the add-ons are free for testing (ROBLOX-66), so this is
-- always false. It is the one place to wire ownership when Nathan says the sales start: ROBLOX-48's Game Pass pattern (the server checks
-- ownership, a replicated Player attribute holds the answer, a Studio override) fills `owned` ({ [appearance id] = true }), and this
-- returns true for a pass-only spider (the peacock, the ant mimic) that is not in it. The first spider is never locked. Both ways of
-- choosing, the crack's key and the Settings row, skip a locked spider through next() and step() below.
function SpiderChoice.locked(id: string, owned: { [string]: boolean }?): boolean
	return false
end

-- The appearance `dir` (+1 or -1) places from this one in ORDER, wrapping and skipping any that is locked. When nothing else is open it is
-- this one again. An id that is not in ORDER steps to the default (the first spider).
function SpiderChoice.step(id: string, dir: number, owned: { [string]: boolean }?): string
	local n = #SpiderChoice.ORDER
	local at = table.find(SpiderChoice.ORDER, id)
	if at == nil then return Appearances.default end
	local way = if dir < 0 then -1 else 1
	for k = 1, n - 1 do
		local name = SpiderChoice.ORDER[(at - 1 + way * k) % n + 1]
		if not SpiderChoice.locked(name, owned) then return name end
	end
	return id
end

-- The appearance after this one (the crack's key).
function SpiderChoice.next(id: string, owned: { [string]: boolean }?): string
	return SpiderChoice.step(id, 1, owned)
end

-- What the spider is doing, as the client reads it off the motor, the jump, the growth and the struggle (all booleans but `mode`).
export type Standing = { mode: string, seized: boolean, preparing: boolean, jumping: boolean, onLine: boolean, moulting: boolean, struggling: boolean }

-- May the Settings row change the spider now (ROBLOX-71)? Anywhere on the sill, but only while standing safely: attached to a surface and
-- not held by the wasp, not winding up a jump or in the air, not on a silk line, not moulting and not holding a struggling fly. The crack
-- keeps its own rule (resting awake) and does not ask this.
function SpiderChoice.safeToChange(s: Standing): boolean
	return s.mode == "attached" and not s.seized and not s.preparing and not s.jumping and not s.onLine and not s.moulting and not s.struggling
end

-- Does this appearance have a fan to display (and so a courtship dance)?
function SpiderChoice.canDance(id: string): boolean
	local look = Appearances.profiles[id]
	return look ~= nil and (look :: any).fan ~= nil
end

-- Does this appearance have antennae to show (legs I raised when it stands still) and so an antennae pose on the display key?
function SpiderChoice.hasAntennae(id: string): boolean
	local look = Appearances.profiles[id]
	return look ~= nil and (look :: any).antennae ~= nil
end

-- What the display key (X / RB / the touch button) does for this appearance: "dance" (the peacock's courtship dance), "antennae" (the
-- ant mimic's antennae pose) or nil (the first spider has none).
function SpiderChoice.displayKind(id: string): string?
	if SpiderChoice.canDance(id) then return "dance" end
	if SpiderChoice.hasAntennae(id) then return "antennae" end
	return nil
end

return SpiderChoice
