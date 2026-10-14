extends SceneTree
func _initialize() -> void:
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
	var player := preload("res://source_cutscene_player.gd").new()
	root.add_child(player)
	var meshes: Array = []
	if args.has("--cached"):
		var cache: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.cutsceneMeshes[0].file)))
		for file in cache.files:
			assert(FileAccess.get_sha256(content.path_join(file.file)) == file.sha256)
			meshes.append(load(content.path_join(file.file)))
	assert(player.setup(data,models,tables,atlas,texture,0,meshes))
	assert(player.present_next(4,0).waiting and player.last_index == -1)
	assert(player.present_next(5,0).index == 0 and player.fade.kind == 1)
	var before: Dictionary = player.fade.duplicate(true)
	assert(player.present_next(5,0).waiting and player.fade == before)
	assert(player.present_next(4,0).has("fault") and player.last_index == 0)
	var durations: Array = []
	for index in range(1,data.frames.size()):
		var started := Time.get_ticks_usec()
		var result := player.present_next(int(data.frames[index].stream.requiredSectorCount),0)
		durations.append(Time.get_ticks_usec()-started)
		assert(not result.has("fault") and result.index == index)
	assert(player.complete and player.last_index == 290 and player.fade.kind == 8 and player.fade.ready)
	assert(player.present_next(1455,0).complete and player.last_index == 290)
	if args.has("--cached"):
		assert(player.setup(data,models,tables,atlas,texture,0,meshes))
		var timeline := preload("res://source_cutscene_timeline.gd").new()
		assert(timeline.begin(player,manifest.cutsceneAudio[0],0,6667))
		assert(timeline.advance(33333,0,1).presented.is_empty())
		assert(timeline.advance(1,0,1).presented == [0])
		assert(timeline.advance(20000,0,1).audio_frames == 2016)
		timeline.clock.paused = true
		assert(timeline.advance(1000000,0,1).paused and player.last_index == 0)
		timeline.clock.paused = false
		var advanced: Dictionary = timeline.advance(10000000,0,64)
		var count: int = advanced.presented.size()+1
		while not advanced.complete:
			advanced = timeline.advance(0,0,64)
			count += advanced.presented.size()
		assert(count == 291 and player.last_index == 290)
		var stopped_sector: int = timeline.clock.clock.cursor
		assert(timeline.advance(1000000,0,1).presented.is_empty() and timeline.clock.clock.cursor == stopped_sector)
	player.free()
	durations.sort()
	var total := 0
	for duration in durations: total += int(duration)
	print("CUTSCENE_CPU_PROFILE_US: ",{"mean":float(total)/durations.size(),"p95":durations[int(durations.size()*0.95)],"maximum":durations[-1]})
	print("PASS: original sector-ready SAD mesh/fade component presents all291 records without duplicate/wait-time advancement")
	quit(0)
