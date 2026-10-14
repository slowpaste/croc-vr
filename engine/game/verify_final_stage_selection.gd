extends SceneTree
class World extends "res://imported_main.gd":
	var can_start := true
	func enter_source_final_ending(_level: int) -> bool: return can_start
func _initialize() -> void:
	for entry in [[6,0,39],[5,0,38],[0,0x4000,40]]:
		var world := World.new()
		world.map_name = "MP047_00.MAP"
		world.source_menu_state.selected_index = 38
		world.source_menu_progress_flags = {35:entry[0],36:entry[0],37:entry[0],40:entry[1]}
		assert(world.apply_source_stage_return())
		assert(world.source_menu_state.selected_index == entry[2])
		world.free()
	var failed := World.new(); failed.map_name = "MP047_00.MAP"
	failed.source_menu_state.selected_index = 38; failed.source_menu_progress_flags = {35:6,36:6,37:6}
	failed.can_start = false
	assert(not failed.apply_source_stage_return() and failed.source_menu_state.selected_index == 38)
	failed.free()
	print("PASS: final story-stage return commits original selector index before ending and rolls back if playback cannot start")
	quit(0)
