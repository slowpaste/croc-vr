extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
	root.size=Vector2i(640,480)
	if OS.get_cmdline_user_args().has("--clear-probe"):RenderingServer.set_default_clear_color(Color.MAGENTA)
	var camera:=Camera3D.new();root.add_child(camera)
	var args:=OS.get_cmdline_user_args();var content:String=args[args.find("--content")+1]
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var display=preload("res://source_sequence_screen.gd").new();root.add_child(display)
	assert(display.setup(content,manifest,tables,0,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667},camera))
	display.session.audio.stream.stop_stream();assert(display.session.present_frame(0,299))
	display.session.player.fade.level=0;display.apply_fade()
	for index in range(3):
		camera.position=[Vector3.ZERO,Vector3(0.3,0,-0.5),Vector3(0.3,0.3,-0.5)][index]
		for frame in range(4):await process_frame
		await RenderingServer.frame_post_draw
		if OS.get_cmdline_user_args().has("--clear-probe"):
			var screenshot:Image=root.get_texture().get_image()
			var a:Vector2=camera.unproject_position(display.to_global(Vector3(-1.55,0.75,0)))
			var b:Vector2=camera.unproject_position(display.to_global(Vector3(1.55,-0.75,0)))
			for y in range(ceili(a.y)+3,floori(b.y)-3):
				for x in range(ceili(a.x)+3,floori(b.x)-3):assert(screenshot.get_pixel(x,y)!=Color.MAGENTA,"Ocean cap left uncovered portal pixels")
		root.get_texture().get_image().save_png(content.get_base_dir().path_join("build/portal-coverage-%d.png"%index))
	display.queue_free();await process_frame;quit(0)
