--!strict
-- The words of the ant-mimicking spider's display key for the screen (ROBLOX-64): the prompt, the status line, the touch button and the
-- controls card's line. The walking hint, the status line and the card carry them only for that spider. Button names come from
-- ControlText for the device in use, except on touch, where the button says "Wave" (ControlText's "Dance" is the peacock's). Pure:
-- checked in tests/antmimic.luau.
local ControlText = require(script.Parent.ControlText)

local AntMimicText = {}

AntMimicText.STAND = "Stand still on a surface to wave your antennae"

local function key(device: ControlText.Device): string
	return if device == "touch" then "Wave" else ControlText.name(device, "display")
end

-- The walking hint's extra words.
function AntMimicText.displayHint(device: ControlText.Device, showing: boolean): string
	if showing then return `{key(device)}: antennae down` end
	return `{key(device)}: wave antennae`
end

-- The status line while the display pose is on.
function AntMimicText.statusLine(device: ControlText.Device): string
	return `ANTENNAE UP    {key(device)} or move: stop`
end

-- The touch button's words.
function AntMimicText.touchDisplay(showing: boolean): string return if showing then "Stop" else "Wave" end

-- The controls card's line (legs I rise by themselves when the spider keeps still; the key makes them higher and faster).
function AntMimicText.helpLine(device: ControlText.Device): string
	return `{key(device)}{if device == "touch" then " button:" else ""} wave antennae higher (any move, jump or Cancel stops it)`
end

return AntMimicText
