extends RefCounted
const VM = preload("res://asl_vm.gd")
# Source50be8..50c88, using VSync(-1) display counter rather than room ticks.
static func advance(display_frame: int, sync_result: int, last_command: int, response: PackedByteArray) -> Dictionary:
	var result := {"events":[],"cursor":null}
	if VM.signed32(display_frame)%7 != 0: return result
	result.events.append("sync")
	if sync_result == 5:
		result.events.append("read_command") # CdControl(27,NULL)
	elif sync_result == 2:
		if last_command == 17:
			if response.size() < 8: return {"fault":"Missing original CD GetlocP response"}
			# CdPosToInt68450 reads absolute BCD MSF at response bytes5..7.
			var minute := (int(response[5])>>4)*10+(int(response[5])&15)
			var second := (int(response[6])>>4)*10+(int(response[6])&15)
			var frame := (int(response[7])>>4)*10+(int(response[7])&15)
			var position := (minute*60+second)*75+frame-150
			if position > 0: result.cursor = position
		result.events.append("get_location") # CdControl(17,NULL), including non17 completion.
	return result
