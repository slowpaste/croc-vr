extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,0,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config.fault)); quit(1); return
	var identity = preload("res://source_sequence_cache_identity.gd")
	var output := FileAccess.open("res://../build/cache-identity-desktop.json",FileAccess.WRITE)
	var rooms := {}
	for index in [8,9]: rooms[str(index)] = JSON.stringify(config.parts[index].room)
	output.store_string(JSON.stringify({"fingerprint":identity.fingerprint(config,tables),"components":identity.components(config,tables),"components_full":identity.components(config,tables,true),"room_texts":rooms})); output.close()
	print("CACHE_IDENTITY: ",identity.fingerprint(config,tables))
	quit(0)
