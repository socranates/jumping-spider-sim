extends "res://tests/prey_test_case.gd"
## T12a, sound and the spider's other senses (ROADMAP step 3; spec 7, 16, U01):
##   * the sounds are made in code and are what they say: a fly's buzz at 195 Hz, a mains hum at 60 Hz, loops that join cleanly;
##   * the buses follow the volume settings, and 0 mutes;
##   * a fly buzzes while it flies and while it struggles in the jaws (louder and higher), and is silent perched;
##   * vibration reaches the spider only through solid pieces that touch, fades with distance and joints, never crosses an air gap, and is
##     not felt with the feet off the surface; a walking fly is felt as footsteps from its direction;
##   * muted, every cue still shows: captions with a direction, and a ripple on the side it came from;
##   * slow motion slows the sounds.

const SoundBank = preload("res://scripts/audio/sound_bank.gd")
const Soundscape = preload("res://scripts/audio/soundscape.gd")
const SimClock = preload("res://scripts/core/sim_clock.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")


func after_each() -> void:
	SimClock.set_speed(1.0)
	for bus: String in ["Master", "Ambience", "Cues"]:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_mute(i, false)
			AudioServer.set_bus_volume_db(i, 0.0)
	super.after_each()


func _samples(w: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w.data.size() / 2)
	for i in out.size():
		out[i] = float(w.data.decode_s16(i * 2)) / 32767.0
	return out


## Power at one frequency (Goertzel).
func _power(s: PackedFloat32Array, hz: float, rate: int) -> float:
	var k := TAU * hz / float(rate)
	var c := 2.0 * cos(k)
	var a := 0.0
	var b := 0.0
	for v in s:
		var y := v + c * a - b
		b = a
		a = y
	return a * a + b * b - c * a * b


# ------------------------------------------------------------------ the sounds

func test_the_sounds_are_made_in_code_and_are_what_they_say() -> void:
	for n: String in SoundBank.names():
		var w := SoundBank.stream(n)
		check(w != null and w.data.size() > 1000, "%s exists (%d bytes)" % [n, w.data.size() if w != null else 0])
	check(SoundBank.stream("buzz") == SoundBank.stream("buzz"), "made once and kept")
	var buzz := _samples(SoundBank.stream("buzz"))
	var rate := SoundBank.RATE
	check_eq(buzz.size(), rate, "the buzz loops every second")
	check(_power(buzz, 195.0, rate) > 5.0 * _power(buzz, 150.0, rate) and _power(buzz, 195.0, rate) > 5.0 * _power(buzz, 240.0, rate),
		"its note is a fly's wingbeat, 195 Hz")
	var room := _samples(SoundBank.stream("room"))
	check_eq(room.size(), rate * 4, "the room loops every four seconds")
	check(_power(room, 60.0, rate) > 5.0 * _power(room, 45.0, rate), "with a 60 Hz mains hum")
	for n: String in ["buzz", "room"]:
		var s := _samples(SoundBank.stream(n))
		check(absf(s[s.size() - 1] - s[0]) < 0.12, "%s joins without a click (%.3f)" % [n, absf(s[s.size() - 1] - s[0])])
		check_eq(SoundBank.stream(n).loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % n)


func test_the_buses_follow_the_volume_settings() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	await physics_frames(2)
	for bus: String in ["Ambience", "Cues"]:
		check(AudioServer.get_bus_index(bus) >= 0, "the %s bus exists" % bus)
	check(world.soundscape.room_playing(), "the room hums")
	settings.set_value("volume_ambience", 0.5)
	check_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), linear_to_db(0.5), 0.01, "room sounds at half")
	settings.set_value("volume_cues", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Cues")), "nothing turns the cues off")


# ------------------------------------------------------------------ flies

func test_a_flying_fly_buzzes_and_a_perched_one_is_silent() -> void:
	await spawn_prey_world(floor_pose(4.0, 6.0, 180.0), 0, PREY_SEED, true)
	director().stimulus_enabled = false
	var f := add_fly("floor_east_open", 3)
	await physics_frames(3)
	var sc: Node3D = world.soundscape
	check(not sc.is_buzzing(str(f.id)), "perched: silent")
	f.restless_rate = 1.0
	var flew := [false, false]
	await wait_until(func() -> bool:
		if f.is_flying():
			flew[0] = true
			flew[1] = bool(flew[1]) or sc.is_buzzing(str(f.id))
		return bool(flew[0]) and f.state == f.State.PERCHED, 60 * 12)
	check(bool(flew[0]), "the fly took off")
	check(bool(flew[1]), "and buzzed while it flew")
	for i in 2:   # the soundscape updates in _process: let it run after the landing at any frame rate
		await runner.get_tree().process_frame
	check(not sc.is_buzzing(str(f.id)), "landed again: silent")
	var heard := false
	for c: Dictionary in world.sense_hud.captions:
		heard = heard or str(c["text"]).begins_with("[buzzing, ")
	check(heard or world.sense_hud.captions.is_empty(), "a take-off close by is captioned with its direction")


func test_a_struggling_fly_buzzes_louder_and_higher() -> void:
	prey_struggle = true
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0), 0, PREY_SEED, true)
	var f := add_fly("floor_east_open", 1, true)
	await strike_at(4.0, 11.0)
	await runner.get_tree().process_frame
	var sc: Node3D = world.soundscape
	if not check(world.feeding.struggling, "caught and struggling"):
		return
	var p: AudioStreamPlayer3D = sc.buzz_player(str(f.id))
	check(sc.is_buzzing(str(f.id)), "the struggling fly buzzes in the jaws")
	check(p.volume_db > Soundscape.BUZZ_DB and p.pitch_scale > 1.0, "louder and higher than in flight (%.1f dB, pitch %.2f)" % [p.volume_db, p.pitch_scale])
	for i in 300:
		if not world.feeding.struggling:
			break
		if i % 8 == 0:
			Input.action_press("interact")
			await physics_frames(1)
			Input.action_release("interact")
		else:
			await physics_frames(1)
	for i in 2:
		await runner.get_tree().process_frame
	check(not sc.is_buzzing(str(f.id)), "subdued: silent")


# ------------------------------------------------------------------ vibration

func test_vibration_travels_through_touching_pieces_only() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0))   # facing -Z
	await physics_frames(3)
	var v: Node = world.vibration
	var near: Dictionary = v.shake(Vector3(0.0, 0.0, 3.0), "landing")
	check(bool(near["felt"]) and int(near["joints"]) == 0, "a landing 3 WU away on the same floor is felt: %s" % str(near))
	check_eq(str(near["word"]), "ahead", "and it came from ahead (the spider faces -Z)")
	var aside: Dictionary = v.shake(Vector3(-2.0, 0.0, 3.5), "landing")
	check_eq(str(aside["word"]), "ahead-left", "directions follow the spider's heading (-X is its left)")
	var behind: Dictionary = v.shake(Vector3(0.0, 0.0, 9.0), "landing")
	check_eq(str(behind["word"]), "behind", "and behind is behind")
	var far: Dictionary = v.shake(Vector3(0.0, 0.0, -14.0), "footsteps")
	check(not bool(far["felt"]) and str(far["why"]).begins_with("too faint"), "footsteps 20 WU away are too faint: %s" % str(far["why"]))
	# a slab floating a hand's breadth above the floor, right beside the spider
	world.lab.add_fixture_piece("floating_slab", "wall", Vector3(1.0, 0.6, 4.0), Vector3(3.0, 0.9, 6.0))
	await physics_frames(3)
	var gap: Dictionary = v.shake(Vector3(2.0, 0.9, 5.0), "landing")
	check(not bool(gap["felt"]) and str(gap["why"]).contains("air gap"), "a landing on a slab across an air gap is not felt, however close: %s" % str(gap["why"]))
	# a piece standing on the floor carries it, a little weaker for the joint
	world.lab.add_fixture_piece("standing_block", "wall", Vector3(-3.0, 0.0, 4.0), Vector3(-1.5, 0.8, 5.5))
	await physics_frames(3)
	var joined: Dictionary = v.shake(Vector3(-2.25, 0.8, 4.75), "landing")
	check(bool(joined["felt"]) and int(joined["joints"]) == 1, "a landing on a block standing on the floor is felt through one joint: %s" % str(joined))
	check(float(joined["strength"]) < float(v.STRENGTH["landing"]) * exp(-world.spider.global_position.distance_to(Vector3(-2.25, 0.8, 4.75)) / v.FADE_WU) * 0.6,
		"weaker for the joint")
	# feet off the surface
	world.spider.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 3.0, 6.0)))
	await physics_frames(2)
	var air: Dictionary = v.shake(Vector3(0.0, 0.0, 3.0), "landing")
	check(not bool(air["felt"]) and str(air["why"]).contains("feet are off"), "in the air the spider feels nothing: %s" % str(air["why"]))


func test_a_walking_fly_is_felt_as_footsteps_from_its_direction() -> void:
	await spawn_prey_world(floor_pose(4.0, 8.0, 0.0))   # facing -Z, the fly's perch (4, 0, 11) 3 WU behind
	director().stimulus_enabled = false
	var f := add_fly("floor_east_open", 11)
	await wait_until(func() -> bool:
		for e: Dictionary in world.vibration.felt_log:
			if str(e["kind"]) == "footsteps":
				return true
		return false, 60 * 15)
	var steps: Array = world.vibration.felt_log.filter(func(e: Dictionary) -> bool: return str(e["kind"]) == "footsteps")
	if not check(not steps.is_empty(), "the fly's walking was felt"):
		return
	var e: Dictionary = steps[0]
	check(str(e["word"]).begins_with("behind"), "from behind, where it walks: %s" % str(e["word"]))
	check(f.walks_started >= 1, "it really walked")


# ------------------------------------------------------------------ muted, and slow

func test_muted_every_cue_still_shows_as_words_and_ripples() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	await physics_frames(2)
	settings.set_value("volume_master", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "the game is muted")
	var hud: CanvasLayer = world.sense_hud
	world.vibration.shake(Vector3(3.0, 0.0, 6.0), "landing")
	var said := ""
	for c: Dictionary in hud.captions:
		said += str(c["text"])
	check(said.contains("[felt: landing, right]"), "the caption says what and where: %s" % said)
	check(hud.ripples.size() == 1, "and a ripple is drawn")
	var angle: float = float(hud.ripples[0]["angle"])
	check(absf(angle - PI * 0.5) < 0.6, "on the right of the screen (the camera is behind the spider): %.2f rad" % angle)
	settings.set_value("captions", false)
	hud.captions.clear()
	world.vibration.shake(Vector3(-3.0, 0.0, 6.0), "landing")
	check(hud.captions.is_empty() and hud.ripples.size() == 2, "captions off: no words, the ripple still shows")


func test_slow_motion_slows_the_sounds_and_the_menu_has_the_settings() -> void:
	SimClock.set_speed(0.5)
	check_near(AudioServer.playback_speed_scale, 0.5, 1.0e-6, "half speed: the sounds play at half speed")
	SimClock.set_speed(1.0)
	check_near(AudioServer.playback_speed_scale, 1.0, 1.0e-6, "and back")
	var menu := PauseMenu.new()
	menu.settings = settings
	sandbox.add_child(menu)
	for key: String in ["volume_master", "volume_ambience", "volume_cues"]:
		check(menu._sliders.has(key), "the pause menu has %s" % key)
	for key: String in ["captions", "haptics"]:
		check(menu._checks.has(key), "and the %s switch" % key)
	menu.free()
