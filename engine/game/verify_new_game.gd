extends SceneTree
const World = preload("res://imported_main.gd")
func _initialize() -> void:
	var world = World.new()
	world.source_menu_state.selected_index = 38
	world.source_menu_state.input_lock = 7
	world.source_pickup_counts = {1:75,2:6,3:99}
	world.source_stage_crystal_bank = 98
	world.source_stage_pickup_slots = [1,1,1,1,1,1,1,1]
	world.source_menu_announcement_history = [1,1,1,1,1,1,1,1]
	world.source_map_entity_flags = {"MP010_00.MAP":{7:4},"MP011_00.MAP":{3:1}}
	for index in range(80):
		world.source_menu_progress_flags[index] = 65535
	var destination: Dictionary = world.reset_source_new_game()
	if not world.source_map_entity_flags.is_empty():
		push_error("New Game retained previous campaign's removed/collected map actors"); world.free(); quit(1); return
	if destination != {"level":10,"room":0} or world.source_menu_state.selected_index != 0 or world.source_stage_crystal_bank != 0 or world.source_pickup_counts != {1:75,2:6,3:3} or world.source_menu_state.input_lock != 7:
		push_error("Original new-game reset boundaries differ")
		quit(1)
		return
	if world.source_stage_pickup_slots != [0,0,0,0,0,0,0,0] or world.source_menu_announcement_history != [0,0,0,0,0,0,0,0] or world.source_menu_progress_flags.size() != 80:
		quit(1)
		return
	for index in range(80):
		if world.source_menu_progress_flags[index] != 0:
			quit(1)
			return
	var entry: Dictionary = preload("res://source_menu_progress.gd").enter_selector(0,world.source_menu_progress_flags,world.source_menu_announcement_history)
	if entry.selected_index != 0 or entry.return_mode != 0 or entry.secret_return != 0:
		push_error("Previous game's secret announcements survived new-game reset")
		quit(1)
		return
	world.free()
	print("PASS: source new-game lives, bank, all80 progress words, eight pickup/announcement slots and reset boundaries")
	quit(0)
