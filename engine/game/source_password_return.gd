extends RefCounted
# Native14d40..14dec;12 display,13 entry, shared return flag20272.
static func decide(mode: int, return_flag: int, fade_active: bool, fade_ready: bool) -> Dictionary:
	if mode not in [12,13] or return_flag == 0: return {"start":0,"return":false}
	if not fade_active: return {"start":8,"return":false}
	if not fade_ready: return {"start":0,"return":false}
	return {"start":7,"return":true,"target_mode":5 if mode == 12 or return_flag == 2 else 0,"update_unlocks":mode == 13 and return_flag == 2}
