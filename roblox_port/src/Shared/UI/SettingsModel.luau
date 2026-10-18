--!strict
-- The settings as logic (ROBLOX-49): looking one up, cleaning a value, stepping it, saying it in words, putting everything back to the
-- defaults and carrying saved settings forward. Pure; the table itself is Shared/Data/SettingsSpec. Nothing here knows about Roblox, the
-- panel or the save: the panel (Client/SettingsPanel) and the save (Shared/Persistence/SaveProgress) both call these.
--
-- A value is clean when it has the kind's type and sits in its range. clean() never raises:
--   * an id this build does not know ................ dropped quietly (a newer build's setting must not break an older one)
--   * the wrong type, or a number that is not finite .. a problem (corruption, not a choice)
--   * a number outside the range ...................... clamped to it (a range may be tightened later; the value stays usable)
--   * a choice that is not an option .................. dropped quietly (an option may be removed later)
local SettingsSpec = require(script.Parent.Parent.Data.SettingsSpec)

local SettingsModel = {}

export type Value = boolean | number | string

local BY_ID: { [string]: SettingsSpec.Setting } = {}
local ORDER: { string } = {}
for _, s in SettingsSpec.LIST do
	BY_ID[s.id] = s
	table.insert(ORDER, s.id)
end

SettingsModel.VERSION = SettingsSpec.VERSION

-- Steps that carry saved settings from version N to N + 1: { [N] = function(values) -> values }. None yet (version 1 is the first).
SettingsModel.MIGRATIONS = {} :: { [number]: ({ [string]: any }) -> { [string]: any } }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

-- ---------------------------------------------------------------- the table
function SettingsModel.ids(): { string }
	return table.clone(ORDER)
end

function SettingsModel.spec(id: string): SettingsSpec.Setting?
	return BY_ID[id]
end

function SettingsModel.known(id: any): boolean
	return type(id) == "string" and BY_ID[id] ~= nil
end

-- The settings of one section, in the table's order.
function SettingsModel.items(sectionId: string): { SettingsSpec.Setting }
	local out: { SettingsSpec.Setting } = {}
	for _, s in SettingsSpec.LIST do
		if s.section == sectionId then table.insert(out, s) end
	end
	return out
end

function SettingsModel.sections(): { { id: string, title: string, items: { SettingsSpec.Setting } } }
	local out = {}
	for _, sec in SettingsSpec.SECTIONS do
		local items = SettingsModel.items(sec.id)
		if #items > 0 then table.insert(out, { id = sec.id, title = sec.title, items = items }) end
	end
	return out
end

function SettingsModel.default(id: string): Value?
	local s = BY_ID[id]
	return if s then s.default else nil
end

function SettingsModel.defaults(): { [string]: Value }
	local out: { [string]: Value } = {}
	for _, s in SettingsSpec.LIST do out[s.id] = s.default end
	return out
end

-- ---------------------------------------------------------------- cleaning
-- (clean value or nil, problem or nil). Both nil: the value is dropped quietly (see the header).
function SettingsModel.clean(id: any, value: any): (Value?, string?)
	if type(id) ~= "string" then return nil, "a setting without a name" end
	local s = BY_ID[id]
	if s == nil then return nil, nil end
	if s.kind == "toggle" then
		if type(value) ~= "boolean" then return nil, `setting {id} is not true or false` end
		return value, nil
	elseif s.kind == "slider" then
		if not finite(value) then return nil, `setting {id} is not a number` end
		return math.clamp(value :: number, s.min :: number, s.max :: number), nil
	else
		if type(value) ~= "string" then return nil, `setting {id} is not a choice` end
		for _, o in (s.options :: { SettingsSpec.Option }) do
			if o.id == value then return value, nil end
		end
		return nil, nil
	end
end

-- A value for a client's use: the clean one, else the default. `read(id)` gives whatever is held (a Player attribute) or nil.
function SettingsModel.get(read: (string) -> any, id: string): Value
	local s = BY_ID[id]
	if s == nil then error(`unknown setting {id}`) end
	local raw = read(id)
	if raw == nil then return s.default end
	local v = SettingsModel.clean(id, raw)
	if v == nil then return s.default end
	return v
end

-- Cleans a table of settings: (problems, clean copy). Unknown ids and values dropped quietly are left out of the copy.
function SettingsModel.cleanAll(raw: any, maxProblems: number?): ({ string }, { [string]: Value })
	local problems: { string } = {}
	local out: { [string]: Value } = {}
	if raw == nil then return problems, out end
	if type(raw) ~= "table" then return { "settings are not a table" }, out end
	local cap = maxProblems or 12
	for id, value in raw do
		local v, problem = SettingsModel.clean(id, value)
		if problem ~= nil then
			if #problems < cap then table.insert(problems, problem) end
		elseif v ~= nil then
			out[id] = v
		end
	end
	return problems, out
end

-- Carries settings written at `fromVersion` up to this build's VERSION. `steps` is for tests; the default is SettingsModel.MIGRATIONS.
function SettingsModel.migrate(values: { [string]: any }, fromVersion: number, steps: { [number]: ({ [string]: any }) -> { [string]: any } }?, toVersion: number?): { [string]: any }
	local table_ = steps or SettingsModel.MIGRATIONS
	local to = toVersion or SettingsModel.VERSION
	local out = values
	local v = fromVersion
	while v < to do
		local step = table_[v]
		if step ~= nil then out = step(table.clone(out)) end
		v += 1
	end
	return out
end

-- ---------------------------------------------------------------- changing
local function snap(s: SettingsSpec.Setting, x: number): number
	local step = s.step :: number
	local lo = s.min :: number
	local k = math.floor((x - lo) / step + 0.5)
	-- the grid's own value, rounded to the step's digits so 0.05 added three times is 0.15 and not 0.1500000001
	local digits = 0
	while digits < 6 and math.abs(step * 10 ^ digits - math.floor(step * 10 ^ digits + 0.5)) > 1e-9 do digits += 1 end
	local scale = 10 ^ digits
	return math.clamp(math.floor((lo + k * step) * scale + 0.5) / scale, lo, s.max :: number)
end

-- The value one step in `dir` (+1 or -1) from `current`: a toggle flips, a slider moves a step (and stays on its grid), a choice moves to the
-- next option and wraps. A current value that is not clean counts as the default.
function SettingsModel.step(id: string, current: any, dir: number): Value
	local s = BY_ID[id]
	if s == nil then error(`unknown setting {id}`) end
	local v = SettingsModel.clean(id, current)
	if v == nil then v = s.default end
	if s.kind == "toggle" then
		return not (v :: boolean)
	elseif s.kind == "slider" then
		local on = snap(s, v :: number)
		return snap(s, on + (if dir < 0 then -1 else 1) * (s.step :: number))
	else
		local options = s.options :: { SettingsSpec.Option }
		local at = 1
		for i, o in options do if o.id == v then at = i end end
		return options[(at - 1 + (if dir < 0 then -1 else 1)) % #options + 1].id
	end
end

-- Where a slider's value sits between its ends, 0 to 1 (for drawing the bar); 0 for the other kinds.
function SettingsModel.fraction(id: string, value: any): number
	local s = BY_ID[id]
	if s == nil or s.kind ~= "slider" then return 0 end
	local v = SettingsModel.clean(id, value)
	if v == nil then v = s.default end
	return ((v :: number) - (s.min :: number)) / ((s.max :: number) - (s.min :: number))
end

-- The value a slider takes when its bar is pressed at `fraction` (0 to 1) of the way along: on the grid.
function SettingsModel.fromFraction(id: string, fraction: number): Value?
	local s = BY_ID[id]
	if s == nil or s.kind ~= "slider" then return nil end
	local f = math.clamp(fraction, 0, 1)
	return snap(s, (s.min :: number) + f * ((s.max :: number) - (s.min :: number)))
end

function SettingsModel.isDefault(id: string, value: any): boolean
	local s = BY_ID[id]
	if s == nil then return false end
	local v = SettingsModel.clean(id, value)
	if v == nil then return true end
	if s.kind == "slider" then return math.abs((v :: number) - (s.default :: number)) < 1e-9 end
	return v == s.default
end

-- ---------------------------------------------------------------- words
local function trim(x: number, digits: number): string
	local text = string.format("%." .. digits .. "f", x)
	return text
end

-- The value in words: "On", "80%", "1.00x", "65 degrees", "5.0 studs", or the option's label.
function SettingsModel.valueText(id: string, value: any): string
	local s = BY_ID[id]
	if s == nil then return "" end
	local v = SettingsModel.clean(id, value)
	if v == nil then v = s.default end
	if s.kind == "toggle" then
		return if v then SettingsSpec.WORDS.on else SettingsSpec.WORDS.off
	elseif s.kind == "slider" then
		local x = v :: number
		if s.unit == "percent" then return `{math.floor(x * 100 + 0.5)}%`
		elseif s.unit == "times" then return trim(x, 2) .. "x"
		elseif s.unit == "degrees" then return `{math.floor(x + 0.5)} degrees`
		elseif s.unit == "studs" then return trim(x, 1) .. " studs"
		end
		return trim(x, 2)
	else
		for _, o in (s.options :: { SettingsSpec.Option }) do
			if o.id == v then return o.label end
		end
		return ""
	end
end

-- "Label: value" for a single line (a toggle shows On or Off).
function SettingsModel.line(id: string, value: any): string
	local s = BY_ID[id]
	if s == nil then return "" end
	return `{s.label}: {SettingsModel.valueText(id, value)}`
end

return SettingsModel
