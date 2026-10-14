extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var room = load("res://imported.tscn").instantiate()
	room.set_script(load("res://probe_texture_scene.gd"))
	root.add_child(room)
	for i in range(30):
		await process_frame
	room.set_physics_process(false)
	room.board.hide()
	room.hud.hide()
	if OS.get_cmdline_user_args().has("--probe-detail"):
		room.camera.position = Vector3(11, 3, 9)
		room.camera.look_at(Vector3(14, 1, 12))
	var args := OS.get_cmdline_user_args()
	var target_name := ""
	for i in range(args.size() - 1):
		if args[i] == "--probe-target":
			target_name = args[i + 1]
	if not target_name.is_empty():
		var found := false
		for entry in room.manifest.maps:
			if entry.name == room.map_name:
				for entity in room.read_json(entry.file).entities:
					if entity.name == target_name:
						var target: Vector3 = room.vector(entity.position) + Vector3(0, 0.8, 0)
						room.camera.position = target + Vector3(0, 0.8, -3)
						if args.has("--probe-side"):
							room.camera.position = target + Vector3(3, 0.8, 0)
						room.camera.look_at(target)
						found = true
						break
		if not found:
			push_error("Texture probe target not found: " + target_name)
			quit(1)
			return
	await RenderingServer.frame_post_draw
	var suffix := "legacy" if OS.get_cmdline_user_args().has("--probe-legacy-uv") else "corrected"
	if OS.get_cmdline_user_args().has("--probe-detail"):
		suffix += "-detail"
	if not target_name.is_empty():
		suffix += "-" + target_name.to_lower()
	var result := root.get_texture().get_image().save_png("res://../build/texture-probe-" + suffix + ".png")
	quit(result)
