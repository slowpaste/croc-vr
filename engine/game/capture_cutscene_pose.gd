extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--hdr"): root.use_hdr_2d = true
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var asset: Dictionary = manifest.cutscenePoses[0]
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
	var models: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.model)))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var texture_record: Dictionary = {}
	for candidate in manifest.textures:
		if candidate.name == "INTRO.BIN": texture_record = candidate
	if texture_record.is_empty(): quit(1); return
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(texture_record.file)))
	var frame: Dictionary = poses.frames[0]
	var view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
	var projection := {"h":int(frame.camera.projectionDistance),"offset":Vector2i(256<<16,192<<16)} if args.has("--source-culling") else {}
	if args.has("--source-ordering"): projection = {"h":int(frame.camera.projectionDistance),"offset":Vector2i(256<<16,192<<16),"ordering":true}
	if args.has("--gpu-color"): projection.gpu_color = true
	var result := preload("res://source_cutscene_mesh.gd").build(frame,models.models,view,atlas,tables.gameOver.sequenceLighting,projection)
	if result.has("fault"): push_error(str(result)); quit(1); return
	print("CUTSCENE_GEOMETRY: ",{"vertices":result.vertices,"culled_faces":result.culled_faces})
	root.size = Vector2i(512,240)
	var camera := Camera3D.new()
	camera.near = 0.01
	camera.fov = rad_to_deg(2.0*atan(120.0/float(frame.camera.projectionDistance)))
	root.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	root.add_child(environment)
	var node := MeshInstance3D.new()
	node.mesh = result.mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://source_cutscene_material.gdshader")
	if args.has("--gpu-color"): material.shader = preload("res://source_cutscene_gpu_material.gdshader")
	if args.has("--source-ordering"): material.set_shader_parameter("source_ordered_depth",true)
	if args.has("--source-origin"): material.set_shader_parameter("source_vertical_offset",0.6)
	material.set_shader_parameter("atlas_texture",ImageTexture.create_from_image(Image.load_from_file(content.path_join(texture_record.image))))
	node.material_override = material
	root.add_child(node)
	if args.has("--background"):
		var config := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[128,128,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
		if config.has("fault"): push_error(str(config)); quit(1); return
		var record: Dictionary = {}
		for candidate in manifest.textures:
			if candidate.name == "TK05_TRK.BIN": record = candidate
		if record.is_empty(): quit(1); return
		var background_atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(record.file)))
		var anchored := preload("res://source_cutscene_view.gd").anchored_camera(frame.camera,config.anchor.position,int(config.anchor.yaw),tables.rotation.pairs)
		var background_view := preload("res://source_cutscene_view.gd").camera_view(anchored,tables.rotation.pairs)
		# Directional terrain lighting; point lights/depth ordering still pending.
		var room_projection := {"h":int(frame.camera.projectionDistance),"offset":Vector2i(256<<16,192<<16),"ordering":true,"terrain":true,"tie_base":int(result.primitive_count)} if args.has("--source-ordering") else {}
		var background := preload("res://source_cutscene_mesh.gd").build(config.tiles,config.track_models.models,background_view,background_atlas,config.room_lighting,room_projection)
		if background.has("fault"): push_error(str(background)); quit(1); return
		var surface := MeshInstance3D.new()
		surface.mesh = background.mesh
		var background_material := ShaderMaterial.new()
		background_material.shader = preload("res://source_cutscene_material.gdshader")
		if args.has("--source-ordering"): background_material.set_shader_parameter("source_ordered_depth",true)
		if args.has("--source-origin"): background_material.set_shader_parameter("source_vertical_offset",0.6)
		background_material.set_shader_parameter("atlas_texture",ImageTexture.create_from_image(Image.load_from_file(content.path_join(record.image))))
		surface.material_override = background_material
		root.add_child(surface)
		if args.has("--sky"):
			var sky_models: Dictionary = {}
			var sky_atlas: Dictionary = {}
			var sky_record: Dictionary = {}
			for entry in manifest.models:
				if entry.name == "TB01_DOM.MOD": sky_models = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
			for entry in manifest.textures:
				if entry.name == "TB26.BIN":
					sky_record = entry
					sky_atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
			if sky_models.is_empty() or sky_atlas.is_empty(): quit(1); return
			var sky_frame := preload("res://source_cutscene_sky.gd").frame(anchored,sky_models.models.size())
			var sky_result := preload("res://source_cutscene_mesh.gd").build(sky_frame,sky_models.models,background_view,sky_atlas)
			if sky_result.has("fault"): push_error(str(sky_result)); quit(1); return
			var dome := MeshInstance3D.new()
			dome.mesh = sky_result.mesh
			var dome_material := ShaderMaterial.new()
			dome_material.shader = preload("res://source_cutscene_material.gdshader")
			dome_material.set_shader_parameter("source_fixed_far",true)
			if args.has("--source-origin"): dome_material.set_shader_parameter("source_vertical_offset",0.6)
			dome_material.set_shader_parameter("atlas_texture",ImageTexture.create_from_image(Image.load_from_file(content.path_join(sky_record.image))))
			dome.material_override = dome_material
			root.add_child(dome)
	for index in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var output := root.get_texture().get_image()
	if root.use_hdr_2d:
		# HDR viewport readback is linear; PNG comparison uses display sRGB bytes.
		for y in range(output.get_height()):
			for x in range(output.get_width()): output.set_pixel(x,y,output.get_pixel(x,y).linear_to_srgb())
	var error := output.save_png("res://../build/cutscene-SAD-gpu-color.png" if args.has("--gpu-color") else "res://../build/cutscene-SAD-ordered.png" if args.has("--source-ordering") else "res://../build/cutscene-SAD-source-origin.png" if args.has("--source-origin") else "res://../build/cutscene-SAD-culled.png" if args.has("--source-culling") else "res://../build/cutscene-SAD-background.png" if args.has("--background") else "res://../build/cutscene-SAD-first.png")
	node.queue_free(); camera.queue_free(); environment.queue_free()
	await process_frame
	quit(error)
