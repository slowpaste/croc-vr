extends RefCounted
# Native15718..157a4: state1, outgoing8; zero lives selects main mode14.
static func decide(state: int, lives: int, fade_active: bool, fade_ready: bool) -> Dictionary:
	if state != 1: return {"start":0,"action":"wait"}
	if not fade_active: return {"start":8,"action":"wait"}
	if not fade_ready: return {"start":0,"action":"wait"}
	if lives == 0: return {"start":0,"action":"game_over","mode":14}
	return {"start":1,"action":"respawn"}
