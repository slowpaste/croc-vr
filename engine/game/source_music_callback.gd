extends RefCounted
const VM = preload("res://asl_vm.gd")
# Callbacks51cd0/51e0c. CD polling/read acknowledgements are supplied by playback.
static func advance(state: Dictionary, reason: int, sector_step: int, polled_cursor: Variant = null) -> Dictionary:
	var next := state.duplicate(true)
	var events: Array = []
	if int(next.active) in [0,2]:
		next.events = events
		return next
	if reason == 1:
		next.cursor = VM.signed32(int(next.cursor)+sector_step)
		events.append("poll")
		if polled_cursor != null:
			next.cursor = VM.signed32(int(polled_cursor))
		if (int(next.cursor)&0xffffffff) > (int(next.end_sector)&0xffffffff):
			if not bool(next.loop):
				next.active = 0
				events.append_array(["detach_callback","pause","complete"])
				if int(next.mode) == 4:
					next.room_start = 0
					next.room_variant = VM.signed32(int(next.room_variant)^1)
					next.last_room = next.room
				next.completion_pending = 1
			elif int(next.cue) == 64:
				next.active = 0
				events.append_array(["detach_callback","pause","restore_mix"])
			else:
				events.append_array(["read_start","restore_mix"])
		elif (int(next.cursor)&0xffffffff) > (int(next.fade_sector)&0xffffffff) and int(next.cue) != 64:
			events.append("fade_mix")
	elif reason == 5:
		events.append("read_command")
	elif bool(next.loop):
		if int(next.seek_phase) == 1:
			next.start_sector = next.pack_start
			next.seek_phase = 2
		events.append("read_start_retry")
	next.events = events
	return next
