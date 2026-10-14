extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var viewer := Camera3D.new(); root.add_child(viewer)
	for variant in [0,1]:
		var display := preload("res://source_credits_screen.gd").new(); root.add_child(display)
		if not display.setup(content,manifest,variant,viewer): push_error(display.presenter.fault); quit(1); return
		var anchored := display.global_transform
		if int(display.screen.material_override.get_shader_parameter("source_black_level")) != 255: push_error("Credits skipped original incoming black fade"); quit(1); return
		display.advance(1.0/30.0)
		var cursor := int(display.presenter.state.cursor)
		display.set_paused(true)
		if not display.advance(10.0).paused or int(display.presenter.state.cursor) != cursor: push_error("Credits pause advanced text"); quit(1); return
		display.set_paused(false)
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = display.viewport.get_texture().get_image()
		if image == null or image.is_empty(): push_error("Credits screen has no rendered output"); quit(1); return
		var colored := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel := image.get_pixel(x,y)
				if maxf(pixel.r,maxf(pixel.g,pixel.b)) > 0.05: colored += 1
		if colored < 100: push_error("Credits screen rendered no heading"); quit(1); return
		var complete := false
		var outgoing_ticks := 0; var incoming_clear := false
		for tick in range(10000):
			viewer.position.x += 0.0001
			var was_exiting: bool = display.exiting
			var result := display.advance(1.0/30.0)
			if was_exiting: outgoing_ticks += 1
			if not display.exiting and bool(display.fade.ready) and int(display.fade.level) == 0: incoming_clear = true
			if result.has("fault") or display.global_transform != anchored: push_error("Credits fault or viewer-following screen"); quit(1); return
			if bool(result.complete): complete = true; break
		if not complete: push_error("Credits variant did not finish"); quit(1); return
		if not incoming_clear or outgoing_ticks != 13 or int(display.fade.kind) != 8 or not bool(display.fade.ready) or int(display.screen.material_override.get_shader_parameter("source_black_level")) != 255: push_error("Credits incoming/outgoing fade sequence differs"); quit(1); return
		display.queue_free(); await process_frame
	viewer.queue_free(); await process_frame
	print("PASS: both credits screens render original headings, stay world anchored, pause and complete original30Hz page timing")
	quit(0)
