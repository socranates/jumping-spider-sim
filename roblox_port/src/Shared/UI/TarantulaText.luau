--!strict
-- The words of the tarantulas' display key for the screen (ROBLOX-82): the prompt, the status line, the touch button and the controls card's
-- line. The walking hint, the status line and the card carry them only for the two tarantulas. Button names come from ControlText for the
-- device in use, except on touch, where the button says "Rear up" (ControlText's "Dance" is the peacock's, AntMimicText's "Wave" the ant's).
-- Pure: checked in tests/tarantula.luau.
local ControlText = require(script.Parent.ControlText)

local TarantulaText = {}

TarantulaText.STAND = "Stand still on a surface to rear up"

local function key(device: ControlText.Device): string
	return if device == "touch" then "Rear up" else ControlText.name(device, "display")
end

-- The walking hint's extra words.
function TarantulaText.displayHint(device: ControlText.Device, showing: boolean): string
	if showing then return `{key(device)}: stop` end
	return `{key(device)}: rear up`
end

-- The status line while the pose is on.
function TarantulaText.statusLine(device: ControlText.Device): string
	return `THREAT DISPLAY    {key(device)} or move: stop`
end

-- The touch button's words.
function TarantulaText.touchDisplay(showing: boolean): string return if showing then "Stop" else "Rear up" end

-- The controls card's line.
function TarantulaText.helpLine(device: ControlText.Device): string
	return `Standing still: {key(device)} rear up and lay a silk mat. Any move, jump or Cancel stops it`
end

return TarantulaText
