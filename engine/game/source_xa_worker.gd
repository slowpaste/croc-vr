extends RefCounted
const Reader = preload("res://source_xa_channel_reader.gd")
const Zigzag = preload("res://source_xa_zigzag.gd")
const CAPACITY := 3
var thread: Thread = null
var mutex := Mutex.new()
var slots: Semaphore = null
var queue: Array[Dictionary] = []
var stopping := false
func start(content: String, record: Dictionary, sector: int, history: Array, filter_state: Dictionary = {}) -> Error:
	if not Reader.valid_history(history): return ERR_INVALID_PARAMETER
	if not filter_state.is_empty() and (int(record.get("sampleRate",0)) != 37800 or not Zigzag.valid_snapshot(filter_state)): return ERR_INVALID_PARAMETER
	stop()
	stopping = false
	slots = Semaphore.new()
	for slot in range(CAPACITY): slots.post()
	thread = Thread.new()
	var error := thread.start(_run.bind(content,record.duplicate(true),sector,history.duplicate(true),filter_state.duplicate(true)))
	if error != OK: thread = null
	return error
func queued() -> int:
	mutex.lock()
	var size := queue.size()
	mutex.unlock()
	return size
func snapshot_packets() -> Array:
	mutex.lock()
	var packets := queue.duplicate(true)
	mutex.unlock()
	return packets
func take() -> Dictionary:
	mutex.lock()
	var result: Dictionary = {} if queue.is_empty() else queue.pop_front()
	mutex.unlock()
	if not result.is_empty(): slots.post()
	return result
func stop() -> void:
	if thread != null:
		mutex.lock()
		stopping = true
		mutex.unlock()
		slots.post() # Wake a producer suspended on a full queue before joining.
		thread.wait_to_finish()
		thread = null
	mutex.lock()
	queue.clear()
	mutex.unlock()
	slots = null
func _publish(result: Dictionary) -> bool:
	mutex.lock()
	var accepted := not stopping
	if accepted: queue.append(result)
	mutex.unlock()
	return accepted
func _run(content: String, record: Dictionary, sector: int, history: Array, filter_state: Dictionary) -> void:
	# FileAccess, decoder and rings belong solely to this thread. Scene/audio
	# server objects are never touched here; immutable packets cross the queue.
	var reader := Reader.new()
	var filter: RefCounted = null
	if not filter_state.is_empty():
		filter = Zigzag.new()
		filter.restore(filter_state)
	if not reader.open_channel(content,record) or reader.seek_sector(sector,history).has("fault"):
		_publish({"fault":"XA worker could not open/seek source channel"})
		reader.close_channel()
		return
	while true:
		slots.wait()
		mutex.lock()
		var should_stop := stopping
		mutex.unlock()
		if should_stop: break
		var result := reader.read_sector()
		if not result.has("fault") and not bool(result.get("end",false)):
			result.predictor_history = reader.history_snapshot()
		if not result.has("fault") and not bool(result.get("end",false)) and filter != null:
			var source_sector := int(result.source_sector)
			var predictor_history: Array = result.predictor_history
			result = filter.process_pcm(result.pcm,int(result.rate))
			result.source_sector = source_sector
			result.predictor_history = predictor_history
			result.interpolation_state = filter.snapshot()
		if not _publish(result): break
		if result.has("fault") or bool(result.get("end",false)): break
	reader.close_channel()
