extends Node3D
signal finished
var player := preload("res://source_spu_voice_player.gd").new()
func _init() -> void:
	add_child(player)
	player.pcm_completed.connect(_on_completed)
func start_voice(wav: AudioStreamWAV, left: int, right: int, pitch: int) -> bool:
	return player.start_pcm(wav,left,right,true,pitch)
func set_channels(left: int, right: int) -> void: player.set_channels(left,right)
func set_source_pitch(pitch: int) -> bool: return player.set_source_pitch(pitch)
func stop_voice() -> void: player.stop_pcm()
func _on_completed() -> void: finished.emit()
func _exit_tree() -> void: stop_voice()
