extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(30): await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	var effect = world.vr_settings.foveation
	effect.apply(3,false)
	await RenderingServer.frame_post_draw
	var normal := root.get_texture().get_image()
	effect.apply(3,true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var debug := root.get_texture().get_image()
	var middle := Vector2i(debug.get_width()/2,debug.get_height()/2)
	assert(debug.get_pixelv(middle).g>normal.get_pixelv(middle).g+0.02,"Debug full-detail centre did not tint green")
	assert(absf(debug.get_pixel(5,5).g-normal.get_pixel(5,5).g)<0.02,"Debug tinted reduced-detail outer region")
	assert(debug.save_png("res://../build/foveation-debug-preview.png")==OK)
	effect.apply(0,false)
	assert(root.vrs_mode==Viewport.VRS_DISABLED and not effect.overlay.visible)
	world.queue_free()
	await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: full-detail debug shader changes centre, preserves periphery, and disables cleanly")
	quit(0)
