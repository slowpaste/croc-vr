extends SceneTree
func _initialize() -> void:
	var directory := "user://save-slots-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	assert(slots.list_slots().is_empty() and slots.slot_path(-1)=="" and slots.slot_path(100)=="")
	assert(slots.new_slot().slot==1)
	var capture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../reference/original-campaign-save.json")))
	for index in range(2):
		var record := PackedByteArray();record.resize(256)
		for word in range(64):record.encode_u32(word*4,int(capture.rows[index].words[word]))
		assert(preload("res://source_save_store.gd").new(slots.slot_path(3 if index==0 else 9)).write_copies(record+record).written)
	var file := FileAccess.open(slots.slot_path(7),FileAccess.WRITE);file.store_buffer(PackedByteArray([1,2,3]));file.close()
	var listed: Array=slots.list_slots()
	assert(listed.size()==3 and listed[0].slot==3 and listed[1].slot==7 and listed[2].slot==9)
	assert(listed[0].percentage==13 and listed[2].percentage==100 and listed[1].has("fault"))
	assert(slots.new_slot().slot==10)
	# Interrupted transaction is recovered during enumeration.
	assert(DirAccess.rename_absolute(slots.slot_path(9),slots.slot_path(9)+".previous")==OK)
	assert(slots.list_slots()[2].percentage==100 and FileAccess.file_exists(slots.slot_path(9)))
	for index in [3,7,9]:assert(DirAccess.remove_absolute(slots.slot_path(index))==OK)
	assert(DirAccess.remove_absolute(directory)==OK)
	print("PASS: ordered multi-slot saved progress listing, corrupt-entry reporting and interrupted-slot recovery")
	quit(0)
