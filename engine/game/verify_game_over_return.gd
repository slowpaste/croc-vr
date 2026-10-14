extends SceneTree
func _initialize() -> void:
	var flow = preload("res://source_game_over_return.gd")
	var fade = preload("res://source_transition_fade.gd")
	var outgoing: Dictionary = fade.start(14)
	for tick in range(12): outgoing = fade.advance(outgoing,0)
	assert(outgoing.counter == 288 and not outgoing.ready)
	outgoing = fade.advance(outgoing,0)
	assert(outgoing.ready and outgoing.active and outgoing.level == 255)
	var incoming: Dictionary = fade.start(15)
	assert(fade.advance(incoming,1).counter == 256)
	for tick in range(8): incoming = fade.advance(incoming,0)
	assert(incoming.counter == 0 and incoming.active and not incoming.ready)
	incoming = fade.advance(incoming,0)
	assert(incoming.ready and not incoming.active and incoming.level == 0)
	for mode in range(16):
		if mode != 9: assert(flow.decide(mode,true,0,true,true) == {"start":0,"return":false})
	for target in [0,1,4,8]:
		assert(flow.decide(9,false,target,false,false).start == 0)
		assert(flow.decide(9,true,target,false,false).start == (14 if target == 0 else 8))
		assert(not flow.decide(9,true,target,true,false).get("return"))
		# Source active-fade completion does not re-test the request flag.
		for requested in [true,false]:
			var done: Dictionary = flow.decide(9,requested,target,true,true)
			assert(done.get("return") and done.start == 15 and done.target_mode == target)
			assert(done.outer_action == (2 if target == 0 else 0))
	print("PASS: original mode9 Load Game return request, fade readiness, target and outer-action gates")
	quit(0)
