extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var bindings := {}
	for pair in [["font","TK01_TRK.BIN"],["track","TK01_TRK.BIN"],["shared","TK01_ENM.BIN"]]:
		for record in manifest.textures:
			if record.name == pair[1]:
				bindings[pair[0]] = {"data":JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file))),"texture":ImageTexture.create_from_image(Image.load_from_file(content.path_join(record.image)))}
	root.size = Vector2i(512,240)
	var camera := Camera3D.new()
	camera.position.z = 3
	root.add_child(camera)
	var renderer := preload("res://source_stage_stats_renderer.gd").new()
	root.add_child(renderer)
	var state := preload("res://source_stage_stats.gd").initialize(0,75,6,40,3,[0,0,0,0,0,0,0,0])
	if args.has("--dimmed"): state.phase = 64
	if not renderer.update_stats(state,tables.stageResults,bindings): push_error("Results preview binding failed"); quit(1); return
	if args.has("--white"):
		var overlay := preload("res://source_fade_overlay.gd").new()
		root.add_child(overlay)
		overlay.set_source_white_level(128)
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var filename := "stage-results-white-fade.png" if args.has("--white") else "stage-results-dimmed.png" if args.has("--dimmed") else "stage-results-preview.png"
	var error := root.get_texture().get_image().save_png("res://../build/"+filename)
	renderer.queue_free()
	camera.queue_free()
	await process_frame
	quit(error)
