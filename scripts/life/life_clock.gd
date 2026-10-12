extends RefCounted
## The life clock (spec 13; LIFE_DESIGN.md, round 1): the windowsill's time of day and the spider's age in days. It is one of three
## separate clocks: the action clock (SimClock) is unchanged by it, so a jump is never shortened when the day goes faster.
## While the spider is active the day passes slowly (ACTIVE_HOURS_PER_S of game hours for each second of action time); while it sleeps in
## its retreat at night the hours pass quickly (SLEEP_HOURS_PER_S), in steps no bigger than one tick's worth, until morning or until the
## sleep ends. It only moves when it is told to (the habitat loop, each physics tick): the paused game never advances it.
## Time is compressed on purpose. A real Phidippus audax lives about a year; one life here is meant to take a few hours to play
## (Nathan, LIFE-03: about 2 to 3 hours over roughly 10 game days). The notebook says so.

## The day: the spider wakes at WAKE_H, the light goes at DUSK_H and it is fully dark from NIGHT_H until DAWN_H.
const WAKE_H := 7.0
const DAWN_H := 6.0
const DUSK_H := 19.0
const NIGHT_H := 20.5
## From this hour, a rest in the retreat sleeps until morning (Phidippus goes into its nest before dark: LIFE_DESIGN.md).
const EVENING_H := 18.0
const START_DAY := 1
const START_H := 9.0
## About 12 waking hours in about 15 minutes of play.
const ACTIVE_HOURS_PER_S := 12.0 / (15.0 * 60.0)
## A night of sleep (about 11 hours) in about 8 seconds.
const SLEEP_HOURS_PER_S := 1.4

var day: int = START_DAY
var hour: float = START_H
## Whether the clock is passing a night of sleep right now.
var sleeping: bool = false


## Lets `seconds` of action time pass. Asleep, the hours run at the sleeping rate, and a sleep that reaches the morning ends there.
## Returns the game hours that passed.
func advance(seconds: float, asleep: bool) -> float:
	if not is_finite(seconds) or seconds <= 0.0:
		return 0.0
	var rate := SLEEP_HOURS_PER_S if asleep else ACTIVE_HOURS_PER_S
	var hours := seconds * rate
	if asleep:
		var to_morning := hours_until(WAKE_H)
		if to_morning <= hours:
			hours = to_morning
			sleeping = false
		else:
			sleeping = true
	else:
		sleeping = false
	_add_hours(hours)
	return hours


## A moult passing (LIFE_DESIGN round 3): the hours run at the sleeping rate and do not stop at morning. Returns the hours that passed.
func advance_moult(seconds: float) -> float:
	if not is_finite(seconds) or seconds <= 0.0:
		return 0.0
	sleeping = false
	var hours := seconds * SLEEP_HOURS_PER_S
	_add_hours(hours)
	return hours


func _add_hours(hours: float) -> void:
	hour += hours
	while hour >= 24.0:
		hour -= 24.0
		day += 1


## Hours from now until the clock next shows `target` (0 when it shows it now).
func hours_until(target: float) -> float:
	var h := fposmod(target - hour, 24.0)
	return h


## Whether a rest now would be a night's sleep: the evening, the night, or the early morning before waking.
func is_sleep_time() -> bool:
	return hour >= EVENING_H or hour < WAKE_H


## How much daylight there is, 0 (night) to 1 (full day), easing through dawn and dusk.
func daylight() -> float:
	if hour >= WAKE_H + 1.0 and hour <= DUSK_H:
		return 1.0
	if hour > DUSK_H and hour < NIGHT_H:
		return 1.0 - smoothstep(DUSK_H, NIGHT_H, hour)
	if hour >= DAWN_H and hour < WAKE_H + 1.0:
		return smoothstep(DAWN_H, WAKE_H + 1.0, hour)
	return 0.0


## Words for the time of day, for the screen.
func part_of_day() -> String:
	if hour >= 5.0 and hour < 10.0:
		return "morning"
	if hour >= 10.0 and hour < 14.0:
		return "midday"
	if hour >= 14.0 and hour < 18.0:
		return "afternoon"
	if hour >= 18.0 and hour < 20.5:
		return "evening"
	return "night"


func to_dict() -> Dictionary:
	return {"day": day, "hour": hour, "sleeping": sleeping}


## Restores a record made by to_dict. False, and nothing changed, for anything that is not one.
func load_dict(d: Dictionary) -> bool:
	if not problems(d).is_empty():
		return false
	day = int(d["day"])
	hour = float(d["hour"])
	sleeping = bool(d["sleeping"])
	return true


static func problems(d: Variant) -> PackedStringArray:
	var e := PackedStringArray()
	if typeof(d) != TYPE_DICTIONARY:
		e.append("life: not a record")
		return e
	var r: Dictionary = d
	var dv: Variant = r.get("day")
	if not (typeof(dv) == TYPE_INT or (typeof(dv) == TYPE_FLOAT and is_finite(float(dv)) and float(dv) == floorf(float(dv)))) or int(dv) < 1:
		e.append("life: the day is not a whole number from 1")
	var hv: Variant = r.get("hour")
	if not (typeof(hv) == TYPE_INT or typeof(hv) == TYPE_FLOAT) or not is_finite(float(hv)) or float(hv) < 0.0 or float(hv) >= 24.0:
		e.append("life: the hour is not in [0, 24)")
	if typeof(r.get("sleeping")) != TYPE_BOOL:
		e.append("life: 'sleeping' is not true or false")
	return e
