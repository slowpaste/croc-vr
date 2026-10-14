extends SceneTree
const Move = preload("res://source_player_movement.gd")
const Controls = preload("res://vr_controls.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("verify")
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(90): await physics_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.vr_controls.layout = "modern"
	var player = world.source_player_actor
	var initial: Vector3 = player.position
	var motion_state := {"mode":0,"counter":0,"lock":0,"forced":0,"motion":Vector2i.ZERO,"magnitude":0,"reset_pending":false,"yaw_rate":0,"timer":0}
	var fixture := {"position":Vector3i.ZERO,"yaw":0,"primary":0,"secondary":2,"surface_type":0,"status":0,"entry_flags":0}
	var direct := {"modern":true,"pad_mode":2,"magnitude":127,"idle_threshold":16,"run_threshold":90,"camera_yaw":0,"stick_yaw":1024,"buttons":0,"suppression":0}
	for tick in range(14):
		var result := Move.step(motion_state,fixture,direct,{"x":0,"z":0,"yaw":0},world.runtime_tables)
		check(not result.has("fault"),"Modern movement composition failed")
		motion_state = result.state
		if tick == 0: check(result.position.x == 70 and result.position.z == 0,"Movement should follow the requested direction immediately, independently of facing")
	check(motion_state.magnitude >= 139 and motion_state.magnitude <= 140,"Modern acceleration must preserve the original maximum travel speed")
	var previous_speed := -1
	for strength in [0.0,0.15,0.25,0.4,0.6,0.8,1.0]:
		var input: Dictionary = world.vr_controls.analog_input(Vector2(0,-strength),Vector3.FORWARD)
		input.merge({"mode":0,"counter":0,"surface_type":0,"secondary":2,"actor_yaw":0,"buttons":0},true)
		var selected := Move.modern_input(input,[])
		check(int(selected.forward)>previous_speed,"Analog speed must increase across the usable stick range")
		previous_speed = int(selected.forward)
		if strength>0.7: check(selected.mode == 2,"Full stick must run immediately")
	var clips: Dictionary = {}
	for scenario in ["walk","run","ease-walk","run","run-stop","backward","left","right","stop"]:
		for action in ["move_forward","move_back","move_left","move_right","precision_move"]: Input.action_release(action)
		if scenario in ["walk","ease-walk"]: Input.action_press("move_forward",0.4)
		if scenario == "run": Input.action_press("move_forward")
		if scenario in ["backward","left","right"]:
			Input.action_press("precision_move")
			Input.action_press("move_back" if scenario == "backward" else "move_left" if scenario == "left" else "move_right")
		clips[scenario] = []
		for tick in range(28):
			world.sample_source_player_controls()
			world.tick_source_actors()
			player.apply_pose()
			player.refresh_source_render_pose()
			player.modern_pose.apply(player,1.0/30.0)
			if not clips[scenario].has(player.clip_name): clips[scenario].append(player.clip_name)
			check(player.vm.fault == "","Modern response caused a source controller fault")
			for part in player.mesh_parts: check(part.transform.origin.is_finite(),"Procedural pose must remain finite")
		if scenario == "stop": check(world.source_player_movement_state.motion.length()<4096,"Released stick should settle within a few ticks")
	print("MODERN_RESPONSE_CLIPS: ",clips)
	check(clips.run.has("CROCRUN.ANI"),"Run animation missing")
	check(clips["run-stop"].has("CROCSKID.ANI"),"Run release must use the original skid")
	check(clips["ease-walk"].has("CROCWR2W.ANI"),"Easing out of a run must use the authored run-to-walk transition")
	check(clips.walk.has("CROCWALK.ANI") or clips.walk.has("CROCSTWK.ANI"),"Walk animation missing")
	check(clips.backward.has("CROCBKW2.ANI"),"Backward gait missing")
	check(clips.left.has("CROCSLT2.ANI"),"Left sidestep missing")
	check(clips.right.has("CROCSRT2.ANI"),"Right sidestep missing")
	check(player.position.distance_to(initial)>0.1,"Modern input did not move character")
	for tick in range(60):
		world.sample_source_player_controls()
		world.tick_source_actors()
		player.apply_pose()
		player.refresh_source_render_pose()
		player.modern_pose.apply(player,1.0/30.0)
	var physics_position: Vector3 = player.position
	player.position.y += 0.06 # Force a contact correction without changing collision.
	for frame in range(30):
		player.apply_pose()
		player.refresh_source_render_pose()
		var hand: Transform3D = player.mesh_parts[4].transform
		player.modern_pose.apply(player,1.0/30.0)
		check(player.mesh_parts[4].transform == hand,"Foot solving must preserve the rigid hand parts")
	check(is_equal_approx(player.position.y,physics_position.y+0.06),"Visual foot solving must not move the physical actor")
	var foot_errors: Array = []
	for side in [0,1]:
		var sole: Vector3 = player.mesh_parts[0].global_transform*preload("res://modern_character_pose.gd").sole(player.modern_pose.last_points,side)
		var floor_hit: Dictionary = world.source_cached_floor_at(sole,{})
		if not floor_hit.is_empty():
			var error: float = absf(sole.y-float(floor_hit.height_units)*world.CELL_METERS/4096.0)
			foot_errors.append(error)
			check(error<0.005,"Standing foot vertices must settle onto terrain after a height perturbation")
	check(foot_errors.size()==2,"Both grounded feet need terrain contacts")
	print("MODERN_FOOT_ERRORS_METERS: ",foot_errors)
	player.position = physics_position
	var original_state: int = world.source_extended_globals[0]
	for state in [7,11]:
		world.source_extended_globals[0] = state<<16
		for pair in [["move_forward",1],["move_back",2],["move_left",4],["move_right",8]]:
			Input.action_press(pair[0])
			world.sample_source_player_controls()
			check((int(world.source_input_held_mask)&int(pair[1])) != 0,"Traversal must retain all source direction queries")
			Input.action_release(pair[0])
	world.source_extended_globals[0] = original_state
	world.vr_controls.layout = "classic"
	player.apply_pose()
	var authored: Transform3D = player.mesh_parts[4].transform
	player._process(1.0/30.0)
	check(player.mesh_parts[4].transform == authored,"Modern pose must not alter classic characters")
	world.vr_controls.layout = "modern"
	world.sample_source_player_controls()
	Input.action_press("move_forward")
	world.sample_source_player_controls()
	player.clip = world.read_json(world.manifest.character.animations["CROCWALK.ANI"])
	world.source_player_input_state.merge({"magnitude":50,"natural_step":false,"turn_step":false,"precision":false},true)
	player.clip_name = "CROCWALK.ANI"
	player.secondary_flags |= 2
	for travel in [0.0,30.0,60.0]:
		player.modern_speed = travel
		player.clip_frame = 0
		player.clip_fraction = 0
		player.clip_playing = true
		player.advance_animation()
		var phase: int = player.clip_frame*256+player.clip_fraction
		check(phase == roundi(float(player.clip.speed)*travel/60.0),"Gait cadence must follow actual travel, including zero motion")
	Input.action_release("move_forward")
	print("PASS: proportional analog speed, immediate run, gait transitions, stop and finite grounded poses" if failures == 0 else "FAIL: modern response")
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):
		push_error("Modern response audio did not retire");quit(1);return
	quit(0 if failures == 0 else 1)
