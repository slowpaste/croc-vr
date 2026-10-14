extends Node
var preview := preload("res://source_options_preview.gd").new()
var output: SubViewport = null
var text: Node = null
var heading: Node = null
var legend: Node = null
var values: Node = null
var mute: Node = null
var notice: Node = null
var controller_status: Node = null
var controller_scheme: Node = null
var controller_directions: Node = null
var calibration: Node = null
var music_track: Node = null
var frame_prompts: Node = null
var compositor_id := 0
var models: Dictionary = {}
var fault := ""
var last_render_revision:=-1
func _init() -> void:add_child(preview)
func present(world: Node, session: Dictionary, pose: Dictionary, supplement: Dictionary, view: Dictionary, projection: Dictionary) -> bool:
	fault = ""
	var frame_native: bool=world.xr_active or OS.get_cmdline_user_args().has("--frame-menu-preview")
	var slot:int=pose.get("slot",0)
	if not frame_native:
		var binding := preload("res://source_options_assets.gd").bind(world.manifest)
		if binding.has("fault") or not binding.slots.has(slot):fault="Missing Options model slot";return false
		if not models.has(slot):models[slot]=world.read_json(binding.slots[slot].file)
	var frontend: Dictionary=world.material_for_texture("FRONTEND.BIN")
	var font: Dictionary=world.material_for_texture("FONT.BIN")
	if frontend.is_empty() or font.is_empty():fault="Missing Options textures";return false
	var layout: Dictionary
	if frame_native and int(session.page) in [2,4,21,22]:
		layout=preload("res://source_frame_options.gd").text(world,session,supplement,preload("res://source_frame_options.gd").rows(world,int(session.page)),180 if int(session.page)==2 else 110)
	else:layout=preload("res://source_options_text.gd").layout(world.runtime_tables.mainMenu,int(session.page),int(session.navigation.selected),session.navigation.sizes,bool(session.music_player_available),int(session.get("parent_mode",0)),supplement)
	if int(session.page)==5 and int(session.get("playback_state",0))==1:
		var text: Dictionary=world.runtime_tables.mainMenu.duplicate(true);text.glyphs.merge(supplement.glyphs,false)
		text.labels=[{"text":"PAUSE TRACK","y":150},{"text":"STOP TRACK","y":165},{"text":"NEXT TRACK","y":180},{"text":"PREVIOUS TRACK","y":195},{"text":"RETURN TO AUDIO OPTIONS","y":210}]
		layout=preload("res://source_menu_text.gd").layout(text,session.navigation.sizes,false)
	if layout.has("fault"):fault=str(layout.fault);return false
	var heading_layout := preload("res://source_options_text.gd").heading_layout(int(session.page),supplement)
	if frame_native and int(session.page) in [21,22]:
		var heading_data := {"glyphs":supplement.headingGlyphs,"centerX":256,"labels":[{"text":"CAMERA OPTIONS" if int(session.page)==21 else "DISPLAY OPTIONS","y":24},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0}]}
		heading_layout=preload("res://source_menu_text.gd").layout(heading_data,[65536,65536,65536,65536,65536],false)
	if heading_layout.has("fault"):fault=str(heading_layout.fault);return false
	var legend_layout := preload("res://source_options_text.gd").legend_layout(world.runtime_tables.mainMenu,int(session.page),int(session.navigation.selected),supplement)
	if frame_native:legend_layout={"labels":[]}
	if legend_layout.has("fault"):fault=str(legend_layout.fault);return false
	var value_layout := preload("res://source_options_text.gd").audio_bar_layout(world.runtime_tables.mainMenu,session,supplement)
	if value_layout.has("fault"):fault=str(value_layout.fault);return false
	var mute_layout := preload("res://source_options_text.gd").mute_layout(session,supplement)
	if mute_layout.has("fault"):fault=str(mute_layout.fault);return false
	var notice_layout := preload("res://source_options_text.gd").notice_layout(world.runtime_tables.mainMenu,session,supplement)
	if notice_layout.has("fault"):fault=str(notice_layout.fault);return false
	var status_layout := preload("res://source_options_text.gd").controller_status_layout(session,supplement)
	if status_layout.has("fault"):fault=str(status_layout.fault);return false
	var scheme_layout := preload("res://source_options_text.gd").controller_scheme_layout(world.runtime_tables.mainMenu,session,supplement)
	if scheme_layout.has("fault"):fault=str(scheme_layout.fault);return false
	var directions_layout := preload("res://source_options_text.gd").controller_directions_layout(world.runtime_tables.mainMenu,session,supplement)
	if directions_layout.has("fault"):fault=str(directions_layout.fault);return false
	var calibration_layout := preload("res://source_options_text.gd").calibration_layout(world.runtime_tables.mainMenu,session,supplement)
	if frame_native and int(session.page)==2:
		status_layout={"labels":[]};scheme_layout={"labels":[]};directions_layout={"labels":[]}
	if calibration_layout.has("fault"):fault=str(calibration_layout.fault);return false
	if not frame_native:
		if not preview.present(pose,models[slot],frontend.data,world.texture_cache["FRONTEND.BIN"],world.runtime_tables.rotation.pairs,view,projection):fault=preview.fault;return false
	var needs_output:bool=not is_instance_valid(output) if frame_native else compositor_id!=preview.compositor.get_instance_id()
	if needs_output:
		if frame_native:
			output=SubViewport.new();output.size=Vector2i(512,240);output.own_world_3d=true;output.use_hdr_2d=true
			output.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(output)
			var camera:=Camera3D.new();camera.position.z=1.0;output.add_child(camera)
			var environment:=WorldEnvironment.new();environment.environment=Environment.new()
			environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;output.add_child(environment)
		else:
			compositor_id=preview.compositor.get_instance_id()
			output=preview.compositor.viewport_3d(int(projection.h),preview.compositor.output)
			output.get_camera_3d().position.z=1.0
			output.transparent_bg=true
		text=preload("res://source_menu_text_renderer.gd").new();output.add_child(text)
		heading=preload("res://source_menu_text_renderer.gd").new();output.add_child(heading)
		legend=preload("res://source_menu_text_renderer.gd").new();output.add_child(legend)
		values=preload("res://source_menu_text_renderer.gd").new();output.add_child(values)
		mute=preload("res://source_menu_text_renderer.gd").new();output.add_child(mute)
		mute.text_material.render_priority=127
		notice=preload("res://source_menu_text_renderer.gd").new();output.add_child(notice)
		notice.text_material.render_priority=127
		controller_status=preload("res://source_menu_text_renderer.gd").new();output.add_child(controller_status)
		controller_status.text_material.render_priority=127
		controller_scheme=preload("res://source_menu_text_renderer.gd").new();output.add_child(controller_scheme)
		controller_scheme.text_material.render_priority=127
		controller_directions=preload("res://source_menu_text_renderer.gd").new();output.add_child(controller_directions)
		controller_directions.text_material.render_priority=127
		calibration=preload("res://source_menu_text_renderer.gd").new();output.add_child(calibration)
		music_track=preload("res://source_menu_text_renderer.gd").new();output.add_child(music_track)
		frame_prompts=preload("res://source_menu_text_renderer.gd").new();output.add_child(frame_prompts);frame_prompts.text_material.render_priority=127
	if frame_native:
		frame_prompts.frame_buttons_enabled=true
		var prompt_rows: Array=["{ SELECT   } BACK"]
		var adjustable:bool=(int(session.page)==2 and int(session.navigation.selected)==0) or (int(session.page)==21 and int(session.navigation.selected)<4) or (int(session.page)==22 and int(session.navigation.selected)==0)
		if adjustable:prompt_rows=["< > ADJUST   { CHANGE   } BACK"]
		var hints:=preload("res://source_frame_options.gd").text(world,session,supplement,prompt_rows,66 if int(session.page)==2 else 46,15,[49152,49152,49152,49152,49152])
		if int(session.page)==2:
			var instructions:=preload("res://source_frame_options.gd").text(world,session,supplement,["LEFT STICK - MOVE" if world.vr_controls.layout=="modern" else "LEFT STICK - MOVE AND TURN","{ JUMP   } ATTACK","~ QUICK TURN   | OPTIONS","RIGHT STICK - CAMERA"],94,17,[49152,49152,49152,49152,49152])
			hints.labels.append_array(instructions.labels)
		if not frame_prompts.set_text(hints,font.data,world.texture_cache["FONT.BIN"]):fault="Steam Frame prompts failed";return false
	else:frame_prompts.hide()
	if int(session.page)==5 and int(session.get("playback_state",0)) in [1,2]:
		var track_data: Dictionary=world.runtime_tables.mainMenu.duplicate(true);track_data.glyphs.merge(supplement.glyphs,false)
		track_data.labels=[{"text":"TRACK %d"%int(session.track),"y":135},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0}]
		var track_layout := preload("res://source_menu_text.gd").layout(track_data,[32768,65536,65536,65536,65536],false)
		if not music_track.set_text(track_layout,font.data,world.texture_cache["FONT.BIN"]):fault="Music track label failed";return false
	else:music_track.hide()
	if not text.set_text(layout,font.data,world.texture_cache["FONT.BIN"]):fault="Options panel glyph rendering failed";return false
	if not heading.set_text(heading_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Options heading glyph rendering failed";return false
	if not legend.set_text(legend_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Options button legend rendering failed";return false
	if not values.set_text(value_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Audio value rendering failed";return false
	if not mute.set_text(mute_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Audio MUTE rendering failed";return false
	if not notice.set_text(notice_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Options notice rendering failed";return false
	if not controller_status.set_text(status_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Controller status rendering failed";return false
	if not controller_scheme.set_text(scheme_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Controller configuration rendering failed";return false
	if not controller_directions.set_text(directions_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Controller instruction rendering failed";return false
	if not calibration.set_text(calibration_layout,frontend.data,world.texture_cache["FRONTEND.BIN"]):fault="Calibration prompt rendering failed";return false
	if frame_native:
		var changed:=0
		for renderer in [text,heading,legend,values,mute,notice,controller_status,controller_scheme,controller_directions,calibration,music_track,frame_prompts]:changed+=renderer.revision
		if changed!=last_render_revision:output.render_target_update_mode=SubViewport.UPDATE_ONCE;last_render_revision=changed
	return true
func output_texture() -> Texture2D:return output.get_texture() if is_instance_valid(output) else null
