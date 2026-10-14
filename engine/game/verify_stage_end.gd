extends SceneTree
const Ending = preload("res://source_stage_end.gd")
const World = preload("res://imported_main.gd")
func _initialize() -> void:
	if Ending.next_level_selection(0,{}) != 1 or Ending.next_level_selection(3,{0:6,1:6,2:6}) != 4 or Ending.next_level_selection(3,{0:6,1:6,2:5}) != 5 or Ending.next_level_selection(39,{}) != 39 or Ending.next_level_selection(39,{40:0x4000}) != 40:
		push_error("Original NextLevel skip/increment/index39 gate differs")
		quit(1)
		return
	var flags := {0:0x8006,1:0x8006,2:0x8006}
	if Ending.next_selection(3,flags,17) != 4 or Ending.next_selection(3,flags,0) != 4:
		quit(1)
		return
	flags[2] = 5
	if Ending.next_selection(3,flags,17) != 10 or Ending.next_selection(3,flags,0) != 10:
		quit(1)
		return
	# This threshold differs from secret unlocking's exact18 requirement.
	flags[2] = 7
	if Ending.next_selection(3,flags,0) != 4:
		quit(1)
		return
	for index in range(3):
		if Ending.next_selection(index,flags,0) != 10:
			push_error("Unsigned stage-end prefix bounds differ")
			quit(1)
			return
	if Ending.next_selection(38,{},15) != 38 or Ending.next_selection(38,{40:0x4000},15) != 40 or Ending.next_selection(38,{40:0x8000},15) != 38 or Ending.next_selection(38,{},0) != 40:
		quit(1)
		return
	if Ending.next_selection(38,{35:6,36:6,37:6},15) != 39:
		quit(1)
		return
	var world = World.new()
	world.source_menu_state.selected_index = 38
	world.source_menu_progress_flags = {40:0x4000}
	if world.source_stage_end_selection(47) != 40 or world.source_menu_state.selected_index != 38:
		quit(1)
		return
	world.free()
	var expected := {13:17,17:10,23:18,27:11,33:14,37:12,43:13,47:15,54:16}
	for level in range(55):
		if Ending.sequence_id(level) != int(expected.get(level,0)):
			quit(1)
			return
	print("PASS: source stage-end selection, unsigned prefix, rescue threshold, index38 gate and sequence table")
	quit(0)
