extends RefCounted
var directory: String
func _init(save_directory: String="user://") -> void:directory=save_directory
func slot_path(index: int) -> String:
	return directory.path_join("source-save-%02d.bin"%index) if index>=0 and index<=99 else ""
func new_slot() -> Dictionary:
	var entries := list_slots()
	if entries.size()>=15:return {"full":true,"path":""}
	var maximum := 0 # Native gp1348 begins0, then increments for new file.
	for entry in entries:maximum=maxi(maximum,int(entry.slot))
	if maximum>=99:return {"fault":"Save filename suffix range exhausted"}
	return {"slot":maximum+1,"path":slot_path(maximum+1)}
func list_slots() -> Array:
	var result := []
	for index in range(100):
		var path := slot_path(index)
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".previous") and not FileAccess.file_exists(path+".pending"):continue
		var stored := preload("res://source_save_store.gd").new(path).read_record()
		if not stored.has("record"):
			result.append({"slot":index,"path":path,"fault":str(stored.get("fault","Missing saved record"))});continue
		var state := preload("res://source_campaign_save.gd").decode(stored.record)
		result.append({"slot":index,"path":path,"level":int(state.level),"room":int(state.room),"lives":int(state.lives),"percentage":int(state.percentage),"selection":int(state.selection),"copy":int(stored.copy)})
	return result
