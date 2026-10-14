extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=4;world.source_resume_input_baseline_pending=false
	world.source_options_state.calibration=preload("res://source_controller_calibration.gd").normalize(Vector2i(128,128),Vector2i.ZERO,Vector2i(255,255))
	var context={"player_present":true,"camera_yaw":0,"player_yaw":0,"room_type":0}
	var packet := PackedByteArray([0,0x73,255,255,128,128,128,0])
	var virtual := preload("res://source_virtual_pad.gd")
	if virtual.analog_packet(Vector2(0,-1),Vector2.ZERO)!=packet or virtual.analog_packet(Vector2(1,0),Vector2(-1,1),0xbfff)!=PackedByteArray([0,0x73,255,191,0,255,255,128]) or not virtual.analog_packet(Vector2(INF,0),Vector2.ZERO).is_empty():push_error("Virtual packet adapter layout/endpoints differ");quit(1);return
	packet=virtual.analog_packet(Vector2(0,-1),Vector2.ZERO)
	var decoded: Dictionary=world.update_source_analog_packet(packet,0,context)
	if decoded.has("fault") or world.source_input_held_mask!=0x10001 or world.source_input_pressed_mask!=0x10001 or world.source_player_input_state.pad_mode!=2 or world.source_player_input_state.magnitude!=128 or world.source_player_input_state.idle_threshold!=63 or world.source_player_input_state.run_threshold!=123:push_error("Analog world movement state differs");quit(1);return
	var player=world.create_source_player()
	var bound: Dictionary=world.source_analog_input_context()
	if bound.get("room_type",-1)!=int(world.room_data.style) or bound.player_yaw!=int(player.source_angles.y) or bound.camera_yaw!=int(world.source_camera_state.yaw):push_error("World analog context did not bind source fields");quit(1);return
	if world.update_source_analog_packet(packet,0).has("fault"):push_error("Automatic analog context failed");quit(1);return
	var start: Vector3=player.position
	for tick in range(45):world.tick_source_actors()
	var movement: Vector3=player.position-start
	if not player.vm.fault.is_empty() or Vector2(movement.x,movement.z).length()<0.1:push_error("Analog bridge did not move original Croc horizontally");quit(1);return
	var prior: Dictionary=world.source_player_input_state.duplicate(true)
	if not world.update_source_analog_packet(PackedByteArray([0]),0,context).has("fault") or world.source_player_input_state!=prior:push_error("Invalid analog packet changed world state");quit(1);return
	packet[0]=255
	if world.update_source_analog_packet(packet,0x10001,context).has("fault") or world.source_input_held_mask!=0 or world.source_input_released_mask!=0x10001 or world.source_player_input_state.pad_mode!=0:quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: verified analog packets populate actual world held/edge/movement thresholds; invalid input leaves prior state, disconnect releases")
	quit(0)
