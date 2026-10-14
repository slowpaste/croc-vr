extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	if not world.load_room("MP090_00.MAP"):
		quit(1)
		return
	world.source_frame_clock.counter = 777
	world.source_tick_count = 900
	world.source_cd_fade_counter = 3
	world.source_pickup_counts[1] = 55
	world.source_pickup_counts[2] = 6
	world.source_bonus_mask = 31
	world.source_level_script_state = 5
	for tick in range(2):
		world._physics_process(1.0/30.0)
		if world.source_fade_phase != "" or world.source_main_mode != 0:
			push_error("Title timeout ignored original CD fade gate")
			quit(1)
			return
	world._physics_process(1.0/30.0)
	if world.source_fade_phase != "attract-out":
		quit(1)
		return
	for tick in range(13):
		world._physics_process(1.0/30.0)
	if world.source_main_mode != 3 or not world.source_demo_playing or world.source_pickup_counts[1] != 0 or world.source_pickup_counts[2] != 0 or world.source_bonus_mask != 0 or world.source_level_script_state != 0:
		push_error("Automatic original attract entry did not initialize recorded playback/reset counters")
		quit(1)
		return
	var frames := 0
	while world.source_main_mode == 3 and frames < 940:
		world._physics_process(1.0/30.0)
		if world.source_transition_fault != "":
			push_error(world.source_transition_fault)
			quit(1)
			return
		frames += 1
	if world.source_main_mode != 0 or world.source_demo_playing or world.map_name == "MP090_00.MAP":
		push_error("Automatic attract cycle did not return to a fresh title")
		quit(1)
		return
	world.stop_imported_audio()
	world.queue_free()
	await process_frame
	print("PASS: automatic title timeout, CD counter gate, outgoing fade, original demo selection/playback and title return")
	quit(0)
