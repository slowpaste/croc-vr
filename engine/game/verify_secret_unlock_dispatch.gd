extends SceneTree
class UnlockWorld extends "res://imported_main.gd":
	var scenes: Array = []
	var selector_entries := 0
	func enter_source_sequence(scene: int) -> bool:
		scenes.append(scene); return true
	func apply_source_island_selection() -> bool:
		selector_entries += 1; source_main_mode = 5; return true
func _initialize() -> void:
	for level in [48,17,47]:
		for next_level in [false,true]:
			var world := UnlockWorld.new()
			world.map_name = "MP%03d_00.MAP"%level
			world.source_menu_state.selected_index = 39
			world.source_stage_pickup_slots.fill(1)
			world.source_stage_crystal_bank = 42; world.source_pickup_counts[3] = 7
			world.source_pending_exit = {"source_level":level,"target_level":48}
			assert(world.apply_source_next_level_return() if next_level else world.apply_source_stage_return())
			assert(world.scenes == [7] and world.source_menu_state.selected_index == 39 and world.source_menu_progress_flags.get(40,0) == 0)
			assert(world.finish_source_secret_unlock(7))
			assert(world.source_menu_state.selected_index == 40 and world.source_menu_progress_flags[40] == 0x4000)
			if level == 17:
				assert(world.scenes == [7,10] and world.selector_entries == 0)
				assert(world.finish_source_story_return(10))
				assert(world.selector_entries == 1 and world.source_menu_state.selected_index == 40)
			elif level == 47: assert(world.scenes == [7,15] and world.source_ending_root == 15 and world.selector_entries == 0)
			else: assert(world.scenes == [7] and world.selector_entries == 1)
			assert(world.source_stage_crystal_bank == 42 and world.source_pickup_counts[3] == 7)
			world.free()
	print("PASS: both stage exits play JIG7 before unlock mutation, retain pending story/ending order and preserve secret selection/awards")
	quit(0)
