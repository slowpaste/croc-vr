extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	for index in range(45):
		world.source_menu_state.selected_index = index
		var destination: Dictionary = world.source_selected_menu_destination()
		if destination.has("fault") or destination.room != 0 or destination.level != int(world.runtime_tables.menuLevels.values[index]):
			push_error("Original selected-index destination failed: "+str(index))
			quit(1)
			return
		var selector: Dictionary = world.source_selected_selector_destination()
		if selector.has("fault") or selector.map != "MP100_%02d.MAP" % int(int(destination.level)/10):
			push_error("Original island scene lookup failed: "+str(index))
			quit(1)
			return
	world.source_menu_state.selected_index = 4
	if world.source_selected_menu_destination().map != "MP018_00.MAP":
		quit(1)
		return
	world.source_menu_state.selected_index = 5
	if world.source_selected_menu_destination().map != "MP014_00.MAP":
		quit(1)
		return
	for index in [-1,45,46]:
		world.source_menu_state.selected_index = index
		if not world.source_selected_menu_destination().has("fault"):
			push_error("Invalid/sentinel menu destination was accepted")
			quit(1)
			return
	world.runtime_tables.menuLevels.values = []
	world.source_menu_state.selected_index = 0
	if not world.source_selected_menu_destination().has("fault"):
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: all45 original menu destinations, reordered levels, sentinel and missing/invalid table checks")
	quit(0)
