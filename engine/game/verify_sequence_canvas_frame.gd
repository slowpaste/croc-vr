extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1]); option = args.find("--scene")
	var scene := int(args[option+1]) if option >= 0 else 15
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config.fault)); quit(1); return
	var part: Dictionary = config.parts[0]
	var plan := preload("res://source_cutscene_frame_plan.gd").build(part,part.room_atlas,0)
	if plan.has("fault"): push_error(str(plan.fault)); quit(1); return
	var textures := {"actor":part.texture,"room":part.background_texture}
	var masks := {"actor":part.actor_mask,"room":part.room_mask}
	if part.sky_texture != null: textures.sky = part.sky_texture; masks.sky = part.sky_mask
	var reference := preload("res://source_cutscene_compositor.gd").new(); root.add_child(reference)
	if not reference.setup(plan,int(plan.h),textures,masks): push_error("Reference compositor failed"); quit(1); return
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var expected: Image = reference.output.get_texture().get_image()
	reference.queue_free(); await process_frame; await process_frame
	var candidate := preload("res://source_sequence_canvas_compositor.gd").new(); root.add_child(candidate)
	if not candidate.setup(plan,int(plan.h),textures,masks): push_error(candidate.fault); quit(1); return
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var actual := candidate.output.get_texture().get_image()
	var different := 0; var max_error := 0
	for y in range(240):
		for x in range(512):
			var a := expected.get_pixel(x,y).linear_to_srgb(); var b := actual.get_pixel(x,y).linear_to_srgb()
			var error := maxi(absi(a.r8-b.r8),maxi(absi(a.g8-b.g8),absi(a.b8-b.b8)))
			if error != 0: different += 1
			max_error = maxi(max_error,error)
	expected.save_png("res://../build/canvas-frame-reference-%d.png"%scene)
	actual.save_png("res://../build/canvas-frame-candidate-%d.png"%scene)
	candidate.queue_free(); await process_frame
	print("CANVAS_FRAME_REFERENCE: ",JSON.stringify({"scene":scene,"different_pixels":different,"max_byte_error":max_error,"passes":plan.passes.size()}))
	quit(0 if different == 0 else 1)
