--!strict
-- The words of the brown rival's contest for the screen (ROBLOX-73): what the spider's strike did to a rival that had seen it coming. The
-- first line is the old line for a catch (a rival that had not noticed is caught outright, as before); the others are the new outcomes.
-- Pure: checked in tests/rival.luau and tests/client_rival.luau.
local RivalText = {}

RivalText.CAPTURED = "Caught the rival! It fights back. Tap to keep your grip."
-- ROBLOX-77: the rival must be subdued with the tapping grip before it can be eaten, and it can tear free.
RivalText.SUBDUED = "The rival goes still. Stay still to eat; worth two housefly meals."
RivalText.TORE = "The rival tore free of your fangs."
RivalText.TORE_GENTLE = "The rival tore free of your fangs. You are safe in this mode."
RivalText.SPRANG = "It sprang clear of your strike."
RivalText.COUNTER = "It bit back! Jump away!"
RivalText.COUNTER_GENTLE = "It bit back, but you are safe in this mode. Jump away!"

-- The line for a counter-bite: the gentle modes cost nothing and say so.
function RivalText.counter(gentle: boolean): string
	return if gentle then RivalText.COUNTER_GENTLE else RivalText.COUNTER
end

-- The status line while the rival fights the grip: the fly's wording (Caught — tap Jump to keep your grip), in the rival's own words. `button` is
-- the name of the jump button on this device.
function RivalText.struggle(button: string): string
	return "Holding the rival — tap " .. button .. " to keep your grip"
end

-- The notice for the rival tearing free: it never harms the player, and the gentle modes say so.
function RivalText.tore(gentle: boolean): string
	return if gentle then RivalText.TORE_GENTLE else RivalText.TORE
end

-- The notice for a strike's outcome event ("captured", "sprang", "counter"), or nil for any other event.
function RivalText.strike(event: string, gentle: boolean): string?
	if event == "captured" then return RivalText.CAPTURED end
	if event == "sprang" then return RivalText.SPRANG end
	if event == "counter" then return RivalText.counter(gentle) end
	return nil
end

return RivalText
