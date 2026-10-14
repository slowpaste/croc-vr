extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(90): await physics_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.vr_controls.layout = "modern"
	var player = world.source_player_actor
	var seen: Dictionary = {}
	for side in ["left","right"]:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press("move_left" if side=="left" else "move_right",0.3)
		seen[side] = []
		for tick in range(60):
			world.sample_source_player_controls()
			world.tick_source_actors()
			if not seen[side].has(player.clip_name): seen[side].append(player.clip_name)
	Input.action_release("move_left")
	Input.action_release("move_right")
	var okay: bool = player.vm.fault == "" and seen.left.has("SWIMSIDL.ANI") and seen.right.has("SWIMSIDR.ANI")
	print("NATURAL_SWIM_CLIPS: ",seen)
	if not okay: push_error("Modern swimming must expose both lateral-stroke animations naturally: "+str(player.vm.fault))
	world.queue_free()
	await process_frame
	quit(0 if okay else 1)
