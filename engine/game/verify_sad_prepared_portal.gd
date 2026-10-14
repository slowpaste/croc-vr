extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args:=OS.get_cmdline_user_args();var content:String=args[args.find("--content")+1]
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var session=preload("res://source_sad_portal_session.gd").new();root.add_child(session)
	assert(session.setup_sad(content,manifest,tables,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}))
	session.audio.stream.stop_stream()
	assert(session.portal_performance.prepared and session.prepared_frames.size()==291)
	for index in [0,30,90,180,290]:
		var expected:=preload("res://source_cutscene_portal.gd").prepare(session.portal_config.compositor_frames[index])
		var actual:Dictionary=session.prepared_frames[index]
		assert(expected.h==actual.h and expected.order==actual.order)
		for key in expected.meshes:assert(expected.meshes[key].surface_get_arrays(0)==actual.meshes[key].surface_get_arrays(0))
	var started:=Time.get_ticks_usec()
	for index in range(60):assert(session.present_portal(index))
	print("PASS: SAD prepared portal equivalence; 60 presentations us=",Time.get_ticks_usec()-started)
	session.queue_free();await process_frame;quit(0)
