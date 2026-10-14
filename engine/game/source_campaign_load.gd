extends RefCounted
static func prepare(record: PackedByteArray) -> Dictionary:
	var state := preload("res://source_campaign_save.gd").decode(record)
	if state.has("fault"):return state
	# Original Load dialog4e134 resets room;5319c..5333c removes a
	# persistent pickup unless its associated fourth stage is complete.
	state.room=0
	for slot in range(8):
		if (int(state.flags[4+slot*5])&0x8000)==0:state.pickups[slot]=0
	state.return_mode=5;state.return_flag=1
	return state
