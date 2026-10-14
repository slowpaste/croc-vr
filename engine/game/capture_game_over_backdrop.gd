extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var record: Dictionary = {}
	for candidate in manifest.textures:
		if candidate.name == "STILLGOH.BIN": record = candidate
	if record.is_empty(): quit(1); return
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file)))
	var texture := ImageTexture.create_from_image(Image.load_from_file(content.path_join(record.image)))
	var backdrop_binding := {"data":atlas,"texture":texture}
	root.size = Vector2i(512,240)
	var camera := Camera3D.new()
	camera.position.z = 3
	root.add_child(camera)
	var renderer := preload("res://source_menu_text_renderer.gd").new()
	root.add_child(renderer)
	if not renderer.set_text(preload("res://source_game_over_backdrop.gd").layout(),atlas,texture): quit(1); return
	if args.has("--labels"):
		var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
		for candidate in manifest.textures:
			if candidate.name == "FONT.BIN": record = candidate
		atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file)))
		texture = ImageTexture.create_from_image(Image.load_from_file(content.path_join(record.image)))
		var labels := preload("res://source_menu_text_renderer.gd").new()
		labels.text_material.render_priority = 127
		root.add_child(labels)
		var text := preload("res://source_game_over_text.gd").layout(tables.gameOver)
		var progress: Array = []; progress.resize(45); progress.fill(0)
		text.labels.append(preload("res://source_game_over_text.gd").password_row(tables.gameOver,progress,0,[0,0,0,0,0,0,0,0]))
		if manifest.has("levelNames"):
			var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.levelNames.file)))
			text = preload("res://source_game_over_screen.gd").compose(tables,names.names,progress,0,[0,0,0,0,0,0,0,0])
		if text.has("fault"): quit(1); return
		if not labels.set_text(text,atlas,texture): quit(1); return
		if manifest.has("levelNames"):
			var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.levelNames.file)))
			var combined := preload("res://source_game_over_renderer.gd").new()
			root.add_child(combined)
			if not combined.update_screen(tables,names.names,progress,0,[0,0,0,0,0,0,0,0],{"backdrop":backdrop_binding,"font":{"data":atlas,"texture":texture}}): quit(1); return
			if args.has("--entry"):
				var state := preload("res://source_password_entry.gd").initialize()
				if not combined.update_entry(tables,state,{"backdrop":backdrop_binding,"font":{"data":atlas,"texture":texture}}): quit(1); return
			if args.has("--continue"):
				if not combined.update_continue(tables,preload("res://source_main_menu.gd").initialize(0,1),{"font":{"data":atlas,"texture":texture}}): quit(1); return
			renderer.hide()
			labels.hide()
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var filename := "game-over-labels.png" if args.has("--labels") else "game-over-backdrop.png"
	if args.has("--entry"): filename = "password-entry.png"
	if args.has("--continue"): filename = "continue-menu.png"
	var error := root.get_texture().get_image().save_png("res://../build/"+filename)
	renderer.queue_free()
	camera.queue_free()
	await process_frame
	quit(error)
