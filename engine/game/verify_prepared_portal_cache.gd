extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args:=OS.get_cmdline_user_args();var content:String=args[args.find("--content")+1]
	var scene:=int(args[args.find("--scene")+1]) if args.has("--scene") else 0
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var session=preload("res://source_sequence_portal_session.gd").new();root.add_child(session)
	assert(session.setup(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}))
	assert(session.portal_performance.prepared)
	session.audio.stream.stop_stream()
	var samples:=0
	for part in range(session.cached_parts.size()):
		for index in [0,int(session.cached_parts[part].size()/2),session.cached_parts[part].size()-1]:
			var original:=preload("res://source_cutscene_compositor_cache.gd").frames(content,{"frames":[session.cached_parts[part][index]]})
			assert(not original.has("fault"))
			var corrected:=preload("res://source_sequence_sky_correction.gd").apply(original.frames[0],session.config.parts[part],index)
			assert(not corrected.has("fault"))
			var expected:=preload("res://source_cutscene_portal.gd").prepare(corrected)
			assert(session.present_frame(part,index))
			var actual:Dictionary=session.loaded_frames["%d:%d"%[part,index]]
			assert(actual.h==expected.h and actual.meshes.size()==expected.meshes.size() and actual.order==expected.order)
			for key in actual.meshes:
				assert(actual.meshes[key].surface_get_arrays(0)==expected.meshes[key].surface_get_arrays(0),"Portal geometry changed at "+str(part)+":"+str(index)+":"+key)
			samples+=1
	session.queue_free();await process_frame
	print("PASS: ",samples," prepared opening frames exactly match legacy clipped vertices, UVs, UV2, colors and indices across all parts")
	quit(0)
