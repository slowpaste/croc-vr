extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	await process_frame
	world.set_process(false); world.set_physics_process(false)
	var name := "TK%02d_ENM.BIN" % int(world.room_data.style)
	if not world.active_texture_animations.has(name): push_error("Missing gem animation"); quit(1); return
	var player = world.active_texture_animations[name]
	var data: Dictionary = world.material_for_texture(name).data
	var uv: Array = data.polygons[25].uv
	var low := Vector2i(int(float(uv[0][0])*int(data.width)),int(float(uv[2][1])*int(data.height)))
	var high := Vector2i(int(float(uv[1][0])*int(data.width)),int(float(uv[0][1])*int(data.height)))
	var gem_rect := Rect2i(low,high-low+Vector2i.ONE)
	var snapshots: Array = []
	for tick in range(16):
		world.tick_source_actors()
		var image: Image = world.texture_cache[name].get_image().get_region(gem_rect)
		var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(image.get_data())
		snapshots.append(hash.finish().hex_encode())
	if snapshots[0] == snapshots[1] or snapshots[0] != snapshots[8] or snapshots[7] != snapshots[15]:
		push_error("Gem atlas did not advance and wrap through the source eight-frame cycle"); quit(1); return
	for state in player.streams:
		if int(state.interval) == 1 and int(state.frames) == 8 and int(state.displayed) != 7:
			push_error("Texture frame upload/counter order differs from source"); quit(1); return
	world.queue_free(); await process_frame
	print("PASS: live shared gem atlas advances and wraps original eight-frame cycle at source ticks")
	quit(0)
