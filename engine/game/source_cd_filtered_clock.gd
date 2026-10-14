extends RefCounted
const Clock = preload("res://source_cd_sector_clock.gd")
const VM = preload("res://asl_vm.gd")
var clock := Clock.new()
var origin := 0
var elapsed_sectors := 0
var next_callback := 0
var initialized := false
func begin(position: int, mode: int, first_callback_after_sectors: int) -> bool:
	if first_callback_after_sectors < 0: return false
	clock.begin(position,mode)
	origin = VM.signed32(position)
	elapsed_sectors = 0
	next_callback = first_callback_after_sectors
	initialized = true
	return true
func advance(microseconds: int, callback_limit: int = 4) -> Dictionary:
	if not initialized or callback_limit < 1 or callback_limit > 64:
		return {"fault":"Missing filtered clock phase or invalid callback budget"}
	var advanced := clock.advance(microseconds)
	if advanced.has("fault"): return advanced
	var callbacks: Array[int] = []
	if clock.reading:
		elapsed_sectors += int(advanced.sectors)
		while next_callback <= elapsed_sectors and callbacks.size() < callback_limit:
			callbacks.append(VM.signed32(origin+next_callback))
			next_callback += 8 # Source gp1804 initialized8; original XA interleave.
	return {"cursor":clock.cursor,"callbacks":callbacks,"pending":clock.reading and next_callback <= elapsed_sectors}
