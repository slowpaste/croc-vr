extends SceneTree
func _initialize() -> void:
	var flow = preload("res://source_cutscene_flow.gd")
	var fade = preload("res://source_transition_fade.gd")
	for scene in range(24):
		assert(flow.entry_fade(scene) == (3 if scene in range(10,19) else 1))
	assert(flow.entry_fade(-1) == 0 and flow.entry_fade(24) == 0)
	var state: Dictionary = flow.initialize()
	var current: Dictionary = fade.start(flow.entry_fade(20))
	var presented := 0
	var started := -1
	for tag in range(290,-1,-1):
		current = fade.advance(current,0)
		state = flow.before_frame(state,tag,0,1)
		if int(state.start) != 0: started = tag; current = fade.start(int(state.start))
		presented += 1
		state = flow.after_frame(state,0,bool(current.ready),tag == 0)
		if state.advance_scene:
			assert(tag == 0 and current.ready); break
	assert(started == 13 and presented == 291)
	assert(flow.before_frame(flow.initialize(),13,0,2).start == 0)
	assert(flow.after_frame(flow.initialize(),0x800000,false,false).start == 0)
	var skipped: Dictionary = flow.after_frame(flow.initialize(),0x800000,true,false)
	assert(skipped.ending and skipped.start == 8 and not skipped.advance_scene)
	assert(flow.after_frame(skipped,0,true,false).advance_scene)
	assert(flow.after_frame(flow.initialize(),1,true,false).start == 0)
	assert(flow.after_frame(flow.initialize(),0x800000,true,true).advance_scene)
	print("PASS: native sequence tag13 exit, all291 SAD poses through terminator and readiness-gated skip")
	quit(0)
