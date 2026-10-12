extends Node
## The naturalist's notebook (LEARN-01; spec 4: "an optional naturalist notebook with sourced facts, separated from in-world perception").
## Nathan, 2026-10-11: "this could also teach people about jumping spiders right? ... presenting facts maybe as you learn to play".
## Each page of data/notebook/pages.json opens the first time its trigger happens in play: the first jump, the first time in the eye view,
## the first felt vibration, and so on. The notebook belongs to the player, not to the spider (spec 4, 11): it is kept in its own file,
## survives a return to the checkpoint and a new life, and is never part of the world's snapshot. It decides nothing in the game and the
## spider learns nothing from it. Opened pages are listed in the order they were found; pages not yet found are not shown or counted
## (spec 4: discovery must not become a completion checklist).

signal page_opened(id: String)

const PAGES_PATH := "res://data/notebook/pages.json"
const SECTION := "notebook"
## Triggers a page may name. "eye_time_N": N seconds in the spider-eye view, all told.
const TRIGGERS: Array[String] = ["start", "jump", "jump_far", "jump_long", "eye_view", "eye_time_20", "eye_time_60", "shimmer",
	"fly_recognised", "catch", "meal", "felt", "buzz", "rest", "sleep", "hungry", "well_fed"]
## LIFE_DESIGN.md round 1: the reserve at or under HUNGRY_AT is "hungry"; at or over WELL_FED_AT, "well_fed".
const HUNGRY_AT := 0.25
const WELL_FED_AT := 0.85
## A leap at least this long (WU, launch to landing point) is "jump_far"; at least JUMP_LONG_WU is "jump_long".
const JUMP_FAR_WU := 5.0
const JUMP_LONG_WU := 8.0

## Where the notebook is kept; "" keeps it in memory only (tests and captures).
var path: String = ""
## All pages, in the file's order: {id, trigger, title, text, game, sources}.
var pages: Array[Dictionary] = []
## Ids of the pages found so far, in the order they were found.
var opened: Array[String] = []
## Seconds spent in the spider-eye view, all told (kept with the notebook, so it is the player's).
var eye_seconds: float = 0.0
var _by_id: Dictionary = {}


func _init() -> void:
	load_pages()


func _exit_tree() -> void:
	save()


## Reads the pages. A page with a missing field or an unknown trigger is left out (tests check that none is).
func load_pages() -> void:
	pages.clear()
	_by_id.clear()
	var f := FileAccess.open(PAGES_PATH, FileAccess.READ)
	if f == null:
		push_error("notebook: cannot read %s" % PAGES_PATH)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary or not (data as Dictionary).get("pages") is Array:
		push_error("notebook: %s has no pages" % PAGES_PATH)
		return
	for raw: Variant in (data as Dictionary)["pages"]:
		if not raw is Dictionary:
			continue
		var p: Dictionary = raw
		if problems(p).is_empty() and not _by_id.has(str(p["id"])):
			pages.append(p)
			_by_id[str(p["id"])] = p


## What is wrong with a page, empty when nothing is.
static func problems(p: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for key in ["id", "trigger", "title", "text"]:
		if str(p.get(key, "")).strip_edges() == "":
			out.append("no %s" % key)
	if not TRIGGERS.has(str(p.get("trigger", ""))):
		out.append("unknown trigger %s" % str(p.get("trigger", "")))
	var sources: Variant = p.get("sources", [])
	if not sources is Array or (sources as Array).is_empty():
		out.append("no source")
	return out


func page(id: String) -> Dictionary:
	return _by_id.get(id, {})


func is_open(id: String) -> bool:
	return opened.has(id)


## Opens every page with this trigger that is not open yet. Returns the ids opened now.
func notice(trigger: String) -> Array[String]:
	var now: Array[String] = []
	for p: Dictionary in pages:
		var id := str(p["id"])
		if str(p["trigger"]) == trigger and not opened.has(id):
			opened.append(id)
			now.append(id)
	if not now.is_empty():
		save()
		for id in now:
			page_opened.emit(id)
	return now


## A leap of `distance_wu`: the first jump, and a far and a long one.
func notice_jump(distance_wu: float) -> void:
	notice("jump")
	if distance_wu >= JUMP_FAR_WU:
		notice("jump_far")
	if distance_wu >= JUMP_LONG_WU:
		notice("jump_long")


## Time in the spider-eye view (real seconds of play, scaled with the game like everything else).
func add_eye_time(seconds: float) -> void:
	var before := eye_seconds
	eye_seconds += maxf(seconds, 0.0)
	for mark in [20, 60]:
		if before < float(mark) and eye_seconds >= float(mark):
			notice("eye_time_%d" % mark)


func save() -> bool:
	if path == "":
		return true
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "opened", PackedStringArray(opened))
	cfg.set_value(SECTION, "eye_seconds", eye_seconds)
	return cfg.save(path) == OK


## Reads the player's notebook. A missing or unreadable file is an empty notebook; ids no page has any more are dropped.
func load_saved() -> void:
	opened.clear()
	eye_seconds = 0.0
	if path == "" or not FileAccess.file_exists(path):
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var ids: Variant = cfg.get_value(SECTION, "opened", PackedStringArray())
	if ids is PackedStringArray or ids is Array:
		for id: Variant in ids:
			if _by_id.has(str(id)) and not opened.has(str(id)):
				opened.append(str(id))
	var eye: Variant = cfg.get_value(SECTION, "eye_seconds", 0.0)
	if eye is float or eye is int:
		eye_seconds = maxf(float(eye), 0.0)
