extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.vr_controls.layout="classic";world.source_options_state.pad_kind=2
	world.source_options_state.calibration=preload("res://source_controller_calibration.gd").normalize(Vector2i(128,128),Vector2i.ZERO,Vector2i(255,255))
	world.source_resume_input_baseline_pending=false;world.update_source_input(0,0)
	Input.action_press("move_forward");world.sample_source_player_controls();Input.action_release("move_forward")
	if world.source_player_input_state.pad_mode!=2 or world.source_player_input_state.magnitude!=128 or world.source_input_held_mask==0 or not world.source_transition_fault.is_empty():push_error("Classic sampled analog path failed");quit(1);return
	var player=world.create_source_player();var start: Vector3=player.position
	for tick in range(45):world.tick_source_actors()
	var move: Vector3=player.position-start
	if not player.vm.fault.is_empty() or Vector2(move.x,move.z).length()<0.1:push_error("Sampled analog did not move original Croc");quit(1);return
	var prior: int=world.source_input_held_mask;world.sample_source_player_controls()
	if world.source_input_held_mask!=0 or world.source_input_released_mask!=prior:quit(1);return
	world.source_options_state.calibration=preload("res://source_controller_calibration.gd").normalize(Vector2i(96,128),Vector2i.ZERO,Vector2i(192,255))
	world.sample_source_player_controls()
	if world.source_player_input_state.magnitude!=32 or world.source_player_input_state.idle_threshold!=48 or world.source_player_input_state.run_threshold!=92 or world.source_input_held_mask!=0:push_error("Changed calibration did not reach neutral analog sampling");quit(1);return
	Input.action_press("move_left");world.sample_source_player_controls();Input.action_release("move_left")
	if world.source_player_input_state.magnitude!=96 or world.source_player_input_state.idle_threshold!=48 or world.source_input_held_mask==0:push_error("Changed center/thresholds did not reach deflected input");quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: explicitly configured classic analog sampler feeds calibrated packets, original Croc movement and release edges")
	quit(0)
