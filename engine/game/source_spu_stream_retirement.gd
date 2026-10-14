extends Node
# Playback mixes asynchronously and retains a raw pointer to its generator.
# Keep the resource alive until AudioServer releases the playback itself.
var pending: Array[Dictionary] = []
static func owner(tree: SceneTree) -> Node:
	var existing := tree.root.get_node_or_null("SourceSpuStreamRetirement")
	if existing != null: return existing
	var service := preload("res://source_spu_stream_retirement.gd").new()
	service.name = "SourceSpuStreamRetirement"
	service.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(service)
	return service
func retain(generator: AudioStream, playback: AudioStreamPlayback) -> void:
	pending.append({"generator":generator,"playback":weakref(playback)})
static func drain(tree: SceneTree, timeout_ms: int = 2000) -> bool:
	var service := tree.root.get_node_or_null("SourceSpuStreamRetirement")
	if service == null: return true
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not service.pending.is_empty() and Time.get_ticks_msec() < deadline: await tree.process_frame
	return service.pending.is_empty()
func _process(_delta: float) -> void:
	for index in range(pending.size()-1,-1,-1):
		if pending[index].playback.get_ref() == null: pending.remove_at(index)
