extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var player = world.source_player_actor
	var motion = preload("res://source_camera_motion.gd")
	var roots: Array = world.runtime_tables.distanceRoot.values
	var angles: Array = world.runtime_tables.wallAngles.values
	var flat: Dictionary = motion.override_query(Vector3i.ZERO,Vector3i(4096,0,0),roots,angles)
	var elevated: Dictionary = motion.override_query(Vector3i.ZERO,Vector3i(4096,999999,0),roots,angles)
	assert(flat == elevated and flat.bearing == 1024)
	assert(motion.override_query(Vector3i.ZERO,Vector3i(0,-999999,4096),roots,angles).bearing == 0)
	assert(motion.override_query(Vector3i.ZERO,Vector3i.ZERO,[],angles).has("fault"))
	assert(motion.override_query(Vector3i.ZERO,Vector3i.ZERO,roots,[]).has("fault"))
	world.update_vr_camera_anchor(1.0/72.0)
	var anchor: Vector3 = world.vr_camera_anchor
	if player.asl_command({"op":149,"args":[[{"op":4,"value":360448},{"op":18}]]},player.vm) != "continue" or world.source_camera_hold_counter != 5: quit(1); return
	world.actor.position.x += 3.0
	world.update_vr_camera_anchor(1.0)
	if world.vr_camera_anchor != anchor:
		push_error("Source CamHold still moved the automatic view anchor")
		quit(1)
		return
	world.actor.position.y += 2.0
	var expected_vertical := lerpf(anchor.y,world.actor.position.y,1.0-exp(-10.0))
	world.update_vr_camera_anchor(1.0)
	assert(Vector2(world.vr_camera_anchor.x,world.vr_camera_anchor.z)==Vector2(anchor.x,anchor.z))
	assert(is_equal_approx(world.vr_camera_anchor.y,expected_vertical))
	anchor=world.vr_camera_anchor
	world.vr_controls.turn_mode = "snap"
	world.vr_controls.snap_degrees = 30
	world.vr_controls.reset_gestures()
	world.vr_turn_focused = true
	world._process(1.0/72.0)
	var yaw: float = world.yaw
	Input.action_press("turn_right")
	world._process(1.0/72.0)
	Input.action_release("turn_right")
	if not is_equal_approx(world.yaw,yaw-PI/6.0) or Vector2(world.vr_camera_anchor.x,world.vr_camera_anchor.z)!=Vector2(anchor.x,anchor.z):
		push_error("CamHold blocked player snap turning or moved the held anchor")
		quit(1)
		return
	world.update_source_input(0,0)
	for tick in range(5): world.tick_source_actors()
	if world.source_camera_hold_counter != 0: quit(1); return
	world.actor.position.x += 3.0
	var expected_recovery: Vector3=world.vr_camera_anchor.lerp(world.actor.position,1.0-exp(-10.0/72.0))
	world.update_vr_camera_anchor(1.0/72.0)
	if world.vr_camera_anchor == anchor or world.vr_camera_anchor.distance_to(expected_recovery)>0.00002: quit(1); return
	player.asl_command({"op":149,"args":[[{"op":4,"value":-65536},{"op":18}]]},player.vm)
	world.tick_source_actors()
	world.source_camera_height_units = 111
	world.source_camera_distance_units = 222
	world.source_camera_distance_copy_units = 333
	world.source_camera_state["orbit_offset"] = 444
	world.source_camera_state["yaw_velocity"] = 555
	world.source_camera_state["distance_velocity"] = -666
	world.source_camera_state["height_velocity"] = 777
	world.source_camera_state["query_counter"] = 15
	world.source_camera_state["look_offset"] = Vector2i(123,-456)
	world.source_camera_state["look_offset_velocity"] = Vector2i(7,-8)
	world.source_camera_state["look_velocity_y"] = 9
	world.source_camera_state["manual_yaw"] = 321
	world.source_camera_state["collision_status"] = 1
	world.source_camera_state["shake_index"] = 3
	world.source_camera_state["shake_strength"] = 65536
	world.source_camera_override_one = player
	if world.source_camera_hold_counter != -2 or not world.reset_source_camera(player) or world.source_camera_hold_counter != 0: quit(1); return
	if world.source_camera_height_units != 0 or world.source_camera_distance_units != 0 or world.source_camera_distance_copy_units != 0:
		push_error("CamTarget retained prior height/distance globals");quit(1);return
	if world.source_camera_state.orbit_offset != 0 or world.source_camera_state.yaw_velocity != 0 or world.source_camera_state.query_counter != 0 or world.source_camera_override_one != player:
		push_error("CamTarget reset missed numeric state or cleared the retained override");quit(1);return
	assert(world.source_camera_state.distance_velocity == 0 and world.source_camera_state.height_velocity == 0)
	assert(world.source_camera_state.look_offset == Vector2i.ZERO and world.source_camera_state.look_offset_velocity == Vector2i.ZERO)
	assert(world.source_camera_state.look_velocity_y == 0 and world.source_camera_state.look_offset_y == 1280)
	var expected_look := Vector3i(roundi(player.position.x/world.CELL_METERS*4096.0),roundi(player.position.y/world.CELL_METERS*4096.0),roundi(player.position.z/world.CELL_METERS*4096.0))
	assert(world.source_camera_state.look_position == expected_look)
	assert(world.source_camera_state.manual_yaw == 321 and world.source_camera_state.collision_status == 1)
	assert(world.source_camera_state.shake_index == 3 and world.source_camera_state.shake_strength == 65536)
	var target := Vector3(3,8,-4)
	for rate in [60,72,90,144]:
		world.vr_camera_anchor = Vector3.ZERO
		world.vr_camera_anchor_initialized = true
		world.actor.position = Vector3(3,8,-4)
		for frame in range(rate): world.update_vr_camera_anchor(1.0/rate)
		if world.vr_camera_anchor.distance_to(target*(1.0-exp(-10.0))) > 0.00002:
			push_error("Camera follow recovery changed with refresh rate or lost player height")
			quit(1)
			return
	world.source_camera_hold_counter = -1
	if not world.load_room("MP100_01.MAP") or world.source_camera_hold_counter != 0 or world.vr_camera_anchor_initialized:
		push_error("Original selector entry retained previous scene camera hold/anchor")
		quit(1)
		return
	world.update_vr_camera_anchor(1.0/72.0)
	anchor = world.vr_camera_anchor
	world.actor.position.x += 1.0
	world.update_vr_camera_anchor(1.0/72.0)
	if world.vr_camera_anchor == anchor: quit(1); return
	world.queue_free()
	await process_frame
	print("PASS: source CamHold signed fixed-point write, nonzero countdown and camera-reset clear")
	quit(0)
