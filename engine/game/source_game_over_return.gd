extends RefCounted
# LOAD GAME return only: original main14fa4..15048, mode9/target20232.
# Password display/entry are modes12/13; continue choice is14.
static func decide(mode: int, requested: bool, target: int, fade_active: bool, fade_ready: bool) -> Dictionary:
	if mode != 9: return {"start":0,"return":false}
	if not fade_active:
		return {"start":(14 if target == 0 else 8) if requested else 0,"return":false}
	if not fade_ready: return {"start":0,"return":false}
	return {"start":15,"return":true,"target_mode":target,"outer_action":2 if target == 0 else 0}
