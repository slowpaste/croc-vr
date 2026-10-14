extends SceneTree
class StoryWorld extends "res://imported_main.gd":
	var scenes: Array = []
	var selector_entries := 0
	func enter_source_sequence(scene: int) -> bool:
		scenes.append(scene); return true
	func apply_source_island_selection() -> bool:
		selector_entries += 1; source_transition_state = 0; return true
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	for level in [13,17,23,27,33,37,43]:
		for next_level in [false,true]:
			var world := StoryWorld.new()
			world.runtime_tables = tables
			world.manifest = manifest
			world.map_name = "MP%03d_00.MAP"%level
			var selected: int = tables.menuLevels.values.find(float(level))
			assert(selected >= 0)
			world.source_menu_state.selected_index = selected+1 if next_level else selected
			for previous in range(selected-3,selected): world.source_menu_progress_flags[previous] = 0x8006
			world.source_pending_exit = {"source_level":level,"target_level":int(tables.menuLevels.values[selected+1])}
			world.source_stage_crystal_bank = 42; world.source_pickup_counts[3] = 7
			assert(world.apply_source_next_level_return() if next_level else world.apply_source_stage_return())
			var sequence := preload("res://source_stage_end.gd").sequence_id(level)
			assert(world.scenes == [sequence] and world.selector_entries == 0)
			assert(int(world.source_story_return.sequence) == sequence)
			assert(world.finish_source_story_return(sequence))
			assert(world.selector_entries == 1 and world.source_menu_state.selected_index == selected+1)
			assert(world.source_story_return.is_empty() and world.source_pending_exit.is_empty())
			assert(world.source_fade_phase == "in" and int(world.source_fade_state.kind) == 1)
			assert(world.source_stage_crystal_bank == 42 and world.source_pickup_counts[3] == 7)
			world.free()
	print("PASS: all seven story levels defer both selector-return paths until mapped cinematic completion and retain progression/awards")
	quit(0)
