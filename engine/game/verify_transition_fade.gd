extends SceneTree
const Fade = preload("res://source_transition_fade.gd")
func _initialize() -> void:
	var state := Fade.start(8)
	for tick in range(12):
		state = Fade.advance(state,0)
		if state.ready or state.counter != (tick+1)*24:
			quit(1)
			return
	state = Fade.advance(state,0)
	if not state.ready or not state.active or state.level != 255 or state.counter != 288:
		quit(1)
		return
	state = Fade.start(1)
	var paused := Fade.advance(state,1)
	if paused.counter != 288 or paused.ready or paused.level != 255:
		quit(1)
		return
	for tick in range(9):
		state = Fade.advance(state,0)
		if state.ready or state.counter != 288-(tick+1)*32:
			quit(1)
			return
	state = Fade.advance(state,0)
	if not state.ready or state.active or state.level != 0:
		quit(1)
		return
	state = Fade.start(2)
	for tick in range(9):
		state = Fade.advance(state,0)
		if state.ready or state.counter != (tick+1)*32:
			quit(1)
			return
	state = Fade.advance(state,0)
	if not state.ready or not state.active or state.level != 255:
		quit(1)
		return
	for kind in [5,12]:
		state = Fade.start(kind)
		paused = Fade.advance(state,1)
		if paused.counter != 0 or paused.rotation != 113 or paused.ready:
			push_error("Polygon transition rotation incorrectly paused with progression")
			quit(1)
			return
		for tick in range(35):
			state = Fade.advance(state,0)
			if state.ready:
				quit(1)
				return
		if state.counter != 432432:
			quit(1)
			return
		state = Fade.advance(state,0)
		if not state.ready or not state.active or state.rotation != 4068 or state.render_scale != 27027:
			push_error("Source polygon transition readiness/render state differs")
			quit(1)
			return
	print("PASS: source fade profiles1/2/5/8/12, polygon growth, readiness and override behavior")
	quit(0)
