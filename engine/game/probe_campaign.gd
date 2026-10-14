extends SceneTree
var audit_ticks := 60
# Room-entry/idle coverage only; this does not establish puzzle/boss completion.
func _initialize() -> void: call_deferred("probe")
func write_results(output: String, results: Array) -> bool:
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: push_error("Cannot write campaign audit"); return false
	file.store_string(JSON.stringify({"coverage":"entry and%d idle source ticks; not full completion" % audit_ticks,"rooms":results}))
	return true
func probe() -> void:
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	await process_frame
	world.set_process(false); world.set_physics_process(false)
	world.source_runtime_enabled = true; world.source_controller_enabled = true
	var rooms: Array = world.manifest.linkage.rooms.keys(); rooms.sort()
	var results: Array = []
	var args := OS.get_cmdline_user_args()
	var output := "res://../build/campaign-room-audit.json"
	var option := args.find("--audit-output")
	if option >= 0 and option+1 < args.size(): output = str(args[option+1])
	var only := ""
	option = args.find("--audit-ticks")
	if option >= 0 and option+1 < args.size(): audit_ticks = int(args[option+1])
	if audit_ticks < 1 or audit_ticks > 9000: push_error("Audit ticks must be1..9000");quit(1);return
	option = args.find("--audit-room")
	if option >= 0 and option+1 < args.size(): only = str(args[option+1])
	for name in rooms:
		if not only.is_empty() and name != only: continue
		if bool(world.manifest.linkage.rooms[name].get("menu",false)): continue
		world.source_map_entity_flags.clear()
		var level := int(str(name).substr(2,3))
		var selected: int = world.runtime_tables.get("menuLevels",{}).get("values",[]).find(float(level))
		if selected < 0: push_error("Missing authored level selection for "+str(name));quit(1);return
		world.source_menu_state.selected_index = selected
		world.source_level_script_state = 0
		world.source_pickup_counts = {1:0,2:0,3:3}
		world.source_transition_state = 0; world.source_transition_fault = ""
		world.update_source_input(0,0); world.source_player_input_state = {"pad_mode":1}
		var record := {"room":name,"selected_index":selected,"loaded":world.load_room(name),"faults":[],"actors":0,"ticks_completed":0}
		if record.loaded:
			var player = world.create_source_player()
			if player == null: record.faults.append({"actor":"player","fault":"No initial player"})
			for tick in range(audit_ticks):
				world.tick_source_actors()
				record.ticks_completed = tick+1
				if world.source_actors.any(func(actor): return not actor.vm.fault.is_empty()): break
			for actor in world.source_actors:
				if not actor.vm.fault.is_empty():
					var failure := {"actor":actor.source_name,"pc":actor.vm.pc,"fault":actor.vm.fault,"instruction":actor.vm.instructions.get(actor.vm.pc,{})}
					if int(failure.instruction.get("op",-1)) == 191:
						failure.movement_fault = actor.vm.fault
						failure.movement_state = world.source_player_movement_state.duplicate(true)
						failure.ground = actor.source_ground.duplicate(true)
						failure.secondary_flags = actor.secondary_flags
					if actor.vm.fault.contains("LoopSound"):
						failure.parameters = actor.vm.parameters.duplicate(); failure.handles = actor.handles.duplicate()
						failure.sample_volumes = world.source_sample_volumes.duplicate()
					record.faults.append(failure)
			record.actors = world.source_actors.size()
			record.transition_fault = world.source_transition_fault
		results.append(record)
		if not write_results(output,results): quit(1); return
		print("CAMPAIGN_ROOM: ",JSON.stringify(record))
		await process_frame
	world.stop_imported_audio(); world.queue_free(); await process_frame
	await create_timer(0.25).timeout
	print("CAMPAIGN_AUDIT_ROOMS: ",results.size())
	var clean := results.all(func(record): return bool(record.loaded) and record.faults.is_empty() and str(record.get("transition_fault","")).is_empty())
	quit(1 if args.has("--require-clean") and not clean else 0)
