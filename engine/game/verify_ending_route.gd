extends SceneTree
func _initialize() -> void:
	var routes = preload("res://source_ending_route.gd")
	var normal: Dictionary = routes.after_sequence(15)
	var complete: Dictionary = routes.after_sequence(16)
	if normal != {"followup":[19],"mode":7,"credits_variant":0,"credits_available":true,"incoming_fade":1,"return_mode":5} or complete != {"followup":[],"mode":7,"credits_variant":1,"credits_available":false,"incoming_fade":1,"return_mode":0}:
		push_error("Original normal/true ending credits paths differ"); quit(1); return
	for sequence in range(24):
		if sequence not in [15,16] and routes.after_sequence(sequence).mode != -1:
			push_error("Non-final boss sequence entered credits"); quit(1); return
	print("PASS: normal ending chains OUTRO19 then normal credits; Secret Sentinel uses true credits with distinct menu availability")
	quit(0)
