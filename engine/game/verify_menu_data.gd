extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var count := 0
	for name in world.manifest.linkage.rooms:
		var linked: Dictionary = world.manifest.linkage.rooms[name]
		if not bool(linked.get("menu",false)):
			continue
		if not world.load_room(name) or world.create_source_player() != null or world.terrain_models.is_empty():
			push_error("Menu scene data failed or instantiated a gameplay controller: "+name)
			quit(1)
			return
		count += 1
		await process_frame
	world.queue_free()
	await process_frame
	if count != 10:
		quit(1)
		return
	print("PASS: ten original menu scene data loads without a gameplay controller")
	quit(0)
