extends RefCounted
# Main151d0..15294. Shared dialog word20956 is NOT the saved mode9 target.
static func decide(mode: int, held: int, dialog: int, fade_active: bool, fade_ready: bool) -> Dictionary:
	if mode != 14: return {"start":0,"return":false}
	if not fade_active:
		return {"start":8 if (held & 0xf00200) != 0 else 0,"return":false}
	if not fade_ready: return {"start":0,"return":false}
	return {"start":7,"return":true,"target_mode":5 if dialog == 0 else 6 if dialog == 1 else 14,"outer_reload":dialog == 0,"lives":3,"current_room":0,"crystal_bank":0}
