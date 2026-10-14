extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var rooms := 0
	for entry in world.manifest.maps:
		var link: Dictionary = world.manifest.linkage.rooms.get(entry.name,{})
		if link.get("camera",null) == null: continue
		world.map_name = str(entry.name);world.room_data = world.read_json(entry.file)
		var geometry: Dictionary = world.source_camera_geometry()
		if geometry.has("fault"):
			push_error(str(geometry.fault));quit(1);return
		assert(geometry.tracks.size() == world.room_data.tracks.size())
		for tile in geometry.tracks:
			assert(geometry.models[int(tile.index)].get("collision",{}).has("groups"))
		rooms += 1
	assert(rooms == 252)
	world.queue_free();await process_frame
	print("PASS: all252 authored camera banks and tile redirects bind valid collision models")
	quit(0)
