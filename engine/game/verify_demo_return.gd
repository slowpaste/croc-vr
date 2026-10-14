extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.source_title_scene_index = 0
	world.source_frame_clock.counter = 777
	if not world.initialize_source_demo_scene({"level":15,"room":0}):
		quit(1)
		return
	world.source_tick_count = 900
	world.source_fade_state.clear()
	world.source_fade_phase = ""
	if not world.process_source_demo_exit(0) or world.source_fade_phase != "demo-out":
		quit(1)
		return
	for tick in range(12):
		if not world.process_source_demo_exit(0) or world.map_name != "MP015_00.MAP":
			push_error("Demo returned before original outgoing fade readiness")
			quit(1)
			return
	if not world.process_source_demo_exit(0) or world.source_main_mode != 0 or world.map_name == "MP090_00.MAP" or not world.map_name.begins_with("MP09") or world.source_tick_count != 0 or world.source_frame_clock.counter != 777 or world.source_fade_phase != "in":
		push_error("Original demo return did not select a fresh title scene with retained global clock")
		quit(1)
		return
	for tick in range(120):
		world.tick_source_actors()
		if not world.process_source_title_confirmation(0):
			quit(1)
			return
	for node in world.source_actors:
		if node.vm.fault != "":
			push_error("Returned title actor failed: "+node.source_name+" "+node.vm.fault)
			quit(1)
			return
	if world.source_fade_phase != "" or world.source_player_actor == null or world.source_player_actor.source_name != "TitleCamera":
		quit(1)
		return
	world.stop_imported_audio()
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Demo return audio did not retire");quit(1);return
	print("PASS: original demo outgoing fade boundary, nonrepeating title reload, mode0 and global clock retention")
	quit(0)
