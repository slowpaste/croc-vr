extends RefCounted
const VM = preload("res://asl_vm.gd")
static func advance(offset: Vector2i, held: int, pressed: int) -> Dictionary:
	# Native4ce44..4cf94 applies every held direction before clamping,
	# even opposite directions;16cd8 runs whenever any direction was held.
	var next := offset
	var moves := 0
	for command in [[0x20000,0,-1],[0x80000,0,1],[0x10000,1,-1],[0x40000,1,1]]:
		if (held&int(command[0])) == 0: continue
		next[int(command[1])] = VM.signed32(int(next[int(command[1])])+int(command[2]))
		moves += 1
	next.x = clampi(next.x,-8,24);next.y = clampi(next.y,-8,24)
	return {"offset":next,"apply_display":moves!=0,"moves":moves,"back":(pressed&0x900000)!=0,"parent_page":4,"parent_selection":3,"parent_last_index":4}
