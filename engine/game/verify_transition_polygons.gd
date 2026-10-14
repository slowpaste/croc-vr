extends SceneTree
const Polygons = preload("res://source_transition_polygons.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var table: Dictionary = {}
	for resource in world.manifest.resources:
		if resource.owner == "EXCLUDE.WAD" and resource.type == "unknown-table":
			table = world.read_json(resource.file)
	var quarter: Array = world.runtime_tables.trigonometry.quarterSine
	var result := Polygons.project(table.get("triangles",[]),0,4096,quarter)
	if table.get("count",0) != 10 or result.has("fault") or result.triangles[0] != [Vector2i(256,220),Vector2i(223,149),Vector2i(256,120)]:
		quit(1)
		return
	result = Polygons.project(table.triangles,1024,4096,quarter)
	if result.triangles[0] != [Vector2i(96,120),Vector2i(210,99),Vector2i(256,120)]:
		quit(1)
		return
	result = Polygons.project(table.triangles,0,32768,quarter)
	if result.triangles[0][0] != Vector2i(256,360) or result.triangles[2][0].x != 768 or result.triangles[4][0].x != -128:
		push_error("Source polygon screen bounds differ")
		quit(1)
		return
	if world.source_fade_overlay == null:
		world.source_fade_overlay = preload("res://source_fade_overlay.gd").new()
		world.camera.add_child(world.source_fade_overlay)
	world.source_fade_state = preload("res://source_transition_fade.gd").start(5)
	for tick in range(35):
		if not world.advance_source_transition():
			push_error(world.source_transition_fault)
			quit(1)
			return
	if not bool(world.source_fade_overlay.fade_material.get_shader_parameter("polygon_mode")) or int(world.source_fade_overlay.fade_material.get_shader_parameter("triangle_count")) != 10:
		quit(1)
		return
	world.source_fade_state = preload("res://source_transition_fade.gd").start(1)
	world.source_fade_phase = "in"
	world.advance_source_transition()
	if bool(world.source_fade_overlay.fade_material.get_shader_parameter("polygon_mode")):
		push_error("Standard fade retained the star mask")
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: ten original transition triangles, fixed-point rotation, negative rounding and viewport clamps")
	quit(0)
