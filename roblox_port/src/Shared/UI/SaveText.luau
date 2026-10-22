--!strict
-- The words about saving (ROBLOX-39): what the menu and a short toast say. Plain and honest: saved, saving, or off for this visit and why.
-- The reasons are SaveRules.REASONS. Pure; checked in tests/state_client.luau.
local SaveText = {}

SaveText.SAVED = "Your notebook and last rests are saved."
SaveText.SAVING = "Saving..."
SaveText.TROUBLE = "Having trouble saving. Your progress is kept for now and the game keeps trying."
SaveText.REST_REFUSED = "Your latest rest could not be saved online. It is kept for this visit; your earlier saved rest is unchanged."
SaveText.REST_PROTECTED = "A saved rest is protected and cannot be replaced during this visit. Your notebook and unaffected rest slots can still save."
SaveText.OFF = "Saving is off for this visit: your notebook and rests will last only until you leave."
SaveText.LOOKING = "Finding your saved game..."
SaveText.BACK = "Saving is back on."
-- ROBLOX-92: the client's saving broke (something in it raised): saving is off for the rest of the visit, and the game goes on. The one status line, and the menu's.
SaveText.BROKEN = "Saving is off"

SaveText.WHY = {
	offline = "The game could not reach its saving service.",
	no_api = "Saving is not available here.",
	load_failed = "Your saved game could not be read just now. It has not been changed, and the game keeps trying.",
	other_session = "Your game is open somewhere else, and this copy cannot save over it.",
	corrupt = "Your saved game could not be read, so it was left exactly as it is.",
	newer = "Your saved game was made by a newer version of this game, so it was left exactly as it is.",
	write_failed = "This visit could not be saved. Your earlier saved game is still kept.",
	rest_refused = SaveText.REST_REFUSED,
 rest_protected = "A stored rest could not be read safely and was left unchanged.",
} :: { [string]: string }

local function because(reason: string?): string?
	if reason == nil then return nil end
	return SaveText.WHY[reason]
end

-- The line for the menu: one or two sentences.
function SaveText.menuLine(status: string?, reason: string?): string
	if status == "session" then
		local why = because(reason)
		return SaveText.OFF .. (if why then "\n" .. why else "")
	elseif status == "saving" then
		if reason == "rest_refused" then return SaveText.REST_REFUSED end
  if reason == "rest_protected" then return SaveText.REST_PROTECTED end
		return if reason == "write_failed" then SaveText.TROUBLE else SaveText.SAVING
	elseif status == "saved" then
		return SaveText.SAVED
	end
	return SaveText.LOOKING
end

-- The line for the menu once the client's own saving has broken (the server's word no longer matters: nothing more is sent).
function SaveText.brokenLine(): string
	return SaveText.OFF .. "\nSomething in the saving broke, so this visit will not be saved."
end

-- A short toast when the status changes, or "" when nothing needs saying (a plain saving/saved flicker is not announced).
function SaveText.toast(oldStatus: string?, oldReason: string?, status: string?, reason: string?): string
	local was: string = oldStatus or ""
	local now: string = status or ""
	local toSession = now == "session" and was ~= "session"
	local fromSession = was == "session" and (now == "saved" or now == "saving")
	local newTrouble = now == "saving" and reason == "write_failed" and was ~= "" and not (was == "saving" and oldReason == "write_failed")
	if now == "saving" then
		if reason == "rest_protected" then
			if was ~= "saving" or oldReason ~= reason then return SaveText.REST_PROTECTED end
		elseif reason == "rest_refused" then
			if was ~= "saving" or oldReason ~= reason then return SaveText.REST_REFUSED end
		end
	end
	if toSession then
		local why = because(reason)
		return SaveText.OFF .. (if why then " " .. why else "")
	elseif fromSession then
		return SaveText.BACK
	elseif newTrouble then
		return SaveText.TROUBLE
	end
	return ""
end

-- Only operational trouble/recovery enters the minimal screen. Routine saving,
-- saved, loading and gameplay messages remain quiet. Do not refresh each retry.
function SaveText.notice(oldStatus: string?, oldReason: string?, status: string?, reason: string?): string
	if status == oldStatus and reason == oldReason then return "" end
	if status == "session" then
		return SaveText.menuLine(status, reason)
	elseif status == "saving" and (reason == "write_failed" or reason == "rest_refused" or reason == "rest_protected") then
		return SaveText.menuLine(status, reason)
	elseif status == "saved" and reason == nil
		and (oldStatus == "session" or (oldStatus == "saving" and (oldReason == "write_failed" or oldReason == "rest_refused" or oldReason == "rest_protected"))) then
		return SaveText.BACK
	end
	return ""
end

return SaveText
