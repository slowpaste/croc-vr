extends RefCounted
const VM = preload("res://asl_vm.gd")
static func begin(data: Dictionary) -> Dictionary:
	if not data.has("commands") or data.commands.is_empty(): return {"fault":"Missing original credits command stream"}
	return {"commands":data.commands,"cursor":0,"mode":1,"lines":[],"timer":0,"terminal_counter":0,"complete":false,"details":[]}
static func advance(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	if bool(result.complete): return result
	if int(result.mode) == 1:
		result.lines = []; result.details = []; result.timer = 0
		var headings := 0
		while int(result.cursor) < result.commands.size():
			var command: Dictionary = result.commands[int(result.cursor)]
			if int(command.op) == 0:
				headings += 1
				if headings == 2: result.mode = 0; return result
			result.cursor = int(result.cursor)+1
			if int(command.op) in [0,1,5]: result.lines.append({"text":str(command.text),"large":int(command.op) != 1})
			elif int(command.op) == 4: result.details.append({"name":str(command.name),"detail":str(command.detail)})
			elif int(command.op) == 3: result.mode = 2; result.terminal_counter = VM.signed32(int(result.terminal_counter)+1); return result
			elif int(command.op) != 2: return {"fault":"Invalid original credits command"}
		return {"fault":"Credits stream has no terminal command"}
	result.timer = VM.signed32(int(result.timer)+1)
	if int(result.mode) == 2:
		if (int(result.terminal_counter)&0xffffffff) < 150: result.terminal_counter = VM.signed32(int(result.terminal_counter)+1)
		else: result.mode = 3; result.complete = true
	elif (int(result.timer)&0xffffffff) > result.lines.size()*15+59: result.mode = 1
	return result
static func layout(state: Dictionary) -> Array:
	var labels: Array = []; var y: int = (240-state.lines.size()*30)>>1; var body_started := false
	for line in state.lines:
		if bool(line.large): labels.append({"text":line.text,"large":true,"y":y}); y += 24
		else:
			if not body_started: y += 10; body_started = true
			labels.append({"text":line.text,"large":false,"y":y}); y += 20
	return labels
