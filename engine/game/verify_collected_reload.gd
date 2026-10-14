extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var target = null
	for actor in world.source_actors:
		if actor.source_name == "SmashBlock":
			target = actor
			break
	if target == null:
		quit(1)
		return
	var index := int(target.source_map_entity_index)
	var pickups: Dictionary = world.source_pickup_counts.duplicate()
	if target.asl_command({"op":175,"args":[]},target.vm) != "continue" or not world.source_actors.has(target) or world.source_pickup_counts != pickups:
		quit(1)
		return
	if not world.load_room(world.map_name):
		quit(1)
		return
	for actor in world.source_actors:
		if actor.source_map_entity_index == index:
			push_error("Collected source map entity respawned during room reload")
			quit(1)
			return
	world.queue_free()
	await process_frame
	print("PASS: original Collected retains actor/inventory now and suppresses its map entity on room reload")
	quit(0)
