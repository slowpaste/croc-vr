extends SceneTree
const Poll = preload("res://source_music_poll.gd")
func _initialize() -> void:
	var response := PackedByteArray([0,0,0,0,0,0x01,0x23,0x45])
	for frame in range(1,21):
		var result := Poll.advance(frame,2,17,response)
		if frame%7 == 0:
			if result.events != ["sync","get_location"] or result.cursor != 6120: quit(1); return
		elif not result.events.is_empty() or result.cursor != null: quit(1); return
	if Poll.advance(-7,5,17,response).events != ["sync","read_command"] or Poll.advance(0,1,17,response).events != ["sync"]: quit(1); return
	var result := Poll.advance(7,2,27,PackedByteArray())
	if result.events != ["sync","get_location"] or result.cursor != null: quit(1); return
	response[5] = 0
	response[6] = 2
	response[7] = 0
	if Poll.advance(7,2,17,response).cursor != null: push_error("Zero polled CD position replaced cursor"); quit(1); return
	response[7] = 1
	if Poll.advance(7,2,17,response).cursor != 1 or not Poll.advance(7,2,17,PackedByteArray()).has("fault"): quit(1); return
	print("PASS: original seven-display-frame CD poll gate, command/status branches and absolute BCD cursor")
	quit(0)
