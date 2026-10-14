extends SceneTree
const Record=preload("res://source_save_record.gd")
const Store=preload("res://source_save_store.gd")
func _initialize() -> void:
	var path := "user://save-store-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())+".bin"
	var settings := {}
	var values := [2,119,80,2,96,144,8,16,192,240,-8,24]
	for index in range(Record.SETTINGS_KEYS.size()):settings[Record.SETTINGS_KEYS[index]]=values[index]
	var store=Store.new(path)
	assert(store.read_record().has("missing"))
	assert(store.write_options(settings).written)
	var restarted=Store.new(path)
	var record: PackedByteArray=restarted.read_record().record
	assert(Record.options(record)==settings and record.decode_u32(12)==10 and record.decode_u32(28)==3)
	# A progressed prior record survives a settings-only write byte for byte.
	record.encode_u32(12,54);record.encode_u32(28,27);record.encode_u16(32,0x8000);record.encode_u32(252,Record.checksum(record))
	assert(store.write_copies(record+record).written)
	settings.music=0;settings.screen_x=24
	assert(restarted.write_options(settings).written)
	var changed: PackedByteArray=Store.new(path).read_record().record
	for word in range(63):
		if word not in Record.SETTINGS_WORDS:assert(changed.decode_u32(word*4)==record.decode_u32(word*4))
	assert(Record.options(changed)==settings)
	var corrupt := changed+changed;corrupt[12]^=1
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(corrupt);file.close()
	assert(store.read_record().copy==1)
	corrupt[268]^=1;file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(corrupt);file.close()
	assert(store.write_options(settings).has("fault") and FileAccess.get_file_as_bytes(path)==corrupt)
	assert(DirAccess.remove_absolute(path)==OK)
	print("PASS: real saved-record restart, settings-only campaign preservation, duplicate recovery and corrupt-save refusal")
	quit(0)
