extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var record: Dictionary = {}
	for texture in manifest.textures:
		if texture.name == "TK01_TRK.BIN": record = texture
	if record.is_empty(): quit(1); return
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file)))
	var texture := ImageTexture.create_from_image(Image.load_from_file(content.path_join(record.image)))
	var renderer := preload("res://source_menu_text_renderer.gd").new()
	root.add_child(renderer)
	var layout := preload("res://source_stage_stats.gd").number_layout({"kind":0,"shown_rescues":6,"shown_bank":15,"shown_lives":9})
	if not renderer.set_text(layout,atlas,texture) or renderer.mesh == null or renderer.mesh.surface_get_array_len(0) != 24:
		push_error("Original results digits did not bind to track atlas and source quads")
		quit(1)
		return
	var arrays: Array = renderer.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if not vertices[0].is_equal_approx(Vector3(100.0/256.0-1.0,1.0-136.0/120.0,0)):
		push_error("Results renderer displaced original first number")
		quit(1)
		return
	var icons := preload("res://source_stage_stats.gd").icon_layout({"kind":0})
	if not renderer.set_text(icons.track,atlas,texture) or renderer.mesh.surface_get_array_len(0) != 18:
		push_error("Original results track icons failed real atlas binding")
		quit(1)
		return
	var shared_name := preload("res://source_stage_stats.gd").shared_texture_name(1)
	for candidate in manifest.textures:
		if candidate.name == shared_name: record = candidate
	if record.name != shared_name: quit(1); return
	atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file)))
	texture = ImageTexture.create_from_image(Image.load_from_file(content.path_join(record.image)))
	icons = preload("res://source_stage_stats.gd").icon_layout({"kind":1})
	if not renderer.set_text(icons.shared,atlas,texture) or renderer.mesh.surface_get_array_len(0) != 6:
		push_error("Original boss-results shared gameplay atlas binding failed")
		quit(1)
		return
	renderer.queue_free()
	var bindings := {}
	for pair in [["font","TK01_TRK.BIN"],["track","TK01_TRK.BIN"],["shared","TK01_ENM.BIN"]]:
		for candidate in manifest.textures:
			if candidate.name == pair[1]:
				bindings[pair[0]] = {"data":JSON.parse_string(FileAccess.get_file_as_string(content.path_join(candidate.file))),"texture":ImageTexture.create_from_image(Image.load_from_file(content.path_join(candidate.image)))}
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var combined := preload("res://source_stage_stats_renderer.gd").new()
	root.add_child(combined)
	var state := preload("res://source_stage_stats.gd").initialize(0,75,6,40,3,[1,1,1,1,1,1,1,1])
	if not combined.update_stats(state,tables.stageResults,bindings) or not combined.labels.visible or not combined.track.visible or combined.shared.visible: quit(1); return
	var label_vertices := int(combined.labels.mesh.surface_get_array_len(0))
	state.phase = 64
	if not combined.update_stats(state,tables.stageResults,bindings) or not combined.backdrop.visible or combined.backdrop.fade_material.render_priority >= combined.labels.text_material.render_priority: quit(1); return
	state.secret = 1
	if not combined.update_stats(state,tables.stageResults,bindings) or combined.backdrop.visible: quit(1); return
	state.kind = 1
	state.busy = 1
	if not combined.update_stats(state,tables.stageResults,bindings) or not combined.shared.visible or combined.labels.mesh.surface_get_array_len(0) >= label_vertices:
		push_error("Combined results renderer lost boss icon or busy prompt suppression")
		quit(1)
		return
	combined.queue_free()
	await process_frame
	print("PASS: original track-atlas result digit binding and source screen-space geometry")
	quit(0)
