extends RefCounted
const Player = preload("res://source_cutscene_player.gd")
var clock := preload("res://source_cutscene_clock.gd").new()
var player: Node3D = null
var audio_record: Dictionary = {}
var active := false
func begin(target: Node3D, audio: Dictionary, prefilled_sectors: int, first_sector_after_us: int) -> bool:
	if target == null or not target is Player or target.availability.is_empty() or target.complete: return false
	if not audio.has_all(["firstSector","sectors"]) or not clock.begin(prefilled_sectors,first_sector_after_us): return false
	player = target
	audio_record = audio.duplicate(true)
	active = true
	return true
func advance(microseconds: int, held: int, budget: int) -> Dictionary:
	if not active: return {"fault":"Cutscene timeline is not active"}
	if budget < 1 or budget > 64 or microseconds < 0: return {"fault":"Invalid cutscene timeline advance"}
	if player.complete: return {"paused":clock.paused,"presented":[],"complete":true,"audio_frames":clock.available_audio_frames(audio_record),"processed_sectors":clock.clock.cursor}
	var elapsed := clock.advance(microseconds)
	if clock.paused: return {"paused":true,"presented":[],"complete":player.complete,"audio_frames":clock.available_audio_frames(audio_record)}
	var presented: Array = []
	for index in range(budget):
		var result: Dictionary = player.present_next(int(elapsed.processed_sectors),held)
		if result.has("fault"): return result
		if bool(result.get("waiting",false)): break
		if result.has("index"): presented.append(int(result.index))
		if result.complete: break
	return {"paused":false,"presented":presented,"complete":player.complete,"audio_frames":clock.available_audio_frames(audio_record),"processed_sectors":int(elapsed.processed_sectors)}
