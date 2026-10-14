extends RefCounted
const Record = preload("res://source_save_record.gd")
var path: String
func _init(record_path: String) -> void:path=record_path

func read_record() -> Dictionary:
	var recovery := recover()
	if recovery.has("fault"):return recovery
	return read_path(path)

func read_path(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate):return {"missing":true}
	var file := FileAccess.open(candidate,FileAccess.READ)
	if file==null:return {"fault":"Cannot read saved record"}
	var bytes := file.get_buffer(file.get_length());file.close()
	return Record.select_copy(bytes)

func recover() -> Dictionary:
	var staging := path+".pending"
	var backup := path+".previous"
	if not FileAccess.file_exists(staging) and not FileAccess.file_exists(backup):return {}
	var current := read_path(path)
	if current.has("record"):
		# The committed name is authoritative once it contains a valid copy.
		for extra in [staging,backup]:
			if FileAccess.file_exists(extra) and DirAccess.remove_absolute(extra)!=OK:return {"fault":"Cannot finish saved-record recovery"}
		return {"recovered":"committed"}
	if current.has("fault"):
		# Preserve a damaged committed file for diagnosis instead of replacing it.
		return {"fault":"Damaged committed save retained during recovery"}
	if FileAccess.file_exists(backup):
		var previous := read_path(backup)
		if not previous.has("record"):return {"fault":"Cannot validate previous saved record"}
		if DirAccess.rename_absolute(backup,path)!=OK:return {"fault":"Cannot restore previous saved record"}
		if FileAccess.file_exists(staging) and DirAccess.remove_absolute(staging)!=OK:return {"fault":"Previous save restored; staging cleanup failed"}
		return {"recovered":"previous"}
	var pending := read_path(staging)
	if not pending.has("record"):return {"fault":"Incomplete first saved record retained"}
	if DirAccess.rename_absolute(staging,path)!=OK:return {"fault":"Cannot recover first saved record"}
	return {"recovered":"first"}

func write_options(settings: Dictionary) -> Dictionary:
	var prior := read_record()
	if prior.has("fault"):return prior # Never replace unverified campaign bytes.
	var record: PackedByteArray=Record.new_record() if prior.has("missing") else prior.record
	var patched := Record.patch_options(record,settings)
	if patched.has("fault"):return patched
	return write_copies(patched.copies)
func delete_slot() -> Dictionary:
	var removed := false
	# Explicit confirmed slot deletion includes its own interrupted transaction.
	for candidate in [path,path+".previous",path+".pending"]:
		if FileAccess.file_exists(candidate):
			if DirAccess.remove_absolute(candidate)!=OK:return {"fault":"Cannot remove saved slot","partially_deleted":removed}
			removed=true
	return {"deleted":true} if removed else {"fault":"Saved slot no longer exists"}

func write_copies(copies: PackedByteArray) -> Dictionary:
	if copies.size()!=512 or not Record.valid(copies.slice(0,256)) or copies.slice(0,256)!=copies.slice(256,512):
		return {"fault":"Save write requires identical valid original copies"}
	var recovery := recover()
	if recovery.has("fault"):return recovery
	var directory := path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return {"fault":"Cannot create save directory"}
	var staging := path+".pending"
	var backup := path+".previous"
	# An unresolved earlier transaction requires recovery before another write.
	if FileAccess.file_exists(staging) or FileAccess.file_exists(backup):return {"fault":"Unresolved save transaction"}
	var file := FileAccess.open(staging,FileAccess.WRITE)
	if file==null:return {"fault":"Cannot stage saved record"}
	file.store_buffer(copies);file.flush()
	var error := file.get_error();file.close()
	if error!=OK or FileAccess.get_file_as_bytes(staging)!=copies:
		DirAccess.remove_absolute(staging);return {"fault":"Saved record staging failed"}
	var existed := FileAccess.file_exists(path)
	if existed and DirAccess.rename_absolute(path,backup)!=OK:
		DirAccess.remove_absolute(staging);return {"fault":"Cannot retain prior saved record"}
	if DirAccess.rename_absolute(staging,path)!=OK:
		if existed:DirAccess.rename_absolute(backup,path)
		DirAccess.remove_absolute(staging);return {"fault":"Cannot commit saved record"}
	if existed and DirAccess.remove_absolute(backup)!=OK:return {"fault":"Saved record committed; prior copy cleanup failed","committed":true}
	return {"written":true}
