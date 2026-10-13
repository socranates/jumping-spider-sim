extends RefCounted
## The player's progress across lives (LIFE round 5; MODES-01). Like the notebook it belongs to the player, not to a world: it is kept in
## its own file (only when the player's settings are saved; tests and captures keep it in memory), survives every new world, and is never
## part of a checkpoint.
##   * finished_main_life: one spider of the main life has reached adulthood. That opens Easy for later main lives (MODES-01). Free play
##     and lives on Easy never count toward it.
##   * deaths, and the summaries of lives that ended (newest last, at most MAX_LIVES): what the end-of-life screen showed.

const SECTION := "progress"
const MAX_LIVES := 30

## Where it is kept; "" keeps it in memory only.
var path := ""
var finished_main_life := false
var deaths := 0
var lives: Array[Dictionary] = []


func easy_unlocked() -> bool:
	return finished_main_life


## The main life has been finished. True when this is the first time.
func finish_main_life() -> bool:
	if finished_main_life:
		return false
	finished_main_life = true
	save()
	return true


func record_death() -> void:
	deaths += 1
	save()


## A life that has ended for good (the player went on as another spider).
func record_life(summary: Dictionary) -> void:
	lives.append(summary.duplicate(true))
	while lives.size() > MAX_LIVES:
		lives.pop_front()
	save()


func save() -> bool:
	if path == "":
		return true
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "finished_main_life", finished_main_life)
	cfg.set_value(SECTION, "deaths", deaths)
	cfg.set_value(SECTION, "lives", lives)
	return cfg.save(path) == OK


## Reads the player's progress. A missing or unreadable file is no progress; values of the wrong kind are ignored.
func load_saved() -> void:
	finished_main_life = false
	deaths = 0
	lives.clear()
	if path == "" or not FileAccess.file_exists(path):
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var f: Variant = cfg.get_value(SECTION, "finished_main_life", false)
	finished_main_life = f is bool and bool(f)
	var d: Variant = cfg.get_value(SECTION, "deaths", 0)
	deaths = maxi(int(d), 0) if d is int else 0
	var l: Variant = cfg.get_value(SECTION, "lives", [])
	if l is Array:
		for item: Variant in l:
			if item is Dictionary:
				lives.append(item)
