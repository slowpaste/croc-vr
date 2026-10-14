extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config)); quit(1); return
	var records := {}
	for record in manifest.textures: records[str(record.name)] = record
	var room_atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(records["TK05_TRK.BIN"].file)))
	var textures := {"room":ImageTexture.create_from_image(Image.load_from_file(content.path_join(records["TK05_TRK.BIN"].image))),"actor":config.texture,"sky":config.sky_texture}
	var masks := {"actor":ImageTexture.create_from_image(Image.load_from_file(content.path_join(records["INTRO.BIN"].maskImage)))}
	var first := preload("res://source_cutscene_frame_plan.gd").build(config,room_atlas,20)
	if first.has("fault"): quit(1); return
	var live := preload("res://source_cutscene_compositor.gd").new()
	root.add_child(live)
	var cached: Dictionary = {}
	if args.has("--cached"):
		var descriptor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.cutsceneCompositor[0].file)))
		cached = preload("res://source_cutscene_compositor_cache.gd").frames(content,descriptor)
		assert(not cached.has("fault") and live.setup_cached(cached.frames[20],textures,masks))
	else: assert(live.setup(first,int(first.h),textures,masks))
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var previous := live.output.get_texture().get_image().get_data()
	var matched := true
	for index in [21,100,200,289]:
		var next := preload("res://source_cutscene_frame_plan.gd").build(config,room_atlas,index)
		var presented: bool = live.present_cached(cached.frames[index]) if args.has("--cached") else live.present(next,int(next.h))
		if next.has("fault") or not presented: matched = false; break
		await process_frame; await RenderingServer.frame_post_draw
		var updated := live.output.get_texture().get_image().get_data()
		var reference := preload("res://source_cutscene_compositor.gd").new()
		root.add_child(reference)
		assert(reference.setup(next,int(next.h),textures,masks))
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var expected := reference.output.get_texture().get_image().get_data()
		matched = matched and updated == expected and previous != updated
		print("SAD_REAL_FRAME_UPDATE: ",{"index":index,"viewports":live.stages.size(),"changed":previous!=updated,"matches_fresh_after_one_render":updated==expected})
		previous = updated
		reference.queue_free(); await process_frame
	if args.has("--cached"):
		var timings: Array[int] = []
		var total := 0
		for frame_data in cached.frames:
			var start := Time.get_ticks_usec()
			assert(live.present_cached(frame_data))
			var elapsed := Time.get_ticks_usec()-start
			timings.append(elapsed); total += elapsed
		timings.sort()
		print("COMPOSITOR_CACHED_SWITCH_CPU_US: ",{"frames":timings.size(),"mean":float(total)/timings.size(),"p95":timings[int(timings.size()*0.95)],"maximum":timings[-1]})
	live.queue_free(); await process_frame
	quit(0 if matched else 1)
