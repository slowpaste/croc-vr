extends RefCounted
var pending: Array[Dictionary] = []
func reset() -> void: pending.clear()
func register(owner: Node3D) -> void:
	owner.source_references_registered = true
	var index := 0
	for reference in owner.vm.program.get("references",[]):
		if int(reference.kind) != 0: continue
		if pending.size() < 32: pending.append({"owner":owner,"index":index,"name":str(reference.name)})
		index += 1
func refresh(active: Array) -> void:
	# Native2d264 consumes pending records, retaining the final exact-name match.
	for reference in pending:
		var owner: Node3D = reference.owner
		if not is_instance_valid(owner): continue
		for candidate in active:
			if is_instance_valid(candidate) and candidate.source_name == reference.name:
				owner.source_reference_slots[int(reference.index)] = candidate.source_pool_id
	pending.clear()
