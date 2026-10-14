extends RefCounted
# Only Quest's isolated private build includes the bundle index/data assets.
const INDEX="res://bundled-content/index.json"
var state_lock:=Mutex.new()
var progress:=0.0
var fault:=""
func status() -> Dictionary:
	state_lock.lock();var value:={"progress":progress,"fault":fault};state_lock.unlock();return value
func set_status(value: float, error: String="") -> void:
	state_lock.lock();progress=value;fault=error;state_lock.unlock()
func read_index(index_path: String=INDEX) -> Dictionary:
	var data=JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not data is Dictionary or int(data.get("schema",0))!=1 or data.get("packs",[]).is_empty():return {}
	for pack in data.packs:
		if str(pack.file).get_file()!=str(pack.file) or not str(pack.file).ends_with(".pck") or str(pack.archive).get_file()!=str(pack.archive):return {}
		if str(pack.sha256).length()!=64 or int(pack.bytes)<=0:return {}
	return data
func cached_path(pack: Dictionary) -> String:
	return "user://bundled-import/"+str(pack.sha256)+".pck"
func prepare_archives(index: Dictionary, archive_root: String="res://bundled-content") -> bool:
	for pack in index.packs:
		if not ProjectSettings.load_resource_pack(archive_root.path_join(str(pack.archive)),false):return false
	return true
func install(index: Dictionary) -> bool:
	var directory:=ProjectSettings.globalize_path("user://bundled-import")
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:set_status(0,"Cannot create the game data folder.");return false
	var total:=0.0;var completed:=0.0
	for pack in index.packs:total+=float(pack.bytes)
	for pack in index.packs:
		var destination:=cached_path(pack)
		# Hash-addressed files plus an atomic verified marker avoid a full reread
		# on every launch. An interrupted install never creates the marker.
		if FileAccess.file_exists(destination+".verified") and FileAccess.file_exists(destination):
			var existing:=FileAccess.open(destination,FileAccess.READ)
			if existing!=null and existing.get_length()==int(pack.bytes):
				completed+=float(pack.bytes);set_status(completed/total);continue
		var source:=FileAccess.open("res://"+str(pack.file),FileAccess.READ)
		var output:=FileAccess.open(destination+".part",FileAccess.WRITE)
		if source==null or output==null:set_status(completed/total,"Cannot prepare the included game data. Check free headset storage.");return false
		var hash_context:=HashingContext.new();hash_context.start(HashingContext.HASH_SHA256)
		var written:=0
		while written<int(pack.bytes):
			var block:=source.get_buffer(mini(1024*1024,int(pack.bytes)-written))
			if block.is_empty() or not output.store_buffer(block):set_status(completed/total,"Game data preparation was interrupted. Check free headset storage and relaunch.");return false
			hash_context.update(block);written+=block.size();set_status((completed+written)/total)
		output.flush();output.close();source.close()
		if hash_context.finish().hex_encode()!=str(pack.sha256):set_status(completed/total,"Included game data failed verification.");return false
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(destination+".part"),ProjectSettings.globalize_path(destination))!=OK:set_status(completed/total,"Cannot finish preparing the game data.");return false
		var marker:=FileAccess.open(destination+".verified",FileAccess.WRITE)
		if marker==null:set_status(completed/total,"Cannot save game data verification.");return false
		marker.store_string(str(pack.sha256));marker.close()
		completed+=float(pack.bytes)
	set_status(1);return true
func mount(index: Dictionary) -> bool:
	for pack in index.packs:
		if not ProjectSettings.load_resource_pack(cached_path(pack),false):return false
	return FileAccess.file_exists("res://imported_data/manifest.json")
