extends SceneTree
class Credits extends Node3D:
	var paused := false
	func set_paused(value: bool) -> void: paused = value
	func advance(_delta: float) -> Dictionary: return {"complete":true}
class World extends "res://imported_main.gd":
	var returned := false
	func apply_source_demo_title_return() -> bool:
		returned = true; source_main_mode = 0; source_main_menu_credits_available = false; return true
	func apply_source_island_selection() -> bool:
		returned = true; source_main_mode = 5; return true
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	for entry in [[false,0],[true,0],[true,5]]:
		var available: bool = entry[0]
		var destination: int = entry[1]
		var world := World.new()
		world.source_main_mode = 7
		world.source_main_menu_credits_available = available
		world.source_credits_return_mode = destination
		var credits := Credits.new()
		root.add_child(credits)
		world.source_credits_screen = credits
		assert(world.process_source_credits(1.0/30.0))
		assert(world.returned and world.source_main_mode == destination and world.source_credits_screen == null)
		assert(world.source_main_menu_credits_available == (available if destination == 5 else false))
		assert(world.source_fade_phase == "in" and int(world.source_fade_state.kind) == 7)
		world.free(); await process_frame
	print("PASS: credits completion returns to original selector/title target; title entry clears credits availability")
	quit(0)
