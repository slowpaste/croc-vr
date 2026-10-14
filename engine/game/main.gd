extends Node3D

const MISSING_DATA_MESSAGE := "Game data isn't imported."

# Shared player and camera setup used by the imported game.
var actor: CharacterBody3D
var visual: Node3D
var rig: XROrigin3D
var head: XRCamera3D
var camera: Camera3D
var left: XRController3D
var right: XRController3D
var hud: Label
var board: Label3D
var missing_data_label: Label
var xr_active := false
var yaw := 0.0
var snap_armed := true
var jump_held := false
var attack_held := false
var gems := 0
var pickups: Array[Node3D] = []
var checkpoint := Vector3(0, 1, 3)

func _ready() -> void:
	if not InputMap.has_action("source_select"):
		InputMap.add_action("source_select")
		var select_key := InputEventKey.new();select_key.physical_keycode=KEY_TAB
		InputMap.action_add_event("source_select",select_key)
	for pair in [["move_left", KEY_A], ["move_right", KEY_D], ["move_forward", KEY_W], ["move_back", KEY_S], ["jump", KEY_SPACE], ["attack", KEY_E], ["reset", KEY_R], ["turn_left", KEY_Q], ["turn_right", KEY_C], ["precision_move", KEY_SHIFT], ["turn_in_place", KEY_ALT]]:
		if InputMap.has_action(pair[0]):continue
		InputMap.add_action(pair[0])
		var key := InputEventKey.new()
		key.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], key)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	actor = CharacterBody3D.new()
	add_child(actor)
	actor.position = checkpoint
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.1
	collision.shape = capsule
	collision.position.y = 0.55
	actor.add_child(collision)
	visual = Node3D.new()
	actor.add_child(visual)
	rig = XROrigin3D.new()
	add_child(rig)
	head = XRCamera3D.new()
	rig.add_child(head)
	left = XRController3D.new()
	left.tracker = &"left_hand"
	rig.add_child(left)
	right = XRController3D.new()
	right.tracker = &"right_hand"
	rig.add_child(right)
	var xr := XRServer.find_interface("OpenXR")
	xr_active = xr != null and xr.is_initialized()
	get_viewport().use_xr = xr_active
	camera = Camera3D.new()
	add_child(camera)
	camera.current = not xr_active
	head.current = xr_active
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24,20)
	hud.add_theme_font_size_override("font_size",24)
	layer.add_child(hud)
	hud.visible = not xr_active
	missing_data_label = Label.new()
	layer.add_child(missing_data_label)
	missing_data_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	missing_data_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	missing_data_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	missing_data_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	missing_data_label.add_theme_font_size_override("font_size",32)
	missing_data_label.text = MISSING_DATA_MESSAGE
	missing_data_label.visible = not xr_active
	board = Label3D.new()
	board.font_size = 32
	board.pixel_size = 0.008
	board.no_depth_test = true
	board.text = MISSING_DATA_MESSAGE
	head.add_child(board)
	board.position = Vector3(0,0,-3)
	board.visible = xr_active
	update_camera()

func hide_missing_data_message() -> void:
	missing_data_label.hide()
	board.hide()
	# Restore the imported game's existing background.
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.background_color = Color("a3ceda")

func update_camera() -> void:
	# Seated spectator rig follows horizontal motion only; jumps never bob the HMD.
	var anchor := Vector3(actor.position.x, 0, actor.position.z)
	var offset := Basis(Vector3.UP,yaw) * Vector3(0,0,5)
	rig.position = anchor + offset + Vector3(0,0.5,0)
	rig.rotation.y = yaw
	camera.position = anchor + offset + Vector3(0,3.3,0)
	camera.look_at(anchor + Vector3(0,0.7,-2),Vector3.UP)

func _physics_process(_delta: float) -> void:
	pass
