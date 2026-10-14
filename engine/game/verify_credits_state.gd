extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var machine = preload("res://source_credits_state.gd")
	var timing: Dictionary = machine.begin({"commands":[{"op":0,"text":"heading"},{"op":1,"text":"body"},{"op":0,"text":"next"},{"op":3}]})
	timing = machine.advance(timing)
	for tick in range(89): timing = machine.advance(timing)
	if timing.mode != 0: push_error("Credits page ended before lines*15+60 ticks"); quit(1); return
	timing = machine.advance(timing)
	if timing.mode != 1: push_error("Credits page delay missed its exact threshold"); quit(1); return
	for entry in manifest.credits:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
		var state: Dictionary = machine.begin(data)
		var page_count := 0; var terminal_ticks := 0; var saw_complete_text := false
		for tick in range(20000):
			var parsing := int(state.mode) == 1
			state = machine.advance(state)
			if state.has("fault"): push_error(str(state.fault)); quit(1); return
			if parsing:
				page_count += 1
				for line in state.lines:
					if line.text == "100% COMPLETE!": saw_complete_text = true
				if int(entry.variant) == 1 and page_count == 1:
					var layout: Array = machine.layout(state)
					if layout.size() != 5 or layout[0].y != 45 or layout[3].y != 127 or layout[4].y != 147:
						push_error("Original true-ending page placement/font spacing differs"); quit(1); return
			elif int(state.mode) == 2 or bool(state.complete): terminal_ticks += 1
			if state.complete: break
		if not state.complete or page_count != (31 if int(entry.variant) == 0 else 34) or terminal_ticks != 150 or saw_complete_text != (int(entry.variant) == 1):
			push_error("Credits page/timing/variant differs: "+str(entry.variant)+" "+str(page_count)+" "+str(terminal_ticks)); quit(1); return
		print("CREDITS_STATE: variant=",entry.variant," pages=",page_count," final_ticks=",terminal_ticks)
	print("PASS: original credits pages, font styles/placement, per-page delay,150-tick terminal wait and true100% message")
	quit(0)
