extends RefCounted
# Post-sequence actions at native15d40..15dc4; playback must finish first.
static func after_sequence(sequence: int) -> Dictionary:
	if sequence == 15:
		return {"followup":[19],"mode":7,"credits_variant":0,"credits_available":true,"incoming_fade":1,"return_mode":5}
	if sequence == 16:
		return {"followup":[],"mode":7,"credits_variant":1,"credits_available":false,"incoming_fade":1,"return_mode":0}
	return {"followup":[],"mode":-1}
