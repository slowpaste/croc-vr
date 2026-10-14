extends RefCounted
static func read_json(content: String, file: String) -> Dictionary:
	var path := content.path_join(file)
	if not FileAccess.file_exists(path): return {"fault":"Missing cutscene content: " + file}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {"fault":"Invalid cutscene content: " + file}

static func load_sad(content: String, manifest: Dictionary, tables: Dictionary, state: Dictionary) -> Dictionary:
	if not state.has_all(["mix","history","filter","threaded","prefill","phase_us"]): return {"fault":"Cutscene requires explicit CD state and onset"}
	var resolved := preload("res://source_cutscene_resources.gd").resolve(20,tables,manifest)
	if resolved.has("fault"): return resolved
	var room := read_json(content,str(resolved.parts[0].room.file))
	if room.has("fault"): return room
	var factors: Array = tables.get("mapYScale",{}).get("values",[])
	var style := int(room.get("style",-1))
	if room.get("entities",[]).is_empty() or style < 0 or style >= factors.size(): return {"fault":"Missing original cutscene room anchor"}
	var first: Dictionary = room.entities[0]
	var anchor := preload("res://source_rotation.gd").map_position(first.position,int(factors[style]))
	if anchor.has("fault"): return anchor
	anchor.yaw = preload("res://source_rotation.gd").halfword(roundi(float(first.rotation[1])*4096.0))
	var track_name := "TK%02d_TRK.MOD" % int(room.get("style",-1))
	var track: Dictionary = {}
	for entry in manifest.get("models",[]):
		if entry.name == track_name: track = entry
	if track.is_empty(): return {"fault":"Missing SAD background geometry"}
	var track_models := read_json(content,str(track.file))
	if track_models.has("fault"): return track_models
	for tile in room.get("tracks",[]):
		if int(tile.index) < 0 or int(tile.index) >= track_models.get("models",[]).size(): return {"fault":"Invalid SAD background tile"}
	var tiles := preload("res://source_cutscene_tiles.gd").poses(room,tables)
	if tiles.has("fault"): return tiles
	var pose: Dictionary = {}
	var audio: Dictionary = {}
	var cache: Dictionary = {}
	var texture: Dictionary = {}
	for entry in manifest.get("cutscenePoses",[]):
		if entry.name == "SAD": pose = entry
	for entry in manifest.get("cutsceneAudio",[]):
		if entry.name == "SAD": audio = entry
	for entry in manifest.get("cutsceneMeshes",[]):
		if entry.name == "SAD": cache = entry
	for entry in manifest.get("textures",[]):
		if entry.name == "INTRO.BIN": texture = entry
	if pose.is_empty() or audio.is_empty() or cache.is_empty() or texture.is_empty(): return {"fault":"SAD cutscene assets are not imported"}
	var room_lighting := read_json(content,str(pose.get("roomLighting","")))
	if room_lighting.has("fault"): return room_lighting
	if pose.model != resolved.parts[0].model.file: return {"fault":"SAD pose/model binding mismatch"}
	var config := state.duplicate(true)
	var sky_model: Dictionary = {}
	var sky_texture: Dictionary = {}
	for entry in manifest.models:
		if entry.name == "TB01_DOM.MOD": sky_model = entry
	for entry in manifest.textures:
		if entry.name == "TB26.BIN": sky_texture = entry
	if sky_model.is_empty() or sky_texture.is_empty(): return {"fault":"Missing original SAD26 dome resources"}
	config.sky_models = read_json(content,str(sky_model.file))
	config.sky_atlas = read_json(content,str(sky_texture.file))
	config.sky_colors=preload("res://source_background_colors.gd").lookup(manifest,"TB26.BIN")
	if config.sky_models.has("fault") or config.sky_atlas.has("fault"): return {"fault":"Invalid original SAD dome data"}
	var sky_image := Image.load_from_file(content.path_join(sky_texture.image))
	if sky_image == null or sky_image.is_empty(): return {"fault":"Missing SAD dome image"}
	config.sky_texture = ImageTexture.create_from_image(sky_image)
	for binding in [["data",pose.file],["models",pose.model],["atlas",texture.file],["cache",cache.file]]:
		var data := read_json(content,str(binding[1]))
		if data.has("fault"): return data
		config[str(binding[0])] = data
	var image := Image.load_from_file(content.path_join(texture.image))
	if image == null or image.is_empty(): return {"fault":"Missing SAD atlas image"}
	var meshes: Array = []
	for entry in config.cache.get("files",[]):
		var path := content.path_join(entry.file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(entry.sha256): return {"fault":"Missing or changed SAD cached mesh"}
		meshes.append(load(path))
	config.foreground_ordered = bool(config.cache.get("ordering",false))
	config.erase("cache")
	config.room_lighting = room_lighting
	config.compositor_frames = []
	for entry in manifest.get("cutsceneCompositor",[]):
		if entry.name != "SAD": continue
		var descriptor := read_json(content,str(entry.file))
		if descriptor.has("fault"): return descriptor
		var loaded := preload("res://source_cutscene_compositor_cache.gd").frames(content,descriptor)
		if loaded.has("fault"): return loaded
		config.compositor_frames = loaded.frames
	if texture.has("maskImage"):
		var mask_image := Image.load_from_file(content.path_join(texture.maskImage))
		if mask_image == null or mask_image.is_empty(): return {"fault":"Missing original texture transparency mask"}
		config.actor_mask = ImageTexture.create_from_image(mask_image)
	config.background_meshes = []
	config.sky_meshes = []
	config.background_ordered = false
	for entry in manifest.get("cutsceneBackgroundMeshes",[]):
		if entry.name != "SAD": continue
		var background := read_json(content,str(entry.file))
		if background.has("fault"): return background
		config.background_ordered = bool(background.get("ordering",false))
		for file in background.get("files",[]):
			var mesh_path := content.path_join(file.file)
			if not FileAccess.file_exists(mesh_path) or FileAccess.get_sha256(mesh_path) != str(file.sha256): return {"fault":"Missing or changed SAD background mesh"}
			config.background_meshes.append(load(mesh_path))
			if file.has("sky_file"):
				var sky_path := content.path_join(file.sky_file)
				if not FileAccess.file_exists(sky_path) or FileAccess.get_sha256(sky_path) != str(file.sky_sha256): return {"fault":"Missing or changed SAD sky mesh"}
				config.sky_meshes.append(load(sky_path))
		for candidate in manifest.textures:
			if candidate.name != str(entry.texture): continue
			var background_image := Image.load_from_file(content.path_join(candidate.image))
			if background_image == null or background_image.is_empty(): return {"fault":"Missing SAD background atlas"}
			config.background_texture = ImageTexture.create_from_image(background_image)
	config.merge({"content":content,"tables":tables,"texture":ImageTexture.create_from_image(image),"audio":audio,"meshes":meshes,"resources":resolved,"room":room,"track_models":track_models,"anchor":anchor,"tiles":tiles},true)
	return config
