extends Node
const Player = preload("res://source_xa_stream_player.gd")
const Zigzag = preload("res://source_xa_zigzag.gd")
func _ready() -> void:
	call_deferred("profile")
func quit(code: int) -> void:
	get_tree().quit(code)
func profile() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var record: Dictionary = index.streams[0]
	var player := Player.new()
	add_child(player)
	var filter := Zigzag.new()
	var initial := filter.snapshot()
	filter = null
	player.set_cd_mix([127,127,0,0])
	var threaded := args.has("--threaded")
	if not player.start_stream(content,record,int(record.sourceLba),[[0,0],[0,0]],initial,threaded): quit(1); return
	if threaded: await get_tree().create_timer(0.05).timeout
	var warmup := player.pump(4)
	if warmup.has("fault"): push_error(str(warmup)); quit(1); return
	var initial_skips := player.playback.get_skips()
	var durations: Array[int] = []
	var decoded := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec()-start < 5000000:
		var before := Time.get_ticks_usec()
		var result := player.pump(1)
		durations.append(Time.get_ticks_usec()-before)
		if result.has("fault"): push_error(str(result)); quit(1); return
		decoded += int(result.decoded_sectors)
		await get_tree().process_frame
	var skips := player.playback.get_skips()-initial_skips
	durations.sort()
	var total := 0
	for duration in durations: total += duration
	print("XA_STREAM_PROFILE: threaded=",threaded," seconds=5 callbacks=",durations.size()," decoded_sectors=",decoded," mean_callback_us=",float(total)/durations.size()," p95_callback_us=",durations[int(durations.size()*0.95)]," max_callback_us=",durations.back()," generator_skips=",skips," queued_frames=",player.queued_frames)
	player.stop_stream()
	await get_tree().create_timer(0.05).timeout
	player.queue_free()
	await get_tree().process_frame
	quit(0 if decoded > 30 else 1)
