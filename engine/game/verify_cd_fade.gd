extends SceneTree
const Fade = preload("res://source_cd_fade.gd")
func _initialize() -> void:
	for adjustment in [[100,10,110],[120,20,127],[5,-10,0],[10,65536,10],[10,65535,9],[65535,2,1]]:
		var adjusted := Fade.adjust(adjustment[0],adjustment[1],0)
		if adjusted.volume != adjustment[2] or adjusted.counter != adjustment[2] or adjusted.mix != [adjustment[2],adjustment[2],adjustment[2],adjustment[2]]:
			push_error("Original music option adjustment differs")
			quit(1)
			return
	for pair in [[100,12],[7,0],[-7,0],[-9,-1],[65535,0],[32768,-4096]]:
		var restored := Fade.restore(pair[0],1)
		var signed_level := int(pair[0])&65535
		if signed_level >= 32768: signed_level -= 65536
		if restored.counter != signed_level or restored.decrement != pair[1] or restored.mix != [signed_level&255,signed_level&255,0,0]:
			push_error("Source mix restoration lost signed-halfword/division/routing behavior")
			quit(1)
			return
	if Fade.advance(0,0) != {"counter":0,"changed":false}:
		quit(1)
		return
	var state := Fade.advance(3,0)
	if state.counter != 2 or state.level != 2 or state.mix != [2,2,2,2]:
		quit(1)
		return
	state = Fade.advance(3,1)
	if state.mix != [2,2,0,0]:
		quit(1)
		return
	state = Fade.advance(1,0)
	if state.counter != 0 or state.level != 0 or state.mix != [0,0,0,0] or not state.changed:
		quit(1)
		return
	state = Fade.advance_callback(100,7,1,1)
	if state.counter != 93 or state.active != 3 or state.mix != [93,93,0,0]:
		push_error("Music callback fade did not use its decrement/state transition")
		quit(1)
		return
	state = Fade.advance_callback(5,7,0,1)
	if state.counter != 0 or state.active != 1 or state.mix != [0,0,0,0]:
		push_error("Final callback fade overwrote the original active word")
		quit(1)
		return
	state = Fade.advance_callback(0,7,0,3)
	if state != {"counter":0,"active":3,"changed":false}:
		quit(1)
		return
	state = Fade.advance_callback(300,1,0,1)
	if state.counter != 299 or state.mix != [43,43,43,43]:
		push_error("Callback mix lost original low-byte truncation")
		quit(1)
		return
	print("PASS: original title and callback CD fade rates, active word, final-zero update and channel mix numerical effects")
	quit(0)
