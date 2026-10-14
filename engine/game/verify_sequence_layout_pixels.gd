extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args();var content := str(args[args.find("--content")+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,16,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	assert(not config.has("fault"))
	var entry: Dictionary
	for candidate in manifest.cutsceneSequenceCaches:
		if int(candidate.scene_id) == 16: entry = candidate
	var cache: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
	var part: Dictionary = config.parts[0]
	var textures := {"actor":part.texture,"room":part.background_texture,"sky":part.sky_texture}
	var masks := {"actor":part.actor_mask,"room":part.room_mask,"sky":part.sky_mask}
	for index in [0,80,200,420]:
		var loaded := preload("res://source_cutscene_compositor_cache.gd").frames(content,{"frames":[cache.parts[0].frames[index]]})
		assert(not loaded.has("fault"))
		var frame: Dictionary = loaded.frames[0]
		var raw = preload("res://source_cutscene_compositor.gd").new();root.add_child(raw)
		var canonical = preload("res://source_cutscene_compositor.gd").new();root.add_child(canonical)
		assert(raw.setup_cached(frame,textures,masks))
		assert(canonical.setup_cached(preload("res://source_sequence_session.gd").canonical_frame(frame),textures,masks))
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var before: Image = raw.output.get_texture().get_image();before.convert(Image.FORMAT_RGB8)
		var after: Image = canonical.output.get_texture().get_image();after.convert(Image.FORMAT_RGB8)
		if before.get_data() != after.get_data(): push_error("Canonical graph changed movie RGB pixels at frame"+str(index));quit(1);return
		raw.queue_free();canonical.queue_free();await process_frame
	print("PASS: canonical movie graph preserves every RGB pixel in four rendered ending frames")
	quit(0)
