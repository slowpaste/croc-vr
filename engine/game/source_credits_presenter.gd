extends Node3D
var state: Dictionary = {}
var fonts: Dictionary = {}
var atlas: Dictionary = {}
var texture: Texture2D
var text := preload("res://source_menu_text_renderer.gd").new()
var fault := ""
func _init() -> void: add_child(text)
func setup(content: String, manifest: Dictionary, variant: int) -> bool:
	var descriptor: Dictionary = {}
	for entry in manifest.get("credits",[]):
		if int(entry.variant) == variant: descriptor = entry; break
	if descriptor.is_empty() or not manifest.has("creditsFonts"): fault = "Original credits data/fonts are not imported"; return false
	var data := preload("res://source_cutscene_content.gd").read_json(content,str(descriptor.file))
	fonts = preload("res://source_cutscene_content.gd").read_json(content,str(manifest.creditsFonts.file))
	var image: Dictionary = {}
	for entry in manifest.textures:
		if entry.name == manifest.creditsFonts.texture: image = entry; break
	if data.has("fault") or fonts.has("fault") or image.is_empty(): fault = "Invalid original credits bindings"; return false
	atlas = preload("res://source_cutscene_content.gd").read_json(content,str(image.file))
	texture = preload("res://source_sequence_content.gd").texture(content,image)
	state = preload("res://source_credits_state.gd").begin(data)
	if atlas.has("fault") or texture == null or state.has("fault"): fault = "Credits setup failed"; return false
	return true
func advance() -> Dictionary:
	if not fault.is_empty(): return {"fault":fault}
	if state.is_empty(): return {"fault":"Credits are not initialized"}
	var parsing := int(state.mode) == 1
	state = preload("res://source_credits_state.gd").advance(state)
	if state.has("fault"): fault = str(state.fault); return {"fault":fault}
	if parsing:
		var layout := preload("res://source_credits_text.gd").layout(state,fonts)
		if not text.set_text(layout,atlas,texture): fault = "Credits glyph rendering failed"; return {"fault":fault}
	return {"complete":bool(state.complete),"mode":int(state.mode),"cursor":int(state.cursor)}
