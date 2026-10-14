extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var session = preload("res://source_options_session.gd")
	var state: Dictionary = session.initialize({"music":world.source_music_volume,"effects":world.source_effects_volume,"mode":world.source_cd_stereo_flag})
	state.page = 3;state.navigation = preload("res://source_main_menu.gd").initialize(0,3)
	state = session.advance(state,0,0x80000)
	if not world.apply_source_options_audio(state) or world.source_music_volume!=88 or world.source_cd_mix_state.mix!=[88,88,0,0]:quit(1);return
	state.navigation.selected = 1
	state = session.advance(state,0,0x20000)
	if not world.apply_source_options_audio(state) or world.source_effects_volume!=120 or world.source_audio_master_maximum!=119 or world.source_effects_restore_volume!=127:quit(1);return
	var previous := [world.source_music_volume,world.source_effects_volume,world.source_cd_stereo_flag,world.source_cd_mix_state.duplicate(true)]
	var invalid := state.duplicate(true)
	invalid.audio.effects = 0;invalid.cd_mix_events = [{"option_volume":88,"stereo_flag":1,"counter":88,"decrement":5,"mix":[0,0,0,0]}]
	if world.apply_source_options_audio(invalid) or previous!=[world.source_music_volume,world.source_effects_volume,world.source_cd_stereo_flag,world.source_cd_mix_state]:push_error("Invalid Options batch changed live audio state");quit(1);return
	state.navigation.selected = 2
	state = session.advance(state,0,0x80000)
	if not world.apply_source_options_audio(state) or world.source_cd_stereo_flag!=2:quit(1);return
	var rear: Dictionary = world.source_sound_channels(world.camera.global_position+Vector3(0,0,world.CELL_METERS),1000)
	# Use an identity listener to verify the mode reaches actual spatial routing.
	world.camera.global_transform = Transform3D.IDENTITY
	rear = world.source_sound_channels(Vector3(0,0,world.CELL_METERS),1000)
	if rear.left!=250 or rear.right!=-250:push_error("Options stereo mode did not reach live sound panning");quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: Options session changes live music mix, effects/display/restore levels and signed panning; invalid batches leave all live fields unchanged")
	quit(0)
