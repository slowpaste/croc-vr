extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var elevator: Node3D = null
	for candidate in world.source_actors:
		if candidate.source_name == "UpExit": elevator = candidate;break
	if elevator == null: push_error("Missing authored underground elevator");quit(1);return
	assert(elevator.asl_command(elevator.vm.instructions[69],elevator.vm) == "continue")
	assert(world.source_input_suppression_count == 1)
	assert(elevator.asl_command(elevator.vm.instructions[102],elevator.vm) == "continue")
	assert(world.source_pending_exit.destination == "MP010_00.MAP")
	for tick in range(100):
		assert(world.process_source_exit())
		if world.map_name == "MP010_00.MAP" and world.source_fade_phase == "": break
	assert(world.map_name == "MP010_00.MAP" and world.source_transition_state == 0)
	assert(world.source_input_suppression_count == 0)
	assert(world.source_player_actor != null and world.source_player_actor.vm.fault.is_empty())
	var player = world.source_player_actor
	var returned_position: Vector3 = player.position
	Input.action_press("move_forward")
	var displacement := 0.0
	for tick in range(45):
		world.sample_source_player_controls()
		world.tick_source_actors()
		displacement = maxf(displacement,Vector2(player.position.x-returned_position.x,player.position.z-returned_position.z).length())
	Input.action_release("move_forward")
	if not player.vm.fault.is_empty() or not world.source_transition_fault.is_empty() or displacement < 0.1:
		push_error("Returned player cannot move away from well: "+str(player.vm.fault)+" displacement="+str(displacement));quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Well return audio did not retire");quit(1);return
	print("PASS: authored UpExit returns to main well, releases input and accepts movement after return; elevator travel not simulated")
	quit(0)
