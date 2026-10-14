extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var data: Dictionary = world.runtime_tables.mainMenu
	for tick in [0,15,32,1050]:
		if not preload("res://source_menu_text.gd").title_layout(data,tick).labels.is_empty():
			quit(1)
			return
	for tick in [16,31,1049]:
		var prompt: Dictionary = preload("res://source_menu_text.gd").title_layout(data,tick)
		if prompt.labels.size() != 1 or prompt.labels[0].text != "PRESS START" or prompt.labels[0].width != 203 or prompt.labels[0].glyphs.size() != 10 or prompt.labels[0].glyphs[0].position != Vector2i(155,180):
			push_error("Original title prompt blink/layout differs")
			quit(1)
			return
	var result := preload("res://source_menu_text.gd").layout(data,[65536,38912,38912,38912,38912],false)
	if result.has("fault") or result.labels[0].width != 208 or result.labels[0].glyphs.size() != 9 or result.labels[0].glyphs[0].position != Vector2i(152,156) or result.labels[0].glyphs[0].size != Vector2i(16,12):
		quit(1)
		return
	if result.labels[1].width != 74 or result.labels[1].glyphs[0].position != Vector2i(219,173) or result.labels[1].glyphs[0].size != Vector2i(14,7) or result.labels[3].text != "ENTER PASSWORD":
		quit(1)
		return
	result = preload("res://source_menu_text.gd").layout(data,[65536,65536,65536,65536,65536],true)
	if result.labels[3].text != "CREDITS" or result.labels[3].glyphs.size() != 7:
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: original menu labels, glyph advances/sprite sizes, scale rounding, centering and credits variant")
	quit(0)
