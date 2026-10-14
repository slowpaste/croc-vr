extends SceneTree
func _initialize() -> void:
	var flow = preload("res://source_death_transition.gd")
	for lives in [0,1,3,-1]:
		assert(flow.decide(1,lives,false,false).start == 8)
		assert(flow.decide(1,lives,true,false).action == "wait")
		var done: Dictionary = flow.decide(1,lives,true,true)
		assert(done.action == ("game_over" if lives == 0 else "respawn"))
		assert(done.start == (0 if lives == 0 else 1))
	assert(flow.decide(1,0,true,true).mode == 14)
	for state in [0,2,3,4]: assert(flow.decide(state,0,true,true).action == "wait")
	print("PASS: source death fade gates, exact zero-life game-over mode14 and nonzero respawn")
	quit(0)
