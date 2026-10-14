extends SceneTree
func _initialize() -> void:
	var layout := preload("res://source_game_over_backdrop.gd").layout()
	var glyphs: Array = layout.labels[0].glyphs
	if glyphs.size() != 1920 or glyphs[64].position != Vector2(0,8) or glyphs[-1].position != Vector2(504,232) or glyphs[-1].sprite != 1919: quit(1); return
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
	var renderer := preload("res://source_menu_text_renderer.gd").new()
	if not renderer.set_text(layout,atlas,texture) or renderer.mesh.surface_get_array_len(0) != 11520: renderer.free(); quit(1); return
	renderer.free()
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var text := preload("res://source_game_over_text.gd").layout(tables.gameOver)
	var progress: Array = []; progress.resize(45); progress.fill(0)
	var password := preload("res://source_game_over_text.gd").password_row(tables.gameOver,progress,0,[0,0,0,0,0,0,0,0])
	if password.has("fault") or password.glyphs.size() != 15 or password.glyphs[0].position.y != 140: quit(1); return
	text.labels.append(password)
	if text.has("fault") or text.labels.size() != 6 or text.labels[3].text != "is" or text.labels[3].glyphs[0].position.y != 116 or text.labels[0].glyphs.size() != 8 or text.labels[0].glyphs[0].position.y != 24 or text.labels[0].glyphs[0].size.y != 18: quit(1); return
	if text.labels[4].text != "{ or | to return" or text.labels[4].glyphs[0].position.y != 196: quit(1); return
	if text.labels[0].glyphs[0].position.x != 256-int(int(text.labels[0].width)/2) or text.labels[1].glyphs[0].position.y != 48 or text.labels[2].glyphs[0].position.y != 80: quit(1); return
	var name_row := preload("res://source_game_over_text.gd").stage_name_row(tables.gameOver,"A #B")
	if name_row.has("fault") or name_row.glyphs.size() != 2 or name_row.glyphs[0].position.y != 96 or name_row.glyphs[0].size.y != 13: quit(1); return
	if name_row.glyphs[1].position.x != name_row.glyphs[0].position.x+int(tables.gameOver.stageNameGlyphs["65"].advance)+int(tables.gameOver.stageNameGlyphs["32"].advance)+int(tables.gameOver.stageNameGlyphs["35"].advance): quit(1); return
	text.labels.append(name_row)
	var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.levelNames.file)))
	var screen = preload("res://source_game_over_screen.gd")
	var full: Dictionary = screen.compose(tables,names.names,progress,0,[0,0,0,0,0,0,0,0])
	if full.has("fault") or full.level != 10 or full.labels.size() != 7 or full.labels[5].text != names.names[10]: quit(1); return
	var last: Dictionary = screen.compose(tables,names.names,progress,44,[0,0,0,0,0,0,0,0])
	if last.has("fault") or last.level != 54 or last.labels[5].text != "secret sentinel": quit(1); return
	if not screen.compose(tables,[],progress,0,[0,0,0,0,0,0,0,0]).has("fault"): quit(1); return
	text = full
	for candidate in manifest.textures:
		if candidate.name == "FONT.BIN": record = candidate
	atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file)))
	texture = ImageTexture.create_from_image(Image.load_from_file(content.path_join(record.image)))
	renderer = preload("res://source_menu_text_renderer.gd").new()
	if not renderer.set_text(text,atlas,texture) or renderer.mesh == null: renderer.free(); quit(1); return
	renderer.free()
	var combined := preload("res://source_game_over_renderer.gd").new()
	var bindings := {"backdrop":backdrop_binding,"font":{"data":atlas,"texture":texture}}
	if not combined.update_screen(tables,names.names,progress,44,[0,0,0,0,0,0,0,0],bindings) or not combined.visible or combined.backdrop.mesh.surface_get_array_len(0) != 11520 or combined.labels.mesh == null: combined.free(); quit(1); return
	if combined.clear_material.get_shader_parameter("clear_color") != Vector3.ZERO or combined.clear_material.render_priority >= combined.backdrop.text_material.render_priority: combined.free(); quit(1); return
	var saved_clear: Array = tables.gameOver.clearColor
	tables.gameOver.erase("clearColor")
	if combined.update_screen(tables,names.names,progress,44,[0,0,0,0,0,0,0,0],bindings) or combined.visible: combined.free(); quit(1); return
	tables.gameOver.clearColor = saved_clear
	if combined.update_screen(tables,[],progress,0,[0,0,0,0,0,0,0,0],bindings) or combined.visible: combined.free(); quit(1); return
	combined.free()
	print("PASS: original1920-tile backdrop order,512x240 coverage and real STILLGOH atlas geometry")
	quit(0)
