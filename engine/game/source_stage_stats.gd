extends RefCounted
const VM = preload("res://asl_vm.gd")
static func backdrop_level(state: Dictionary) -> int:
	return 0 if int(state.secret) != 0 else int(state.get("backdrop_phase",state.phase))&255
static func shared_texture_name(style: int) -> String:
	# Source25514..25574 writes gp2252, alias of absolute751ac.
	return "TK%02d_ENM.BIN"%(style&65535)
static func label_layout(data: Dictionary, busy: int) -> Dictionary:
	if not data.has("heading") or not data.has("continuePrompt") or not data.has("glyphs"):
		return {"fault":"Missing original stage-results label data"}
	var labels: Array = [data.heading,data.continuePrompt,{"text":"","y":0},{"text":"","y":0},{"text":"","y":0}]
	var adapted := {"labels":labels,"glyphs":data.glyphs,"centerX":256}
	var result := preload("res://source_menu_text.gd").layout(adapted,[65536,65536,65536,65536,65536],false)
	if not result.has("fault"): result.labels.resize(1 if busy != 0 else 2)
	return result
# Source53ef4..540d4, number sprite quads53c48: original pixel placements.
static func number_quads(state: Dictionary) -> Array:
	var quads: Array = []
	if int(state.kind) in [0,1]:
		quads.append({"digit":int(state.shown_rescues) if int(state.kind) == 0 else int(state.pickup_count),"x":100,"y":136,"width":18,"height":17})
	var bank := int(state.shown_bank)&0xffffffff
	var bank_x := 235
	var hundreds := int(bank/100)
	if hundreds != 0:
		quads.append({"digit":hundreds,"x":235,"y":136,"width":18,"height":17})
		quads.append({"digit":int((bank%100)/10),"x":253,"y":136,"width":18,"height":17})
		bank_x = 271
	elif int((bank%100)/10) != 0:
		quads.append({"digit":int((bank%100)/10),"x":bank_x,"y":136,"width":18,"height":17})
		bank_x += 18
	quads.append({"digit":bank%10,"x":bank_x,"y":136,"width":18,"height":17})
	var lives := int(state.shown_lives)&0xffffffff
	var lives_x := 332 if lives >= 10 else 350
	if int(lives/10) != 0:
		quads.append({"digit":int(lives/10),"x":lives_x,"y":136,"width":18,"height":17})
		lives_x += 18
	quads.append({"digit":lives%10,"x":lives_x,"y":136,"width":18,"height":17})
	return quads
static func number_layout(state: Dictionary) -> Dictionary:
	var glyphs: Array = []
	for quad in number_quads(state):
		# Source digit index directly selects the shared track atlas's sprite0..9.
		glyphs.append({"sprite":int(quad.digit),"position":Vector2(quad.x,quad.y),"size":Vector2(quad.width,quad.height)})
	return {"labels":[{"glyphs":glyphs}]}
static func icon_layout(state: Dictionary) -> Dictionary:
	var track: Array = []
	var shared: Array = []
	# Source540dc..5430c. The boss row uses separate shared texture751ac.
	if int(state.kind) == 0:
		track.append({"sprite":11,"position":Vector2(60,120),"size":Vector2(61,24)})
	elif int(state.kind) == 1:
		shared.append({"sprite":26,"position":Vector2(60,120),"size":Vector2(50,24)})
	track.append({"sprite":12,"position":Vector2(200,117),"size":Vector2(45,27)})
	track.append({"sprite":10,"position":Vector2(350,115),"size":Vector2(74,35)})
	return {"track":{"labels":[{"glyphs":track}]},"shared":{"labels":[{"glyphs":shared}]}}
static func advance(state: Dictionary, pressed: int, current_crystals: int) -> Dictionary:
	var next := state.duplicate(true)
	# Source53d28..53d68 draws the old phase before increment/confirm.
	next.backdrop_phase = int(state.phase)&255
	var events: Array = []
	if int(next.busy) == 0:
		if (int(next.phase)&0xffffffff) < 64:
			next.phase = VM.signed32(int(next.phase)+1)
		if (pressed&0x800200) != 0:
			next.busy = 1
			next.shown_bank = next.bank
			next.shown_crystals = 0
			current_crystals = 0
			next.shown_lives = VM.signed32(int(next.lives)-1) if int(next.lives) != 0 else 0
			events.append("confirm")
	if int(next.shown_crystals) != 0:
		if int(next.delay) != 0:
			next.delay = VM.signed32(int(next.delay)-1)
		else:
			next.shown_bank = VM.signed32(int(next.shown_bank)+1)
			if (int(next.shown_bank)&0xffffffff) >= 100:
				next.shown_bank = VM.signed32(int(next.shown_bank)-100)
				next.shown_lives = VM.signed32(int(next.shown_lives)+1)
				if (int(next.shown_lives)&0xffffffff) >= 100:
					next.shown_lives = 99
				elif int(next.busy) == 0:
					events.append("life")
			next.shown_crystals = VM.signed32(int(next.shown_crystals)-1)
			current_crystals = VM.signed32(current_crystals-1)
			next.delay = 2
			if int(next.busy) == 0:
				events.append("crystal")
	next.current_crystals = current_crystals
	next.events = events
	return next
# Numeric effects of0x800539c8..0x80053c28; presentation/music are separate.
static func initialize(index: int, crystals: int, rescues: int, bank: int, lives: int, pickup_slots: Array) -> Dictionary:
	if pickup_slots.size() != 8:
		return {"fault":"Missing source eight-slot stage pickup table"}
	var selected := index&0xffffffff
	var remainder := selected%10
	var secret := selected < 40 and remainder in [3,8]
	var kind := 3 if selected >= 40 else 2 if secret else 1 if remainder in [4,9] else 0
	var collected := 0
	for value in pickup_slots:
		collected += int(int(value) != 0)
	var total := VM.signed32(bank+crystals)&0xffffffff
	var awards := int(total/100)
	var updated_lives := lives&0xffffffff
	if awards > 0:
		updated_lives = (updated_lives+1)&0xffffffff
		if updated_lives >= 100:
			updated_lives = 99
		updated_lives = mini(99,updated_lives+awards-1)
	return {"delay":30,"kind":kind,"secret":int(secret),"pickup_count":collected,"shown_crystals":VM.signed32(crystals),"shown_rescues":VM.signed32(rescues),"shown_bank":VM.signed32(bank),"shown_lives":VM.signed32(lives-1) if lives != 0 else 0,"bank":total%100,"lives":VM.signed32(updated_lives),"phase":0,"busy":0,"active":1}
