extends RefCounted
static func advance(state: Dictionary, sample: Vector2i, pressed: int) -> Dictionary:
	if not state.has_all(["phase","center","minimum","maximum"]) or int(state.phase) not in [0,1]:
		return {"fault":"Invalid original calibration state"}
	if sample.x < 0 or sample.x > 255 or sample.y < 0 or sample.y > 255:
		return {"fault":"Calibration requires original unsigned pad bytes"}
	var next := state.duplicate(true)
	next.commit = false;next.back = false
	# Native4d094..4d110 updates extrema before confirmation.
	if int(next.phase) == 1:
		next.minimum = Vector2i(mini(next.minimum.x,sample.x),mini(next.minimum.y,sample.y))
		next.maximum = Vector2i(maxi(next.maximum.x,sample.x),maxi(next.maximum.y,sample.y))
	if (pressed&0x800000) != 0:
		if int(next.phase) == 0:
			next.center = sample;next.minimum = sample;next.maximum = sample
		else:
			next.commit = true # Native4d1b8 copies all six captured values.
		next.phase = int(next.phase)+1
		if int(next.phase) == 2: next.back = true
	# Cancellation follows confirmation; it doesn't undo an already committed
	# calibration when both face buttons are pressed together.
	if (pressed&0x100000) != 0: next.back = true
	next.parent_page = 2;next.parent_selection = 0;next.parent_last_index = 2
	return next

static func normalize(center: Vector2i, minimum: Vector2i, maximum: Vector2i) -> Dictionary:
	# Native39188..39308 rejects any side shorter than32, replacing all
	# calibration globals with the original128/0/255 defaults.
	var accepted := true
	for axis in range(2):
		if maximum[axis]-minimum[axis] < 32 or center[axis]-minimum[axis] < 32 or maximum[axis]-center[axis] < 32:
			accepted = false
	if not accepted:
		center = Vector2i(128,128);minimum = Vector2i.ZERO;maximum = Vector2i(255,255)
	var low := center-minimum
	var high := maximum-center
	var radius := mini(mini(low.x,high.x),mini(low.y,high.y))
	return {"status":1 if accepted else -1,"center":center,"minimum":minimum,"maximum":maximum,"lower_midpoint":Vector2i(minimum.x+(low.x>>1),minimum.y+(low.y>>1)),"upper_midpoint":Vector2i(center.x+(high.x>>1),center.y+(high.y>>1)),"half_radius":radius>>1,"radius":radius-4}
