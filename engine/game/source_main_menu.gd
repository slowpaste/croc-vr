extends RefCounted
const VM = preload("res://asl_vm.gd")
static func initialize(selected: int, last_index: int) -> Dictionary:
	var sizes: Array = [32768,32768,32768,32768,32768]
	if selected >= 0 and selected < 5:
		sizes[selected] = 65536
	return {"selected":selected,"last_index":last_index,"cooldown":0,"locked":0,"pulse":0,"sizes":sizes}

# Source53344..53600, followed by common timer decrement145d8..145f0.
static func advance(state: Dictionary, held: int, pressed: int) -> Dictionary:
	var result := state.duplicate(true)
	var changes := 0
	if int(result.locked) == 0:
		for direction in [0x10000,0x40000]:
			if ((held&direction) != 0 and int(result.cooldown) == 0) or (pressed&direction) != 0:
				result.cooldown = 10
				result.selected = VM.signed32(int(result.selected)+(-1 if direction == 0x10000 else 1))
				if direction == 0x10000 and int(result.selected) == -1:
					result.selected = result.last_index
				elif direction == 0x40000 and int(result.selected) == int(result.last_index)+1:
					result.selected = 0
				result.sizes[int(result.selected)] = 65536
				result.pulse = VM.signed32(int(result.pulse)+1)
				changes += 1
	for index in range(5):
		var size := int(result.sizes[index])&0xffffffff
		if index == int(result.selected) and int(result.pulse) != 0:
			if size > 0x11fff:
				result.pulse = 0
			else:
				result.sizes[index] = VM.signed32(size+(size>>4))
		else:
			var minimum := 65536 if index == int(result.selected) else 0x9800
			if size > minimum:
				size = (size>>1)+(size>>2)+(size>>3)+(size>>4)
			result.sizes[index] = maxi(size,minimum)
	if int(result.cooldown) != 0:
		result.cooldown = VM.signed32(int(result.cooldown)-1)
	result.changes = changes
	return result
