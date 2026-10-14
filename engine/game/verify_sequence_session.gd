extends SceneTree
func playback_id(stream: Node) -> int: return stream.playback.get_instance_id()
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	option = args.find("--scene")
	var scene := int(args[option+1]) if option >= 0 else 16
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var session := preload("res://source_sequence_session.gd").new(); root.add_child(session)
	if not session.setup(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":true,"prefill":0,"phase_us":6667}):
		push_error(session.fault); quit(1); return
	var captured := 0; var frames := 0; var graphs := {}
	var expected_frames: int = session.player.frames.size()
	var visited_parts := {}
	for tick in range(expected_frames+160):
		var result: Dictionary = session.advance(33334,0,1)
		if result.has("fault"): push_error(str(result.fault)); quit(1); return
		frames += result.get("presented",[]).size()
		if not result.get("presented",[]).is_empty(): visited_parts[int(session.player.current_part)] = true
		if session.audio.started and captured == 0: captured = playback_id(session.audio.stream)
		graphs[session.compositor.get_instance_id()] = true
		if session.loaded_frames.size() > 4: push_error("Sequence retained unbounded frame meshes"); quit(1); return
		var stages := 0
		for graph in session.graph_cache.values(): stages += graph.stages.size()
		if stages > maxi(session.CACHED_STAGE_BUDGET,session.compositor.stages.size()): push_error("Cached compositor stage budget exceeded"); quit(1); return
		if tick%60 == 0:
			var progress := FileAccess.open("res://../build/sequence-%02d-session-progress.json"%scene,FileAccess.WRITE)
			progress.store_string(JSON.stringify({"scene":scene,"last_index":int(session.player.last_index),"expected_frames":expected_frames,"parts_visited":visited_parts.size(),"loaded_frames":session.loaded_frames.size(),"retained_stages":stages,"graph_builds":session.graph_builds,"complete":false}))
			progress.close()
		if tick == 20:
			var prior := session.player.last_index; session.set_paused(true)
			if not session.advance(1000000,0,1).paused or session.player.last_index != prior: push_error("Sequence pause advanced poses"); quit(1); return
			session.set_paused(false)
		await process_frame
		if result.complete: break
	if not session.complete or session.player.last_index != expected_frames-1 or frames != expected_frames or visited_parts.size() != session.config.parts.size() or session.audio.started or not session.audio.ended or session.output_texture() == null:
		push_error("Sequence scenic/audio session did not finish every pose and part"); quit(1); return
	var builds := session.graph_builds
	if session.graph_cache.size() > 4 or (scene == 16 and builds >= 180):
		push_error("Compositor layout reuse did not reduce graph construction"); quit(1); return
	for graph in session.graph_cache.values():
		for stage in graph.stages:
			if graph != session.compositor and stage.render_target_update_mode != SubViewport.UPDATE_DISABLED:
				push_error("Inactive cached compositor kept rendering"); quit(1); return
	await RenderingServer.frame_post_draw
	var image: Image = session.output_texture().get_image()
	if image == null or image.is_empty(): push_error("Ending session has no rendered output"); quit(1); return
	session.queue_free(); await process_frame; await create_timer(0.2).timeout
	var deadline := Time.get_ticks_msec()+2000
	while captured != 0 and is_instance_id_valid(captured) and Time.get_ticks_msec() < deadline: await process_frame
	if captured != 0 and is_instance_id_valid(captured): push_error("Sequence audio playback did not retire"); quit(1); return
	var final_progress := FileAccess.open("res://../build/sequence-%02d-session-progress.json"%scene,FileAccess.WRITE)
	final_progress.store_string(JSON.stringify({"scene":scene,"last_index":expected_frames-1,"expected_frames":expected_frames,"parts_visited":visited_parts.size(),"graph_builds":builds,"complete":true}))
	final_progress.close()
	print("PASS: sequence",scene," renders",expected_frames," cached scenic poses across",visited_parts.size()," parts, pauses, keeps shared audio onset/stop and retires playback; graph_builds=",builds)
	quit(0)
