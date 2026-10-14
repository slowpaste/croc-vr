extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	var world = World.new()
	var actor = Actor.new()
	world.add_child(actor)
	actor.world = world
	actor.vm.host = actor
	if world.source_level_script_state != 0 or actor.vm.evaluate([{"op":3,"index":45},{"op":18}]) != 0 or actor.vm.evaluate([{"op":3,"index":80},{"op":18}]) != 0:
		quit(1)
		return
	if actor.asl_command({"op":56,"args":[68,[{"op":4,"value":-131071},{"op":18}]]},actor.vm) != "continue" or world.source_level_script_state != -2 or actor.vm.evaluate([{"op":3,"index":68},{"op":18}]) != -131072:
		push_error("Source level-state setter/getter shift differs")
		quit(1)
		return
	world.source_menu_state.selection_changes = 4294967295
	if actor.vm.evaluate([{"op":3,"index":80},{"op":18}]) != -1 or actor.vm.evaluate([{"op":3,"index":80},{"op":18}]) != 0:
		push_error("Source menu selection-change read did not consume its word")
		quit(1)
		return
	world.source_menu_state.return_mode = 2
	world.source_menu_reveal_state = -2147483648
	if actor.vm.evaluate([{"op":3,"index":82},{"op":18}]) != -2147483648:
		push_error("Source reveal-state getter did not preserve raw signed word")
		quit(1)
		return
	world.source_menu_state.selected_index = 1
	world.source_menu_progress_flags[0] = 0x8000
	world.apply_source_menu_navigation(0xa0000,0)
	if world.source_menu_state.selected_index != 1 or world.source_menu_reveal_state != 0:
		push_error("Previous navigation did not reset reveal state before opposite navigation")
		quit(1)
		return
	world.source_menu_state.selection_changes = 5
	if actor.asl_command({"op":255,"args":[16,[{"op":3,"index":80},{"op":18}]]},actor.vm) != "continue" or world.source_menu_state.selection_changes != 0:
		push_error("Source LewisTest discarded expression evaluation side effects")
		quit(1)
		return
	world.source_menu_state.secret_return = 1
	world.source_menu_state.selected_index = 16
	if actor.vm.evaluate([{"op":3,"index":87},{"op":18}]) != 131072 or actor.vm.evaluate([{"op":3,"index":88},{"op":18}]) != 65536 or actor.vm.evaluate([{"op":3,"index":81},{"op":18}]) != 393216:
		push_error("Source menu return/selection getters differ")
		quit(1)
		return
	world.source_menu_state.selected_index = -1
	if actor.vm.evaluate([{"op":3,"index":81},{"op":18}]) != 327680:
		push_error("Source selected-stage remainder was not unsigned")
		quit(1)
		return
	if actor.asl_command({"op":183,"args":[]},actor.vm) != "continue" or world.source_camera_override_one != actor or actor.asl_command({"op":208,"args":[]},actor.vm) != "continue" or world.source_camera_override_one != null:
		push_error("Source camera override pointer set/clear differs")
		quit(1)
		return
	world.free()
	print("PASS: native menu consume read, level state shifts, unsigned stage remainder, returns and camera override pointer")
	quit(0)
