extends SceneTree
const Callback = preload("res://source_music_callback.gd")
func _initialize() -> void:
	var state := {"active":1,"cursor":100,"end_sector":200,"fade_sector":150,"loop":false,"cue":1,"mode":4,"room":3,"room_start":100,"room_variant":0,"seek_phase":0,"start_sector":100,"pack_start":90}
	var result := Callback.advance(state,1,100)
	if result.active != 1 or result.cursor != 200 or result.events != ["poll","fade_mix"] or state.cursor != 100:
		quit(1)
		return
	result = Callback.advance(result,1,1)
	if result.active != 0 or result.room_start != 0 or result.room_variant != 1 or result.last_room != 3 or result.completion_pending != 1:
		quit(1)
		return
	state.loop = true
	result = Callback.advance(state,1,101)
	if result.active != 1 or result.events != ["poll","read_start","restore_mix"]:
		quit(1)
		return
	state.cue = 64
	result = Callback.advance(state,1,80)
	if result.events != ["poll"]:
		quit(1)
		return
	result = Callback.advance(state,1,101)
	if result.active != 0 or result.events != ["poll","detach_callback","pause","restore_mix"]:
		quit(1)
		return
	state.seek_phase = 1
	result = Callback.advance(state,2,0)
	if result.start_sector != 90 or result.seek_phase != 2 or result.events != ["read_start_retry"]:
		quit(1)
		return
	state.active = 2
	if not Callback.advance(state,1,100).events.is_empty():
		quit(1)
		return
	print("PASS: source music strict end boundary, near-end fade, room variant toggle, loop/stat64 and seek retry decisions")
	quit(0)
