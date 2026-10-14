extends RefCounted
var clock := preload("res://source_cd_sector_clock.gd").new()
var first_delay := 0
var first_pending := true
var paused := false
func begin(prefilled_sectors: int, first_sector_after_us: int) -> bool:
	if prefilled_sectors < 0 or first_sector_after_us < 0: return false
	clock.begin(prefilled_sectors,192) # Native22ff0 Setmode byte0xc0, double speed.
	first_delay = first_sector_after_us
	first_pending = true
	paused = false
	return true
func advance(microseconds: int) -> Dictionary:
	if microseconds < 0: return {"fault":"Negative cutscene interval"}
	if paused: return {"processed_sectors":clock.cursor,"sectors":0}
	var elapsed := microseconds
	var first := 0
	if first_pending:
		if elapsed < first_delay:
			first_delay -= elapsed
			return {"processed_sectors":clock.cursor,"sectors":0}
		elapsed -= first_delay
		first_delay = 0
		first_pending = false
		clock.cursor += 1
		first = 1
	var result := clock.advance(elapsed)
	return {"processed_sectors":int(result.cursor),"sectors":int(result.sectors)+first}
func available_audio_frames(record: Dictionary) -> int:
	if not record.has_all(["firstSector","sectors"]) or int(clock.cursor) <= int(record.firstSector): return 0
	var sectors := mini(int(record.sectors),int((int(clock.cursor)-1-int(record.firstSector))/8)+1)
	return sectors*2016
