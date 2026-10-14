extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(90):
		await physics_frame
	world.set_physics_process(false)
	world.vr_controls.layout = "modern"
	world.vr_controls.reset_gestures()
	var player = world.source_player_actor
	var start: Vector3 = player.position
	Input.action_press("move_forward")
	for tick in range(40):
		world.sample_source_player_controls()
		world.tick_source_actors()
		world.update_camera()
	Input.action_release("move_forward")
	Input.action_press("move_back")
	var clips: Array = []
	var slow_turn_ticks := 0
	var completed_turns := 0
	for tick in range(90):
		var before: Vector3 = player.position
		var flip_before: bool = preload("res://modern_motion_palette.gd").reversal(player.clip_name)
		var turning_before: bool = player.clip_name in ["CROC1801.ANI","CROC1802.ANI","CROCT180.ANI"] and player.clip_frame >= 2 and player.clip_frame < int(player.clip.frameCount)*0.5
		world.sample_source_player_controls()
		world.tick_source_actors()
		world.update_camera()
		if flip_before and not preload("res://modern_motion_palette.gd").reversal(player.clip_name):
			var error := ((int(player.source_angles.y)-int(world.source_player_input_state.stick_yaw)+2048)&4095)-2048
			print("FLIP_EXIT_HEADING_ERROR: ",error)
			assert(absi(error)<256,"Flip finished facing away from requested travel")
			completed_turns += 1
		if turning_before:
			assert(Vector2(player.position.x-before.x,player.position.z-before.z).length()<0.004,"Quick turn retained running momentum")
			slow_turn_ticks += 1
		if not clips.has(player.clip_name):
			clips.append(player.clip_name)
	Input.action_release("move_back")
	assert(slow_turn_ticks>0,"Slow quick-turn phase was not exercised")
	assert(completed_turns>0,"Flip completion facing was not exercised")
	print("MODERN_REVERSAL_CLIPS: ",clips)
	if player.vm.fault != "" or player.position.distance_to(start) < 0.1 or not (clips.has("CROC1801.ANI") or clips.has("CROC1802.ANI") or clips.has("CROCT180.ANI")):
		push_error("Modern movement failed to retain the original quick-turn animation: "+str(player.vm.fault))
		quit(1)
		return
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Modern controls audio did not retire");quit(1);return
	print("PASS: modern native movement and stick reversal original quick-turn animation")
	quit(0)




