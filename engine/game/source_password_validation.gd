extends RefCounted
static func advance(state: Dictionary, pressed: int, levels: Array, prior_progress: Array) -> Dictionary:
	var result := preload("res://source_password_entry.gd").advance(state,pressed)
	if result.has("fault"): return result
	result.erase("progress") # Native commit runs once, before shared return flag is set.
	if not result.needs_validation: return result
	var fields := preload("res://source_password_fields.gd").read(result.symbols)
	if fields.has("fault"): return fields
	var progress := preload("res://source_password_progress.gd").restore(fields,levels,prior_progress)
	if progress.has("fault"): return progress
	if not progress.accepted:
		# Native5313c calls3ae9c: reset80 progress halfwords and eight pickups.
		var flags: Array = []; flags.resize(80); flags.fill(0)
		progress = {"accepted":false,"flags":flags,"announcements":[0,0,0,0,0,0,0,0],"pickup_words":[0,0,0,0,0,0,0,0],"selected_index":0,"level":10,"room":0,"lives":3,"crystal_bank":0,"return_flag":1}
		result.events.append({"sound_handle":20432,"volume":15,"pitch":0})
	else: result.events.append({"sound_handle":20264,"volume":80,"pitch":24})
	result.progress = progress
	result.return_flag = int(progress.return_flag)
	result.return_requested = true
	result.needs_validation = false
	return result
