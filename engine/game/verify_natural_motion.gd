extends SceneTree
const Controls = preload("res://vr_controls.gd")
const Move = preload("res://source_player_movement.gd")
const Palette = preload("res://modern_motion_palette.gd")
var failures := 0
func expression_terms(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for child in value: result.append_array(expression_terms(child))
	elif value is Dictionary:
		if int(value.get("op",-1)) in [2,19]: result.append(value)
		else:
			for child in value.values(): result.append_array(expression_terms(child))
	return result
func selection_paths(strategy: Dictionary) -> Dictionary:
	var dependencies: Dictionary = {}
	var symbols: Dictionary = {}
	var pending: Array = []
	var names: Dictionary = {}
	for instruction in strategy.get("instructions",[]):
		var op := int(instruction.op)
		if op == 54:
			var target := int(instruction.args[0])
			if not dependencies.has(target): dependencies[target] = []
			if not symbols.has(target): symbols[target] = []
			for term in expression_terms(instruction.args[1]):
				if int(term.op) == 2: dependencies[target].append(int(term.index))
				elif term.has("name"): symbols[target].append(str(term.name))
		elif op in [11,63]:
			for term in expression_terms(instruction.args[0]):
				if int(term.op) == 2: pending.append(int(term.index))
				elif term.has("name"): names[str(term.name)] = true
	var visited: Dictionary = {}
	while not pending.is_empty():
		var variable := int(pending.pop_back())
		if visited.has(variable): continue
		visited[variable] = true
		for name in symbols.get(variable,[]): names[name] = true
		pending.append_array(dependencies.get(variable,[]))
	return names
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(90): await physics_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.vr_controls.layout = "modern"
	var controls = Controls.new()
	var speeds: Array = []
	for heading in [0,1024,2048,3072]:
		controls.reset_gestures()
		var request := {"modern":true,"magnitude":40,"idle_threshold":16,"run_threshold":90,"stick_yaw":heading,"mode":0,"surface_type":0,"secondary":2}
		var intent: Dictionary = controls.resolve_motion(request,0,true)
		check(bool(intent.natural_step) == (heading != 0),"Gentle rear/lateral input should use natural footwork")
		var selection := Move.modern_input(intent,[])
		speeds.append(selection.forward)
		check(int(selection.get("movement_yaw",-1)) == heading,"Animation choice must preserve requested travel heading")
		if heading != 0: check(Controls.responsive_turn(0,intent,0,0).yaw == 0,"Gentle footwork should preserve facing")
		request.magnitude = 58
		check(controls.resolve_motion(request,0,true).natural_step == (heading != 0),"Natural footwork needs threshold hysteresis")
		request.magnitude = 75
		check(not controls.resolve_motion(request,0,true).natural_step,"Moderate input should turn toward travel")
		request.magnitude = 40
		check(not controls.resolve_motion(request,0,false).natural_step,"Airborne steering must follow intent rather than grounded footwork")
	check(speeds.all(func(value): return value == speeds[0]),"Animation families must not introduce speed discontinuities")
	var player = world.source_player_actor
	var origin: Vector3 = player.position
	var yaw: int = player.source_angles.y
	var live_clips: Dictionary = {}
	for scenario in ["backward","left","right","turn"]:
		for action in ["move_forward","move_back","move_left","move_right"]: Input.action_release(action)
		for tick in range(40):
			world.sample_source_player_controls()
			world.tick_source_actors()
		player.position = origin
		player.source_angles.y = yaw
		player.source_rotation_y = yaw
		player.rotation.y = float(yaw)*TAU/4096.0
		world.source_player_movement_state.motion = Vector2i.ZERO
		world.vr_controls.reset_gestures()
		world.camera.look_at(world.camera.global_position+player.basis.z,Vector3.UP)
		Input.action_press("move_back" if scenario in ["backward","turn"] else "move_left" if scenario == "left" else "move_right",0.55 if scenario == "turn" else 0.3)
		live_clips[scenario] = []
		for tick in range(40):
			world.sample_source_player_controls()
			world.tick_source_actors()
			if not live_clips[scenario].has(player.clip_name): live_clips[scenario].append(player.clip_name)
		check(player.position.distance_to(origin)>0.1,"Natural footwork must actually follow the stick")
	check(live_clips.backward.has("CROCBKW2.ANI"),"Gentle backward input must play backward walking without a modifier")
	check(live_clips.left.has("CROCSLT2.ANI"),"Gentle lateral input must play left sidesteps without a modifier")
	check(live_clips.right.has("CROCSRT2.ANI"),"Gentle lateral input must play right sidesteps without a modifier")
	check(live_clips.turn.has("CROCLEFT.ANI") or live_clips.turn.has("CROCRGHT.ANI"),"Moderate direction change must use the turning palette while travelling")
	for action in ["move_forward","move_back","move_left","move_right"]: Input.action_release(action)
	print("NATURAL_MOTION_CLIPS: ",live_clips)
	player.clip = world.read_json(world.manifest.character.animations["CROCWALK.ANI"])
	player.clip_name = "CROCWALK.ANI"
	player.clip_frame = 0
	var walking_position: Vector3 = player.position
	var walking_angles: Vector3i = player.source_angles
	check(player.apply_root_frame(),"Modern walking root policy failed")
	check(player.position==walking_position and player.source_angles==walking_angles,"Ordinary locomotion must not override physical movement intent")
	player.clip = world.read_json(world.manifest.character.animations["CROC1801.ANI"])
	player.clip_name = "CROC1801.ANI"
	player.clip_frame = 0
	var physical_position: Vector3 = player.position
	check(player.apply_root_frame(),"Modern reversal root policy failed")
	check(Vector2(player.position.x,player.position.z).distance_to(Vector2(physical_position.x,physical_position.z))<world.CELL_METERS/4096.0,"Flip root must not override horizontal stick travel; authored rotation/vertical arc remain allowed")
	var palette: Dictionary = {}
	for profile in ["normal","swim","slide"]:
		var controller: Dictionary = world.manifest.linkage.controllers[profile]
		var strategy: Dictionary = {}
		for asset in controller.assets:
			if asset.name == controller.file: strategy = world.read_json(asset.file)
		var paths := selection_paths(strategy)
		for asset in controller.assets:
			if int(asset.kind) != 4 or asset.name == "BIRD.ANI": continue
			var role := Palette.family(asset.name)
			check(role != "","Player animation lacks a semantic use: "+asset.name)
			var referenced: bool = asset.name in ["CROCWALK.ANI","CROCWA4.ANI"]
			for reference in strategy.get("references",[]):
				if str(reference.get("name","")) == asset.name: referenced = true
			check(referenced,"Player animation has no source strategy path: "+asset.name)
			var selected: bool = paths.has(asset.name) or asset.name in ["CROCWALK.ANI","CROCWA4.ANI"]
			check(selected,"Loaded animation never reaches a selection command: "+asset.name)
			palette[asset.name] = {"role":role,"controller":profile,"source_reference":referenced,"selection_path":selected}
	for name in world.manifest.character.animations:
		check(palette.has(name),"Character palette entry omitted: "+name)
	var normal_strategy: Dictionary = {}
	for asset in world.manifest.linkage.controllers.normal.assets:
		if asset.name == "CROC.BIN": normal_strategy = world.read_json(asset.file)
	var regional_paths := selection_paths(normal_strategy)
	for room_name in world.manifest.linkage.rooms:
		for asset in world.manifest.linkage.rooms[room_name].get("assets",[]):
			if int(asset.kind) != 4 or not (str(asset.name).begins_with("CROC") or str(asset.name).begins_with("SWIM")): continue
			var role := Palette.family(asset.name)
			check(role != "","Regional player animation lacks a semantic use: "+asset.name)
			var referenced: bool = role == "idle" # The source room's waitAnimation selects this resource.
			for reference in normal_strategy.get("references",[]):
				if str(reference.get("name","")) == asset.name: referenced = true
			check(referenced,"Regional animation has no source strategy path: "+asset.name)
			var selected: bool = role == "idle" or regional_paths.has(asset.name)
			check(selected,"Regional animation never reaches a selection command: "+asset.name)
			if not palette.has(asset.name): palette[asset.name] = {"role":role,"controller":"normal","source_reference":referenced,"selection_path":selected,"rooms":[]}
			if palette[asset.name].has("rooms"): palette[asset.name].rooms.append(room_name)
	var report := FileAccess.open(ProjectSettings.globalize_path("res://../build/player-animation-palette.json"),FileAccess.WRITE)
	if report != null: report.store_string(JSON.stringify(palette,"\t"))
	print("PLAYER_PALETTE_AUDIT: ",palette.size()," unique player clips with semantic roles and animation-selection paths; report: build/player-animation-palette.json")
	print("PASS: natural intent, continuous speed across animation families, hysteresis, airborne steering and complete declared palette/source-reference coverage" if failures == 0 else "FAIL: natural intent/palette audit")
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Natural-motion audio did not retire");quit(1);return
	quit(0 if failures == 0 else 1)
