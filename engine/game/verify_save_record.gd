extends SceneTree
const Save = preload("res://source_save_record.gd")
func _initialize() -> void:
	var path := ProjectSettings.globalize_path("res://../reference/original-options-save-patch.json")
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(capture.executableSha256=="f2a62a1e9741bbfa3c0186a878caefbaea72aa12dc2936f709bbefc2256a6996")
	var values := [[0,127,80,1,128,128,0,0,255,255,0,0],[2,119,0,2,96,144,8,16,192,240,-8,24]]
	for row in range(2):
		var prior := PackedByteArray();prior.resize(256)
		for word in range(64):prior.encode_u32(word*4,0x10203000+word*257)
		var settings := {}
		for key in range(Save.SETTINGS_KEYS.size()):settings[Save.SETTINGS_KEYS[key]]=values[row][key]
		var patched := Save.patch_options(prior,settings)
		assert(not patched.has("fault") and Save.valid(patched.record))
		for word in range(64):
			assert(patched.record.decode_u32(word*4)==int(capture.rows[row].words[word]),"Native mismatch at word "+str(word))
			if word not in Save.SETTINGS_WORDS and word!=63:assert(patched.record.decode_u32(word*4)==prior.decode_u32(word*4))
		assert(Save.select_copy(patched.copies).copy==0)
		var corrupted: PackedByteArray=patched.copies.duplicate();corrupted[12]^=1
		assert(Save.select_copy(corrupted).copy==1)
		corrupted[268]^=1;assert(Save.select_copy(corrupted).has("fault"))
	assert(Save.patch_options(PackedByteArray(),{}).has("fault"))
	assert(Save.select_copy(PackedByteArray()).has("fault"))
	var fresh := Save.new_record()
	assert(Save.valid(fresh) and fresh.decode_u32(12)==10 and fresh.decode_u32(28)==3)
	print("PASS: native options save patch/checksum parity, campaign words preserved, duplicate-copy recovery and original new-file defaults")
	quit(0)
