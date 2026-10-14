extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var content := str(args[args.find("--content")+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var session = preload("res://source_sequence_session.gd").new();root.add_child(session)
	assert(session.setup(content,manifest,tables,0,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}))
	session.audio.stream.stop_stream()
	for sample in [[0,299,"300"],[2,28,"600"],[5,35,"1200"]]:
		assert(session.present_frame(sample[0],sample[1]))
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		assert(session.output_texture().get_image().save_png(content.get_base_dir().path_join("build/frame-sky-"+sample[2]+".png")) == OK)
	session.queue_free();await process_frame
	print("PASS: three corrected opening frames rendered")
	quit(0)
