extends SceneTree
func _initialize() -> void:
	call_deferred("render_probe")
func render_probe() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size():
		quit(1)
		return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content+"/manifest.json"))
	var table: Dictionary = {}
	for resource in manifest.resources:
		if resource.owner == "EXCLUDE.WAD" and resource.type == "unknown-table":
			table = JSON.parse_string(FileAccess.get_file_as_string(content+"/"+resource.file))
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content+"/resources/runtime-tables.json"))
	var projected: Dictionary = preload("res://source_transition_polygons.gd").project(table.triangles,0,4096,runtime.trigonometry.quarterSine)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.3,0.55,0.8)
	scene.add_child(environment)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var overlay = preload("res://source_fade_overlay.gd").new()
	camera.add_child(overlay)
	if not overlay.set_source_polygons(projected.triangles):
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://../build/transition-star.png")
	if screenshot.save_png(output) != OK or screenshot.get_pixel(screenshot.get_width()/2,screenshot.get_height()/2).r > 0.05 or screenshot.get_pixel(5,5).r < 0.1:
		push_error("Original transition star shader did not preserve background outside its black polygon mask")
		quit(1)
		return
	if screenshot.get_width() == 512 and screenshot.get_height() == 240 and (screenshot.get_pixel(256,210).r > 0.05 or screenshot.get_pixel(256,30).r < 0.1):
		push_error("Source transition viewport Y coordinates were flipped")
		quit(1)
		return
	print("PASS: original transition star rendered; screenshot "+output)
	quit(0)
