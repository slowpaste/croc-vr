extends RefCounted
# Sector boundaries are exported from actual interleaved AN2 data extents.
static func initialize(frames: Array, prefilled_sectors: int) -> Dictionary:
	if frames.is_empty() or prefilled_sectors < 0: return {"fault":"Invalid cutscene stream origin"}
	var thresholds: Array = []
	var previous := 0
	for frame in frames:
		if not frame.has("stream") or not frame.stream.has("requiredSectorCount"): return {"fault":"Missing cutscene record availability"}
		var required := int(frame.stream.requiredSectorCount)
		if required <= previous: return {"fault":"Invalid cutscene sector ordering"}
		thresholds.append(required)
		previous = required
	return {"required_sectors":thresholds,"cursor":0,"processed_sectors":prefilled_sectors}

static func consume_ready(state: Dictionary, processed_sectors: int, budget: int) -> Dictionary:
	if budget < 1 or budget > 64 or processed_sectors < int(state.processed_sectors): return {"fault":"Invalid cutscene stream advance"}
	var result := state.duplicate(true)
	result.processed_sectors = processed_sectors
	result.ready_indices = []
	while int(result.cursor) < result.required_sectors.size() and result.ready_indices.size() < budget:
		if int(result.required_sectors[int(result.cursor)]) > processed_sectors: break
		result.ready_indices.append(int(result.cursor))
		result.cursor = int(result.cursor)+1
	result.complete = int(result.cursor) == result.required_sectors.size()
	return result
