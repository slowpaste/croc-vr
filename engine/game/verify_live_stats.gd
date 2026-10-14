extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.source_pickup_counts = {1:2,2:6,3:3}
	world.source_stage_crystal_bank = 99
	var player = world.source_player_actor
	if player != null: player.asl_command({"op":180,"args":[[{"op":4,"value":458752},{"op":18}]]},player.vm)
	if player == null or player.asl_command({"op":198,"args":[]},player.vm) != "continue":
		push_error("Original LevelStats command did not initialize live presentation")
		quit(1)
		return
	if world.source_stage_crystal_bank != 1 or world.source_pickup_counts[3] != 4 or world.source_stage_stats_state.pickup_count != 1 or not is_instance_valid(world.source_stage_stats_renderer) or not world.source_stage_stats_renderer.track.visible:
		quit(1)
		return
	world.source_input_pressed_mask = 0
	world.tick_source_actors()
	if world.source_stage_stats_state.phase != 1 or world.source_stage_stats_state.delay != 29:
		push_error("Live source tick failed to advance results once")
		quit(1)
		return
	var stats_before: Dictionary = world.source_stage_stats_state.duplicate(true)
	world.source_stage_stats_renderer.configure_vr_panel(true)
	assert(world.source_stage_stats_renderer.update_stats(world.source_stage_stats_state,world.runtime_tables.stageResults,world.source_stage_stats_bindings))
	assert(world.source_stage_stats_renderer.labels.rendered_labels[1]=="{ TO CONTINUE")
	assert(world.source_stage_stats_renderer.labels.button_mesh!=null)
	world.vr_settings.toggle()
	Input.action_press("jump")
	world._physics_process(1.0)
	if world.source_stage_stats_state != stats_before:
		push_error("Open VR settings advanced or confirmed the results screen")
		quit(1)
		return
	world.vr_settings.toggle()
	world._physics_process(1.0/30.0)
	if world.source_stage_stats_state.busy != 0:
		push_error("Held confirm input confirmed results when VR settings closed")
		quit(1)
		return
	Input.action_release("jump")
	world.sample_source_player_controls()
	stats_before = world.source_stage_stats_state.duplicate(true)
	world.xr_active = true # No focused XR session in this headless gate.
	world._physics_process(1.0)
	world.xr_active = false
	if world.source_stage_stats_state != stats_before:
		push_error("Unfocused XR session advanced the live results screen")
		quit(1)
		return
	Input.action_press("jump")
	world._physics_process(1.0/30.0)
	if world.source_stage_stats_state.busy != 0:
		push_error("Focus resume synthesized a results confirmation")
		quit(1)
		return
	Input.action_release("jump")
	world.sample_source_player_controls()
	# Continue count-up from its source fixture after checking pause/resume.
	world.source_stage_stats_state = stats_before
	world.source_stage_stats_state.delay = 29
	for tick in range(30): world.advance_source_stage_stats(0)
	if world.source_stage_stats_state.events != ["life","crystal"]: quit(1); return
	for pair in [["SEEDRED",75],["CRYS",25]]:
		var matched := false
		for asset in world.manifest.linkage.bootstrap:
			if int(asset.kind) == 3 and asset.name == pair[0]:
				matched = world.source_sample_volumes.get(asset.file,-1) == pair[1]
		if not matched: push_error("Original results sample/volume was not played"); quit(1); return
	Input.action_press("jump")
	world._physics_process(1.0/30.0)
	Input.action_release("jump")
	if world.source_stage_stats_state.busy != 1 or world.source_pickup_counts[1] != 0 or world.source_stage_stats_state.shown_bank != 1:
		quit(1)
		return
	var start_played := false
	for asset in world.manifest.linkage.bootstrap:
		if int(asset.kind) == 3 and asset.name == "START": start_played = world.source_sample_volumes.get(asset.file,-1) == 80
	if not start_played: push_error("Results confirmation did not play original START sample"); quit(1); return
	var old_renderer = world.source_stage_stats_renderer
	if not world.load_room("MP010_01.MAP") or world.source_stage_stats_renderer != null or not world.source_stage_stats_state.is_empty() or old_renderer.visible:
		push_error("Results presentation survived destination room reload")
		quit(1)
		return
	for voice in world.source_voice_nodes.values().duplicate():
		if is_instance_valid(voice): world.retire_imported_voice(voice)
	await create_timer(0.1).timeout
	world.queue_free()
	await process_frame
	print("PASS: live LevelStats command, original awards/count-up/confirm, source tick and room presentation cleanup")
	quit(0)
