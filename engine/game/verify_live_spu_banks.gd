extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for observation in [{"room":"MP033_02.MAP","count":33,"end":0x4dad0},{"room":"MP033_01.MAP","count":29,"end":0x3e580},{"room":"MP033_02.MAP","count":33,"end":0x4dad0}]:
		assert(world.load_room(observation.room))
		assert(world.source_spu_layout_fault.is_empty())
		assert(world.source_spu_layout.resident_samples.size() == observation.count)
		assert(world.source_spu_layout.cursor == observation.end)
		assert(world.source_spu_layout.permanent_boundary == 7 and world.source_spu_layout.controller_boundary == 22)
	var sample_address := -1
	for sample in world.source_spu_layout.resident_samples:
		if sample.name == "NEPTTAIL": sample_address = int(sample.address)
	assert(sample_address == 0x429b0)
	var boss = world.source_actors[0]
	var sound_handle: int = boss.asl_asset({"kind":4,"name":"NEPTTAIL"},boss.vm)>>16
	assert(sound_handle > 0)
	world.source_spawn_scratch.camera_query(0x80080f78)
	world.source_transition_state = 0
	assert(boss.asl_command({"op":9,"args":[1,[{"op":4,"value":sound_handle<<16},{"op":18}]]},boss.vm) == "continue")
	assert(world.source_spawn_scratch.pose().words[1] == sample_address)
	world.source_spawn_scratch.sound_header(123)
	world.source_audio_master_gain = 0
	assert(boss.asl_command({"op":9,"args":[1,[{"op":4,"value":sound_handle<<16},{"op":18}]]},boss.vm) == "continue")
	assert(world.source_spawn_scratch.pose().words[1] == 123)
	world.source_audio_master_gain = 127
	world.source_voice_pool.reserved.fill(true)
	assert(world.play_imported_sound_voice(boss.handles[sound_handle],Vector3.ZERO,100.0,0,true) == -1)
	assert(world.play_imported_sound(boss.handles[sound_handle],Vector3.ZERO,100.0,0,true))
	assert(world.source_spawn_scratch.pose().words[1] == 123)
	world.source_voice_pool.reserved.fill(false)
	world.source_spu_layout.resident_samples.clear()
	var cursor: int = world.source_voice_pool.cursor
	assert(not world.play_imported_sound(boss.handles[sound_handle],Vector3.ZERO,100.0,0,true))
	assert(not world.source_spu_layout_fault.is_empty())
	assert(world.source_voice_pool.cursor == cursor and world.source_spawn_scratch.pose().words[1] == 123)
	var retired: Array[WeakRef] = []
	for voice in world.sound_voices:
		retired.append(weakref(voice.player.generator_playback))
		retired.append(weakref(voice.player.stream))
	assert(not retired.is_empty())
	world.queue_free();await process_frame
	var retirement := root.get_node("SourceSpuStreamRetirement")
	var deadline := Time.get_ticks_msec()+2000
	while not retirement.pending.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	assert(retirement.pending.is_empty())
	for reference in retired: assert(reference.get_ref() == null)
	print("PASS: actual room loading retains/replaces original sound banks through Neptuna revisit and restores the native NEPTTAIL address")
	quit(0)
