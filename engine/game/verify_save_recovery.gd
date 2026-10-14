extends SceneTree
const Record=preload("res://source_save_record.gd")
const Store=preload("res://source_save_store.gd")
func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE);assert(file!=null)
	file.store_buffer(bytes);file.close()
func _initialize() -> void:
	var path := "user://save-recovery-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())+".bin"
	var old := Record.new_record();old.encode_u32(12,27);old.encode_u32(252,Record.checksum(old))
	var newer := old.duplicate();newer.encode_u32(12,54);newer.encode_u32(252,Record.checksum(newer))
	# Crash before retaining the old file: preserve committed progress.
	write_bytes(path,old+old);write_bytes(path+".pending",newer+newer)
	assert(Store.new(path).read_record().record==old and not FileAccess.file_exists(path+".pending"))
	# Crash between the two renames: restore the prior committed file.
	assert(DirAccess.rename_absolute(path,path+".previous")==OK)
	write_bytes(path+".pending",newer+newer)
	assert(Store.new(path).read_record().record==old)
	assert(not FileAccess.file_exists(path+".previous") and not FileAccess.file_exists(path+".pending"))
	# Crash after commit: retain new progress, remove the prior file.
	write_bytes(path,newer+newer);write_bytes(path+".previous",old+old)
	assert(Store.new(path).read_record().record==newer and not FileAccess.file_exists(path+".previous"))
	assert(DirAccess.remove_absolute(path)==OK)
	# Interrupted first save can finish only from a validated record.
	write_bytes(path+".pending",newer+newer)
	assert(Store.new(path).read_record().record==newer)
	assert(DirAccess.remove_absolute(path)==OK)
	var truncated := PackedByteArray([1,2,3]);write_bytes(path+".pending",truncated)
	assert(Store.new(path).read_record().has("fault") and FileAccess.get_file_as_bytes(path+".pending")==truncated)
	assert(DirAccess.remove_absolute(path+".pending")==OK)
	# A damaged committed file is retained along with the recoverable backup.
	write_bytes(path,truncated);write_bytes(path+".previous",old+old)
	assert(Store.new(path).read_record().has("fault"))
	assert(FileAccess.get_file_as_bytes(path)==truncated and FileAccess.get_file_as_bytes(path+".previous")==old+old)
	assert(DirAccess.remove_absolute(path)==OK and DirAccess.remove_absolute(path+".previous")==OK)
	print("PASS: restart recovery before/between/after save renames, validated first-save commit and damaged-file preservation")
	quit(0)
