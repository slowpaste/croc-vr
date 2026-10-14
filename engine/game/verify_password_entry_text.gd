extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var state := preload("res://source_password_entry.gd").initialize()
	var layout := preload("res://source_password_entry_text.gd").layout(tables.gameOver,state)
	assert(not layout.has("fault") and layout.labels.size() == 5)
	assert(layout.labels[0].text == "Enter Password" and layout.labels[0].glyphs[0].position.y == 24)
	assert(layout.labels[4].text == "_______________" and layout.labels[4].glyphs.size() == 15 and layout.labels[4].glyphs[0].position.y == 100)
	for entry in manifest.textures:
		if entry.name != "FONT.BIN": continue
		var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
		var texture := ImageTexture.create_from_image(Image.load_from_file(content.path_join(entry.image)))
		var renderer := preload("res://source_menu_text_renderer.gd").new()
		assert(renderer.set_text(layout,atlas,texture))
		renderer.free()
		var backdrop_binding := {}
		for background in manifest.textures:
			if background.name == "STILLGOH.BIN":
				backdrop_binding = {"data":JSON.parse_string(FileAccess.get_file_as_string(content.path_join(background.file))),"texture":ImageTexture.create_from_image(Image.load_from_file(content.path_join(background.image)))}
		var combined := preload("res://source_game_over_renderer.gd").new()
		var bindings := {"font":{"data":atlas,"texture":texture},"backdrop":backdrop_binding}
		assert(combined.update_entry(tables,state,bindings) and combined.visible)
		state.symbols[0] = 5
		assert(not combined.update_entry(tables,state,bindings) and not combined.visible)
		combined.free()
		print("PASS: original password-entry heading, instructions,15 blank slots and actual FONT atlas")
		quit(0); return
	quit(1)
