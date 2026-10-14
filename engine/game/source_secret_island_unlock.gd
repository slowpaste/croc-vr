extends RefCounted
# Original common stage return15c84..15d20, before retained story sequence s6.
static func decide(flags: Dictionary, pickups: Array) -> Dictionary:
	if (int(flags.get(40,0))&0x4000) != 0: return {"play":false}
	if pickups.size() != 8: return {"fault":"Missing eight original jigsaw pickup words"}
	for word in pickups:
		if int(word) == 0: return {"play":false}
	return {"play":true,"sequence":7,"selected_index":40,"level":50,"room":0,"flag":0x4000}
