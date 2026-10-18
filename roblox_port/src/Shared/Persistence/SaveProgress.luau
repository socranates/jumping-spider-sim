--!strict
-- The player's progress record (ROBLOX-39): the small precious part of a save, kept apart from the world's rests.
--   { notebook = { opened = { page ids }, eye_seconds }, finished_main, appearance, prefs = { [name] = boolean } }
-- notebook: the pages found (FieldNotebook.toRecord) and the seconds in the eye view. finished_main: a main-life Standard spider became an
-- adult, which opens Easy (Session.finishedMain; there is no separate "adult reached", it is the same fact). appearance: the spider the
-- player chose (a free choice, the peacock included). prefs: the toggles the client reads from Player attributes (SaveRules.PREF_KEYS).
-- Everything is bounded. Merging is monotonic where it can be (pages found are a union, the longest eye time and a finished main life
-- stay), and the last change wins for the choices. Unknown page ids that are well formed are kept: a build that lost a page must not
-- erase what a newer build found. Pure; checked in tests/state.luau.
local SaveRules = require(script.Parent.Parent.Data.SaveRules)
local SaveEnvelope = require(script.Parent.SaveEnvelope)

local SaveProgress = {}

SaveProgress.SCHEMA = 1
export type Payload = { notebook: { opened: { string }, eye_seconds: number }, finished_main: boolean, appearance: string?, prefs: { [string]: boolean } }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function goodId(id: any): boolean
	return type(id) == "string" and #id >= 1 and #id <= SaveRules.MAX_ID_CHARS and string.match(id, "^[%w_]+$") ~= nil
end

local PREF_SET: { [string]: boolean } = {}
for _, k in SaveRules.PREF_KEYS do PREF_SET[k] = true end

function SaveProgress.default(): Payload
	return { notebook = { opened = {}, eye_seconds = 0 }, finished_main = false, appearance = nil, prefs = {} }
end

-- Checks a payload and returns (problems, cleaned copy). A wrongly typed or out-of-range field is a problem; a repeat page id and a
-- preference this build does not know are dropped quietly. `cleaned` is always a fresh table of the right shape (or nil with problems).
function SaveProgress.sanitize(raw: any): ({ string }, Payload?)
	local problems: { string } = {}
	local function bad(t: string) if #problems < 12 then table.insert(problems, t) end end
	if type(raw) ~= "table" then return { "progress is not a table" }, nil end
	local out = SaveProgress.default()
	local nb = raw.notebook
	if type(nb) ~= "table" then
		bad("no notebook")
	else
		if type(nb.opened) ~= "table" then
			bad("the notebook's pages are not a list")
		else
			local n = 0
			for _ in nb.opened do n += 1 end
			if n > SaveRules.MAX_PAGES or #nb.opened ~= n then
				bad("too many pages, or not a list")
			else
				local seen: { [string]: boolean } = {}
				for _, id in nb.opened do
					if not goodId(id) then bad("a page id that is not a short plain name"); break end
					if not seen[id] then
						seen[id] = true
						table.insert(out.notebook.opened, id)
					end
				end
			end
		end
		local eye = nb.eye_seconds
		if not finite(eye) or eye < 0 or eye > SaveRules.MAX_EYE_SECONDS then bad("eye seconds out of range") else out.notebook.eye_seconds = eye end
	end
	if type(raw.finished_main) ~= "boolean" then bad("finished_main is not true or false") else out.finished_main = raw.finished_main end
	if raw.appearance ~= nil then
		if not goodId(raw.appearance) then bad("the appearance is not a short plain name") else out.appearance = raw.appearance end
	end
	if raw.prefs ~= nil then
		if type(raw.prefs) ~= "table" then
			bad("preferences are not a table")
		else
			for k, v in raw.prefs do
				if type(k) ~= "string" then
					bad("a preference without a name")
				elseif PREF_SET[k] then
					if type(v) ~= "boolean" then bad(`preference {k} is not true or false`) else out.prefs[k] = v end
				end
			end
		end
	end
	if #problems > 0 then return problems, nil end
	return problems, out
end

-- The envelope spec of this kind. Schema 1 is the first; add a migration here when the payload changes shape (see tests/state.luau
-- for the pattern under test).
SaveProgress.SPEC = {
	kind = "progress", current = SaveProgress.SCHEMA,
	migrations = {} :: { [number]: (any) -> any },
	validate = function(payload: any): ({ string }, any?) return SaveProgress.sanitize(payload) end,
} :: SaveEnvelope.Spec

-- Merges two payloads: `base` (stored) and `incoming` (this session's). Pages are a union (base order first), eye seconds the longest,
-- a finished main life stays finished; the appearance and the preferences come from `incoming` when it is at least as new
-- (`incomingTime` >= `baseTime`), else from `base`. Both must already be sanitized. Returns a fresh payload; trims to the page cap.
function SaveProgress.merge(base: Payload, incoming: Payload, baseTime: number, incomingTime: number): Payload
	local out = SaveProgress.default()
	local seen: { [string]: boolean } = {}
	for _, list in { base.notebook.opened, incoming.notebook.opened } do
		for _, id in list do
			if not seen[id] and #out.notebook.opened < SaveRules.MAX_PAGES then
				seen[id] = true
				table.insert(out.notebook.opened, id)
			end
		end
	end
	out.notebook.eye_seconds = math.max(base.notebook.eye_seconds, incoming.notebook.eye_seconds)
	out.finished_main = base.finished_main or incoming.finished_main
	local newer, older = incoming, base
	if incomingTime < baseTime then newer, older = base, incoming end
	out.appearance = if newer.appearance ~= nil then newer.appearance else older.appearance
	for k, v in older.prefs do out.prefs[k] = v end
	for k, v in newer.prefs do out.prefs[k] = v end
	return out
end

-- Whether two payloads say the same thing (for deciding whether a write would change anything).
function SaveProgress.same(a: Payload, b: Payload): boolean
	if a.finished_main ~= b.finished_main or a.appearance ~= b.appearance or a.notebook.eye_seconds ~= b.notebook.eye_seconds then return false end
	if #a.notebook.opened ~= #b.notebook.opened then return false end
	for i, id in a.notebook.opened do if b.notebook.opened[i] ~= id then return false end end
	for k, v in a.prefs do if b.prefs[k] ~= v then return false end end
	for k, v in b.prefs do if a.prefs[k] ~= v then return false end end
	return true
end

-- The payload the client sends, built from what it holds. `prefs` maps a preference name to its current boolean or nil (not set).
function SaveProgress.snapshot(notebookRecord: any, finishedMain: boolean, appearance: string?, prefs: { [string]: boolean? }): Payload
	local out = SaveProgress.default()
	if type(notebookRecord) == "table" then
		if type(notebookRecord.opened) == "table" then
			for _, id in notebookRecord.opened do
				if goodId(id) and #out.notebook.opened < SaveRules.MAX_PAGES and not table.find(out.notebook.opened, id) then table.insert(out.notebook.opened, id) end
			end
		end
		if finite(notebookRecord.eye_seconds) and notebookRecord.eye_seconds >= 0 then out.notebook.eye_seconds = math.min(notebookRecord.eye_seconds, SaveRules.MAX_EYE_SECONDS) end
	end
	out.finished_main = finishedMain
	if appearance ~= nil and goodId(appearance) then out.appearance = appearance end
	for _, k in SaveRules.PREF_KEYS do
		local v = prefs[k]
		if type(v) == "boolean" then out.prefs[k] = v end
	end
	return out
end

return SaveProgress
