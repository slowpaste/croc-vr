extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	if RenderingServer.get_video_adapter_name().is_empty():
		push_error("Fade pixel checks require a real renderer")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64,64)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(1.0,0.8,0.3)
	viewport.world_3d.environment = environment
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var overlay = preload("res://source_fade_overlay.gd").new()
	camera.add_child(overlay)
	var pixels: Array[Color] = []
	for level in [0,128,255]:
		overlay.set_source_level(level)
		for frame in range(3):
			await process_frame
		RenderingServer.force_draw()
		pixels.append(viewport.get_texture().get_image().get_pixel(32,32))
	print("SOURCE_FADE_PIXELS: ",pixels)
	if pixels[0].b < 0.1 or pixels[1].b > 0.03 or pixels[1].r < 0.1 or pixels[2].r > 0.03 or pixels[2].g > 0.03 or pixels[2].b > 0.03:
		push_error("Subtractive fade pixel output failed")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("PASS: GPU subtractive fade threshold and full-black output")
	quit(0)
