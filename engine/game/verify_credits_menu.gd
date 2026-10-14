extends SceneTree
func _initialize() -> void:
	for available in [false,true]:
		var world := preload("res://imported_main.gd").new()
		world.source_main_mode = 1; world.source_menu_state.dialog_mode = 3
		world.source_main_menu_credits_available = available
		world.source_fade_overlay = preload("res://source_fade_overlay.gd").new()
		world.add_child(world.source_fade_overlay)
		assert(world.process_source_main_menu_confirmation(0x800000))
		assert(world.source_fade_phase == ("credits-menu-out" if available else "password-menu-out"))
		assert(int(world.source_fade_state.kind) == 5 and world.source_transition_fault.is_empty())
		world.free()
	print("PASS: title menu item3 uses original fade5 and routes to credits when unlocked, password otherwise")
	quit(0)
