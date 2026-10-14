extends RefCounted
static func initialize() -> Dictionary:
	var slots: Array = []
	for index in range(30):
		slots.append({"active":0,"x":0,"y":0,"size":0,"shrinking":0,"sprite":0})
	return {"phase":0,"allocated":0,"burst":0,"slots":slots}
# Shared effect488b8..48ec4; projected trail quads are returned for later drawing.
static func advance(state: Dictionary, logo_depth: int, random_source: RefCounted) -> Dictionary:
	var next := state.duplicate(true)
	var quads: Array = []
	for slot in next.slots:
		if int(slot.active) == 0:
			continue
		var height := int(slot.size)&65535
		var width := int(height*16/10)
		quads.append({"sprite":196+int(slot.sprite),"position":Vector2i(int(slot.x)-(width>>1),int(slot.y)-(height>>1)),"size":Vector2i(width,height)})
		if int(slot.shrinking) == 0:
			if height == 20:
				slot.shrinking = 1
			else:
				slot.size = (height+2)&65535
		elif height != 0:
			slot.size = (height-2)&65535
		else:
			slot.active = 0
	if logo_depth >= 1289 and int(next.phase) == 0:
		next.phase = 1 # Main13df4..13e0c, before effect rendering.
	next.render_phase = next.phase
	# Central reveal488aa4..48e24. Source modifies right U by width, not width-1.
	var central: Array = []
	if int(next.render_phase) != 0:
		var first_width := mini(int(next.render_phase)*8,128)
		central.append({"sprite":188,"position":Vector2i(210,130),"size":Vector2i(first_width,16),"source_u_span":first_width})
		if (int(next.render_phase)&0xffffffff) >= 16:
			var second_width := mini((int(next.render_phase)-16)*8,128)
			central.append({"sprite":189,"position":Vector2i(338,130),"size":Vector2i(second_width,16),"source_u_span":second_width})
	next.central = central
	if int(next.phase) != 0 and (int(next.phase)&0xffffffff) < 32:
		next.phase = int(next.phase)+1
		var chance: int = random_source.bios_rand()%100
		if chance < 35 or int(next.burst) == 0:
			next.burst = 2
			if int(next.allocated) != 30:
				for slot in next.slots:
					if int(slot.active) == 0:
						slot.active = 1
						slot.x = (210+int(next.phase)*8)&65535
						slot.y = (random_source.bios_rand()&7)+132
						slot.size = 2
						slot.shrinking = 0
						slot.sprite = random_source.bios_rand()%6
						next.allocated = int(next.allocated)+1
						break
			next.burst = int(next.burst)-1
		else:
			next.burst = int(next.burst)-1
	next.quads = quads
	return next
