extends RefCounted
# Native520a4 return control: pressed-edge word &0x00900000.
static func sample(pressed: int) -> Dictionary:
	if (pressed & 0x900000) == 0: return {"return_requested":false,"events":[]}
	return {"return_requested":true,"events":[{"sound":"START","volume":80,"pitch":24}]}
