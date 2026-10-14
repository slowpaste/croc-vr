extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var streams: Array = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.musicIndex))).streams
	var found := 0
	var bootstrap: Array = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.bootstrapMusic.file))).endSectorOffsets
	for catalog in manifest.musicBounds:
		if catalog.name not in ["MUSIC.BIN","MAGMUS.BIN"]: continue
		var bounds: Array = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(catalog.file))).endSectorOffsets
		if (bounds == bootstrap) != (catalog.name == "MUSIC.BIN"): quit(1); return
		var session := preload("res://source_music_session.gd").new()
		var prepared := session.prepare({"cue":64,"mode":4,"room":0,"style":0,"loop":false},tables.musicCues.pairs,bounds,streams)
		if prepared.has("fault") or prepared.logical != 64 or prepared.pack != 10 or prepared.channel != 1: quit(1); return
		session.acknowledge_read(true)
		var callback := session.receive(1)
		if catalog.name == "MUSIC.BIN":
			if int(prepared.end_sector)-int(prepared.pack_start) != 600 or callback.active != 1 or callback.completion_pending != 0: quit(1); return
		else:
			if int(prepared.end_sector) != int(prepared.pack_start) or callback.active != 0 or callback.completion_pending != 1: quit(1); return
		found += 1
	if found != 2: quit(1); return
	print("PASS: original results cue64 catalog spans and first-callback continuation/completion differ as source data specifies")
	quit(0)
