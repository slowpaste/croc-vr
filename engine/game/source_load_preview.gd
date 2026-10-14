extends Node
var preview := preload("res://source_options_preview.gd").new()
var output: SubViewport
var heading: Node
var legend: Node
var actions: Node
var icons: Node
var details: Node
var icon_texture: Texture2D
var icon_timer := 0
var icon_frame := 0
var icon_atlas := {"width":48,"height":16,"polygons":[]}
func reset_icon_animation() -> void:
	icon_timer=0;icon_frame=0
var compositor_id := 0
var models: Dictionary = {}
var fault := ""
func _init() -> void:add_child(preview)
func present(world: Node, yaw: int, font: Dictionary, session: Dictionary = {}) -> bool:
	var binding := preload("res://source_options_assets.gd").bind(world.manifest)
	if binding.has("fault"):fault=str(binding.fault);return false
	if models.is_empty():models=world.read_json(binding.slots[1284].file)
	var frontend: Dictionary=world.material_for_texture("FRONTEND.BIN")
	var pose := {"position":Vector3i(0,0,1000),"angles":Vector3i(0,yaw&65535,0),"scale":Vector3i(4096,4096,4096)}
	var view := {"matrix":[-4096,0,0,0,-4096,0,0,0,4096],"position":[0,0,0]}
	var projection := {"h":288,"offset":Vector2i(256<<16,192<<16)}
	if not preview.present(pose,models,frontend.data,world.texture_cache["FRONTEND.BIN"],world.runtime_tables.rotation.pairs,view,projection):fault=preview.fault;return false
	if compositor_id!=preview.compositor.get_instance_id():
		compositor_id=preview.compositor.get_instance_id()
		output=preview.compositor.viewport_3d(288,preview.compositor.output);output.transparent_bg=true
		output.get_camera_3d().position.z=1.0
		heading=preload("res://source_menu_text_renderer.gd").new();output.add_child(heading)
		legend=preload("res://source_menu_text_renderer.gd").new();output.add_child(legend)
		actions=preload("res://source_menu_text_renderer.gd").new();output.add_child(actions)
		icons=preload("res://source_menu_text_renderer.gd").new();output.add_child(icons)
		details=preload("res://source_menu_text_renderer.gd").new();output.add_child(details)
	var title := {"glyphs":font.headingGlyphs,"labels":[{"text":"LOAD GAME","y":24},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0}],"centerX":256}
	var saving := str(session.get("kind",""))=="save"
	var deleting := str(session.get("kind",""))=="delete"
	if saving:title.labels[0].text="SAVE GAME"
	if deleting:title.labels[0].text="DELETE BLOCK"
	var layout := preload("res://source_menu_text.gd").layout(title,[65536,65536,65536,65536,65536],false)
	if not heading.set_text(layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Load heading failed";return false
	var buttons := preload("res://source_options_text.gd").legend_layout(world.runtime_tables.mainMenu,1,0,font)
	var frame_native:bool=world.xr_active or OS.get_cmdline_user_args().has("--frame-menu-preview")
	if frame_native:
		for frame_binding in preview.compositor.bindings:
			if frame_binding.kind=="opaque":
				for node in frame_binding.nodes.values():node.hide()
		var frame_font:Dictionary=world.material_for_texture("FONT.BIN")
		var frame_session:Dictionary=session if session.has("navigation") else {"navigation":{"sizes":[65536,65536,65536,65536,65536]}}
		buttons=preload("res://source_frame_options.gd").text(world,frame_session,font,["{ SELECT   } BACK"],46,15,[49152,49152,49152,49152,49152])
		legend.frame_buttons_enabled=true
		if not legend.set_text(buttons,frame_font.data,world.texture_cache["FONT.BIN"]):fault="Steam Frame save/load prompts failed";return false
	if saving:
		for label in buttons.labels:
			for glyph in label.glyphs:glyph.position.y+=6 # Native Save legendY52.
	if not frame_native and not legend.set_text(buttons,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Load legend failed";return false
	if not session.is_empty():
		var text: Dictionary=world.runtime_tables.mainMenu.duplicate(true)
		text.glyphs.merge(font.glyphs,false)
		text.labels=[{"text":"LOAD GAME","y":195},{"text":"RETURN","y":210},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0}]
		var sizes: Array=session.navigation.sizes.duplicate()
		if deleting:
			text.labels[0].text="YES" if bool(session.overwrite) else "DELETE BLOCK"
			text.labels[1].text="NO" if bool(session.overwrite) else "RETURN"
			if session.slots.is_empty():text.labels[0]={"text":"RETURN","y":210};text.labels[1].text=""
			if bool(session.overwrite):
				text.labels[2]={"text":"Do you really want","y":100};text.labels[3]={"text":"to delete this block ?","y":114};sizes[2]=65536;sizes[3]=65536
			if not str(session.get("delete_error","")).is_empty():text.labels[2]={"text":"MEMORY CARD PROBLEM","y":100};sizes[2]=65536
		if saving:
			text.labels[0].text="OVERWRITE BLOCK" if bool(session.overwrite) else "OVERWRITE GAME" if str(session.new_path).is_empty() else "SAVE GAME"
			text.labels[1].text="CANCEL" if bool(session.overwrite) else "RETURN TO MAP"
			text.labels[2]={"text":"Requires 1 block","y":40};sizes[2]=32768
			if int(session.get("save_counter",0))>0:
				text.labels[3]={"text":"GAME SAVED %d%%"%int(session.saved_percentage),"y":100};sizes[3]=65536
			elif not str(session.get("save_error","")).is_empty():
				text.labels[3]={"text":"MEMORY CARD PROBLEM","y":100};sizes[3]=65536
		var action_layout := preload("res://source_menu_text.gd").layout(text,sizes,false)
		var atlas: Dictionary=world.material_for_texture("FONT.BIN")
		if not actions.set_text(action_layout,atlas.data,world.texture_cache["FONT.BIN"]):fault=str(action_layout.get("fault","Load action rows failed"));return false
	else:actions.hide()
	if not session.is_empty():
		var caption := "Empty Block"
		if int(session.slot)<session.slots.size():
			var entry: Dictionary=session.slots[int(session.slot)]
			caption="MEMORY CARD PROBLEM" if entry.has("fault") else "Croc! %2d%%"%int(entry.get("percentage",0))
		var text: Dictionary=world.runtime_tables.mainMenu.duplicate(true);text.glyphs.merge(font.glyphs,false)
		text.labels=[{"text":caption,"y":162},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0}]
		var atlas: Dictionary=world.material_for_texture("FONT.BIN")
		if not details.set_text(preload("res://source_menu_text.gd").layout(text,[65536,65536,65536,65536,65536],false),atlas.data,world.texture_cache["FONT.BIN"]):fault="Save slot details failed";return false
	else:details.hide()
	if not session.is_empty() and not session.slots.is_empty():
		if icon_texture==null:
			var loaded := preload("res://source_save_icon.gd").load_asset(world.content_root,world.manifest.get("saveIcon",{}))
			if loaded.has("fault"):fault=str(loaded.fault);return false
			icon_texture=ImageTexture.create_from_image(loaded.image)
			for frame in range(3):icon_atlas.polygons.append({"uv":[[float(frame)/3.0,1.0],[float(frame+1)/3.0,1.0],[float(frame)/3.0,0.0],[float(frame+1)/3.0,0.0]]})
		if icon_timer>0:icon_timer-=1
		else:icon_timer=25;icon_frame=(icon_frame+1)%3
		var row := preload("res://source_save_icon.gd").layout(session.slots.size(),int(session.slot),icon_frame,saving and not str(session.new_path).is_empty())
		if not icons.set_text(row,icon_atlas,icon_texture):fault="Save icon row failed";return false
	else:icons.hide()
	return true
