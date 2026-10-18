--!strict
-- The words of the peacock spider for the screen (ROBLOX-31): choosing the spider in the crack, the dance's prompts and status
-- line, the controls card's extra lines and the felt caption. Button names come from ControlText for the device in use. The dance's
-- own words are never shown for the first spider; choosing is offered in the crack to both, or the peacock spider could not be found.
-- Pure: checked in tests/peacock.luau.
local ControlText = require(script.Parent.ControlText)
local Peacock = require(script.Parent.Parent.Data.Peacock)
local SpiderChoice = require(script.Parent.Parent.Rig.SpiderChoice)
local AntMimicText = require(script.Parent.AntMimicText)

local PeacockText = {}

PeacockText.NAMES = { first_spider = "the first spider", maratus_volans_male = "the peacock spider", myrmarachne_formicaria_female = "the ant-mimicking spider" } :: { [string]: string }
PeacockText.STAND = "Stand still on a surface to dance"
PeacockText.NOT_RESTING = "You can change spider while resting in the silk-lined crack"

-- The crack's extra hint while resting: how to become the other spider.
function PeacockText.change(device: ControlText.Device, current: string): string
	local other = SpiderChoice.next(current)
	return `{ControlText.name(device, "choose")}: become {PeacockText.NAMES[other] or other}`
end

function PeacockText.changed(id: string): string
	return `You are {PeacockText.NAMES[id] or id} now`
end

-- The walking hint's extra words for the peacock spider.
function PeacockText.displayHint(device: ControlText.Device, dancing: boolean): string
	if dancing then return `{ControlText.name(device, "display")}: stop dancing` end
	return `{ControlText.name(device, "display")}: courtship dance`
end

-- The status line while the dance runs.
function PeacockText.dancingLine(device: ControlText.Device): string
	return `COURTSHIP DANCE    {ControlText.name(device, "display")} or move: stop`
end

-- The touch buttons' words.
function PeacockText.touchChange(): string return "Change" end
function PeacockText.touchDisplay(dancing: boolean): string return if dancing then "Stop" else "Dance" end

-- Lines added to the controls card (H): the crack's choice for every spider, then the display key's line for the spider that has one:
-- `display` is "dance" (the peacock spider), "antennae" (the ant-mimicking spider), nil (the first spider). true means "dance" and false nil.
function PeacockText.helpExtra(device: ControlText.Device, display: (string | boolean)?): string
	local choose = ControlText.name(device, "choose")
	local kind: string? = if display == true then "dance" elseif type(display) == "string" then display else nil
	local lines = { `In the crack: {choose} change spider (first, peacock, ant mimic)` }
	if kind == "dance" then
		table.insert(lines, `Standing still: {ControlText.name(device, "display")} courtship dance. Any move, jump or Cancel stops it`)
	elseif kind == "antennae" then
		table.insert(lines, AntMimicText.helpLine(device))
	end
	return "\n" .. table.concat(lines, "\n")
end

-- The felt caption while a rumble-rump is on: { text, alpha }, or nil when there is none. The vibration is felt through the feet, not seen.
function PeacockText.caption(rumble: number): { text: string, alpha: number }?
	if rumble <= 0.02 then return nil end
	return { text = Peacock.feltCaption, alpha = math.clamp(rumble, 0, 1) }
end

return PeacockText
