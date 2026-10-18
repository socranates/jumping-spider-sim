--!strict
-- Two small pure rules about the stores (ROBLOX-39): which store a build writes to, and what kind of failure a DataStore error is.
local SaveRules = require(script.Parent.Parent.Data.SaveRules)

local SaveStores = {}

-- Which DataStore name to use. Studio and the test place always use the test store, so a Studio run (even with API access on, even of the
-- production project) never touches a real save. A live server of the production place uses the production store. `attribute` is the
-- Workspace attribute SaveStore: it may only choose a test-looking name or the test default, never the production name for a test run.
function SaveStores.name(isStudio: boolean, isTestPlace: boolean, attribute: any): string
	if isStudio or isTestPlace then
		if type(attribute) == "string" and string.match(attribute, "^WindowsillTest[%w_]*$") and #attribute <= 40 then return attribute end
		return SaveRules.STORE_TEST
	end
	return SaveRules.STORE_PRODUCTION
end

-- What kind of failure a DataStore error is, from its message (Roblox puts a number and a sentence in it: "104: Cannot store ..." and the
-- like). Classes:
--   "throttle"  the request was over a budget or queued out: wait and try again, slower
--   "config"    saving cannot work here at all (Studio API access off, an unpublished place, DataStores disabled): do not keep hammering
--   "value"     this key or value can never be stored (a bad key, too large, not storable): retrying the same thing cannot work
--   "transient" anything else (a timeout, the service down, an unknown error): try again later
-- The mapping of messages to classes is from Roblox's documented error codes (101-106 key and value, 301-306 throttles, 4xx and 5xx
-- service); it has not been checked against a live DataStore, and an unknown message is treated as transient on purpose.
function SaveStores.classify(message: any): string
	local m = string.lower(tostring(message))
	local code = tonumber(string.match(m, "^%s*(%d%d%d)%s*:"))
	if code ~= nil then
		if code >= 301 and code <= 306 then return "throttle" end
		if code == 101 or code == 102 or code == 103 or code == 104 or code == 105 then return "value" end
		if code == 403 or code == 401 or code == 402 then return "config" end
	end
	if string.find(m, "studio access", 1, true) or string.find(m, "studioaccesstoapis", 1, true) or string.find(m, "not allowed", 1, true)
		or string.find(m, "publish", 1, true) or string.find(m, "disabled", 1, true) or string.find(m, "must be enabled", 1, true) then
		return "config"
	end
	if string.find(m, "throttl", 1, true) or string.find(m, "over limit", 1, true) or string.find(m, "request queue", 1, true) or string.find(m, "too many requests", 1, true) then
		return "throttle"
	end
	if string.find(m, "too large", 1, true) or string.find(m, "cannot store", 1, true) or string.find(m, "value size", 1, true) or string.find(m, "exceeds", 1, true) then
		return "value"
	end
	return "transient"
end

return SaveStores
