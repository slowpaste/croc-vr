extends SceneTree
func _initialize() -> void:
	var flow = preload("res://source_password_return.gd")
	for mode in range(16):
		for flag in [0,1,2,3]:
			var active: Dictionary = flow.decide(mode,flag,true,true)
			if mode not in [12,13] or flag == 0:
				assert(active == {"start":0,"return":false}); continue
			assert(active.get("return") and active.start == 7)
			assert(active.target_mode == (5 if mode == 12 or flag == 2 else 0))
			assert(active.update_unlocks == (mode == 13 and flag == 2))
			assert(flow.decide(mode,flag,false,false).start == 8)
			assert(not flow.decide(mode,flag,true,false).get("return"))
	print("PASS: native password modes12/13 request gates, outgoing8/incoming7, selector/title and unlock update")
	quit(0)
