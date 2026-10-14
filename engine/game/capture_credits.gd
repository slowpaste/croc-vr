extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var fonts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.creditsFonts.file)))
	var atlas_descriptor: Dictionary = {}
	for entry in manifest.textures:
		if entry.name == manifest.creditsFonts.texture: atlas_descriptor = entry; break
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(atlas_descriptor.file)))
	var texture := ImageTexture.create_from_image(Image.load_from_file(content.path_join(atlas_descriptor.image)))
	var target := SubViewport.new(); target.size = Vector2i(512,240); target.own_world_3d = true; target.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(target)
	var camera := Camera3D.new(); target.add_child(camera)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color.BLACK; target.add_child(environment)
	var node := preload("res://source_menu_text_renderer.gd").new(); target.add_child(node)
	for entry in manifest.credits:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
		var state := preload("res://source_credits_state.gd").advance(preload("res://source_credits_state.gd").begin(data))
		var layout := preload("res://source_credits_text.gd").layout(state,fonts)
		if not node.set_text(layout,atlas,texture): push_error("Credits glyph layout failed"); quit(1); return
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var image := target.get_texture().get_image()
		if image.save_png("res://../build/credits-variant-%d.png"%int(entry.variant)) != OK: quit(1); return
		print("CREDITS_RENDER: variant=",entry.variant," labels=",layout.labels.size()," vertices=",node.mesh.surface_get_array_len(0))
	target.queue_free(); await process_frame
	quit(0)
