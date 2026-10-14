extends RefCounted
const Encoder = preload("res://source_password.gd")
# Native52794 onward. This reads fields/checksum only; later acceptance is separate.
static func read(symbols: Array) -> Dictionary:
	if symbols.size() < 15: return {"fault":"Truncated original password"}
	var word := 0
	for index in range(14,-1,-1):
		var symbol := int(symbols[index])
		if symbol < 1 or symbol > 4: return {"fault":"Invalid original password symbol"}
		word = ((word << 2) | (symbol-1)) & 0xffffffff
	var data: int = (word ^ int(Encoder.MASKS[word & 3])) & 0xffffffff
	var checksum: int = ((data >> 23) & 1) | (2 if data & 8 else 0)
	data &= 0xff7ffff7
	var count := 0
	for bit in range(30):
		if data & (1 << bit): count += 1
	var highest := 0
	var selection := 0
	for bit in range(6):
		if data & (1 << Encoder.COMPLETION_BITS[bit]): highest |= 1 << bit
		if data & (1 << Encoder.SELECTION_BITS[bit]): selection |= 1 << bit
	var pickups: Array = []
	for bit in Encoder.PICKUP_BITS: pickups.append(data & (1 << bit))
	return {"checksum_valid":(count & 3) == checksum,"checksum":checksum,"data":data,"highest_completed":highest,"selection_bits":selection,"pickup_words":pickups}
