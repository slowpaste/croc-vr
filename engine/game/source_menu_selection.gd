extends RefCounted
const VM = preload("res://asl_vm.gd")
static func level_for_index(index: int, levels: Array) -> Dictionary:
	if levels.size() != 46 or index < 0 or index >= 46:
		return {"fault":"Missing source menu level table or invalid index"}
	return {"level":int(levels[index])&65535}
# Main0x800141f0..0x800143d8; flags keyed by their original progress-array index.
static func previous(selected: int, flags: Dictionary) -> int:
	var result := selected
	if result != 0:
		result = VM.signed32(result-1)
		while result != 0 and (int(flags.get(result-1,0))&65535) == 0:
			result = VM.signed32(result-1)
	return result
static func next(selected: int, flags: Dictionary) -> int:
	if (selected&0xffffffff) >= 44:
		return selected
	var candidate := VM.signed32(selected+1)
	while candidate < 46:
		if candidate == 40 and (int(flags.get(40,0))&0x4000) == 0:
			break
		if (int(flags.get(candidate-1,0))&0x8000) != 0:
			return candidate
		candidate = VM.signed32(candidate+1)
	return selected
static func navigate(selected: int, flags: Dictionary, buttons: int, locked: int) -> Dictionary:
	var result := selected
	var changes := 0
	if locked == 0:
		if (buttons&0x20000) != 0:
			var before := result
			result = previous(result,flags)
			changes += int(result != before)
		if (buttons&0x80000) != 0:
			var before := result
			result = next(result,flags)
			changes += int(result != before)
	return {"index":result,"changes":changes}
