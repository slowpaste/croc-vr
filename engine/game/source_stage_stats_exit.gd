extends RefCounted
# Source15834..158b8 state4;15a68..15ab8 state3 confirmation/fade gates.
static func decide_for_level(transition: int, level: int, busy: int, fade_active: bool, fade_ready: bool) -> Dictionary:
	return decide(transition,preload("res://source_stage_end.gd").sequence_id(level),busy,fade_active,fade_ready)
static func decide(transition: int, sequence: int, busy: int, fade_active: bool, fade_ready: bool) -> Dictionary:
	if transition == 3:
		if busy == 0: return {"start":0,"return":false}
		if not fade_active: return {"start":2 if sequence != 0 else 8,"return":false}
		return {"start":0,"return":fade_ready}
	if transition != 4: return {"start":0,"return":false}
	if not fade_active:
		if sequence == 0: return {"start":8,"return":false}
		if busy != 0: return {"start":2,"return":false}
	return {"start":0,"return":fade_ready and (sequence == 0 or busy != 0)}
