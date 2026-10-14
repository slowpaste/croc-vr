extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[128,128,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	assert(not config.has("fault"))
	var atlas: Dictionary = {}
	for entry in manifest.textures:
		if entry.name == "TK05_TRK.BIN": atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
	var cache: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.cutsceneBackgroundMeshes[0].file)))
	assert(cache.files.size() == config.data.frames.size())
	for index in range(cache.files.size()):
		var file: Dictionary = cache.files[index]
		assert(FileAccess.get_sha256(content.path_join(file.file)) == file.sha256)
		var cached: ArrayMesh = load(content.path_join(file.file))
		var anchored := preload("res://source_cutscene_view.gd").anchored_camera(config.data.frames[index].camera,config.anchor.position,int(config.anchor.yaw),tables.rotation.pairs)
		var view := preload("res://source_cutscene_view.gd").camera_view(anchored,tables.rotation.pairs)
		var frame: Dictionary = config.data.frames[index]
		var actor_view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
		var actor_projection := preload("res://source_cutscene_frame.gd").projection(int(frame.camera.projectionDistance))
		actor_projection.ordering = true
		var actor_mesh := preload("res://source_cutscene_mesh.gd").build(frame,config.models.models,actor_view,config.atlas,tables.gameOver.sequenceLighting,actor_projection)
		assert(not actor_mesh.has("fault"))
		var room_projection := actor_projection.duplicate()
		room_projection.terrain = true
		room_projection.tie_base = int(actor_mesh.primitive_count)
		var fresh := preload("res://source_cutscene_mesh.gd").build(config.tiles,config.track_models.models,view,atlas,config.room_lighting,room_projection)
		assert(not fresh.has("fault") and int(file.vertices) == int(fresh.vertices) and cached.surface_get_arrays(0) == fresh.mesh.surface_get_arrays(0))
		if args.has("--ordered"):
			var actor_count := int(actor_mesh.primitive_count)
			var ordered := fresh
			assert(not ordered.has("fault") and ordered.vertices > 0 and ordered.vertices%3 == 0)
			var order: PackedVector2Array = ordered.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			for vertex in range(order.size()):
				assert(order[vertex].x >= 0 and order[vertex].x < 1024)
				assert(order[vertex].y > actor_count)
				if vertex > 0:
					assert(order[vertex].x <= order[vertex-1].x)
					if order[vertex].x == order[vertex-1].x: assert(order[vertex].y >= order[vertex-1].y)
		assert(FileAccess.get_sha256(content.path_join(file.sky_file)) == file.sky_sha256)
		var sky_cached: ArrayMesh = load(content.path_join(file.sky_file))
		var sky_frame := preload("res://source_cutscene_sky.gd").frame(anchored,config.sky_models.models.size())
		var sky_fresh := preload("res://source_cutscene_mesh.gd").build(sky_frame,config.sky_models.models,view,config.sky_atlas)
		assert(not sky_fresh.has("fault") and sky_cached.surface_get_arrays(0) == sky_fresh.mesh.surface_get_arrays(0))
	print("PASS: all291 SAD background caches match source-generated placement, directional lighting and surface arrays")
	quit(0)
