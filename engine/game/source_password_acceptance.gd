extends RefCounted
const Encoder = preload("res://source_password.gd")
# Native52a10..52c78; acceptance only, without subsequent progress writes.
static func accepts(fields: Dictionary) -> bool:
	if not fields.has_all(["checksum_valid","highest_completed","selection_bits","pickup_words","data"]) or not fields.checksum_valid: return false
	var highest := int(fields.highest_completed)
	var selection := int(fields.selection_bits)
	if highest < 0 or highest >= 46 or selection < 0 or selection >= 46 or selection > highest+1: return false
	if fields.pickup_words.size() != 8: return false
	var collected := 0
	for slot in range(8):
		if int(fields.pickup_words[slot]) == 0: continue
		collected += 1
		if highest < 4+slot*5 or (int(fields.data) & (1 << Encoder.SECRET_BITS[slot])) == 0: return false
	return highest < 41 or collected == 8
