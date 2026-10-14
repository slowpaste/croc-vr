extends RefCounted
const VM = preload("res://asl_vm.gd")
# Main0x80012f3c..0x80012fc4: retained s6 sequence identifier by current level.
static func sequence_id(level: int) -> int:
	return int({13:17,17:10,23:18,27:11,33:14,37:12,43:13,47:15,54:16}.get(level,0))
static func next_level_selection(selected: int, flags: Dictionary) -> int:
	# NextLevel2b4d0 calls secret-skip2b428 before its index39 gate/increment.
	var index := selected&0xffffffff
	if index < 40 and index%10 == 3:
		var total := 0
		for previous in range(index-3,index): total += int(flags.get(previous,0))&0x7fff
		if total < 18: index += 1
	if index != 39 or (int(flags.get(40,0))&0x4000) != 0: index += 1
	return VM.signed32(index)

# Main0x800158c4..0x80015a2c, after transition readiness and sequence gating.
static func next_selection(selected: int, flags: Dictionary, sequence: int) -> int:
	var index := selected&0xffffffff
	var total := 0
	var candidate := (index-3)&0xffffffff
	# The source uses unsigned loop bounds; indices0..2 skip the whole sum.
	while candidate < index:
		total += int(flags.get(candidate,0))&0x7fff
		candidate = (candidate+1)&0xffffffff
	if total >= 18:
		return VM.signed32(index+1)
	if sequence != 0 and index == 38:
		return 40 if (int(flags.get(40,0))&0x4000) != 0 else 38
	return VM.signed32((int(index/10)+1)*10)
