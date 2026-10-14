extends SceneTree
const Delete=preload("res://source_delete_session.gd")
func _initialize() -> void:
	var state := Delete.initialize([{"path":"a"},{"path":"b"}])
	assert(state.navigation.selected==1)
	state=Delete.advance(state,0,0x10000);state=Delete.advance(state,0,0x800000)
	assert(state.overwrite and state.navigation.selected==1 and state.pending_path=="")
	state=Delete.advance(state,0,0x80000);assert(state.slot==0)
	state=Delete.advance(state,0,0x800000);assert(not state.overwrite and state.navigation.selected==1)
	state=Delete.advance(state,0,0x10000);state=Delete.advance(state,0,0x800000)
	state=Delete.advance(state,0,0x10000);state=Delete.advance(state,0,0x800000)
	assert(state.pending_path=="a")
	assert(Delete.advance(Delete.initialize([]),0,0x800000).exit_requested)
	var path := "user://delete-slot-test-"+str(OS.get_process_id())+".bin"
	assert(not FileAccess.file_exists(path))
	for suffix in ["",".previous",".pending"]:
		var file := FileAccess.open(path+suffix,FileAccess.WRITE);file.store_buffer(PackedByteArray([1,2,3]));file.close()
	var other := FileAccess.open(path+".other",FileAccess.WRITE);other.store_buffer(PackedByteArray([4,5]));other.close()
	assert(preload("res://source_save_store.gd").new(path).delete_slot().deleted)
	for suffix in ["",".previous",".pending"]:assert(not FileAccess.file_exists(path+suffix))
	assert(FileAccess.get_file_as_bytes(path+".other")==PackedByteArray([4,5]))
	assert(DirAccess.remove_absolute(path+".other")==OK)
	print("PASS: Delete defaults Return/NO, confirmation locks selected slot, approval requests deletion and only selected transaction files removed")
	quit(0)
