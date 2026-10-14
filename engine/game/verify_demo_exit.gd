extends SceneTree
const Exit = preload("res://source_demo_exit.gd")
func _initialize() -> void:
	var state := Exit.decide(899,0,0,false,false)
	if state.action != "continue" or state.tick != 899:
		quit(1)
		return
	for trigger in [{"tick":900,"transition":0,"buttons":0},{"tick":20,"transition":1,"buttons":0},{"tick":20,"transition":0,"buttons":0x800000}]:
		state = Exit.decide(trigger.tick,trigger.transition,trigger.buttons,false,false)
		if state.action != "fade" or state.tick != 900 or state.profile != 8 or state.sound != (trigger.buttons != 0):
			quit(1)
			return
	state = Exit.decide(900,0,0x800000,true,false)
	if state.action != "wait" or state.sound:
		quit(1)
		return
	state = Exit.decide(900,0,0,true,true)
	if state.action != "return" or state.mode != 0:
		quit(1)
		return
	if Exit.decide(100,0,0x10000,false,false).action != "continue":
		push_error("Ignored live direction incorrectly aborted original demo")
		quit(1)
		return
	print("PASS: original demo exit timeout, transition/live-button triggers, sound gating and fade-ready title mode")
	quit(0)
