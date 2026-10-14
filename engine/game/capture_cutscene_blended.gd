extends SceneTree
func _initialize() -> void: call_deferred("capture")
func texture(content: String, record: Dictionary, key: String = "image") -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(content.path_join(record[key])))
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config)); quit(1); return
	var frame: Dictionary = config.data.frames[20]
	var records := {}
	for record in manifest.textures: records[str(record.name)] = record
	var room_atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(records["TK05_TRK.BIN"].file)))
	var anchored := preload("res://source_cutscene_view.gd").anchored_camera(frame.camera,config.anchor.position,int(config.anchor.yaw),tables.rotation.pairs)
	var room_view := preload("res://source_cutscene_view.gd").camera_view(anchored,tables.rotation.pairs)
	var actor_view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
	var projection := preload("res://source_cutscene_frame.gd").projection(int(frame.camera.projectionDistance))
	projection.ordering = true; projection.commands = true; projection.gpu_color = true
	var actors := preload("res://source_cutscene_mesh.gd").build(frame,config.models.models,actor_view,config.atlas,tables.gameOver.sequenceLighting,projection)
	var room_projection := projection.duplicate(); room_projection.terrain = true
	var room := preload("res://source_cutscene_mesh.gd").build(config.tiles,config.track_models.models,room_view,room_atlas,config.room_lighting,room_projection)
	if actors.has("fault") or room.has("fault"): push_error("Invalid frame geometry"); quit(1); return
	if args.has("--opaque-shadows"):
		for command in actors.commands: command.flags = int(command.flags)&~0x20
	var sky_frame := preload("res://source_cutscene_sky.gd").frame(anchored,config.sky_models.models.size())
	var sky := preload("res://source_cutscene_mesh.gd").build(sky_frame,config.sky_models.models,room_view,config.sky_atlas,{}, {"ordering":true,"commands":true,"gpu_color":true})
	if sky.has("fault"): push_error(str(sky)); quit(1); return
	var world_commands: Array = []
	for command in sky.commands:
		command.source = "sky"; command.bucket = 1022
		world_commands.append(command)
	for command in room.commands:
		command.serial = int(command.serial)+sky.commands.size()
		world_commands.append(command)
	var plan := preload("res://source_cutscene_passes.gd").plan(world_commands,actors.commands)
	var graph := preload("res://source_cutscene_compositor.gd").new()
	root.add_child(graph)
	assert(graph.setup(plan,int(frame.camera.projectionDistance),{"room":texture(content,records["TK05_TRK.BIN"]),"actor":texture(content,records["INTRO.BIN"]),"sky":texture(content,records["TB26.BIN"])},{"actor":texture(content,records["INTRO.BIN"],"maskImage")}))
	for index in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var output := graph.output.get_texture().get_image()
	for y in range(output.get_height()):
		for x in range(output.get_width()): output.set_pixel(x,y,output.get_pixel(x,y).linear_to_srgb())
	var error := output.save_png("res://../build/cutscene-SAD-opaque-shadows.png" if args.has("--opaque-shadows") else "res://../build/cutscene-SAD-blended.png")
	print("SAD_COMPOSITOR: ",{"passes":plan.passes.size(),"blend_primitives":plan.blended,"viewports":graph.stages.size()})
	graph.queue_free(); await process_frame
	quit(error)
