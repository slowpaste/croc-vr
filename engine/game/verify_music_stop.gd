extends SceneTree
const Stop = preload("res://source_music_stop.gd")
func _initialize() -> void:
	var state := {"mode":4,"cursor":7749,"start_sector":100,"end_sector":10000,"room":2,"room_start":500,"room_variant":0,"active":1,"completion_pending":1}
	var result := Stop.apply(state,true)
	if result.room_start != 7749 or result.room_variant != 0 or result.last_room != 2 or result.active != 0 or result.completion_pending != 0 or state.room_start != 500:
		quit(1)
		return
	state.cursor = 7750
	result = Stop.apply(state,true)
	if result.room_start != 0 or result.room_variant != 1:
		quit(1)
		return
	for cursor in [100,10000,10001]:
		state.cursor = cursor
		result = Stop.apply(state,true)
		if result.room_start != 0 or result.room_variant != 0:
			quit(1)
			return
	result = Stop.apply(state,false)
	if result.active != 1 or result.room_start != 500 or not result.events.is_empty():
		quit(1)
		return
	state.mode = 3
	result = Stop.apply(state,true)
	if result.room_start != 500 or result.room_variant != 0:
		quit(1)
		return
	print("PASS: source music stop strict cursor range,2250/2251 bookmark boundary, variant toggle and disabled/non-gameplay rules")
	quit(0)
