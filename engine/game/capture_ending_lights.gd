extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,16,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config.fault)); quit(1); return
	var part: Dictionary = config.parts[0]
	var captures: Array = []
	for enabled in [true,false]:
		var local: Dictionary = part.duplicate(false)
		local.room_lighting = part.room_lighting.duplicate(true)
		if not enabled: local.room_lighting.pointLights = []
		var plan := preload("res://source_cutscene_frame_plan.gd").build(local,local.room_atlas,0)
		if plan.has("fault"): push_error(str(plan.fault)); quit(1); return
		var graph := preload("res://source_cutscene_compositor.gd").new(); root.add_child(graph)
		var textures := {"actor":local.texture,"room":local.background_texture}
		if local.sky_texture != null: textures.sky = local.sky_texture
		if not graph.setup(plan,int(plan.h),textures,{"actor":local.actor_mask}): push_error("Ending compositor setup failed"); quit(1); return
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var output: Image = graph.output.get_texture().get_image()
		for y in range(output.get_height()):
			for x in range(output.get_width()): output.set_pixel(x,y,output.get_pixel(x,y).linear_to_srgb())
		output.convert(Image.FORMAT_RGBA8); captures.append(output.get_data())
		var file := "res://../build/CRYSD-point-lights.png" if enabled else "res://../build/CRYSD-no-point-lights.png"
		if output.save_png(file) != OK: quit(1); return
		graph.queue_free(); await process_frame
	var changed := 0; var maximum := 0
	for index in range(0,captures[0].size(),4):
		var difference := false
		for channel in range(3):
			var delta := absi(int(captures[0][index+channel])-int(captures[1][index+channel]))
			maximum = maxi(maximum,delta); difference = difference or delta > 0
		changed += 1 if difference else 0
	print("ENDING_POINT_LIGHT_RENDER: ",{"changed_pixels":changed,"maximum_byte_delta":maximum})
	quit(0 if changed > 0 else 1)
