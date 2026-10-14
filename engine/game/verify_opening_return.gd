extends SceneTree
class OpeningWorld extends "res://imported_main.gd":
	var loaded := ""
	func source_title_destination(_index: int, _frame_seed: Variant = null) -> Dictionary: return {"map":"MP090_00.MAP"}
	func load_room(name: String, _incoming_id: int = -1, _source_origin: Dictionary = {}, _arrival_override: Dictionary = {}) -> bool:
		loaded = name; source_main_mode = 0; return true
func _initialize() -> void:
	var world := OpeningWorld.new()
	world.source_main_mode = 2
	world.source_random.bios_seed = 123
	world.source_input_suppression_count = 9
	world.source_transition_state = 1
	world.source_controller_enabled = true
	assert(world.finish_source_opening())
	assert(world.loaded == "MP090_00.MAP" and world.source_main_mode == 0)
	assert(not world.source_controller_enabled and world.source_transition_state == 0)
	assert(world.source_random.bios_seed == 123 and world.source_input_suppression_count == 9)
	assert(world.source_player_input_state == {"pad_mode":1})
	world.free()
	print("PASS: first-boot INTRO returns to title without the later-entry reset")
	quit(0)
