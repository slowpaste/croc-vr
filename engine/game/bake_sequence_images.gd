extends SceneTree
func _initialize() -> void: call_deferred("bake")
func bake() -> void:
	var args := OS.get_cmdline_user_args()
	for option in ["--content","--scene","--output"]:
		if args.find(option) < 0: push_error("Missing "+option);quit(1);return
	var content := str(args[args.find("--content")+1]);var scene := int(args[args.find("--scene")+1]);var directory := str(args[args.find("--output")+1])
	assert(not DirAccess.dir_exists_absolute(directory))
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var session = preload("res://source_sequence_session.gd").new();root.add_child(session)
	if not session.setup(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}): push_error(session.fault);quit(1);return
	session.audio.stream.stop_stream()
	var parts: Array = [];var count := 0
	for part_index in range(session.cached_parts.size()):
		var frames: Array = []
		for index in range(session.cached_parts[part_index].size()):
			assert(session.present_frame(part_index,index))
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			var image: Image = session.output_texture().get_image()
			var packed := preload("res://source_cutscene_image_codec.gd").encode(image)
			var restored := preload("res://source_cutscene_image_codec.gd").decode(packed.bytes,packed)
			assert(not restored.has("fault") and restored.image.get_data() == image.get_data())
			var file := "%02d-%04d.cfi"%[part_index,index]
			var output := FileAccess.open(directory.path_join(file),FileAccess.WRITE);assert(output != null)
			output.store_buffer(packed.bytes);output.close();packed.erase("bytes")
			packed.file = file;packed.sha256 = FileAccess.get_sha256(directory.path_join(file));frames.append(packed);count += 1
			if index%30 == 0: print("MOVIE_IMAGE_BAKE: scene=",scene," part=",part_index," frame=",index," total=",count)
		parts.append({"frames":frames})
	var descriptor := {"schema":1,"sky_orientation_revision":1,"scene_id":scene,"fingerprint":preload("res://source_sequence_cache_identity.gd").fingerprint(session.config,tables),"parts":parts,"frames":count}
	var output := FileAccess.open(directory.path_join("index.json"),FileAccess.WRITE);output.store_string(JSON.stringify(descriptor));output.close()
	session.queue_free();await process_frame
	print("MOVIE_IMAGE_CACHE_COMPLETE: scene=",scene," frames=",count)
	quit(0)
