extends SceneTree
const Campaign=preload("res://source_campaign_save.gd")
func _initialize() -> void:
	var capture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../reference/original-campaign-save.json")))
	assert(capture.executableSha256=="f2a62a1e9741bbfa3c0186a878caefbaea72aa12dc2936f709bbefc2256a6996")
	var settings := {"scheme":2,"effects":119,"music":40,"mode":0,"center_x":96,"center_y":128,"minimum_x":0,"minimum_y":0,"maximum_x":192,"maximum_y":255,"screen_x":-8,"screen_y":24}
	for case in range(1,3):
		var flags := [];var pickups := [];var history := []
		for index in range(46):flags.append(0x8000 if case==2 or index in [0,4,43,45] else 0)
		for index in range(8):pickups.append(1 if case==2 or index in [0,3,7] else 0);history.append(index+case)
		var prior := PackedByteArray();prior.resize(256)
		var encoded := Campaign.encode(prior,settings,{"level":27 if case==1 else 54,"selection":12 if case==1 else 44,"room":23,"lives":27,"flags":flags,"pickups":pickups,"announcement_history":history})
		assert(not encoded.has("fault"))
		for word in range(64):assert(encoded.record.decode_u32(word*4)==int(capture.rows[case-1].words[word]),"Native campaign save mismatch at word "+str(word))
		assert(encoded.record.decode_u32(24)==(13 if case==1 else 100))
		var decoded := Campaign.decode(encoded.record)
		assert(decoded.level==(27 if case==1 else 54) and decoded.room==23 and decoded.selection==(12 if case==1 else 44) and decoded.lives==27)
		assert(decoded.flags==flags and decoded.announcement_history==history and decoded.settings==settings)
		for index in range(8):assert(decoded.pickups[index]==((0x80>>index) if pickups[index]!=0 else 0))
		var roundtrip := Campaign.encode(encoded.record,decoded.settings,decoded)
		assert(roundtrip.record==encoded.record)
		var damaged: PackedByteArray=encoded.record.duplicate();damaged[16]^=1
		assert(Campaign.decode(damaged).has("fault"))
	assert(Campaign.encode(PackedByteArray(),{},{}).has("fault"))
	print("PASS: all64 campaign save words match original partial/complete fixtures, including native percentage, pickup bit order and history")
	quit(0)
