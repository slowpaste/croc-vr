extends RefCounted
var path:="user://performance-history.jsonl"
var limit_bytes:=4*1024*1024
func append(status:Dictionary, events:Array) -> Error:
	var file:=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	if file.get_length()>=limit_bytes:
		file.close()
		var absolute:=ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path+".previous"):
			var removed:=DirAccess.remove_absolute(absolute+".previous")
			if removed!=OK:return removed
		var rotated:=DirAccess.rename_absolute(absolute,absolute+".previous")
		if rotated!=OK:return rotated
		file=FileAccess.open(path,FileAccess.WRITE)
		if file==null:return FileAccess.get_open_error()
	file.seek_end()
	var row:Dictionary={"timestamp":Time.get_unix_time_from_system(),"slow_events":events}
	for key in ["process_id","runtime_started_at","room","fps","source_main_mode","xr_gameplay_focused","draw_calls","render_objects","source_ticks","performance_cpu","performance_caches","performance_cinematic","source_inventory","source_gameplay_music","source_transition"]:
		if status.has(key):row[key]=status[key]
	file.store_line(JSON.stringify(row));file.close()
	return OK
