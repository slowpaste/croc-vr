extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
# Factory 0x80027080 prepends; map-load sorting 0x8003e724..0x8003e81c.
const VM = preload("res://asl_vm.gd")

static func order(actors: Array, cell_meters: float, initial_state: bool = false) -> Dictionary:
	var priority_count := 0
	for actor in actors:
		var flags: int = actor.source_initial_primary_flags if initial_state else actor.primary_flags
		if (flags & 0x800) != 0:
			priority_count += 1
	# The original adjacent swap rule cannot settle with two priority nodes.
	if priority_count > 1:
		return {"ok":false,"fault":"Source actor sort cannot settle with multiple bit-0x800 nodes","actors":[]}
	var result := actors.duplicate()
	var changed := true
	while changed:
		changed = false
		for i in range(result.size() - 1):
			var first = result[i]
			var second = result[i + 1]
			var first_flags: int = first.source_initial_primary_flags if initial_state else first.primary_flags
			var second_flags: int = second.source_initial_primary_flags if initial_state else second.primary_flags
			var first_priority := (first_flags & 0x800) != 0
			var second_priority := (second_flags & 0x800) != 0
			var first_y: int = first.source_spawn_y_units if initial_state else VM.signed32(roundi(first.position.y / cell_meters * 4096.0))
			var second_y: int = second.source_spawn_y_units if initial_state else VM.signed32(roundi(second.position.y / cell_meters * 4096.0))
			if second_priority or (not first_priority and second_y < first_y):
				result[i] = second
				result[i + 1] = first
				changed = true
	return {"ok":true,"fault":"","actors":result}
