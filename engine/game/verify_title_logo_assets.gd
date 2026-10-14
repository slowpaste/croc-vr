extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var title: Dictionary = world.manifest.frontendTitle
	var binding: Dictionary = world.material_for_texture(title.texture)
	if binding.is_empty() or binding.data.polygons.size() != 435 or title.models.size() != 2:
		quit(1)
		return
	for resource in title.models:
		var model: Dictionary = world.read_json(resource.file)
		var mesh: ArrayMesh = world.geometry(model.models[0],binding.data)
		if mesh.get_surface_count() == 0 or mesh.surface_get_array_len(0) == 0:
			push_error("Original title logo geometry failed: "+resource.name)
			quit(1)
			return
	world.queue_free()
	await process_frame
	print("PASS: both original title logo models build textured meshes from the frontend atlas")
	quit(0)
