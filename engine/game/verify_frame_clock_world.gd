extends SceneTree
const Selection = preload("res://source_title_selection.gd")
const Demo = preload("res://source_attract_demo.gd")
const Random = preload("res://source_random.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.source_frame_clock.counter = 777
	world.source_tick_count = 12
	if not world.load_room("MP090_00.MAP") or world.source_tick_count != 0 or world.source_frame_clock.counter != 777:
		push_error("Room load reset the source global display clock")
		quit(1)
		return
	var expected := Selection.select_scene(0,0,777,Random.new())
	var actual: Dictionary = world.source_title_destination(0)
	if actual.get("index",-1) != expected.index:
		push_error("Title selection used room ticks instead of source display clock")
		quit(1)
		return
	expected = Demo.select_destination(777,world.runtime_tables.attractDemos.destinations,Random.new())
	actual = world.source_attract_demo_destination()
	if actual.get("index",-1) != expected.index or world.source_frame_clock.counter != 777:
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: source display clock persists across room load and supplies default title/demo random seeds")
	quit(0)
