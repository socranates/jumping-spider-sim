--!strict
-- The life clock: a port of the frozen scripts/life/life_clock.gd (LIFE-04). The windowsill's time of day and the spider's
-- age in days. It is one of three separate clocks: the fixed action tick (SpiderMotor.DT) is unchanged by it, so a jump is
-- never shortened when the day goes faster, and slow motion slows it with everything else because it is only ever advanced
-- by action time. While the spider is active the day passes slowly (ACTIVE_HOURS_PER_S game hours for each second of action
-- time); while it sleeps in its retreat at night the hours pass quickly (SLEEP_HOURS_PER_S), never more than one call's
-- worth at a time, until morning or until the sleep ends. It moves only when it is told to (LifeLoop, each fixed tick), so
-- the Roblox menu, which stops the ticks, never passes time.
-- Time is compressed on purpose. A real Phidippus audax lives about a year; one life here is meant to take a few hours to
-- play (LIFE-03: about 2 to 3 hours over roughly 10 game days).
-- Checked against Godot's own values in tests/life_reference.json (tools/export_life_reference.gd).

local LifeClock = {}
LifeClock.__index = LifeClock

-- The day: the spider wakes at WAKE_H, the light goes at DUSK_H and it is fully dark from NIGHT_H until DAWN_H.
LifeClock.WAKE_H = 7.0
LifeClock.DAWN_H = 6.0
LifeClock.DUSK_H = 19.0
LifeClock.NIGHT_H = 20.5
-- From this hour a rest in the retreat sleeps until morning (Phidippus goes into its nest before dark).
LifeClock.EVENING_H = 18.0
LifeClock.START_DAY = 1
LifeClock.START_H = 9.0
-- About 12 waking hours in about 15 minutes of play.
LifeClock.ACTIVE_HOURS_PER_S = 12.0 / (15.0 * 60.0)
-- A night of sleep (about 11 hours) in about 8 seconds.
LifeClock.SLEEP_HOURS_PER_S = 1.4

export type Record = { day: number, hour: number, sleeping: boolean }

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

-- Godot's fposmod: the remainder with the sign of the divisor.
local function fposmod(x: number, y: number): number
	local v = math.fmod(x, y)
	if (v < 0 and y > 0) or (v > 0 and y < 0) then
		v += y
	end
	return v
end

-- Godot's smoothstep (0 below `from`, 1 above `to`, the cubic in between).
local function smoothstep(from: number, to: number, x: number): number
	if from == to then
		return if x < from then 0 else 1
	end
	local s = math.clamp((x - from) / (to - from), 0, 1)
	return s * s * (3.0 - 2.0 * s)
end
LifeClock.smoothstep = smoothstep

function LifeClock.new(): any
	return setmetatable({ day = LifeClock.START_DAY, hour = LifeClock.START_H, sleeping = false }, LifeClock)
end

function LifeClock._addHours(self: any, hours: number)
	self.hour += hours
	while self.hour >= 24.0 do
		self.hour -= 24.0
		self.day += 1
	end
end

-- Lets `seconds` of action time pass. Asleep, the hours run at the sleeping rate, and a sleep that reaches the morning ends
-- there. Returns the game hours that passed.
function LifeClock.advance(self: any, seconds: number, asleep: boolean): number
	if not finite(seconds) or seconds <= 0.0 then
		return 0.0
	end
	local rate = if asleep then LifeClock.SLEEP_HOURS_PER_S else LifeClock.ACTIVE_HOURS_PER_S
	local hours = seconds * rate
	if asleep then
		local toMorning = self:hoursUntil(LifeClock.WAKE_H)
		if toMorning <= hours then
			hours = toMorning
			self.sleeping = false
		else
			self.sleeping = true
		end
	else
		self.sleeping = false
	end
	self:_addHours(hours)
	return hours
end

-- A moult passing: the hours run at the sleeping rate and do not stop at morning. Returns the hours that passed. (Moulting
-- itself is not ported yet; the clock keeps Godot's whole interface.)
function LifeClock.advanceMoult(self: any, seconds: number): number
	if not finite(seconds) or seconds <= 0.0 then
		return 0.0
	end
	self.sleeping = false
	local hours = seconds * LifeClock.SLEEP_HOURS_PER_S
	self:_addHours(hours)
	return hours
end

-- Hours from now until the clock next shows `target` (0 when it shows it now).
function LifeClock.hoursUntil(self: any, target: number): number
	return fposmod(target - self.hour, 24.0)
end

-- Whether a rest now would be a night's sleep: the evening, the night, or the early morning before waking.
function LifeClock.isSleepTime(self: any): boolean
	return self.hour >= LifeClock.EVENING_H or self.hour < LifeClock.WAKE_H
end

-- How much daylight there is, 0 (night) to 1 (full day), easing through dawn and dusk.
function LifeClock.daylightAt(hour: number): number
	local W, D, N, A = LifeClock.WAKE_H, LifeClock.DUSK_H, LifeClock.NIGHT_H, LifeClock.DAWN_H
	if hour >= W + 1.0 and hour <= D then
		return 1.0
	end
	if hour > D and hour < N then
		return 1.0 - smoothstep(D, N, hour)
	end
	if hour >= A and hour < W + 1.0 then
		return smoothstep(A, W + 1.0, hour)
	end
	return 0.0
end

function LifeClock.daylight(self: any): number
	return LifeClock.daylightAt(self.hour)
end

-- Words for the time of day, for the screen.
function LifeClock.partOfDay(self: any): string
	local h = self.hour
	if h >= 5.0 and h < 10.0 then return "morning" end
	if h >= 10.0 and h < 14.0 then return "midday" end
	if h >= 14.0 and h < 18.0 then return "afternoon" end
	if h >= 18.0 and h < 20.5 then return "evening" end
	return "night"
end

function LifeClock.toRecord(self: any): Record
	return { day = self.day, hour = self.hour, sleeping = self.sleeping }
end

-- What is wrong with a record, in Godot's words (an empty list for a good one).
function LifeClock.problems(d: any): { string }
	local e: { string } = {}
	if type(d) ~= "table" then
		table.insert(e, "life: not a record")
		return e
	end
	local dv = d.day
	if not (type(dv) == "number" and finite(dv) and dv == math.floor(dv)) or dv < 1 then
		table.insert(e, "life: the day is not a whole number from 1")
	end
	local hv = d.hour
	if type(hv) ~= "number" or not finite(hv) or hv < 0.0 or hv >= 24.0 then
		table.insert(e, "life: the hour is not in [0, 24)")
	end
	if type(d.sleeping) ~= "boolean" then
		table.insert(e, "life: 'sleeping' is not true or false")
	end
	return e
end

-- Restores a record made by toRecord. False, and nothing changed, for anything that is not one.
function LifeClock.load(self: any, d: any): boolean
	if #LifeClock.problems(d) > 0 then
		return false
	end
	self.day = d.day
	self.hour = d.hour
	self.sleeping = d.sleeping
	return true
end

return LifeClock
