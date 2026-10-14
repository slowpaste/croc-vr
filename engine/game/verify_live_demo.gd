extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.source_frame_clock.counter = 777
	world.source_title_scene_index = 0
	if not world.initialize_source_demo_scene({"level":15,"room":0}) or not world.start_source_demo_playback():
		quit(1)
		return
	world.vr_controls.layout = "modern"
	while world.source_input_held_mask == 0 and world.source_tick_count < 100:
		world._physics_process(1.0/30.0)
	var paused_tick := int(world.source_tick_count)
	var paused_input := int(world.source_input_held_mask)
	world.vr_settings.opened = true
	world._physics_process(1.0)
	world.vr_settings.opened = false
	if world.source_tick_count != paused_tick or world.source_input_held_mask != paused_input:
		push_error("VR settings pause changed recorded demo time/input")
		quit(1)
		return
	world.xr_active = true # No initialized/focused XR session in this desktop probe.
	world._physics_process(1.0)
	world.xr_active = false
	if world.source_tick_count != paused_tick or world.source_input_held_mask != paused_input:
		push_error("Unfocused VR demo advanced or cleared recorded input")
		quit(1)
		return
	Input.action_press("move_left")
	var frames := 0
	var exit_cause := 0
	while world.source_main_mode == 3 and frames < 940:
		var tick := int(world.source_tick_count)
		world._physics_process(1.0/30.0)
		if world.source_fade_phase == "demo-out":
			exit_cause = int(world.source_transition_state)
		if world.source_transition_fault != "":
			push_error(world.source_transition_fault)
			quit(1)
			return
		if world.source_main_mode == 3 and tick < 900 and world.source_input_held_mask != int(world.source_demo_frames[tick]):
			push_error("Live physical movement replaced the original recorded demo input")
			quit(1)
			return
		frames += 1
	Input.action_release("move_left")
	if world.source_main_mode != 0 or world.source_demo_playing or (frames+paused_tick < 900 and exit_cause == 0) or world.map_name == "MP015_00.MAP":
		push_error("Live demo clock did not complete recorded playback and original fade/title return: "+str({"frames":frames,"mode":world.source_main_mode,"playing":world.source_demo_playing,"cause":exit_cause}))
		quit(1)
		return
	if not world.initialize_source_demo_scene({"level":48,"room":0}) or not world.start_source_demo_playback():
		quit(1)
		return
	var neutral_cause:=0;var neutral_fade_tick:=-1
	for tick in range(913):
		# This unused neutral recording's room has live enemies. Qualify the
		# timeout independently with native PauseTriggers84 on the fixture player.
		world.source_player_actor.primary_flags|=0x40
		world._physics_process(1.0/30.0)
		if world.source_fade_phase=="demo-out":
			neutral_cause=int(world.source_transition_state)
			if neutral_fade_tick<0:neutral_fade_tick=tick
		if tick < 912 and world.source_main_mode != 3:
			push_error("Neutral recording returned before its original timeout/fade boundary: "+str({"returned_tick":tick,"fade_tick":neutral_fade_tick,"cause":neutral_cause,"lives":world.source_pickup_counts[3]}))
			quit(1)
			return
	if world.source_main_mode != 0 or world.source_demo_playing:
		quit(1)
		return
	if not world.initialize_source_demo_scene({"level":48,"room":0}) or not world.start_source_demo_playback():
		quit(1)
		return
	for tick in range(12):
		world._physics_process(1.0/30.0)
	Input.action_press("jump")
	world._physics_process(1.0/30.0)
	Input.action_release("jump")
	if world.source_fade_phase != "demo-out" or world.source_input_held_mask != 0:
		push_error("Physical abort changed recorded input or failed to start demo exit")
		quit(1)
		return
	for tick in range(13):
		world._physics_process(1.0/30.0)
	if world.source_main_mode != 0:
		quit(1)
		return
	world.stop_imported_audio()
	world.queue_free()
	await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	print("PASS: live demo recorded input, settings/focus pause, transition exit, protected neutral900-frame timeout and physical abort/title return")
	quit(0)
