extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var resolver = preload("res://source_cutscene_resources.gd")
	for scene in range(24):
		var result: Dictionary = resolver.resolve(scene,tables,manifest)
		assert(not result.has("fault") and result.parts.size() == int(tables.gameOver.sequenceScenes.records[scene].modelCount))
		assert(result.texture.name == ("OUTRO.BIN" if scene == 19 else "INTROJIG.BIN" if scene in [7,16] else "INTRO.BIN"))
	var sad: Dictionary = resolver.resolve(20,tables,manifest)
	assert(sad.parts.size() == 1 and sad.parts[0].model.name == "SAD00.MOD" and sad.parts[0].room.name == "MP084_00.MAP" and sad.entry_fade == 1)
	assert(resolver.resolve(24,tables,manifest).has("fault"))
	var missing: Dictionary = manifest.duplicate(true)
	missing.models = []
	assert(resolver.resolve(20,tables,missing).has("fault"))
	print("PASS: all24 native cutscene descriptors resolve every original model and consecutive room; SAD20 and missing-resource guards")
	quit(0)
