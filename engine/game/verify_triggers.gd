extends SceneTree
const Actor = preload("res://asl_actor.gd")

func _initialize() -> void:
	var actor = Actor.new()
	root.add_child(actor)
	var ledge_program := {"instructions":[{"pc":8,"op":49,"args":[11,30],"next":12},{"pc":12,"op":66,"args":[],"next":13},{"pc":30,"op":68,"args":[29,0],"next":34},{"pc":34,"op":52,"args":[],"next":35}]}
	actor.vm.configure(ledge_program,8,actor,[0])
	actor.vm.run()
	for contact in [0,1,2,0x100,0x200]:
		actor.source_ground.mode = contact
		actor.run_source_scripts()
		assert(actor.vm.parameters[0] == 0)
	for contact in [4,8]:
		actor.source_ground.mode = contact
		actor.run_source_scripts()
	assert(actor.vm.parameters[0] == 131072 and actor.vm.frames.is_empty())
	actor.source_ground.mode = 0
	actor.event_triggers.clear()
	var timer_program := {"instructions":[{"pc":8,"op":49,"args":[2,[{"op":4,"value":196608},{"op":18}],30],"next":18},{"pc":18,"op":66,"args":[],"next":19},{"pc":30,"op":68,"args":[29,0],"next":34},{"pc":34,"op":52,"args":[],"next":35}]}
	actor.vm.configure(timer_program,8,actor,[0])
	actor.vm.run()
	actor.run_source_scripts()
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 0 or actor.event_triggers[0].counter != 2:
		quit(1)
		return
	actor.primary_flags |= 0x40
	actor.run_source_scripts()
	if actor.event_triggers[0].counter != 2:
		quit(1)
		return
	actor.primary_flags &= ~0x40
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 65536 or actor.event_triggers[0].counter != 0 or actor.vm.pc != 18 or not actor.vm.frames.is_empty():
		quit(1)
		return
	actor.asl_command({"op":92,"args":[]},actor.vm)
	if actor.visible or (actor.primary_flags & 0x80000) == 0:
		quit(1)
		return
	for i in range(3):
		actor.run_source_scripts()
	if actor.vm.parameters[0] != 131072:
		quit(1)
		return
	actor.asl_command({"op":93,"args":[]},actor.vm)
	if not actor.visible or (actor.primary_flags & 0x80000) != 0:
		quit(1)
		return
	actor.event_triggers[0].period = 0
	actor.event_triggers[0].counter = -1
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 196608 or actor.event_triggers[0].counter != 0:
		quit(1)
		return
	actor.event_triggers.clear()
	var contact_program := {"instructions":[{"pc":8,"op":49,"args":[1,30],"next":12},{"pc":12,"op":49,"args":[1,50],"next":16},{"pc":16,"op":66,"args":[],"next":17},{"pc":30,"op":108,"args":[0,[{"op":4,"value":65536},{"op":18}]],"next":38},{"pc":38,"op":52,"args":[],"next":39},{"pc":50,"op":108,"args":[0,[{"op":4,"value":131072},{"op":18}]],"next":58},{"pc":58,"op":52,"args":[],"next":59}]}
	actor.vm.configure(contact_program,8,actor,[0])
	actor.vm.run()
	actor.primary_flags |= 0x103042
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 0 or (actor.primary_flags & 0x100000) == 0 or (actor.primary_flags & 0x3002) != 0 or (actor.primary_flags & 0x40) == 0:
		quit(1)
		return
	actor.primary_flags &= ~0x40
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 65536 or (actor.primary_flags & 0x100000) != 0 or actor.vm.pc != 16 or not actor.vm.frames.is_empty():
		quit(1)
		return
	actor.vm.parameters[0] = 0
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 0:
		quit(1)
		return
	actor.primary_flags |= 0x100000
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 65536:
		quit(1)
		return
	actor.event_triggers.clear()
	var program := {"instructions":[{"pc":8,"op":49,"name":"CreateTrigger","args":[1,20],"next":12},{"pc":12,"op":66,"name":"Hold","args":[],"next":13},{"pc":13,"op":59,"name":"FileEnd","args":[],"next":14},{"pc":20,"op":54,"name":"LetGVar","args":[0,[{"op":4,"value":65536},{"op":18}]],"next":28},{"pc":28,"op":108,"name":"LetParam","args":[0,[{"op":4,"value":131072},{"op":18}]],"next":36},{"pc":36,"op":52,"name":"EndTrigger","args":[],"next":37}]}
	actor.vm.configure(program,8,actor,[0])
	if actor.vm.run() != "yielded" or actor.vm.pc != 12:
		quit(1)
		return
	if not actor.dispatch_event(1) or actor.vm.globals.get(0,0) != 65536 or actor.vm.parameters[0] != 131072:
		quit(1)
		return
	if actor.vm.pc != 12 or actor.event_triggers[0].active:
		quit(1)
		return
	actor.released = true
	if actor.vm.run() != "finished":
		quit(1)
		return
	var animation_program := {"instructions":[{"pc":8,"op":49,"name":"CreateTrigger","args":[7,[{"op":4,"value":65536},{"op":18}],30],"next":16},{"pc":16,"op":66,"name":"Hold","args":[],"next":17},{"pc":30,"op":28,"name":"ProcCall","args":[50],"next":34},{"pc":34,"op":16,"name":"Wait","args":[[{"op":4,"value":65536},{"op":18}]],"next":42},{"pc":42,"op":52,"name":"EndTrigger","args":[],"next":43},{"pc":50,"op":108,"name":"LetParam","args":[0,[{"op":4,"value":131072},{"op":18}]],"next":58},{"pc":58,"op":57,"name":"EndProc","args":[],"next":59}]}
	actor.event_triggers.clear()
	actor.vm.configure(animation_program,8,actor,[0])
	if actor.vm.run() != "yielded":
		quit(1)
		return
	actor.animation_triggers = 1
	actor.run_source_scripts()
	if actor.vm.pc != 34 or actor.vm.frames != [{"kind":"trigger","pc":16,"index":0}] or actor.vm.parameters[0] != 131072 or not actor.event_triggers[0].active:
		quit(1)
		return
	actor.animation_triggers = 0
	actor.run_source_scripts()
	if actor.vm.pc != 16 or not actor.vm.frames.is_empty() or actor.event_triggers[0].active or (actor.primary_flags & 0x20000000) != 0:
		quit(1)
		return
	actor.event_triggers.clear()
	var multiple := {"instructions":[{"pc":8,"op":49,"name":"CreateTrigger","args":[1,30],"next":12},{"pc":12,"op":49,"name":"CreateTrigger","args":[1,50],"next":16},{"pc":16,"op":66,"name":"Hold","args":[],"next":17},{"pc":30,"op":108,"name":"LetParam","args":[0,[{"op":4,"value":65536},{"op":18}]],"next":38},{"pc":38,"op":52,"name":"EndTrigger","args":[],"next":39},{"pc":50,"op":108,"name":"LetParam","args":[0,[{"op":4,"value":131072},{"op":18}]],"next":58},{"pc":58,"op":52,"name":"EndTrigger","args":[],"next":59}]}
	actor.vm.configure(multiple,8,actor,[0])
	actor.vm.run()
	if not actor.dispatch_event(1) or actor.vm.parameters[0] != 65536 or actor.vm.pc != 16 or not actor.vm.frames.is_empty():
		quit(1)
		return
	actor.event_triggers.clear()
	var nested := {"instructions":[{"pc":8,"op":49,"name":"CreateTrigger","args":[1,50],"next":12},{"pc":12,"op":24,"name":"For","args":[29,0,[{"op":38}],[{"op":4,"value":131072},{"op":18}]],"next":24},{"pc":24,"op":66,"name":"Hold","args":[],"next":25},{"pc":25,"op":121,"name":"NextImm","args":[],"next":26},{"pc":26,"op":59,"name":"FileEnd","args":[],"next":27},{"pc":50,"op":17,"name":"Repeat","args":[],"next":51},{"pc":51,"op":28,"name":"ProcCall","args":[70],"next":59},{"pc":59,"op":174,"name":"UntilImm","args":[[{"op":4,"value":1},{"op":18}]],"next":66},{"pc":66,"op":52,"name":"EndTrigger","args":[],"next":67},{"pc":70,"op":16,"name":"Wait","args":[[{"op":4,"value":65536},{"op":18}]],"next":78},{"pc":78,"op":57,"name":"EndProc","args":[],"next":79}]}
	actor.vm.configure(nested,8,actor,[0])
	actor.vm.run()
	actor.dispatch_event(1)
	if actor.vm.frames.size() != 4 or actor.vm.frames[0].kind != "for" or actor.vm.frames[1].kind != "trigger" or actor.vm.frames[2].kind != "repeat" or actor.vm.frames[3].kind != "procedure":
		quit(1)
		return
	actor.run_source_scripts()
	if actor.vm.pc != 24 or actor.vm.frames.size() != 1 or actor.vm.frames[0].kind != "for":
		quit(1)
		return
	actor.released = true
	actor.vm.run()
	if actor.vm.parameters[0] != 65536 or actor.vm.pc != 24:
		quit(1)
		return
	actor.released = true
	if actor.vm.run() != "finished" or actor.vm.parameters[0] != 131072 or not actor.vm.frames.is_empty():
		quit(1)
		return
	var disabled_actor = Actor.new()
	disabled_actor.event_triggers.assign([{"mode":1,"pc":30,"active":true},{"mode":2,"pc":50,"active":false}])
	disabled_actor.vm.frames.append({"kind":"trigger","index":0,"pc":8})
	if disabled_actor.asl_command({"op":50,"args":[-1]},disabled_actor.vm) != "continue" or disabled_actor.event_triggers[0].mode != 255 or disabled_actor.event_triggers[1].mode != 2 or disabled_actor.vm.frames.size() != 1:
		disabled_actor.free()
		quit(1)
		return
	disabled_actor.primary_flags = 0x1001
	disabled_actor.asl_command({"op":84,"args":[]},disabled_actor.vm)
	if disabled_actor.primary_flags != 0x1041:
		disabled_actor.free()
		quit(1)
		return
	disabled_actor.asl_command({"op":85,"args":[]},disabled_actor.vm)
	if disabled_actor.primary_flags != 0x1001:
		disabled_actor.free()
		quit(1)
		return
	disabled_actor.free()
	print("PASS: trigger registration, dispatch, current-trigger disabling and pause flag restoration")
	quit(0)
