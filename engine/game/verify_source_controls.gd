extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(30):
		await physics_frame
	if not world.imported or not world.source_controller_enabled or world.source_player_actor == null or world.visual.visible:
		push_error("Native source controller route failed to initialize")
		quit(1)
		return
	var player = world.source_player_actor
	for candidate in world.source_actors:
		if candidate.source_name == "Crystal" and (candidate.model_name != "CRYSTAL1.MOD" or candidate.source_field_180 != 320 or (candidate.primary_flags&0x8000) != 0 or candidate.vm.parameters.size() < 3 or candidate.vm.parameters[2] < 0 or candidate.vm.parameters[2] > 711 or candidate.vm.parameters[1] < 0 or candidate.vm.parameters[1] >= 20):
			push_error("Original crystal initialization failed")
			quit(1)
			return
	var origin: Vector3 = player.position
	Input.action_press("move_forward")
	for frame in range(30):
		await physics_frame
	Input.action_release("move_forward")
	if player.vm.fault != "" or Vector2(player.position.x-origin.x,player.position.z-origin.z).length() < 0.1:
		push_error("Keyboard input did not move the imported controller")
		quit(1)
		return
	for frame in range(60):
		await physics_frame
	var floor_y: float = player.position.y
	var peak_y := floor_y
	Input.action_press("jump")
	for frame in range(30):
		await physics_frame
		peak_y = maxf(peak_y,player.position.y)
	Input.action_release("jump")
	for frame in range(90):
		await physics_frame
	if player.vm.fault != "" or peak_y-floor_y < 0.3 or (player.primary_flags&0x600) != 0 or world.actor.position != player.position:
		push_error("Imported jump/landing or camera anchor routing failed")
		quit(1)
		return
	world.source_pickup_counts[1] = 7
	world.source_pickup_counts[2] = 1
	player.position = Vector3(12,0,24)
	if not player.run_source_collision_response():
		push_error("Original exit collision query failed")
		quit(1)
		return
	var exit_request: Dictionary = world.source_exit_request(player)
	if not bool(exit_request.get("transition",false)) or exit_request.destination != "MP010_01.MAP" or exit_request.state != 2 or exit_request.origin.level != 10 or exit_request.origin.room != 0:
		push_error("Imported door surface did not select the original exit")
		quit(1)
		return
	for frame in range(20):
		await physics_frame
	if world.map_name != "MP010_00.MAP" or world.source_transition_state != 2 or world.source_fade_phase != "out" or world.source_audio_master_gain != 0:
		push_error("Source room changed before fade readiness")
		quit(1)
		return
	for frame in range(10):
		await physics_frame
	if world.map_name != "MP010_01.MAP" or world.source_player_actor == player or world.source_player_actor.vm.fault != "" or world.source_player_actor.source_angles.y != 2048 or world.source_transition_state != 0:
		push_error("Automatic source room transition failed")
		quit(1)
		return
	var arrival_player = world.source_player_actor
	var arrival_z: float = arrival_player.position.z
	Input.action_press("move_forward")
	for frame in range(30):
		await physics_frame
	Input.action_release("move_forward")
	if arrival_player.vm.fault != "" or arrival_player.position.z >= arrival_z-0.1 or world.map_name != "MP010_01.MAP" or world.source_pickup_counts[1] < 7 or world.source_pickup_counts[2] != 1 or world.source_audio_master_gain != 127:
		push_error("Destination control, entry gate or inventory continuity failed")
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: source controls and automatic room change with arrival heading/inventory continuity")
	quit(0)
