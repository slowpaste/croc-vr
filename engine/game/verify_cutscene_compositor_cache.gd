extends SceneTree
func _initialize() -> void:
	call_deferred("run_check")
func run_check() -> void:
	root.add_child(preload("res://probe_sad_cache.gd").new())
