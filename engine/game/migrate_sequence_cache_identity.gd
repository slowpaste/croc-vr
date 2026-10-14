extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1]); option = args.find("--scene")
	if option < 0: quit(1); return
	var scene := int(args[option+1])
	var manifest_path := content.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config.fault)); quit(1); return
	var identity = preload("res://source_sequence_cache_identity.gd")
	var old: String = identity.fingerprint(config,tables,false)
	var portable: String = identity.fingerprint(config,tables,true)
	var descriptor := {}
	for entry in manifest.get("cutsceneSequenceCaches",[]):
		if int(entry.scene_id) == scene: descriptor = entry; break
	if descriptor.is_empty(): push_error("Missing cache to migrate"); quit(1); return
	if descriptor.fingerprint != old and descriptor.fingerprint != portable:
		push_error("Refusing to migrate stale geometry cache"); quit(1); return
	var cache_path := content.path_join(str(descriptor.file))
	var cache: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cache_path))
	if cache.get("fingerprint","") != descriptor.fingerprint or int(cache.get("scene_id",-1)) != scene:
		push_error("Cache descriptor identity differs"); quit(1); return
	# Change only identity metadata; keep every original stage mesh and checksum.
	cache.fingerprint = portable
	var file := FileAccess.open(cache_path,FileAccess.WRITE); file.store_string(JSON.stringify(cache)); file.close()
	# Reread before publishing so an unrelated import is not overwritten.
	manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	for entry in manifest.cutsceneSequenceCaches:
		if int(entry.scene_id) == scene: entry.fingerprint = portable
	file = FileAccess.open(manifest_path,FileAccess.WRITE); file.store_string(JSON.stringify(manifest)); file.close()
	print("CACHE_IDENTITY_MIGRATED: ",scene," ",portable)
	quit(0)
