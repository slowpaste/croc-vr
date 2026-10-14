extends SceneTree
const Demo = preload("res://source_demo_input.gd")
func _initialize() -> void:
	var frames: Array = []
	frames.resize(900)
	frames.fill(0)
	frames[0] = 0x10000
	frames[1] = 0x10000
	frames[2] = 0x800000
	frames[899] = 0x800200
	var state := Demo.sample(frames,0,0)
	if state.held != 0x10000 or state.pressed != 0x10000 or state.released != 0 or state.pad_mode != 1:
		quit(1)
		return
	state = Demo.sample(frames,1,state.held)
	if state.pressed != 0 or state.released != 0:
		quit(1)
		return
	state = Demo.sample(frames,2,state.held)
	if state.pressed != 0x800000 or state.released != 0x10000:
		quit(1)
		return
	state = Demo.sample(frames,900,0x800200)
	if state.held != 0 or state.pressed != 0 or state.released != 0x800200 or not Demo.sample([],0,0).has("fault"):
		quit(1)
		return
	print("PASS: original demo held masks, press/release edges, digital pad and frame900 neutralization")
	quit(0)
