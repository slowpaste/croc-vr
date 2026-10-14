extends RefCounted
const VM = preload("res://asl_vm.gd")
# Stop513c4..514c8, including captured-room bookmark/variant state.
static func apply(state: Dictionary, enabled: bool) -> Dictionary:
	var result := state.duplicate(true)
	result.events = []
	if not enabled:
		return result
	if int(result.mode) == 4:
		var cursor := int(result.cursor)&0xffffffff
		var start := int(result.start_sector)&0xffffffff
		var end := int(result.end_sector)&0xffffffff
		if cursor > start and cursor < end:
			if ((end-cursor)&0xffffffff) >= 2251:
				result.room_start = VM.signed32(cursor)
			else:
				result.room_start = 0
				result.room_variant = VM.signed32(int(result.room_variant)^1)
		else:
			result.room_start = 0
		result.last_room = result.room
	result.active = 0
	result.completion_pending = 0
	result.events = ["pause","detach_callback"]
	return result
