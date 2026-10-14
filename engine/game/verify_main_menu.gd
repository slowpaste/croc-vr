extends SceneTree
const Menu = preload("res://source_main_menu.gd")
func _initialize() -> void:
	var state := Menu.initialize(0,4)
	state = Menu.advance(state,0x10000,0x10000)
	if state.selected != 4 or state.cooldown != 9 or state.sizes[4] != 69632 or state.sizes[0] != 61440:
		quit(1)
		return
	for tick in range(9):
		state = Menu.advance(state,0x10000,0)
		if state.selected != 4:
			quit(1)
			return
	state = Menu.advance(state,0x10000,0)
	if state.selected != 3 or state.cooldown != 9:
		quit(1)
		return
	state = Menu.advance(state,0x40000,0x40000)
	if state.selected != 4:
		push_error("Fresh main-menu press did not bypass repeat delay")
		quit(1)
		return
	state = Menu.advance(state,0,0x40000)
	if state.selected != 0:
		quit(1)
		return
	state.locked = 1
	state = Menu.advance(state,0x40000,0x40000)
	if state.selected != 0 or state.cooldown != 8:
		quit(1)
		return
	state.locked = 0
	for tick in range(30):
		state = Menu.advance(state,0,0)
	if state.pulse != 0 or state.sizes != [65536,38912,38912,38912,38912]:
		push_error("Original menu highlight pulse did not settle")
		quit(1)
		return
	print("PASS: original main-menu wrap, held repeat, fresh press, lock and highlight growth/settling")
	quit(0)
