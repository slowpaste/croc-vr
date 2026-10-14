extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0:quit(1);return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var binder = preload("res://source_options_assets.gd")
	var result: Dictionary = binder.bind(manifest)
	if result.has("fault") or result.slots.size()!=17:quit(1);return
	var expected := [4,3,5,1,9,1,1,1,1,1,1,1,1,1,1,1,1]
	for index in range(17):
		var asset: Dictionary = result.slots[binder.SLOTS[index]]
		var model: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
		if model.get("models",[]).size()!=expected[index]:push_error("Options native slot resolves the wrong imported model group");quit(1);return
	var shuffled := manifest.duplicate(true);shuffled.resources.reverse()
	if binder.bind(shuffled)!=result:push_error("Manifest order changed original Options slot binding");quit(1);return
	var missing := {"resources":[]}
	for resource in manifest.resources:
		if resource.get("owner","")=="OPTIONS.WAD" and resource.get("type","")=="model":missing.resources.append(resource.duplicate(true))
	missing.resources.pop_back()
	if not binder.bind(missing).has("fault"):quit(1);return
	print("PASS: all17 original Options model slots resolve actual imported groups independent of manifest order; incomplete bank rejected")
	quit(0)
