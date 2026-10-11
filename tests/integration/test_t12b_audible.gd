extends "res://tests/prey_test_case.gd"
## T12b (Nathan: "i dont hear anything while playing"; "you can optomize for headphones or have a setting for switvhing"). A recording of the
## game's own mix had 91 % of its energy below 400 Hz, which laptop speakers barely play. Now:
##   * every sound has enough upper content to come through small speakers (its effective frequency, from the energy of its slope, is
##     well above 300 Hz; before T12b the thrum's was 133 Hz and the thud's 238 Hz);
##   * "headphones" off (the default) shapes Master for speakers: the deep bass cut, the presence lifted, a little louder; on, the full
##     range; a limiter keeps every peak under -1 dBFS in both.

const SoundBank = preload("res://scripts/audio/sound_bank.gd")
const Soundscape = preload("res://scripts/audio/soundscape.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")


func after_each() -> void:
	var m := AudioServer.get_bus_index("Master")
	for e in mini(Soundscape.SPEAKER_EFFECTS, AudioServer.get_bus_effect_count(m)):
		AudioServer.set_bus_effect_enabled(m, e, true)
	for bus: String in ["Master", "Ambience", "Cues"]:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_mute(i, false)
			AudioServer.set_bus_volume_db(i, 0.0)
	super.after_each()


## The frequency of a pure tone with the same ratio of slope energy to energy: a rough "how bright is it".
func _effective_hz(w: AudioStreamWAV) -> float:
	var e := 0.0
	var d := 0.0
	var prev := 0.0
	for i in w.data.size() / 2:
		var v := float(w.data.decode_s16(i * 2)) / 32767.0
		e += v * v
		d += (v - prev) * (v - prev)
		prev = v
	return asin(clampf(sqrt(d / maxf(e, 1.0e-12)) / 2.0, 0.0, 1.0)) * float(SoundBank.RATE) / PI


func test_every_sound_comes_through_small_speakers() -> void:
	for n: String in SoundBank.names():
		var hz := _effective_hz(SoundBank.stream(n))
		check(hz >= 350.0, "%s has enough upper content for a laptop's speakers (effective %d Hz)" % [n, roundi(hz)])
	check(SoundBank.names().has("birds"), "and there are birds outside the window")


func test_speakers_or_headphones_and_a_limit_on_every_peak() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	await physics_frames(2)
	var m := AudioServer.get_bus_index("Master")
	check(AudioServer.get_bus_effect_count(m) >= 3, "Master has the speaker shaping and a limiter")
	check(Soundscape.speaker_mode(), "speakers by default")
	check(AudioServer.get_bus_effect(m, 0) is AudioEffectEQ6 and (AudioServer.get_bus_effect(m, 0) as AudioEffectEQ6).get_band_gain_db(0) < -12.0,
		"the deep bass that small speakers cannot play is cut")
	var limiter := AudioServer.get_bus_effect(m, 2) as AudioEffectHardLimiter
	check(limiter != null and AudioServer.is_bus_effect_enabled(m, 2) and limiter.ceiling_db <= -1.0, "and every peak is held under -1 dBFS")
	settings.set_value("headphones", true)
	check(not Soundscape.speaker_mode() and not AudioServer.is_bus_effect_enabled(m, 1), "headphones: the full range, no shaping")
	check(AudioServer.is_bus_effect_enabled(m, 2), "the limiter stays")
	settings.set_value("headphones", false)
	check(Soundscape.speaker_mode(), "and back to speakers")
	var menu := PauseMenu.new()
	menu.settings = settings
	sandbox.add_child(menu)
	var box: CheckBox = menu._checks.get("headphones")
	check(box != null and box.text.begins_with("Headphones"), "the pause menu has the switch")
	menu.free()
