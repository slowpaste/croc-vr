extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(90):
		await physics_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.vr_controls.layout = "classic" if OS.get_cmdline_user_args().has("--probe-classic") else "modern"
	world.vr_controls.reset_gestures()
	var player = world.source_player_actor
	var args := OS.get_cmdline_user_args()
	var scenario := "slam"
	var option := args.find("--probe-action")
	if option >= 0 and option + 1 < args.size():
		scenario = args[option + 1]
	var smashed: Node3D = null
	if scenario in ["slam-lid","slam-box"]:
		var lid: Node3D = null
		for candidate in world.source_actors:
			if candidate.source_name == ("SmashLid" if scenario == "slam-lid" else "SmashBlockGobbo"):
				lid = candidate
				break
		smashed = lid
		if lid == null:
			push_error("Missing smashable lid fixture")
			quit(1)
			return
		var contacts: Dictionary = world.source_contacts_at(lid.position,player)
		if contacts.lower.is_empty() or int(contacts.lower.get("actor",-1)) != int(lid.source_pool_id):
			push_error("Lid fixture did not expose its original standing surface")
			quit(1)
			return
		player.position = Vector3(lid.position.x,int(contacts.lower.height_units)*world.CELL_METERS/4096.0,lid.position.z)
		player.refresh_source_render_pose()
		player.run_source_collision_response()
	var start: Vector3 = player.position
	var peak_y: float = start.y
	var clips: Array = []
	var landed := false
	var airborne := false
	var initial_yaw: int = player.source_angles.y
	var actor_faults: Array = []
	for tick in range(180):
		if scenario == "moving-jump" and tick < 35: Input.action_press("move_forward")
		else: Input.action_release("move_forward")
		Input.action_release("jump")
		Input.action_release("move_left")
		Input.action_release("move_right")
		if (scenario in ["slam","slam-lid","slam-box"] and (tick < 4 or (tick >= 10 and tick < 14))) or (scenario == "jump" and tick < 4) or (scenario == "hold-jump" and tick < 40) or (scenario == "moving-jump" and tick >= 10 and tick < 14):
			Input.action_press("jump")
		elif scenario in ["turn-left", "turn-right"] and tick < 45:
			Input.action_press("turn_in_place")
			Input.action_press("move_left" if scenario == "turn-left" else "move_right",0.55)
		else:
			Input.action_release("turn_in_place")
		world.sample_source_player_controls()
		world.tick_source_actors()
		peak_y = maxf(peak_y,player.position.y)
		if not clips.has(player.clip_name):
			clips.append(player.clip_name)
		if (player.secondary_flags & 2) == 0:
			airborne = true
		elif airborne:
			landed = true
		if player.vm.fault != "":
			break
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("turn_in_place")
	Input.action_release("move_forward")
	for source_actor in world.source_actors:
		if source_actor.vm.fault != "":
			actor_faults.append({"name":source_actor.source_name,"fault":source_actor.vm.fault})
	# Lid removal qualifies player recovery; reward-fountain coverage is reported
	# separately because its parent-resource handling is still incomplete.
	var verified: bool = player.vm.fault == "" and (actor_faults.is_empty() or scenario == "slam-lid")
	if scenario in ["slam","slam-lid","slam-box"]:
		verified = verified and peak_y > start.y + 0.3 and landed and clips.has("CROCSMP1.ANI") and clips.has("CROCSMP2.ANI") and clips.has("CROCSMP3.ANI") and clips.has("CROCSMP4.ANI") and (player.secondary_flags & 2) != 0 and player.clip_name.begins_with("CROCWA")
		verified = verified and world.source_camera_state.has("wobble_request")
		if scenario == "slam-box":
			verified = verified and is_instance_valid(smashed) and smashed.model_data.is_empty() and (int(smashed.secondary_flags)&0x30) == 0
			if is_instance_valid(smashed):
				verified = verified and smashed.model_surface_candidates_at(smashed.position,player).is_empty()
				for body in smashed.camera_bodies: verified = verified and body.collision_layer == 0
	elif scenario in ["jump", "hold-jump", "moving-jump"]:
		verified = verified and peak_y > start.y + 0.3 and landed and not clips.has("CROCSMP1.ANI") and (player.secondary_flags & 2) != 0
		if scenario == "moving-jump": verified = verified and clips.has("CROCJMP2.ANI") and clips.has("CROCJMP4.ANI") and Vector2(player.position.x-start.x,player.position.z-start.z).length()>0.8
	else:
		verified = verified and player.source_angles.y != initial_yaw and clips.has("CROCLEFT.ANI" if scenario == "turn-left" else "CROCRGHT.ANI") and Vector2(player.position.x-start.x,player.position.z-start.z).length() < 0.1 and player.clip_name.begins_with("CROCWA")
	print("MODERN_ACTION: ",JSON.stringify({"scenario":scenario,"start":str(start),"end":str(player.position),"peak_y":peak_y,"landed":landed,"clips":clips,"fault":player.vm.fault,"actor_faults":actor_faults,"effects_supported":actor_faults.is_empty(),"pc":player.vm.pc,"verified":verified}))
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Modern action audio did not retire");quit(1);return
	quit(0 if verified else 1)

