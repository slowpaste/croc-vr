extends SceneTree
func playback_released(reference: WeakRef) -> bool:
	return reference.get_ref() == null
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var asset: Dictionary = manifest.cutscenePoses[0]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
	var models: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.model)))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var record: Dictionary = {}
	for candidate in manifest.textures:
		if candidate.name == "INTRO.BIN": record = candidate
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file)))
	var texture := ImageTexture.create_from_image(Image.load_from_file(content.path_join(record.image)))
	var cache: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.cutsceneMeshes[0].file)))
	var meshes: Array = []
	for file in cache.files: meshes.append(load(content.path_join(file.file)))
	var session := preload("res://source_cutscene_session.gd").new()
	root.add_child(session)
	var loaded := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[128,128,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	assert(not loaded.has("fault") and loaded.room.tracks.size() == 18 and loaded.room.entities[0].name == "IntroStart")
	assert(loaded.anchor.position == Vector3i(8601,-246,8253) and loaded.anchor.yaw == 3069)
	assert(loaded.tiles.parts.size() == 18 and loaded.tiles.parts[0].id == 50 and loaded.tiles.parts[0].position == [4096,0,0] and loaded.tiles.parts[0].matrix == [-4096,0,0,0,4096,0,0,0,-4096])
	var anchored_first := preload("res://source_cutscene_view.gd").anchored_camera(loaded.data.frames[0].camera,loaded.anchor.position,int(loaded.anchor.yaw),tables.rotation.pairs)
	assert(anchored_first.position == [6274,620,11862] and Vector3i(int(anchored_first.angles[0]),int(anchored_first.angles[1]),int(anchored_first.angles[2])) == Vector3i(45,6119,2047))
	assert(not session.setup_sad(content,manifest,tables,{}))
	assert(session.setup_sad(content,manifest,tables,{"mix":[128,128,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}))
	assert(session.advance(33334,0,1).presented == [0] and not session.audio.started)
	assert(session.background_view == preload("res://source_cutscene_view.gd").camera_view(anchored_first,tables.rotation.pairs))
	assert(session.background.mesh == loaded.background_meshes[0])
	assert(session.sky.mesh == loaded.sky_meshes[0])
	assert(not session.advance(20000,0,1).has("fault") and session.audio.started)
	var playback_reference: WeakRef = weakref(session.audio.stream.playback)
	var index: int = session.player.last_index
	var sector: int = session.timeline.clock.clock.cursor
	session.set_paused(true)
	assert(session.advance(1000000,0,1).paused and session.player.last_index == index and session.timeline.clock.clock.cursor == sector and session.audio.stream.stream_paused)
	session.set_paused(false)
	var result: Dictionary = session.advance(10000000,0,64)
	while not result.complete: result = session.advance(0,0,64)
	assert(session.complete and not session.active and session.player.last_index == 290 and session.audio.ended and session.audio.stream.playback == null)
	assert(session.background.mesh == loaded.background_meshes[290])
	assert(session.sky.mesh == loaded.sky_meshes[290])
	assert(session.advance(1000000,0,1).complete and session.audio.ended)
	var failed := preload("res://source_cutscene_session.gd").new()
	root.add_child(failed)
	assert(failed.setup({"data":data,"models":models,"tables":tables,"atlas":atlas,"texture":texture,"content":content,"audio":manifest.cutsceneAudio[0],"mix":[128,128,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667,"meshes":meshes}))
	assert(not failed.advance(53334,0,1).has("fault") and failed.audio.started)
	var failed_playback_reference: WeakRef = weakref(failed.audio.stream.playback)
	failed.timeline.active = false
	var failure: Dictionary = failed.advance(0,0,1)
	assert(failure.has("fault") and not failed.active and failed.audio.stream.playback == null)
	assert(failed.advance(1000000,0,1) == failure)
	failed.queue_free()
	await create_timer(0.1).timeout
	session.queue_free(); await process_frame
	# AudioServer retires stopped playback asynchronously on its mixer thread.
	# Verify actual release rather than exiting while retirement is still pending.
	var deadline := Time.get_ticks_msec()+1000
	while (not playback_released(playback_reference) or not playback_released(failed_playback_reference)) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
		await process_frame
	if not playback_released(playback_reference) or not playback_released(failed_playback_reference):
		push_error("Stopped cutscene session audio was not released within one second")
		quit(1)
		return
	print("PASS: combined cached SAD timeline/audio session shares onset, pause and terminal stop lifecycle")
	quit(0)
