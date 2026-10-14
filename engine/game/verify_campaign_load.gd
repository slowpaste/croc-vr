extends SceneTree
func _initialize() -> void:
	var capture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../reference/original-campaign-save.json")))
	for index in range(2):
		var record := PackedByteArray();record.resize(256)
		for word in range(64):record.encode_u32(word*4,int(capture.rows[index].words[word]))
		var prepared := preload("res://source_campaign_load.gd").prepare(record)
		assert(not prepared.has("fault") and prepared.room==0 and prepared.return_mode==5 and prepared.return_flag==1)
		assert(prepared.level==(27 if index==0 else 54) and prepared.lives==27)
		assert(prepared.pickups==([128,0,0,0,0,0,0,0] if index==0 else [128,64,32,16,8,4,2,1]))
		var stored := preload("res://source_campaign_save.gd").decode(record)
		assert(stored.room==23 and stored.flags==prepared.flags and stored.announcement_history==prepared.announcement_history)
		record[12]^=1;assert(preload("res://source_campaign_load.gd").prepare(record).has("fault"))
	print("PASS: source-derived Load return resets room, prunes incomplete-stage pickups and retains campaign/settings; bad checksum rejected")
	quit(0)
