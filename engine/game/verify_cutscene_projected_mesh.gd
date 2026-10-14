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
	var atlas: Dictionary = {}
	for record in manifest.textures:
		if record.name == "INTRO.BIN": atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file)))
	var minimum := 1620
	var maximum := 0
	var removed := 0
	var blend_minimum := 2
	var blend_maximum := 0
	for index in range(data.frames.size()):
		var frame: Dictionary = data.frames[index]
		var view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
		var mesh := preload("res://source_cutscene_mesh.gd").build(frame,models.models,view,atlas,tables.gameOver.sequenceLighting,{"h":int(frame.camera.projectionDistance),"offset":Vector2i(256<<16,192<<16),"ordering":args.has("--ordered") or args.has("--passes"),"commands":args.has("--passes")})
		assert(not mesh.has("fault") and mesh.vertices > 0 and mesh.vertices <= 1620 and mesh.vertices%3 == 0 and mesh.mesh.get_surface_count() == 1)
		if index == 0: assert(mesh.vertices == 915 and mesh.culled_faces == 147)
		if args.has("--ordered"):
			var coordinates: PackedVector2Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			assert(coordinates.size() == int(mesh.vertices))
			for vertex in range(coordinates.size()):
				assert(coordinates[vertex].x >= 0 and coordinates[vertex].x < 1024)
				if vertex > 0: assert(coordinates[vertex].x <= coordinates[vertex-1].x)
		minimum = mini(minimum,int(mesh.vertices)); maximum = maxi(maximum,int(mesh.vertices)); removed += int(mesh.culled_faces)
		if args.has("--passes"):
			var plan := preload("res://source_cutscene_passes.gd").plan([],mesh.commands)
			assert(plan.commands == int(mesh.primitive_count))
			var flattened := 0
			for pass_data in plan.passes:
				if pass_data.kind == "blend":
					assert(pass_data.mode == 2)
					flattened += 1
				else: flattened += pass_data.commands.size()
			assert(flattened == int(mesh.primitive_count))
			blend_minimum = mini(blend_minimum,int(plan.blended)); blend_maximum = maxi(blend_maximum,int(plan.blended))
	print("PASS: all291 SAD poses project/cull with valid surface arrays; vertex range=",minimum,"..",maximum," removed faces=",removed)
	if args.has("--passes"): print("SAD_BLEND_PASSES: ",{"minimum":blend_minimum,"maximum":blend_maximum})
	quit(0)
