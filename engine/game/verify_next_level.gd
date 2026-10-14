extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.source_menu_state.selected_index = 0
	world.source_pickup_counts = {1:5,2:6,3:3}
	world.source_stage_crystal_bank = 98
	var player = world.source_player_actor
	if player.asl_command({"op":207,"args":[]},player.vm) != "continue": quit(1); return
	if world.source_transition_state != 3 or world.source_menu_state.selected_index != 1 or world.source_menu_progress_flags.get(0,0) != 0x8006 or world.source_pending_exit.target_level != 11 or world.source_stage_crystal_bank != 3 or world.source_pickup_counts[3] != 4:
		push_error("Original stats/NextLevel command lost completion/selection/awards")
		quit(1)
		return
	world.source_fade_state = {}
	world.source_fade_phase = ""
	if not world.process_source_exit() or world.source_fade_phase != "": quit(1); return
	world.advance_source_stage_stats(0x200)
	for tick in range(13):
		if world.source_main_mode != 4 or not world.process_source_exit(): quit(1); return
	if world.map_name != "MP100_01.MAP" or world.source_main_mode != 5 or world.source_menu_state.selected_index != 1 or world.source_fade_phase != "in" or not world.source_pending_exit.is_empty():
		print("NEXT_LEVEL_STATE: ",world.map_name," ",world.source_main_mode," ",world.source_fade_phase," ",world.source_fade_state," ",world.source_pending_exit)
		push_error("Original NextLevel did not return to the selected island after confirmation/fade")
		quit(1)
		return
	Input.action_press("jump")
	for tick in range(12): world._physics_process(1.0/30.0)
	if world.map_name != "MP100_01.MAP" or world.source_main_mode != 5 or world.source_fade_phase != "":
		push_error("Held results confirmation automatically launched the next stage")
		quit(1)
		return
	Input.action_release("jump")
	world._physics_process(1.0/30.0)
	Input.action_press("jump")
	world._physics_process(1.0/30.0)
	if world.source_fade_phase != "menu-out": push_error("Fresh selector confirm did not launch unlocked next stage"); quit(1); return
	Input.action_release("jump")
	for tick in range(13): world._physics_process(1.0/30.0)
	if world.map_name != "MP011_00.MAP" or world.source_main_mode != 4 or not world.source_controller_enabled or world.source_player_actor.vm.fault != "" or world.source_pickup_counts[3] != 4 or world.source_stage_crystal_bank != 3:
		push_error("Results/selector cycle failed to enter next original stage with retained awards")
		quit(1)
		return
	if world.source_pickup_counts[1] != 0 or world.source_pickup_counts[2] != 0 or world.source_stage_stats_renderer != null or not world.source_stage_stats_state.is_empty():
		push_error("Next original stage retained previous results or per-stage counters")
		quit(1)
		return
	for voice in world.source_voice_nodes.values().duplicate():
		if is_instance_valid(voice): world.retire_imported_voice(voice)
	await create_timer(0.1).timeout
	world.queue_free()
	await process_frame
	print("PASS: original results/NextLevel/selector/next-stage cycle, held-input baseline, progress and retained awards")
	quit(0)
