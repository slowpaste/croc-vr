extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.source_fade_state = {"ready":false}
	world.source_fade_phase = ""
	if not world.load_room("MP090_00.MAP") or world.source_fade_phase != "":
		push_error("Title entry invented an incoming fade without prior readiness")
		quit(1)
		return
	world.source_fade_state = {"ready":true}
	if not world.load_room("MP090_00.MAP") or world.source_fade_phase != "in" or world.source_fade_state.kind != 1 or not world.source_fade_overlay.visible:
		quit(1)
		return
	for tick in range(9):
		if not world.process_source_title_confirmation(0) or world.source_fade_phase != "in":
			quit(1)
			return
	if not world.process_source_title_confirmation(0) or world.source_fade_phase != "" or world.source_fade_overlay.visible:
		push_error("Original incoming fade did not finish on its tenth update")
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: source title entry prior-readiness gate and incoming fade timing/visibility")
	quit(0)
