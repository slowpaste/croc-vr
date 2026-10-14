extends SceneTree
const Exit = preload("res://source_stage_stats_exit.gd")
const Fade = preload("res://source_transition_fade.gd")
func _initialize() -> void:
	if Exit.decide(4,17,0,false,true) != {"start":0,"return":false}: quit(1); return
	if Exit.decide(4,17,1,false,true) != {"start":2,"return":false}: quit(1); return
	if Exit.decide(4,0,0,false,true) != {"start":8,"return":false}: quit(1); return
	if Exit.decide(7,17,1,true,true).get("return"): quit(1); return
	for sequence in [0,17]:
		if Exit.decide(3,sequence,0,false,true) != {"start":0,"return":false} or Exit.decide(3,sequence,0,true,true).get("return"):
			push_error("Cross-level transition bypassed results confirmation")
			quit(1)
			return
		if Exit.decide(3,sequence,1,false,true).start != (8 if sequence == 0 else 2) or not Exit.decide(3,sequence,1,true,true).get("return"): quit(1); return
	if Exit.decide_for_level(4,13,0,false,true).start != 0 or Exit.decide_for_level(4,13,1,false,false).start != 2 or Exit.decide_for_level(4,10,0,false,false).start != 8:
		push_error("Source results exit used screen presence instead of retained story sequence")
		quit(1)
		return
	for pair in [[17,2,10],[0,8,13]]:
		var decision := Exit.decide(4,pair[0],1,false,false)
		var fade := Fade.start(int(decision.start))
		for tick in range(pair[2]):
			if Exit.decide(4,pair[0],1,true,bool(fade.ready)).get("return"):
				push_error("Results returned before source outgoing fade was ready")
				quit(1)
				return
			fade = Fade.advance(fade,0)
		if not Exit.decide(4,pair[0],1,true,bool(fade.ready)).get("return"): quit(1); return
	print("PASS: original state4 confirmation gate, white/black outgoing profiles and ready-boundary return")
	quit(0)
