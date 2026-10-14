extends RefCounted
const Encoder = preload("res://source_password.gd")
static func restore(fields: Dictionary, levels: Array, prior_progress: Array = []) -> Dictionary:
	if not preload("res://source_password_acceptance.gd").accepts(fields): return {"accepted":false}
	if levels.size() != 46: return {"fault":"Missing original password level table"}
	if not prior_progress.is_empty() and prior_progress.size() != 80: return {"fault":"Invalid original progress storage"}
	var flags: Array = prior_progress.duplicate()
	if flags.is_empty(): flags.resize(80); flags.fill(0)
	for index in range(45): flags[index] = 0
	var highest := int(fields.highest_completed)
	# Native52cf4 skips marking when highest is zero, retaining an empty stage0.
	if highest != 0:
		for index in range(highest+1): flags[index] = 0x8000
	var announcements: Array = []; announcements.resize(8); announcements.fill(0)
	var all_pickups := true
	for word in fields.pickup_words:
		if int(word) == 0: all_pickups = false
	if all_pickups: flags[40] = int(flags[40]) | 0x4000
	for slot in range(8):
		var base := slot*5
		if int(fields.data) & (1 << Encoder.SECRET_BITS[slot]):
			announcements[slot] = 2
			for index in range(base,base+3): flags[index] = 0x8006
			flags[base+3] = 0x8000
			flags[base+4] = 0x8000
		else: flags[base+3] = 0
	var selected := int(fields.selection_bits)
	return {"accepted":true,"flags":flags,"announcements":announcements,"pickup_words":fields.pickup_words.duplicate(),"selected_index":selected,"level":int(levels[selected]),"room":0,"lives":3,"return_flag":2}
