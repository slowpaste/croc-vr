extends SceneTree
const Traversal = preload("res://modern_traversal.gd")
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	for frame in range(30): await process_frame
	world.set_process(false); world.set_physics_process(false)
	world.vr_controls.layout = "modern"
	var player = world.source_player_actor
	var mode := 7 if world.map_name == "MP010_05.MAP" else 11
	var clip := "CROC_HLR.ANI" if mode == 7 else "CROC_CLU.ANI"
	world.source_extended_globals[0] = mode<<16
	world.source_input_suppression_count = 0
	world.camera.basis = Basis.IDENTITY
	player.source_angles.y = 2048
	var handle: int = player.asl_asset({"kind":5,"name":clip},player.vm)
	assert(handle > 0,"Traversal fixture must load original animations")
	for stick in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
		for action in ["move_forward","move_back","move_left","move_right"]: Input.action_release(action)
		Input.action_press("move_left" if stick.x < 0 else "move_right",absf(stick.x))
		Input.action_press("move_forward" if stick.y < 0 else "move_back",absf(stick.y))
		world.sample_source_player_controls()
		assert(player.select_animation(handle,true))
		player.modern_traversal_remainder = Vector3.ZERO
		var start: Vector3 = player.position
		for tick in range(30): player.begin_source_tick()
		var expected: Vector3 = Traversal.displacement(mode,Traversal.axes(stick),2048,int(world.source_player_input_state.stick_yaw))*30.0*world.CELL_METERS/4096.0
		assert((player.position-start).distance_to(expected)<0.002,"Continuous traversal lost a diagonal axis or authored roots added drift")
		assert(player.source_angles.y == 2048,"Traversal animation rotated the surface frame")
		if mode == 11:
			assert(signf(player.position.y-start.y) == -signf(stick.y))
			assert(signf(player.position.x-start.x) == signf(stick.x))
		else: assert(is_equal_approx(player.position.y,start.y),"Ceiling movement left the climbed plane")
	var previous_speed := 0.0
	for strength in [0.2,0.4,0.7,1.0]:
		var travel := Traversal.displacement(mode,Traversal.axes(Vector2(0,-strength)),2048,2048).length()
		assert(travel > previous_speed,"Traversal speed must remain analog")
		previous_speed = travel
	# Qualify animation selection through the original controller case with a
	# supported climb/ceiling contact, rather than relying on our direction table.
	player.source_ceiling_type = 5
	player.source_movement_status |= 0x400
	world.source_extended_globals[6] = 0
	world.source_extended_globals[7] = 0
	world.source_extended_globals[22] = 0
	for action in ["move_forward","move_back","move_left","move_right"]:
		for released in ["move_forward","move_back","move_left","move_right"]: Input.action_release(released)
		Input.action_press(action)
		world.sample_source_player_controls()
		var idle_handle: int = player.vm.globals[71 if mode == 7 else 54]
		assert(player.select_animation(idle_handle,false))
		player.vm.globals[15] = idle_handle
		player.vm.pc = 9592 if mode == 7 else 10558
		player.vm.status = "ready";player.vm.frames.clear();player.vm.wait_counter=0
		player.vm.run()
		var family: Array = ["CROC_HLR.ANI","CROC_HRL.ANI"] if mode == 7 else {"move_forward":["CROC_CLU.ANI","CROC_CRU.ANI"],"move_back":["CROC_CLD.ANI","CROC_CRD.ANI"],"move_left":["CROC_CLL.ANI","CROC_CLR.ANI"],"move_right":["CROC_CRL.ANI","CROC_CRR.ANI"]}[action]
		if not family.has(player.clip_name):
			print("TRAVERSAL_SELECTION: ",action," ",player.clip_name," fault ",player.vm.fault)
			push_error("Original controller selected the wrong traversal animation");quit(1);return
	var previous_cadence := -1
	for strength in [0.2,0.6,1.0]:
		for action in ["move_forward","move_back","move_left","move_right"]: Input.action_release(action)
		Input.action_press("move_forward",strength)
		world.sample_source_player_controls()
		assert(player.select_animation(handle,true))
		for tick in range(4): player.begin_source_tick()
		var cadence: int = player.clip_frame*256+player.clip_fraction
		assert(cadence > previous_cadence,"Climbing hand cadence did not follow analog speed")
		previous_cadence = cadence
	for action in ["move_forward","move_back","move_left","move_right"]: Input.action_release(action)
	world.sample_source_player_controls()
	var stopped: Vector3 = player.position
	for tick in range(30): player.begin_source_tick()
	assert(player.position.distance_to(stopped)<0.001,"Released traversal input still moved Croc")
	# Ledge acquisition must carry held-up intent into the source pull-up edge.
	Input.action_press("move_forward")
	world.source_extended_globals[0] = 1<<16
	world.sample_source_player_controls()
	world.source_extended_globals[0] = 8<<16
	world.sample_source_player_controls()
	assert((int(world.source_input_pressed_mask)&1)!=0)
	# Run the original ledge case, not a replacement pull-up implementation.
	player.source_movement_status |= 512
	player.source_ground.height_units = roundi(player.position.y*4096.0/world.CELL_METERS)
	player.vm.pc = 9301
	player.vm.status = "ready"
	player.vm.frames.clear()
	player.vm.wait_counter = 0
	player.vm.run()
	if player.clip_name != "CROCEDUP.ANI":
		print("LEDGE_SELECTION: ",player.clip_name," status ",player.vm.status," pc ",player.vm.pc," input ",world.source_input_held_mask," press ",world.source_input_pressed_mask," fault ",player.vm.fault)
		push_error("Held-up acquisition did not select the original pull-up animation");quit(1);return
	world.source_extended_globals[0] = 8<<16
	world.sample_source_player_controls()
	assert((int(world.source_input_pressed_mask)&1)==0,"Pull-up edge repeated every tick")
	Input.action_release("move_forward")
	Input.action_press("move_back")
	world.source_extended_globals[0]=1<<16;world.sample_source_player_controls()
	world.source_extended_globals[0]=8<<16;world.sample_source_player_controls()
	assert((int(world.source_input_pressed_mask)&2)!=0)
	player.vm.pc=9301;player.vm.status="ready";player.vm.frames.clear();player.vm.wait_counter=0
	player.vm.run()
	assert(player.clip_name == "CROCEDOF.ANI","Held-back acquisition did not select the original ledge release")
	Input.action_release("move_back")
	world.vr_controls.layout = "classic"
	world.source_extended_globals[0] = mode<<16
	assert(player.select_animation(handle,true))
	stopped = player.position
	player.begin_source_tick()
	assert(player.position.distance_to(stopped)>0.001,"Classic traversal lost authored animation roots")
	assert(player.vm.fault.is_empty())
	world.queue_free(); await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: original traversal animations, eight analog directions, proportional speed, neutral stop, held-input ledge pull-up and classic roots; mode ",mode)
	quit(0)
