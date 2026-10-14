extends SceneTree
func _initialize() -> void:
	var flow = preload("res://source_game_over_display_return.gd")
	var fade = preload("res://source_transition_fade.gd")
	var incoming: Dictionary = fade.start(7)
	assert(incoming.counter == 256 and incoming.level == 255)
	assert(fade.advance(incoming,1).counter == 256)
	for tick in range(8): incoming = fade.advance(incoming,0)
	assert(incoming.counter == 0 and not incoming.ready and incoming.active)
	incoming = fade.advance(incoming,0)
	assert(incoming.level == 0 and incoming.ready and not incoming.active)
	for bit in range(32):
		assert(flow.decide(14,1 << bit,0,false,false).start == (8 if bit in [9,20,21,22,23] else 0))
	assert(flow.decide(9,0xf00200,0,true,true) == {"start":0,"return":false})
	for dialog in [0,1,2,-1]:
		assert(not flow.decide(14,0,dialog,true,false).get("return"))
		var done: Dictionary = flow.decide(14,0,dialog,true,true)
		assert(done.get("return") and done.start == 7)
		assert(done.target_mode == (5 if dialog == 0 else 6 if dialog == 1 else 14))
		assert(done.outer_reload == (dialog == 0))
		assert(done.lives == 3 and done.current_room == 0 and done.crystal_bank == 0)
	print("PASS: source mode14 held-input fade gates, selector/dialog branches and game-over count reset")
	quit(0)
