extends "res://tests/prey_test_case.gd"
const WaspBody = preload("res://scripts/predator/wasp_body.gd")
const SoundBank = preload("res://scripts/audio/sound_bank.gd")

func test_jointed_wasp_modes_are_finite_repeatable_and_do_not_add_meshes() -> void:
	var b := WaspBody.new()
	sandbox.add_child(b)
	check_eq(b._legs.size(),6,"six legs")
	check_eq(b._wings.size(),4,"two wing pairs")
	var n := b.find_children("*","MeshInstance3D",true,false).size()
	for mode in [WaspBody.Mode.FLYING,WaspBody.Mode.WALKING,WaspBody.Mode.HOLDING]:
		b.pose(mode,0.37,1.0)
		var poses: Array[Transform3D] = []
		for part in b.find_children("*","MeshInstance3D",true,false):
			check(part.transform.is_finite(),"finite geometry")
			poses.append(part.transform)
		b.pose(mode,0.37,1.0)
		var i := 0
		for part in b.find_children("*","MeshInstance3D",true,false):
			check_eq(part.transform,poses[i],"absolute-time pose is repeatable")
			i += 1
		check_eq(i,n,"poses reuse the same meshes")
	b.pose(WaspBody.Mode.WALKING,0.0,0.0)
	var walk: Transform3D = b._legs[0].get_child(2).transform
	b.pose(WaspBody.Mode.HOLDING,0.0,0.0)
	check(b._legs[0].get_child(2).transform != walk,"front feet fold to carry")
	b.queue_free()

func test_seized_spider_stays_tucked_at_every_growth_stage() -> void:
	for stage in 4:
		use_windowsill = true
		await spawn_prey_world(floor_pose(-25,6,-90),0,PREY_SEED,false)
		var s: Node3D = world.spider
		var b: Node3D = s.get_node("Body")
		b.set_growth_stage(stage)
		b.start_recoil(Vector3.RIGHT)
		s.seize()
		await physics_frames(2)
		var pose: Transform3D = b.transform
		var feet: Array = b.legs.foot_positions()
		for i in 8:
			check(not b.legs.is_planted(i),"no abandoned surface anchor")
			check(absf(feet[i].x)<0.20,"tips drawn beneath body")
		await physics_frames(35)
		check_eq(b.transform,pose,"no twitch or recoil after seizure")
		check_eq(b.legs.foot_positions(),feet,"no leg cycle after seizure")
		check_vec_near(s.scale,Vector3.ONE,1e-6,"motor scale unchanged")

func test_warning_hum_starts_in_arrival_and_stops_after_visit() -> void:
	use_windowsill = true
	await spawn_prey_world(floor_pose(-25,6,-90),0,PREY_SEED,true)
	world.wasp_director.force_visit("floor_middle")
	world.soundscape._update_wasp()
	check(world.soundscape.wasp_humming(),"hum present from warning phase")
	check_eq(world.wasp_director.phase_name(),"arriving","no search before warning")
	check_eq(str(world.soundscape._wasp_hum.bus),"Cues","cue volume/mute apply")
	world.wasp_director.wasp.visible = false
	world.soundscape._update_wasp()
	check(not world.soundscape.wasp_humming(),"no lingering hum")

func test_wasp_sample_is_looped_and_has_small_speaker_harmonics() -> void:
	var wav := SoundBank.stream("wasp")
	check_eq(wav.loop_mode,AudioStreamWAV.LOOP_FORWARD,"warning loops")
	var n := wav.data.size()/2
	var power := 0.0
	var upper := 0.0
	for hz in [120.0,480.0,720.0,960.0,1440.0]:
		var re := 0.0
		var im := 0.0
		for i in n:
			var v := float(wav.data.decode_s16(i*2))/32768.0
			re += v*cos(TAU*hz*i/SoundBank.RATE)
			im += v*sin(TAU*hz*i/SoundBank.RATE)
		var energy := re*re+im*im
		if hz==120.0:
			power = energy
		else:
			upper += energy
	check(upper>power,"upper warning content survives bass loss")
