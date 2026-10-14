extends "res://main.gd"
# SPDX-License-Identifier: GPL-2.0-only
# UV corner convention informed by CrocUtils, Copyright 2020 Zane van Iperen.
# External, user-generated data only. Imported files never belong in res://.
const CELL_METERS := 3.0
var content_root := ""
var manifest: Dictionary
var runtime_tables: Dictionary = {}
var terrain_models: Array = []
var source_camera_geometry_cache: Dictionary = {}
const SourceCollision = preload("res://source_collision.gd")
const SourceActorList = preload("res://source_actor_list.gd")
const SourceActorPool = preload("res://source_actor_pool.gd")
const SourceRandom = preload("res://source_random.gd")
var source_random = SourceRandom.new()
var source_frame_clock = preload("res://source_frame_clock.gd").new()
var source_pool = SourceActorPool.new()
var source_actor_references = preload("res://source_actor_references.gd").new()

func register_source_actor_references(owner: Node3D) -> void:
	source_actor_references.register(owner)
var source_actor_parameter_memory: Dictionary = {}
var source_actor_global_memory: Dictionary = {}
var source_actor_pose_memory: Dictionary = {}

func source_parent_global_bank(index: int) -> Dictionary:
	if source_pool.slots.has(index):
		var node = source_pool.slots[index].get("node",null)
		if is_instance_valid(node):return {"bank":node.vm.globals}
	if source_actor_global_memory.has(index):return {"bank":source_actor_global_memory[index]}
	return {}

func restore_source_actor_pose_memory(node: Node3D, index: int) -> void:
	if source_actor_pose_memory.has(index):
		var memory: Dictionary = source_actor_pose_memory[index]
		node.source_pose_padding = memory.current.duplicate(true)
		node.source_saved_pose_padding = memory.saved.duplicate(true)
func source_parent_parameters(index: int) -> Dictionary:
	if source_pool.slots.has(index):
		var node = source_pool.slots[index].get("node",null)
		if is_instance_valid(node) and node.has_method("asl_expression"):
			return {"parameters":node.vm.parameters}
		return {}
	if source_actor_parameter_memory.has(index):
		return {"parameters":source_actor_parameter_memory[index]}
	return {}
var source_player_id := -1
var source_player_actor: Node3D = null
var source_ground_mode_80_value: Variant = 0 # Initialized word0x80074a28.
var source_shadow_meshes: Dictionary = {}
var source_input_suppression_count := 0 # Startup 0x80013064.
var source_input_held_mask: Variant = null
var source_input_pressed_mask: Variant = null
var source_input_released_mask: Variant = null
var source_player_movement_state: Dictionary = preload("res://source_player_movement.gd").initial_state()
var source_player_input_state: Dictionary = {}
var source_demo_frames: Array = []
var source_demo_playing := false
var source_cd_fade_counter := 0 # Source gp2108, initialized before CD playback.
var source_cd_stereo_flag := 0
var source_cd_mix_state: Dictionary = {}
var source_music_volume := 0
var source_effects_volume := 127
var source_options_state: Dictionary = {}
var source_options_pose: Dictionary = {}
var source_options_font: Dictionary = {}
var source_options_screen: Node = null
var source_options_parent_selection := 1
var source_options_parent_mode := 1
var source_options_music_backend: Node = null
var source_gameplay_music: Node = null
func enter_source_password_display() -> bool:
	if source_main_mode!=5:source_transition_fault="Password display requires selector";return false
	if not refresh_source_game_over_screen():return false
	source_game_over_renderer.position.z=-1.0
	if is_instance_valid(source_main_menu_text):source_main_menu_text.hide()
	source_main_mode=12;source_controller_enabled=false;return true
func process_source_password_display() -> bool:
	if source_fade_phase!="":return advance_source_transition()
	if (int(source_input_pressed_mask)&0x900000)!=0:
		play_source_menu_sound("START")
		source_fade_state=preload("res://source_transition_fade.gd").start(8);source_fade_phase="password-display-out"
	return true
var source_options_save_path := "user://source-save-00.bin"
var source_saved_options_error := ""
var source_load_state: Dictionary = {}
var source_load_screen: Node = null
var source_load_yaw := 0
var source_save_state: Dictionary = {}
var source_delete_state: Dictionary = {}
func enter_source_delete_menu() -> bool:
	var slots: Array=preload("res://source_save_slots.gd").new(source_options_save_path.get_base_dir()).list_slots()
	var state := preload("res://source_delete_session.gd").initialize(slots)
	if state.has("fault"):source_transition_fault=str(state.fault);return false
	if not is_instance_valid(source_load_screen):
		source_load_screen=preload("res://source_load_screen.gd").new()
		var view: Camera3D=head if xr_active else camera;view.add_child(source_load_screen)
	source_load_yaw=0;source_load_screen.panel.reset_icon_animation()
	if not source_load_screen.present(self,state,0,source_options_font_data()):source_transition_fault=source_load_screen.panel.fault;return false
	source_delete_state=state;source_options_screen.hide();source_main_mode=10;return true
func process_source_delete_menu(held: int, pressed: int) -> bool:
	if source_fade_phase!="":return advance_source_transition()
	if not str(source_delete_state.get("pending_path","")).is_empty():
		var result := preload("res://source_save_store.gd").new(str(source_delete_state.pending_path)).delete_slot()
		source_delete_state.pending_path="";source_delete_state.overwrite=false
		if result.has("fault"):source_delete_state.delete_error=str(result.fault)
		source_delete_state.slots=preload("res://source_save_slots.gd").new(source_options_save_path.get_base_dir()).list_slots()
		source_delete_state.slot=mini(int(source_delete_state.slot),maxi(source_delete_state.slots.size()-1,0))
		source_delete_state.navigation=preload("res://source_main_menu.gd").initialize(0 if source_delete_state.slots.is_empty() else 1,0 if source_delete_state.slots.is_empty() else 1)
	else:
		var next := preload("res://source_delete_session.gd").advance(source_delete_state,held,pressed)
		if next.has("fault"):source_transition_fault=str(next.fault);return false
		for sound in next.sounds:play_source_menu_sound(str(sound),15.0 if sound=="BON_BEEP" else 80.0,0 if sound=="BON_BEEP" else 24)
		source_delete_state=next
		if bool(next.exit_requested):
			source_load_screen.hide();source_main_mode=8;source_delete_state.clear()
			return source_options_screen.present(self,source_options_state,source_options_pose,source_options_font)
	if not source_load_screen.present(self,source_delete_state,source_load_yaw,source_options_font_data()):source_transition_fault=source_load_screen.panel.fault;return false
	source_load_yaw=(source_load_yaw+16)&65535;return true
var source_selector_action_state: Dictionary = {}
func advance_source_selector_actions(held: int, pressed: int) -> bool:
	if source_fade_phase!="":return true
	var phase := int(source_menu_state.save_mode)
	if phase not in [0,1,2]:return true
	if phase!=0 and (pressed&0x100000)!=0:
		phase=0 if phase==1 else 1;source_menu_state.save_mode=phase;source_menu_state.dialog_mode=1;source_selector_action_state.clear();play_source_menu_sound("SELECT")
	var last := 3 if phase==0 else 2 if phase==1 else 1
	if source_selector_action_state.is_empty() or int(source_selector_action_state.last_index)!=last:source_selector_action_state=preload("res://source_main_menu.gd").initialize(int(source_menu_state.dialog_mode),last)
	source_selector_action_state=preload("res://source_main_menu.gd").advance(source_selector_action_state,held,pressed)
	source_menu_state.dialog_mode=int(source_selector_action_state.selected)
	var font := source_options_font_data()
	if font.has("fault"):source_transition_fault=str(font.fault);return false
	var data: Dictionary=runtime_tables.mainMenu.duplicate(true);data.glyphs.merge(font.glyphs,false)
	data.labels=[{"text":"START LEVEL","y":165},{"text":"OPTIONS","y":180},{"text":"SAVE GAME","y":195},{"text":"SHOW LEVEL PASSWORD","y":210},{"text":"","y":0}]
	if phase==1:data.labels=[{"text":"OTHER OPTIONS","y":180},{"text":"QUIT GAME","y":195},{"text":"RETURN","y":210},{"text":"","y":0},{"text":"","y":0}]
	var sizes: Array=source_selector_action_state.sizes.duplicate()
	if phase==2:
		data.labels=[{"text":"NO","y":195},{"text":"YES","y":210},{"text":"REALLY QUIT ?","y":175},{"text":"","y":0},{"text":"","y":0}];sizes[2]=65536
	if not render_source_frontend_text(preload("res://source_menu_text.gd").layout(data,sizes,false)):return false
	# The selector actions and stage name share the physical frontend plane.
	return true
func enter_source_save_menu() -> bool:
	if source_main_mode!=5:source_transition_fault="Save requires original island selector";return false
	var catalog=preload("res://source_save_slots.gd").new(source_options_save_path.get_base_dir())
	var allocation := catalog.new_slot()
	if allocation.has("fault"):source_transition_fault=str(allocation.fault);return false
	var state := preload("res://source_save_session.gd").initialize(catalog.list_slots(),str(allocation.get("path","")))
	if state.has("fault"):source_transition_fault=str(state.fault);return false
	if not is_instance_valid(source_load_screen):
		source_load_screen=preload("res://source_load_screen.gd").new()
		var view: Camera3D=head if xr_active else camera;view.add_child(source_load_screen)
	source_load_yaw=0
	source_load_screen.panel.reset_icon_animation()
	if not source_load_screen.present(self,state,0,source_options_font_data()):source_transition_fault=source_load_screen.panel.fault;return false
	source_save_state=state;source_main_mode=11;source_controller_enabled=false
	if is_instance_valid(source_main_menu_text):source_main_menu_text.hide()
	return true
func finish_source_save_menu() -> bool:
	source_load_screen.hide();source_save_state.clear()
	source_menu_state.save_mode=0;source_menu_state.dialog_mode=0
	source_selector_action_state.clear()
	return apply_source_island_selection()
func process_source_save_menu(held: int, pressed: int) -> bool:
	if source_fade_phase!="":return advance_source_transition()
	var counter := int(source_save_state.get("save_counter",0))
	if counter!=0:
		if counter>=60:return finish_source_save_menu()
		source_save_state.save_counter=counter+1
	elif not str(source_save_state.get("pending_path","")).is_empty():
		var previous_path := source_options_save_path
		source_options_save_path=str(source_save_state.pending_path)
		var result := write_source_campaign()
		source_save_state.pending_path=""
		if bool(result.get("written",false)):
			source_save_state.save_counter=3
			var saved := preload("res://source_save_store.gd").new(source_options_save_path).read_record()
			source_save_state.saved_percentage=int(preload("res://source_campaign_save.gd").decode(saved.record).percentage)
		else:
			source_options_save_path=previous_path;source_save_state.save_error=str(result.get("fault","Save failed"))
			source_save_state.overwrite=false;source_save_state.navigation=preload("res://source_main_menu.gd").initialize(1,1)
	else:
		var next := preload("res://source_save_session.gd").advance(source_save_state,held,pressed)
		if next.has("fault"):source_transition_fault=str(next.fault);return false
		for sound in next.sounds:play_source_menu_sound(str(sound),15.0 if sound=="BON_BEEP" else 80.0,0 if sound=="BON_BEEP" else 24)
		source_save_state=next
		if bool(next.exit_requested):return finish_source_save_menu()
	if not source_load_screen.present(self,source_save_state,source_load_yaw,source_options_font_data()):source_transition_fault=source_load_screen.panel.fault;return false
	source_load_yaw=(source_load_yaw+16)&65535;return true
func enter_source_load_menu() -> bool:
	var font := source_options_font_data()
	if font.has("fault"):source_transition_fault=str(font.fault);return false
	var slots: Array=preload("res://source_save_slots.gd").new(source_options_save_path.get_base_dir()).list_slots()
	var state := preload("res://source_load_session.gd").initialize(slots)
	if state.has("fault"):source_transition_fault=str(state.fault);return false
	if not is_instance_valid(source_load_screen):
		source_load_screen=preload("res://source_load_screen.gd").new()
		var view: Camera3D=head if xr_active else camera;view.add_child(source_load_screen)
	source_load_yaw=0
	source_load_screen.panel.reset_icon_animation()
	if not source_load_screen.present(self,state,source_load_yaw,font):source_transition_fault=source_load_screen.panel.fault;return false
	source_load_state=state;source_main_mode=9;source_controller_enabled=false
	if is_instance_valid(source_main_menu_text):source_main_menu_text.hide()
	for logo in source_title_logo_nodes:
		if is_instance_valid(logo):logo.hide()
	for effect in source_title_effect_nodes:
		if is_instance_valid(effect):effect.hide()
	return true
func process_source_load_menu(held: int, pressed: int) -> bool:
	if source_fade_phase!="":return advance_source_transition()
	if not str(source_load_state.get("pending_path","")).is_empty():
		var previous_path := source_options_save_path
		source_options_save_path=str(source_load_state.pending_path)
		if load_source_campaign():
			source_load_screen.hide();source_load_state.clear();return true
		source_options_save_path=previous_path;source_load_state.pending_path=""
		source_load_state.slots[int(source_load_state.slot)].fault=source_transition_fault
		source_transition_fault=""
	var next := preload("res://source_load_session.gd").advance(source_load_state,held,pressed)
	if next.has("fault"):source_transition_fault=str(next.fault);return false
	for sound in next.sounds:
		play_source_menu_sound(str(sound),15.0 if sound=="BON_BEEP" else 80.0,0 if sound=="BON_BEEP" else 24)
	source_load_state=next
	if bool(next.exit_requested):
		source_load_screen.hide();source_main_mode=1;source_menu_state.dialog_mode=2;source_main_menu_animation_state.selected=2
		return refresh_source_title_logo() and refresh_source_main_menu_text()
	if not source_load_screen.present(self,next,source_load_yaw,source_options_font_data()):source_transition_fault=source_load_screen.panel.fault;return false
	source_load_yaw=(source_load_yaw+16)&65535
	return true
func restore_source_saved_options() -> bool:
	var selected_path := source_options_save_path
	var saved := preload("res://source_save_store.gd").new(selected_path).read_record()
	if saved.has("missing") and selected_path.get_file()=="source-save-00.bin":
		var slots: Array=preload("res://source_save_slots.gd").new(selected_path.get_base_dir()).list_slots()
		if not slots.is_empty():
			selected_path=str(slots[0].path)
			saved=preload("res://source_save_store.gd").new(selected_path).read_record()
	if saved.has("missing"):return true
	if saved.has("fault"):source_saved_options_error=str(saved.fault);return false
	var settings := preload("res://source_save_record.gd").options(saved.record)
	if settings.has("fault"):source_saved_options_error=str(settings.fault);return false
	if int(settings.scheme) not in [0,1,2] or int(settings.mode) not in [0,1,2] or int(settings.music)>127 or int(settings.effects)>127:
		source_saved_options_error="Invalid saved audio/controller settings";return false
	for key in ["center_x","center_y","minimum_x","minimum_y","maximum_x","maximum_y"]:
		if int(settings[key])<0 or int(settings[key])>255:source_saved_options_error="Invalid saved calibration bytes";return false
	if int(settings.screen_x)< -8 or int(settings.screen_x)>24 or int(settings.screen_y)< -8 or int(settings.screen_y)>24:
		source_saved_options_error="Invalid saved screen position";return false
	var state := preload("res://source_options_session.gd").initialize({"music":int(settings.music),"effects":int(settings.effects),"mode":int(settings.mode)})
	state.scheme=int(settings.scheme)
	state.screen_offset=Vector2i(settings.screen_x,settings.screen_y)
	state.calibration=preload("res://source_controller_calibration.gd").normalize(Vector2i(settings.center_x,settings.center_y),Vector2i(settings.minimum_x,settings.minimum_y),Vector2i(settings.maximum_x,settings.maximum_y))
	state.cd_mix_events=[preload("res://source_cd_fade.gd").restore(int(settings.music),int(settings.mode))]
	state.cd_mix_events[0].option_volume=int(settings.music);state.cd_mix_events[0].stereo_flag=int(settings.mode)
	if not apply_source_options_audio(state):source_saved_options_error="Cannot apply saved audio settings";return false
	source_options_state=state;source_options_save_path=selected_path;source_saved_options_error="";return true
func source_saved_settings(state: Dictionary) -> Dictionary:
	var calibration: Dictionary=state.calibration
	var offset: Vector2i=state.screen_offset
	var settings := {"scheme":int(state.scheme),"music":int(state.audio.music),"effects":int(state.effects_restore_volume),"mode":int(state.audio.mode),"center_x":int(calibration.center.x),"center_y":int(calibration.center.y),"minimum_x":int(calibration.minimum.x),"minimum_y":int(calibration.minimum.y),"maximum_x":int(calibration.maximum.x),"maximum_y":int(calibration.maximum.y),"screen_x":offset.x,"screen_y":offset.y}
	return settings
func write_source_options(state: Dictionary) -> Dictionary:
	return preload("res://source_save_store.gd").new(source_options_save_path).write_options(source_saved_settings(state))
func source_campaign_save_state() -> Dictionary:
	if map_name.length()!=12 or not map_name.begins_with("MP") or not map_name.ends_with(".MAP"):
		return {"fault":"Invalid campaign room name"}
	var flags := []
	for index in range(46):flags.append(int(source_menu_progress_flags.get(index,0)))
	var level := int(map_name.substr(2,3));var room := int(map_name.substr(6,2))
	# Native selector14300..14314 updates logical level/room while its
	# loaded display map remains100. Save mode11 retains that logical pair.
	if source_main_mode in [5,11]:
		var destination := source_selected_menu_destination()
		if destination.has("fault"):return destination
		level=int(destination.level);room=0
	return {"level":level,"room":room,"selection":int(source_menu_state.selected_index),"lives":int(source_pickup_counts[3]),"flags":flags,"pickups":source_stage_pickup_slots.duplicate(),"announcement_history":source_menu_announcement_history.duplicate()}
func write_source_campaign() -> Dictionary:
	var state := source_campaign_save_state()
	if state.has("fault"):return state
	var options := source_options_state.duplicate(true)
	if options.is_empty():options=preload("res://source_options_session.gd").initialize({"music":source_music_volume,"effects":source_effects_restore_volume,"mode":source_cd_stereo_flag})
	options.audio={"music":source_music_volume,"effects":source_effects_volume,"mode":source_cd_stereo_flag}
	options.effects_restore_volume=source_effects_restore_volume
	var store=preload("res://source_save_store.gd").new(source_options_save_path)
	var prior := store.read_record()
	if prior.has("fault"):return prior
	var record: PackedByteArray=preload("res://source_save_record.gd").new_record() if prior.has("missing") else prior.record
	var encoded := preload("res://source_campaign_save.gd").encode(record,source_saved_settings(options),state)
	if encoded.has("fault"):return encoded
	return store.write_copies(encoded.copies)
func load_source_campaign() -> bool:
	var saved := preload("res://source_save_store.gd").new(source_options_save_path).read_record()
	if not saved.has("record"):source_transition_fault=str(saved.get("fault","No saved campaign"));return false
	var state := preload("res://source_campaign_load.gd").prepare(saved.record)
	if state.has("fault"):source_transition_fault=str(state.fault);return false
	var destination := preload("res://source_menu_selection.gd").level_for_index(int(state.selection),runtime_tables.get("menuLevels",{}).get("values",[]))
	if destination.has("fault") or int(destination.get("level",0))==0 or int(state.lives)<0:
		source_transition_fault="Invalid saved campaign destination/lives";return false
	var island := int(int(destination.level)/10)
	if island<1 or island>5 or not manifest.linkage.rooms.has("MP100_%02d.MAP"%island):
		source_transition_fault="Missing saved campaign selector";return false
	if not restore_source_saved_options():source_transition_fault=source_saved_options_error;return false
	for index in range(46):source_menu_progress_flags[index]=int(state.flags[index])
	source_stage_pickup_slots=state.pickups.duplicate()
	source_menu_announcement_history=state.announcement_history.duplicate()
	source_menu_state.selected_index=int(state.selection)
	source_pickup_counts[3]=int(state.lives)
	return apply_source_island_selection()
func enter_source_title_options(pad_kind: int = 1, parent_mode: int = 1) -> bool:
	if pad_kind not in [1,2]:source_transition_fault="Unsupported Options controller kind";return false
	var font := source_options_font_data()
	if font.has("fault"):source_transition_fault=str(font.fault);return false
	source_options_font=font
	source_options_parent_selection=int(source_menu_state.dialog_mode)
	source_options_parent_mode=parent_mode
	var retained := {}
	for key in ["scheme","calibration","screen_offset","saved_game_selection"]:
		if source_options_state.has(key):retained[key]=source_options_state[key]
	source_options_state=preload("res://source_options_session.gd").initialize({"music":source_music_volume,"effects":source_effects_volume,"mode":source_cd_stereo_flag},0,pad_kind)
	source_options_state.parent_mode=parent_mode
	source_options_state.merge(retained.duplicate(true),true)
	source_options_state.effects_restore_volume=source_effects_restore_volume
	source_options_state.effects_maximum=source_audio_master_maximum
	source_options_state.effects_step=source_audio_master_step
	source_options_pose={"slot":1316 if pad_kind==2 else 1252,"position":Vector3i(0,0,3000),"angles":Vector3i.ZERO,"scale":Vector3i(4096,4096,4096)}
	if not is_instance_valid(source_options_screen):
		source_options_screen=preload("res://source_options_screen.gd").new()
		var view: Camera3D=head if xr_active else camera
		view.add_child(source_options_screen)
	if not source_options_screen.present(self,source_options_state,source_options_pose,source_options_font):
		source_transition_fault=source_options_screen.panel.fault
		source_options_screen.hide();return false
	source_main_mode=8;source_controller_enabled=false
	source_resume_input_baseline_pending=true
	if parent_mode==4 and is_instance_valid(source_stage_stats_renderer):source_stage_stats_renderer.hide()
	if is_instance_valid(source_main_menu_text):source_main_menu_text.hide()
	for logo in source_title_logo_nodes:
		if is_instance_valid(logo):logo.hide()
	return true
func source_options_pad_sample() -> Vector2i:
	var stick: Vector2=left.get_vector2("primary") if xr_active else Input.get_vector("move_left","move_right","move_forward","move_back")
	if xr_active:stick.y=-stick.y
	var adapter=preload("res://source_virtual_pad.gd")
	return Vector2i(adapter.axis_byte(stick.x),adapter.axis_byte(stick.y))
func process_source_options(held: int, pressed: int, calibration_sample: Variant = null) -> bool:
	if source_fade_phase!="":return advance_source_transition()
	source_options_state.audio={"music":source_music_volume,"effects":source_effects_volume,"mode":source_cd_stereo_flag}
	var root_selection := -1
	var audio_mode_preview := -1
	var audio_selection := -1
	var audio_player_available := false
	if int(source_options_state.page)==1:
		root_selection=int(preload("res://source_main_menu.gd").advance(source_options_state.navigation,held,pressed).selected)
	elif int(source_options_state.page)==3:
		audio_selection=int(preload("res://source_main_menu.gd").advance(source_options_state.navigation,held,pressed).selected)
		audio_player_available=bool(source_options_state.music_player_available)
		audio_mode_preview=source_cd_stereo_flag
	var sample: Variant=calibration_sample
	if int(source_options_state.page)==6 and sample==null:sample=source_options_pad_sample()
	var music_state := 0 if not is_instance_valid(source_options_music_backend) else int(source_options_music_backend.playback_state)
	if is_instance_valid(source_options_music_backend) and not source_options_music_backend.pending_track_changes.is_empty():
		if int(source_options_state.page)==5:source_options_state.track=source_options_music_backend.pending_track_changes.back()
		source_options_music_backend.pending_track_changes.clear()
	var next := preload("res://source_frame_options.gd").advance(self,source_options_state,held,pressed,sample,music_state)
	if next.has("fault"):source_transition_fault=str(next.fault);return false
	if str(next.get("pending_action",""))=="music_player":
		if not is_instance_valid(source_options_music_backend):
			source_options_music_backend=preload("res://source_options_music_backend.gd").new();add_child(source_options_music_backend)
		var played: Dictionary=source_options_music_backend.execute(self,int(next.track),next.audio_commands)
		if played.has("fault"):source_transition_fault=str(played.fault);return false
		next.pending_action="";next.playback_state=int(played.state)
	else:next.playback_state=music_state
	if str(next.get("pending_action",""))=="delete_saved_game":
		next.pending_action="";source_options_state=next;return enter_source_delete_menu()
	if str(next.get("pending_action",""))=="write_options":
		var saved := write_source_options(next)
		next.pending_action=""
		next.write_notice_ticks=30 if bool(saved.get("written",false)) else -30
		next.write_error=str(saved.get("fault",""))
	if str(next.get("pending_action",""))=="reset_defaults":
		if xr_active or OS.get_cmdline_user_args().has("--frame-menu-preview"):
			var fresh=preload("res://vr_controls.gd").new()
			for key in ["layout","turn_mode","snap_degrees","smooth_degrees_per_second","foveation_level","jump_camera","camera_tilt","haptics_enabled"]:vr_controls.set(key,fresh.get(key))
			vr_camera_pitch=0;vr_settings.save_changes()
		var defaults := preload("res://source_options_session.gd").default_values(next)
		var event: Dictionary=defaults.cd_mix.duplicate(true)
		event.option_volume=80;event.stereo_flag=1
		defaults.cd_mix_events=[event]
		if not apply_source_options_audio(defaults):source_transition_fault="Original defaults could not be applied";return false
		next=preload("res://source_options_session.gd").complete_defaults(defaults,true)
	if (pressed&0x200)!=0:next.exit_requested=true
	if not apply_source_options_audio(next):source_transition_fault="Invalid live Options audio update";return false
	var final_effects := source_effects_volume
	var final_mode := source_cd_stereo_flag
	for preview in next.get("adjustment_previews",[]):
		source_effects_volume=int(preview.effects);source_cd_stereo_flag=int(preview.mode)
		play_source_menu_sound("SELECT",80.0,24)
	source_effects_volume=final_effects;source_cd_stereo_flag=final_mode
	if str(next.get("last_action",""))=="controller_error_sound":play_source_menu_sound("BON_BEEP",15.0,0)
	source_options_state=next
	if bool(next.exit_requested):
		if source_options_parent_mode==4:
			if str(next.get("last_action",""))=="return_to_title":
				source_options_screen.hide()
				return apply_source_demo_title_return()
			source_options_screen.hide();source_main_mode=4;source_controller_enabled=true;source_resume_input_baseline_pending=true
			if is_instance_valid(source_stage_stats_renderer):source_stage_stats_renderer.show()
			return true
		if source_options_parent_mode==5:
			source_options_screen.hide();source_main_mode=5;source_menu_state.dialog_mode=source_options_parent_selection;source_selector_action_state.clear()
			return advance_source_selector_actions(0,0)
		source_main_mode=1;source_menu_state.dialog_mode=source_options_parent_selection
		source_main_menu_animation_state.selected=source_options_parent_selection
		source_options_screen.hide()
		if not refresh_source_title_logo() or not refresh_source_main_menu_text():return false
		return true
	var frame := preload("res://source_options_model_pose.gd").draw_step(source_options_pose)
	var presentation_started:=Time.get_ticks_usec()
	if not source_options_screen.present(self,next,frame.draw,source_options_font):source_transition_fault=source_options_screen.panel.fault;return false
	record_runtime_cost("options_present",Time.get_ticks_usec()-presentation_started)
	source_options_pose=frame.next
	if root_selection>=0:source_options_pose=preload("res://source_options_model_pose.gd").root_selection(source_options_pose,root_selection,int(next.pad_kind))
	elif audio_selection>=0:source_options_pose=preload("res://source_options_model_pose.gd").audio_selection(source_options_pose,audio_selection,audio_mode_preview,audio_player_available)
	elif int(next.page)==1:source_options_pose=preload("res://source_options_model_pose.gd").root_selection(source_options_pose,int(next.navigation.selected),int(next.pad_kind))
	elif int(next.page)==5:source_options_pose=preload("res://source_options_model_pose.gd").music_selection(source_options_pose,int(next.navigation.selected),int(next.playback_state))
	return true
var source_cutscene_screen: Node3D = null
var vr_cinematic_view:Dictionary={}
func capture_source_cinematic_view() -> void:
	# Keep the virtual eye where the cinematic is placed. Remove inherited
	# gameplay/menu camera tilt without changing the tracked head position.
	if xr_active:
		var eye:=head.global_position
		var level:=preload("res://source_horizon_anchor.gd").transform(rig.global_transform,0.0).basis
		rig.global_transform=Transform3D(level,eye-level*head.position)
	camera.global_transform=preload("res://source_horizon_anchor.gd").transform(camera.global_transform,0.0)
	vr_cinematic_view={"camera":camera.global_transform,"rig":rig.global_transform}
var source_sequence_load:Thread
var source_sequence_loading:=false
var source_sequence_loading_text:MeshInstance3D
var source_opening_preparation:Dictionary={}
var source_startup_movie:Node3D
func enter_source_startup() -> bool:
	if not enter_source_opening():return false
	source_sequence_loading_text.hide()
	source_startup_movie=preload("res://source_startup_movie.gd").new();add_child(source_startup_movie)
	source_startup_movie.finished.connect(finish_source_startup_movie)
	source_startup_movie.setup(head if xr_active else camera,source_effects_volume)
	return true
func finish_source_startup_movie() -> void:
	if is_instance_valid(source_startup_movie):source_startup_movie.queue_free()
	source_startup_movie=null
	if is_instance_valid(source_sequence_loading_text):source_sequence_loading_text.show()
var source_cutscene_progress: Dictionary = {}
var source_cutscene_cpu_max_us := 0
var source_cutscene_transport_state := {"prefill":0,"phase_us":6667,"history":[[0,0],[0,0]],"filter":{}}
func enter_source_opening() -> bool:
	return enter_source_sequence(0)

var source_ending_root := -1
var source_story_return: Dictionary = {}
var source_secret_unlock_return: Dictionary = {}
var source_credits_screen: Node3D = null
var source_credits_return_mode := 0
var source_credits_hud_visible := false
func hide_source_cinematic_world() -> void:
	if is_instance_valid(source_gameplay_music):source_gameplay_music.stop_room()
	if is_instance_valid(source_options_music_backend):source_options_music_backend.stop_track()
	clear_source_stage_stats()
	if is_instance_valid(terrain): terrain.hide()
	for node in source_actors: node.hide()
	for node in source_title_logo_nodes: node.hide()
	for node in source_title_effect_nodes: node.hide()
	if is_instance_valid(source_main_menu_text): source_main_menu_text.hide()
	if is_instance_valid(source_fade_overlay): source_fade_overlay.set_source_level(0)

func enter_source_sequence(scene_id: int, preparation:Dictionary={}) -> bool:
	if scene_id==0 and preparation.is_empty() and not source_opening_preparation.is_empty():preparation=source_opening_preparation
	if scene_id==0 and preparation.is_empty():
		if source_sequence_loading:return true
		capture_source_cinematic_view()
		hide_source_cinematic_world()
		source_main_mode=2;source_controller_enabled=false
		source_fade_phase="";source_fade_state.clear()
		var state:=source_cutscene_transport_state.duplicate(true)
		state.mix=source_cd_mix_state.get("mix",[]).duplicate();state.threaded=true
		if state.filter.is_empty():state.filter=preload("res://source_xa_zigzag.gd").new().snapshot()
		source_sequence_load=Thread.new()
		var error:=source_sequence_load.start(preload("res://source_sequence_preparation.gd").prepare.bind(content_root,manifest,runtime_tables,scene_id,state))
		if error!=OK:source_transition_fault="Cannot prepare opening sequence";return false
		source_sequence_loading=true
		source_cutscene_progress={"scene":0,"loading":true,"complete":false}
		source_sequence_loading_text=preload("res://source_menu_text_renderer.gd").new()
		(head if xr_active else camera).add_child(source_sequence_loading_text)
		source_sequence_loading_text.configure_vr_panel(xr_active)
		source_sequence_loading_text.add_child(preload("res://source_cinematic_surround.gd").new())
		var font:=material_for_texture("FONT.BIN")
		var layout:Dictionary=runtime_tables.mainMenu.duplicate(true)
		layout.labels=[{"text":"LOADING INTRO","y":112},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0},{"text":"","y":0}]
		source_sequence_loading_text.set_text(preload("res://source_menu_text.gd").layout(layout,[65536,65536,65536,65536,65536],false),font.data,font.material.albedo_texture)
		return true
	var display := preload("res://source_sequence_screen.gd").new()
	if not source_sequence_loading and source_cutscene_screen==null:capture_source_cinematic_view()
	add_child(display)
	var state := source_cutscene_transport_state.duplicate(true)
	state.mix = source_cd_mix_state.get("mix",[]).duplicate()
	state.threaded = true
	if not preparation.is_empty():state.preparation=preparation
	if state.filter.is_empty(): state.filter = preload("res://source_xa_zigzag.gd").new().snapshot()
	if not display.setup(content_root,manifest,runtime_tables,scene_id,state,head if xr_active else camera):
		source_transition_fault = display.session.fault
		display.queue_free()
		return false
	source_cutscene_screen = display
	source_cutscene_cpu_max_us = 0
	source_cutscene_progress = {"scene":scene_id,"presented_index":-1,"complete":false,"paused":false}
	hide_source_cinematic_world()
	source_main_mode = 2 if scene_id == 0 else 4
	source_controller_enabled = false
	source_fade_state.clear(); source_fade_phase = ""
	if is_instance_valid(source_fade_overlay): source_fade_overlay.set_source_level(0)
	report_runtime()
	return true

func enter_source_final_ending(level: int) -> bool:
	var sequence := preload("res://source_stage_end.gd").sequence_id(level)
	if sequence not in [15,16]:
		source_transition_fault = "Invalid final ending level"; return false
	if not enter_source_sequence(sequence): return false
	for slot in source_voice_nodes.keys().duplicate():
		if is_instance_valid(source_voice_nodes[slot]):
			retire_imported_voice(source_voice_nodes[slot])
	for slot in range(4,24): source_voice_pool.release(slot)
	source_pending_exit.clear()
	source_ending_root = sequence
	return true

func enter_source_story_return(kind: String, level: int) -> bool:
	var sequence := preload("res://source_stage_end.gd").sequence_id(level)
	if not enter_source_sequence(sequence): return false
	source_story_return = {"kind":kind,"sequence":sequence}
	for slot in source_voice_nodes.keys().duplicate():
		if is_instance_valid(source_voice_nodes[slot]):
			retire_imported_voice(source_voice_nodes[slot])
	for slot in range(4,24): source_voice_pool.release(slot)
	return true

func enter_source_secret_unlock(level: int) -> bool:
	if not enter_source_sequence(7): return false
	source_secret_unlock_return = {"level":level}
	for slot in source_voice_nodes.keys().duplicate():
		if is_instance_valid(source_voice_nodes[slot]):
			retire_imported_voice(source_voice_nodes[slot])
	for slot in range(4,24): source_voice_pool.release(slot)
	return true

func finish_source_secret_unlock(scene: int) -> bool:
	if scene != 7 or source_secret_unlock_return.is_empty():
		source_transition_fault = "Unexpected secret-island sequence completion"; return false
	var level := int(source_secret_unlock_return.level); source_secret_unlock_return.clear()
	# Native15d04..15d20 runs only after JIG7 finishes (including source skip).
	source_menu_state.selected_index = 40
	source_menu_progress_flags[40] = 0x4000
	source_level_script_state = 0
	if level in [47,54]: return enter_source_final_ending(level)
	if preload("res://source_stage_end.gd").sequence_id(level) != 0: return enter_source_story_return("selector",level)
	if not apply_source_island_selection(): return false
	source_pending_exit.clear()
	source_resume_input_baseline_pending = true
	source_fade_state = preload("res://source_transition_fade.gd").start(1)
	source_fade_phase = "in"
	return true

func finish_source_story_return(scene: int) -> bool:
	if source_story_return.is_empty() or int(source_story_return.sequence) != scene:
		source_transition_fault = "Unexpected story sequence completion"; return false
	var kind := str(source_story_return.kind); source_story_return.clear()
	var returned := apply_source_island_selection() if kind == "selector" else apply_source_next_level_return(true) if kind == "next-level" else apply_source_stage_return(true)
	if not returned: return false
	source_pending_exit.clear()
	source_fade_state = preload("res://source_transition_fade.gd").start(1)
	source_fade_phase = "in"
	return true

func advance_source_ending_route(finished_scene: int) -> bool:
	var route := preload("res://source_ending_route.gd").after_sequence(source_ending_root)
	if int(route.get("mode",-1)) != 7:
		source_transition_fault = "Missing original ending route"; return false
	if finished_scene == 15: return enter_source_sequence(19)
	if finished_scene != (19 if source_ending_root == 15 else 16):
		source_transition_fault = "Unexpected ending sequence completion"; return false
	return enter_source_credits(int(route.credits_variant),bool(route.credits_available),int(route.return_mode))

func enter_source_credits(variant: int, available: bool, return_mode: int = 0) -> bool:
	if return_mode not in [0,5]: source_transition_fault = "Invalid original credits return mode"; return false
	var destination := source_title_destination(7)
	if destination.has("fault") or not load_room(str(destination.get("map",""))):
		source_transition_fault = "Original credits scenery load failed"; return false
	source_controller_enabled = false
	update_source_input(0,0)
	tick_source_actors()
	if is_instance_valid(source_camera_override_one): actor.position = source_camera_override_one.position
	update_camera()
	var display := preload("res://source_credits_screen.gd").new()
	(rig if xr_active else camera).add_child(display)
	if not display.setup(content_root,manifest,variant,head if xr_active else camera,2.5,true):
		source_transition_fault = display.presenter.fault; display.queue_free(); return false
	source_credits_screen = display
	source_credits_return_mode = return_mode
	if is_instance_valid(hud): source_credits_hud_visible = hud.visible; hud.hide()
	source_main_menu_credits_available = available
	source_ending_root = -1
	source_main_mode = 7; source_transition_state = 0
	source_fade_state.clear(); source_fade_phase = ""
	if is_instance_valid(source_fade_overlay): source_fade_overlay.set_source_level(255)
	return true

func process_source_credits(delta: float) -> bool:
	source_credits_screen.set_paused(not xr_gameplay_is_focused())
	var result: Dictionary = source_credits_screen.advance(delta)
	if result.has("fault"): source_transition_fault = str(result.fault); return false
	for tick in range(int(result.get("ticks",0))): tick_source_actors()
	if is_instance_valid(source_fade_overlay) and source_credits_screen.get("has_world_background") == true:
		source_fade_overlay.set_source_level(int(source_credits_screen.fade.level))
	if is_instance_valid(source_camera_override_one): actor.position = source_camera_override_one.position
	if int(result.get("ticks",0)) != 0: update_camera()
	if bool(result.get("complete",false)):
		source_credits_screen.queue_free(); source_credits_screen = null
		if is_instance_valid(hud): hud.visible = source_credits_hud_visible
		var returned := apply_source_island_selection() if source_credits_return_mode == 5 else apply_source_demo_title_return()
		if not returned: return false
		source_fade_state = preload("res://source_transition_fade.gd").start(7)
		source_fade_phase = "in"
		if is_instance_valid(source_fade_overlay): source_fade_overlay.set_source_level(255)
	return true

func finish_source_opening() -> bool:
	# Native first-boot mode2 plays scene0 then writes mode0, without538ac reset.
	var destination := source_title_destination(0)
	if destination.has("fault") or not load_room(str(destination.get("map",""))):
		source_transition_fault = "Original opening return title load failed"
		return false
	source_controller_enabled = false
	source_transition_state = 0
	update_source_input(0,0)
	source_player_input_state = {"pad_mode":1}
	return true

func enter_source_sad_cutscene() -> bool:
	capture_source_cinematic_view()
	if source_cd_mix_state.get("mix",[]).size() != 4:
		source_transition_fault = "Missing source cutscene CD mix"
		return false
	var display := preload("res://source_cutscene_screen.gd").new()
	add_child(display)
	var state := source_cutscene_transport_state.duplicate(true)
	state.mix = source_cd_mix_state.mix.duplicate()
	state.threaded = true
	if state.filter.is_empty(): state.filter = preload("res://source_xa_zigzag.gd").new().snapshot()
	if not display.setup_sad(content_root,manifest,runtime_tables,state,head if xr_active else camera):
		source_transition_fault = display.session.fault
		display.queue_free()
		return false
	source_cutscene_screen = display
	source_cutscene_cpu_max_us = 0
	source_cutscene_progress = {"scene":20,"presented_index":-1,"complete":false,"paused":false}
	clear_source_game_over_screen()
	hide_source_cinematic_world()
	source_main_mode = 6
	source_controller_enabled = false
	source_fade_state.clear()
	source_fade_phase = ""
	if is_instance_valid(source_fade_overlay): source_fade_overlay.set_source_level(0)
	report_runtime()
	return true

func process_source_sad_cutscene(delta: float) -> bool:
	if not is_instance_valid(source_cutscene_screen): return false
	var focused := xr_gameplay_is_focused()
	source_cutscene_screen.set_paused(not focused)
	source_cutscene_progress.paused = not focused
	report_elapsed += delta
	if report_elapsed >= 1.0:
		report_elapsed = 0.0
		report_runtime()
	if not focused: return true
	sample_source_player_controls()
	var prior_fade: Dictionary = source_cutscene_screen.session.player.fade.duplicate(true)
	var cpu_start := Time.get_ticks_usec()
	var result: Dictionary = source_cutscene_screen.advance(roundi(delta*1000000.0),int(source_input_held_mask) if source_input_held_mask != null else 0,1)
	source_cutscene_cpu_max_us = maxi(source_cutscene_cpu_max_us,Time.get_ticks_usec()-cpu_start)
	source_cutscene_progress.merge({"presented_index":source_cutscene_screen.session.player.last_index,"available_sectors":source_cutscene_screen.session.timeline.clock.clock.cursor,"complete":bool(result.get("complete",false)),"audio_started":source_cutscene_screen.session.audio.started,"decoder_queued_frames":source_cutscene_screen.session.audio.stream.queued_frames,"cpu_max_us":source_cutscene_cpu_max_us,"fault":str(result.get("fault",""))},true)
	if result.has("fault"):
		source_transition_fault = str(result.fault)
		return false
	if not result.get("presented",[]).is_empty() and bool(prior_fade.get("active",false)) and source_fade_override != 1:
		var audio_math = preload("res://source_audio_math.gd")
		if int(prior_fade.kind) in [1,3,7]:
			source_audio_master_gain = audio_math.fade_half_up(source_audio_master_gain,source_audio_master_step,source_audio_master_maximum)
		elif audio_math.should_fade_out(source_transition_state,int(source_pickup_counts[3]),source_main_mode,0):
			source_audio_master_gain = audio_math.fade_half_down(source_audio_master_gain,source_audio_master_step)
	if bool(result.get("complete",false)):
		var opening := source_main_mode == 2
		var finished_scene := int(source_cutscene_progress.scene)
		source_cutscene_screen.queue_free()
		source_cutscene_screen = null
		if not source_secret_unlock_return.is_empty():
			if not finish_source_secret_unlock(finished_scene): return false
		elif source_ending_root >= 0:
			if not advance_source_ending_route(finished_scene): return false
		elif not source_story_return.is_empty():
			if not finish_source_story_return(finished_scene): return false
		elif opening:
			if not finish_source_opening(): return false
		else:
			if not apply_source_demo_title_return(): return false
			source_fade_state = preload("res://source_transition_fade.gd").start(7)
			source_fade_phase = "in"
		report_runtime()
	return true
func initialize_source_audio_options() -> bool:
	var defaults: Dictionary = runtime_tables.get("optionsStartup",{})
	if not defaults.has_all(["musicVolume","effectsVolume","stereoFlag"]): return false
	source_music_volume = int(defaults.musicVolume)
	source_effects_volume = int(defaults.effectsVolume)
	source_cd_stereo_flag = int(defaults.stereoFlag)
	# Original4fa54 invokes516d4 after assigning the options defaults.
	source_cd_mix_state = preload("res://source_cd_fade.gd").restore(source_music_volume,source_cd_stereo_flag)
	source_cd_fade_counter = int(source_cd_mix_state.counter)
	return true

func source_options_font_data() -> Dictionary:
	var binding: Dictionary = manifest.get("optionsFont",{})
	if not binding.has_all(["file","sha256","executableSha256"]):return {"fault":"Missing imported Options font metadata"}
	if FileAccess.get_sha256(content_root.path_join(str(binding.file)))!=str(binding.sha256):return {"fault":"Options font payload hash mismatch"}
	var data := read_json(str(binding.file))
	if int(data.get("schema",0))!=1 or data.get("executableSha256","")!=binding.executableSha256 or not data.has_all(["glyphs","headingGlyphs"]):return {"fault":"Invalid Options font provenance or tables"}
	return data

func apply_source_options_audio(state: Dictionary) -> bool:
	if not source_cd_mix_state.has_all(["counter","decrement","mix"]): return false
	if not state.has_all(["audio","effects_restore_volume","effects_maximum","effects_step"]) or not state.audio is Dictionary or not state.audio.has_all(["music","effects","mode"]): return false
	for value in [state.audio.music,state.audio.effects,state.effects_restore_volume,state.effects_maximum]:
		if not value is int or value < 0 or value > 127: return false
	if not state.audio.mode is int or state.audio.mode not in [0,1,2] or not state.effects_step is int: return false
	if state.effects_step != preload("res://source_audio_math.gd").fade_step(state.effects_maximum): return false
	var events = state.get("cd_mix_events",[])
	if not events is Array: return false
	var mix: Dictionary = source_cd_mix_state.duplicate(true)
	for event in events:
		if not event is Dictionary or not event.has_all(["option_volume","stereo_flag","counter","decrement","mix"]): return false
		for value in [event.option_volume,event.stereo_flag,event.counter,event.decrement]:
			if not value is int: return false
		if preload("res://source_music_transport.gd").validate_options_mix(event.option_volume,event.stereo_flag,event).has("fault"): return false
		mix = event.duplicate(true)
	if not events.is_empty():
		if mix.option_volume != state.audio.music or mix.stereo_flag != state.audio.mode: return false
	elif state.audio.music != source_music_volume or state.audio.mode != source_cd_stereo_flag:
		return false # A changed music setting must carry its native helper events.
	# Validate the complete update before changing any live option or fade field.
	if is_instance_valid(source_options_music_backend) and not source_options_music_backend.transport.session.current.is_empty() and not events.is_empty():
		var applied: Dictionary=source_options_music_backend.transport.apply_options_events(events)
		if applied.has("fault"):return false
	if is_instance_valid(source_gameplay_music) and not source_gameplay_music.transport.session.current.is_empty() and not events.is_empty():
		var applied: Dictionary=source_gameplay_music.transport.apply_options_events(events)
		if applied.has("fault"):return false
	if not apply_source_effects_option_state(state): return false
	source_music_volume = state.audio.music
	source_cd_stereo_flag = state.audio.mode
	source_cd_mix_state = mix
	source_cd_fade_counter = int(mix.counter)
	return true

func source_live_demo_buttons() -> int:
	var stick := left.get_vector2("primary") if xr_active else Input.get_vector("move_left","move_right","move_forward","move_back")
	if xr_active:
		stick.y = -stick.y
	var raw := 65535
	if stick.y < -0.25: raw &= ~0x10
	if stick.y > 0.25: raw &= ~0x40
	if stick.x > 0.25: raw &= ~0x20
	if stick.x < -0.25: raw &= ~0x80
	if Input.is_action_pressed("jump") or (xr_active and (right.is_button_pressed("ax_button") or right.is_button_pressed("trigger_click"))): raw &= ~0x4000
	if Input.is_action_pressed("attack") or (xr_active and right.is_button_pressed("by_button")): raw &= ~0x8000
	if Input.is_key_pressed(KEY_F) or (xr_active and left.is_button_pressed("ax_button")): raw &= ~0x2000
	return preload("res://source_input.gd").digital_pad(raw,0,3)

func start_source_demo_playback() -> bool:
	if source_main_mode != 3 or source_demo_frames.size() != 900 or not is_instance_valid(source_player_actor):
		source_transition_fault = "Original demo scene is not initialized"
		return false
	if not is_instance_valid(source_fade_overlay):
		source_fade_overlay = preload("res://source_fade_overlay.gd").new()
		var view: Camera3D = head if xr_active else camera
		view.add_child(source_fade_overlay)
	source_fade_state = preload("res://source_transition_fade.gd").start(1) # Mode3 entry134fc->13a0c.
	source_fade_phase = "in"
	source_demo_playing = true
	return true

func load_source_demo_recording(recorded_map: String) -> bool:
	source_demo_frames.clear()
	var name := recorded_map.replace(".MAP",".DEM")
	for recording in manifest.get("demos",[]):
		if str(recording.name) == name:
			var data := read_json(recording.file)
			if data.get("frames",[]).size() == 900:
				source_demo_frames = data.frames
				return true
	source_transition_fault = "Missing original demo recording for "+recorded_map
	return false

func sample_source_demo_controls(tick: int) -> bool:
	var previous := int(source_input_held_mask) if source_input_held_mask != null else 0
	var result: Dictionary = preload("res://source_demo_input.gd").sample(source_demo_frames,tick,previous)
	if result.has("fault"):
		source_transition_fault = str(result.fault)
		return false
	update_source_input(int(result.held),previous)
	source_player_input_state = {"pad_mode":1}
	jump_held = (int(result.held)&0x800000) != 0
	return true

func initialize_source_demo_scene(destination: Dictionary) -> bool:
	if not destination.has("level") or not destination.has("room"):
		source_transition_fault = "Incomplete original demo destination"
		return false
	var recorded_map := "MP%03d_%02d.MAP" % [int(destination.level),int(destination.room)]
	if not load_source_demo_recording(recorded_map):
		return false
	# Outer13034/13064 precedes mode3 initial-arrival24e68 and player factory.
	source_player_movement_state = preload("res://source_player_movement.gd").reset_motion_state(source_player_movement_state)
	source_input_suppression_count = 0
	source_runtime_enabled = true
	if not load_room(recorded_map):
		source_transition_fault = "Original demo scene load failed"
		return false
	source_main_mode = 3
	source_transition_state = 0
	update_source_input(0,0)
	source_player_input_state = {"pad_mode":1}
	var player = create_source_player()
	if player == null or player.vm.fault != "":
		source_transition_fault = "Original demo player initialization failed"
		return false
	visual.hide()
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.position = player.position
	actor.velocity = Vector3.ZERO
	# Scene construction only: attract dispatch/clock must enable recorded playback.
	source_controller_enabled = false
	source_transition_fault = ""
	return true
var source_controller_enabled := false
var source_runtime_enabled := false # Actor construction is independent of input/focus.
var source_resume_input_baseline_pending := false
var vr_controls = preload("res://vr_controls.gd").new()
var vr_settings: Node = null
var vr_head_collision_overlay: MeshInstance3D = null
var vr_head_collision_fade := 0.0
var vr_head_collision_overlapping := false
var vr_camera_anchor := Vector3.ZERO
var vr_camera_anchor_initialized := false
var vr_vertical_state: Dictionary = {}
var source_level_title: MeshInstance3D
var source_level_title_names: Array = []
var source_level_title_level := -1
var source_level_title_mode := -1
var source_level_title_remaining := 0.0
var source_gameplay_hud: Node3D
var source_gameplay_hud_state: Dictionary = {}
var source_hud_bonus_revision := 0
var source_hud_pickup_revisions := {1:0,2:0,3:0}

func update_source_gameplay_hud() -> void:
	var paused: bool = source_main_mode==8 and source_options_parent_mode==4
	var active: bool = source_main_mode==4 or paused
	var input := {"level":int(map_name.substr(2,3)),"crystals":int(source_pickup_counts[1]),"gobbos":int(source_pickup_counts[2]),"lives":int(source_pickup_counts[3]),"mask":int(source_bonus_mask),"bonus_revision":source_hud_bonus_revision,"bonus_request":int(source_bonus_display_timer) if source_bonus_display_timer!=null else 60,"life_request":int(source_pickup_display_timer) if source_pickup_display_timer!=null else 240}
	input.crystals_revision=int(source_hud_pickup_revisions[1]);input.gobbos_revision=int(source_hud_pickup_revisions[2]);input.lives_revision=int(source_hud_pickup_revisions[3])
	input.hidden=not source_fade_phase.is_empty()
	var index := -1
	for candidate in range(runtime_tables.menuLevels.values.size()):
		if int(runtime_tables.menuLevels.values[candidate])==int(input.level):index=candidate;break
	input.gobbo_enabled=index>=0 and index<40 and index%10 not in [3,4,8,9]
	source_gameplay_hud_state=preload("res://source_gameplay_hud.gd").step(source_gameplay_hud_state,input,source_tick_count,active,paused)
	if not active or not source_fade_phase.is_empty():
		if is_instance_valid(source_gameplay_hud):source_gameplay_hud.hide()
		return
	var view: Camera3D=head if xr_active else camera
	if not is_instance_valid(source_gameplay_hud):
		source_gameplay_hud=preload("res://source_gameplay_hud_renderer.gd").new()
		view.add_child(source_gameplay_hud);source_gameplay_hud.configure(xr_active)
	elif source_gameplay_hud.vr!=xr_active:
		source_gameplay_hud.reparent(view);source_gameplay_hud.transform=Transform3D.IDENTITY
		source_gameplay_hud.configure(xr_active)
	var bindings := {"track":material_for_texture("TK%02d_TRK.BIN"%int(room_data.style)),"bonus":material_for_texture("TK%02d_ENM.BIN"%int(room_data.style))}
	if bindings.track.is_empty() or bindings.bonus.is_empty():return
	if source_gameplay_hud.present(source_gameplay_hud_state,paused,bindings):source_gameplay_hud.show()
	hud.hide()

func update_source_level_title(delta: float) -> void:
	var paused: bool = source_main_mode==8 and source_options_parent_mode==4
	var title_mode := 4 if paused else source_main_mode
	if source_level_title_names.is_empty():
		var resource: Dictionary = manifest.get("levelNames",{})
		if not resource.has("file"): return
		var data: Dictionary = read_shared_content(str(resource.file))
		if data.get("names",[]).size()!=100: return
		source_level_title_names=data.names
	var title := preload("res://source_level_title.gd").resolve(title_mode,map_name,int(source_menu_state.selected_index),runtime_tables,source_level_title_names)
	if title.is_empty():
		if is_instance_valid(source_level_title):source_level_title.hide()
		source_level_title_mode=title_mode
		return
	var changed: bool = int(title.level)!=source_level_title_level
	if changed or (title_mode==4 and source_level_title_mode!=4):source_level_title_remaining=6.0
	if not is_instance_valid(source_level_title):
		source_level_title=preload("res://source_menu_text_renderer.gd").new()
		var view: Camera3D=head if xr_active else camera
		view.add_child(source_level_title)
		source_level_title.configure_vr_panel(xr_active)
		if xr_active:source_level_title.scale*=1.75
		changed=true
	if source_level_title.frame_buttons_enabled != xr_active:
		var view: Camera3D=head if xr_active else camera
		source_level_title.reparent(view)
		source_level_title.rotation=Vector3.ZERO
		source_level_title.configure_vr_panel(xr_active)
		if xr_active:source_level_title.scale*=1.75
		changed=true
	if changed:
		var font := material_for_texture("FONT.BIN")
		var row := preload("res://source_game_over_text.gd").level_name_row(runtime_tables.get("gameOver",{}),source_level_title_names,int(title.level))
		if font.is_empty() or row.has("fault"):return
		for glyph in row.glyphs:glyph.position.y=20
		if not source_level_title.set_text({"labels":[row]},font.data,font.material.albedo_texture):return
	if xr_active:
		source_level_title.scale=Vector3(1.6,0.75,1.0)*(1.0 if title_mode==5 else 1.75)
	source_level_title_level=int(title.level)
	source_level_title_mode=title_mode
	var selector: bool = source_main_mode==5 and int(source_menu_state.get("save_mode",0))==0 and int(source_menu_state.get("dialog_mode",0))==0
	var unobscured: bool = source_fade_phase.is_empty() and (paused or vr_settings==null or not vr_settings.opened)
	source_level_title.visible=unobscured and (paused or selector or (title_mode==4 and source_level_title_remaining>0.0))
	if source_main_mode==4 and unobscured:source_level_title_remaining=maxf(0.0,source_level_title_remaining-delta)
var vr_traversal_view_blend := 0.0
var modern_previous_traversal := 0
var vr_camera_pitch := 0.0
var vr_menu_view: Dictionary = {}
var vr_turn_focused := false
const VR_CAMERA_GUARD_RADIUS := 0.30
const VR_CAMERA_WALL_MARGIN := 0.08
const VR_HEAD_CLIP_RADIUS := 0.10
var vr_recenter_interface: Object
var vr_initial_center_pending := false
var vr_recenter_count := 0

func connect_vr_recenter(interface: Object = null) -> void:
	vr_recenter_interface=interface if interface!=null else XRServer.find_interface("OpenXR")
	if vr_recenter_interface!=null and vr_recenter_interface.has_signal("pose_recentered") and not vr_recenter_interface.is_connected("pose_recentered",recenter_vr_view):
		vr_recenter_interface.connect("pose_recentered",recenter_vr_view,CONNECT_DEFERRED)
	if not XRServer.reference_frame_changed.is_connected(reset_vr_head_clearance):
		XRServer.reference_frame_changed.connect(reset_vr_head_clearance,CONNECT_DEFERRED)
	vr_initial_center_pending=xr_active
func center_stage_tracking() -> void:
	# Stage does not move its origin when the user holds Meta/recenter.
	# Local/Local Floor are moved by the runtime and must not be centered twice.
	if vr_recenter_interface!=null and vr_recenter_interface.is_initialized() and vr_recenter_interface.get_play_area_mode()==XRInterface.XR_PLAY_AREA_STAGE:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT,true)
func recenter_vr_view() -> void:
	if not xr_active:return
	center_stage_tracking()
	vr_initial_center_pending=false;vr_recenter_count+=1
	reset_vr_head_clearance()
func reset_vr_head_clearance() -> void:
	vr_head_collision_overlapping=false;vr_head_collision_fade=0.0
	if is_instance_valid(vr_head_collision_overlay):vr_head_collision_overlay.set_source_level(0)
	vr_controls.reset_gestures();source_resume_input_baseline_pending=true
func center_initial_vr_pose() -> void:
	if not vr_initial_center_pending:return
	var tracker:=XRServer.get_tracker("head") as XRPositionalTracker
	if tracker==null:return
	var pose:=tracker.get_pose("default")
	if pose!=null and pose.has_tracking_data:recenter_vr_view()

func _process(delta: float) -> void:
	if source_sequence_loading and not is_instance_valid(source_startup_movie) and not source_sequence_load.is_alive():
		var preparation:Dictionary=source_sequence_load.wait_to_finish()
		source_sequence_loading=false
		if is_instance_valid(source_sequence_loading_text):source_sequence_loading_text.queue_free()
		if preparation.has("fault"):source_transition_fault=str(preparation.fault);finish_source_opening()
		else:
			source_opening_preparation=preparation
			enter_source_sequence(0,preparation)
	if imported and (not xr_active or xr_gameplay_is_focused()):record_runtime_cost("frame_interval",roundi(delta*1000000.0))
	# Source callback12bc4 advances even while gameplay/menu clocks are paused.
	source_frame_clock.advance(delta)
	if not imported:
		return
	if not xr_gameplay_is_focused():
		vr_turn_focused = false
		vr_controls.reset_gestures()
		return
	center_initial_vr_pose()
	update_source_level_title(delta)
	update_source_gameplay_hud()
	if not vr_turn_focused:
		vr_turn_focused = true
		vr_controls.reset_gestures()
	if (vr_settings == null or not vr_settings.opened) and source_main_mode not in [8,9,10,11] and not source_sequence_loading and not is_instance_valid(source_cutscene_screen) and not is_instance_valid(source_startup_movie):
		var axis := right.get_vector2("primary").x if xr_active else Input.get_axis("turn_left","turn_right")
		yaw += vr_controls.turn_delta(axis,delta)
		if xr_active:
			var tilt := right.get_vector2("primary").y
			if absf(tilt) > 0.2:
				vr_camera_pitch = clampf(vr_camera_pitch-tilt*delta*0.6,-0.35,0.55)
				vr_controls.camera_tilt=vr_camera_pitch
		update_vr_camera_anchor(delta)
	update_camera()
	if xr_active and is_instance_valid(vr_head_collision_overlay):
		vr_head_collision_fade = vr_controls.collision_fade(vr_head_collision_fade,vr_head_collision_overlapping,delta)
		vr_head_collision_overlay.set_source_level(ceili(vr_head_collision_fade))
func update_vr_camera_anchor(delta: float) -> void:
	var target := actor.position
	var traversal_mode := player_traversal_mode()
	vr_traversal_view_blend = lerpf(vr_traversal_view_blend,1.0 if traversal_mode in [7,8,9] else 0.0,1.0-exp(-18.0*delta))
	var steady_jump_height: bool = xr_active and vr_controls.jump_camera=="steady" and source_main_mode == 4 and is_instance_valid(source_player_actor) and source_player_actor.source_name == "Croc"
	if not vr_camera_anchor_initialized:
		vr_camera_anchor = target
		vr_camera_anchor_initialized = true
		vr_vertical_state=preload("res://vr_vertical_follow.gd").initialize(target.y)
	else:
		if source_camera_hold_counter == 0:
			vr_camera_anchor.x=lerpf(vr_camera_anchor.x,target.x,1.0-exp(-10.0*delta))
			vr_camera_anchor.z=lerpf(vr_camera_anchor.z,target.z,1.0-exp(-10.0*delta))
		if steady_jump_height:
			var grounded: bool = traversal_mode in [7,8,9,11] or ((int(source_player_actor.secondary_flags)&2)!=0 and (int(source_player_actor.primary_flags)&0x600)==0)
			vr_vertical_state=preload("res://vr_vertical_follow.gd").step(vr_vertical_state,target.y,grounded,delta)
			vr_camera_anchor.y=float(vr_vertical_state.height)
		else:
			vr_camera_anchor.y=lerpf(vr_camera_anchor.y,target.y,1.0-exp(-10.0*delta))
			vr_vertical_state=preload("res://vr_vertical_follow.gd").initialize(vr_camera_anchor.y)

func _unhandled_input(event: InputEvent) -> void:
	if vr_settings != null and vr_settings.keyboard(event):
		get_viewport().set_input_as_handled()

func xr_session_snapshot() -> Dictionary:
	var interface := XRServer.find_interface("OpenXR")
	var initialized := interface != null and interface.is_initialized()
	return {"initialized":initialized,"state":int(interface.get_session_state()) if initialized else 0}

func xr_gameplay_is_focused() -> bool:
	if not xr_active:
		return true
	var session := xr_session_snapshot()
	return bool(session.initialized) and int(session.state) == OpenXRInterface.SESSION_STATE_FOCUSED

func sample_source_player_controls() -> void:
	var stick := Input.get_vector("move_left","move_right","move_forward","move_back",0.0 if vr_controls.layout == "modern" else -1.0)
	var jump := Input.is_action_pressed("jump")
	var attack := Input.is_action_pressed("attack")
	if xr_active:
		stick = left.get_vector2("primary")
		stick.y = -stick.y
		jump = jump or right.is_button_pressed("ax_button") or right.is_button_pressed("trigger_click")
		attack = attack or right.is_button_pressed("by_button")
	var modern: bool = vr_controls.layout == "modern" and source_main_mode == 4 and source_player_actor != null and source_player_actor.source_name == "Croc"
	var virtual_analog := not modern and int(source_options_state.get("pad_kind",1))==2
	var precision := Input.is_action_pressed("precision_move") or (xr_active and left.is_button_pressed("grip_click"))
	var turn_only := Input.is_action_pressed("turn_in_place") or (xr_active and left.is_button_pressed("primary_click"))
	var traversal_mode := player_traversal_mode()
	var traversal: bool = modern and traversal_mode in [7,8,9,11]
	if source_resume_input_baseline_pending:
		vr_controls.reset_gestures()
	var raw := 65535
	if Input.is_action_pressed("source_select") or (xr_active and source_main_mode==8 and left.is_button_pressed("primary_click")):raw &= ~1
	if not modern and not virtual_analog and stick.y < -0.25:
		raw &= ~0x10
	if not modern and not virtual_analog and stick.y > 0.25:
		raw &= ~0x40
	if not modern and not virtual_analog and stick.x > 0.25:
		raw &= ~0x20
	if not modern and not virtual_analog and stick.x < -0.25:
		raw &= ~0x80
	if not modern and not virtual_analog and source_main_mode==4 and precision and absf(stick.x)>0.25:
		# Original L1/R1 sidesteps; Shift/grip precision must not emit turns.
		raw |= 0x20|0x80
		raw &= ~(0x800 if stick.x>0 else 0x400)
	# Swimming's source controller has a separate lateral-stroke palette.
	# Gentle lateral intent must expose those shoulder-button queries too.
	var swimmer: bool = source_player_actor != null and source_player_actor.source_name == "SwimmingCroc"
	if vr_controls.layout == "modern" and swimmer and (stick.length()<0.49 or precision) and absf(stick.x)>absf(stick.y) and absf(stick.x)>0.15:
		raw |= 0x20|0x80
		raw &= ~(0x800 if stick.x>0.0 else 0x400)
	if jump:
		raw &= ~0x4000
	if attack:
		raw &= ~(0x8000 if source_main_mode==4 else 0x1000)
	if Input.is_key_pressed(KEY_F) or (xr_active and left.is_button_pressed("ax_button")):
		raw &= ~0x2000
	if modern and not precision and not turn_only and not traversal and vr_controls.reversal(stick,float(source_tick_count)/30.0):
		raw &= ~0x2000
	if modern and (precision or turn_only):
		vr_controls.last_direction_time = -1.0
	var previous := int(source_input_held_mask) if source_input_held_mask != null else 0
	jump_held = jump
	if virtual_analog:
		var right_stick: Vector2=right.get_vector2("primary") if xr_active else Vector2(Input.get_axis("turn_left","turn_right"),0)
		if xr_active:right_stick.y=-right_stick.y
		var packet := preload("res://source_virtual_pad.gd").analog_packet(stick,right_stick,raw)
		var decoded := update_source_analog_packet(packet,previous)
		if decoded.has("fault"):source_transition_fault=str(decoded.fault)
		return
	if modern:
		var view: Camera3D = head if xr_active else camera
		source_player_input_state = vr_controls.analog_input(stick,-view.global_basis.z)
		source_player_input_state.precision = precision
		source_player_input_state.turn_only = turn_only
		source_player_input_state.traversal = traversal
		source_player_input_state.traversal_mode = traversal_mode if traversal else 0
		source_player_input_state.surface_axes = preload("res://modern_traversal.gd").axes(stick)
		source_player_input_state.turn_requested = (raw&0x2000)==0
		source_player_input_state = vr_controls.resolve_motion(source_player_input_state,int(source_player_actor.source_angles.y),(int(source_player_actor.secondary_flags)&2) != 0)
		if source_player_input_state.turn_only:
			source_player_input_state.turn_axis = stick.x
		if bool(source_player_input_state.natural_step):
			var f := float(source_player_input_state.local_forward)
			var s := float(source_player_input_state.local_side)
			if f < -0.35 and absf(f)>=absf(s): raw &= ~0x40
			if s > 0.35 and absf(s)>absf(f): raw &= ~0x400
			if s < -0.35 and absf(s)>absf(f): raw &= ~0x800
		if not bool(source_player_input_state.natural_step) and not precision and not turn_only and not traversal and stick.length()>16.0/127.0:
			raw &= ~0x10 # Source action queries still need a forward-motion button.
		if traversal:
			if stick.y < -0.15: raw &= ~0x10
			if stick.y > 0.15: raw &= ~0x40
			if stick.x > 0.15: raw &= ~0x20
			if stick.x < -0.15: raw &= ~0x80
		elif precision or int(source_player_movement_state.get("mode",0)) == 4:
			# Facing-relative precision movement exposes backward and sidestep actions.
			if stick.y < -0.15: raw &= ~0x10
			if stick.y > 0.15: raw &= ~0x40
			if stick.x > 0.15: raw &= ~(0x20 if traversal or int(source_player_movement_state.get("mode",0)) == 4 else 0x800)
			if stick.x < -0.15: raw &= ~(0x80 if traversal or int(source_player_movement_state.get("mode",0)) == 4 else 0x400)
	else:
		source_player_input_state = {"pad_mode":1}
	var scheme := 0 if modern or xr_active else int(source_options_state.get("scheme",0))
	update_source_digital_pad(raw,scheme,source_main_mode,previous)
	# Original ledge actions require fresh directional edges. Carry held up/down
	# intent into a newly acquired ledge so the player needn't release/repress.
	if modern and traversal_mode == 8 and modern_previous_traversal != 8:
		if stick.y < -0.15: source_input_pressed_mask = int(source_input_pressed_mask)|1
		elif stick.y > 0.15: source_input_pressed_mask = int(source_input_pressed_mask)|2
	modern_previous_traversal = traversal_mode if modern else 0

func player_traversal_mode() -> int:
	return int(source_extended_globals.get(0,0))>>16 if source_main_mode == 4 and is_instance_valid(source_player_actor) and source_player_actor.source_name == "Croc" else 0

func create_source_player() -> Node3D:
	if source_player_actor != null and is_instance_valid(source_player_actor):
		return source_player_actor
	if not source_pool.slots.has(source_player_id) or not source_player_entry_state.has("present"):
		return null
	var room_link: Dictionary = manifest.linkage.rooms.get(map_name,{})
	if bool(room_link.get("menu",false)):
		return null # Source menu loads entities without the gameplay-controller preload.
	var profile := str(room_link.get("profile",""))
	if not manifest.linkage.controllers.has(profile):
		return null
	var controller: Dictionary = manifest.linkage.controllers[profile]
	var definition: Dictionary = {}
	for candidate in manifest.linkage.definitions:
		if candidate.name == controller.actor:
			definition = candidate
			break
	var program: Dictionary = {}
	for asset in controller.assets:
		if int(asset.kind) == 1 and asset.name == controller.file:
			program = read_json(asset.file)
	if definition.is_empty() or program.is_empty():
		return null
	var player = ASLActor.new()
	player.source_pool_id = source_player_id
	restore_source_actor_pose_memory(player,source_player_id)
	terrain.add_child(player)
	player.set_physics_process(false)
	source_pool.slots[source_player_id].node = player
	player.configure(self,definition,program,{"name":controller.actor,"runtime_position":Vector3i.ZERO,"position":[0,0,0],"rotation":[0,0,0],"params":[],"waypoints":[]},manifest.linkage.bootstrap+controller.assets+room_link.get("assets",[]),false)
	source_actors.push_front(player)
	source_actor_references.refresh(source_actors)
	player.vm.run()
	player.refresh_source_render_pose()
	if not is_instance_valid(source_gameplay_music):
		source_gameplay_music=preload("res://source_gameplay_music.gd").new();add_child(source_gameplay_music)
		source_gameplay_music.automatic=true
	var music_request: Dictionary=source_gameplay_music.start_room(self)
	if music_request.has("fault"):push_error(str(music_request.fault))
	return player
var source_pickup_counts := {1:0,2:0,3:3} # Fresh game/level paths0x800150b0,0x8003aeb8.
var source_key_collected := 0 # Native gp+480 latch, set/cleared by commands78/79.
var source_gobbo_display_state := {"timer":null,"mode":null,"cursor":null}
var source_bonus_mask := 0
var source_level_script_state := 0 # Word0x80074ac4, fresh-level clear0x800150d0.
var source_stage_crystal_bank := 0 # Initialized word0x80074968.
var source_stage_stats_state: Dictionary = {}
var source_stage_stats_renderer: Node3D = null
var source_stage_stats_bindings: Dictionary = {}
var source_stage_pickup_slots: Array = [0,0,0,0,0,0,0,0] # New-game clear0x8003aed0.
var source_game_over_renderer: Node3D = null
var source_continue_state: Dictionary = {}
var source_password_entry_state: Dictionary = {}
var source_password_entry_renderer: Node3D = null
var source_password_entry_destination: Dictionary = {}

func clear_source_password_entry() -> void:
	if is_instance_valid(source_password_entry_renderer):
		source_password_entry_renderer.hide()
		source_password_entry_renderer.queue_free()
	source_password_entry_renderer = null
	source_password_entry_state.clear()

func refresh_source_password_entry(state: Dictionary) -> bool:
	var bindings := {}
	for key in ["font","backdrop"]:
		var filename := "FONT.BIN" if key == "font" else "STILLGOH.BIN"
		var binding := material_for_texture(filename)
		if binding.is_empty(): return false
		bindings[key] = {"data":binding.data,"texture":texture_cache[filename]}
	if not is_instance_valid(source_password_entry_renderer):
		source_password_entry_renderer = preload("res://source_game_over_renderer.gd").new()
		var view: Camera3D = head if xr_active else camera
		view.add_child(source_password_entry_renderer)
	source_password_entry_renderer.configure_vr_panel(xr_active)
	return source_password_entry_renderer.update_entry(runtime_tables,state,bindings)

func initialize_source_password_entry() -> bool:
	var state := preload("res://source_password_entry.gd").initialize()
	if not refresh_source_password_entry(state): return false
	source_password_entry_state = state
	source_password_entry_destination.clear()
	return true

func enter_source_password_entry() -> bool:
	if not initialize_source_password_entry(): return false
	for slot in source_voice_nodes.keys().duplicate():
		if is_instance_valid(source_voice_nodes[slot]):
			retire_imported_voice(source_voice_nodes[slot])
	for slot in range(4,24): source_voice_pool.release(slot)
	source_main_mode = 13
	source_controller_enabled = false
	source_transition_state = 0
	source_resume_input_baseline_pending = true
	if is_instance_valid(source_main_menu_text): source_main_menu_text.hide()
	for node in source_title_logo_nodes: node.hide()
	for node in source_title_effect_nodes: node.hide()
	return true

func process_source_password_entry() -> bool:
	if source_main_mode != 13: return true
	if not advance_source_password_entry(int(source_input_pressed_mask) if source_input_pressed_mask != null else 0): return false
	if source_fade_phase != "": return advance_source_transition()
	var decision := preload("res://source_password_return.gd").decide(13,int(source_password_entry_state.return_flag),false,false)
	if int(decision.start) != 0:
		if not is_instance_valid(source_fade_overlay):
			source_fade_overlay = preload("res://source_fade_overlay.gd").new()
			var view: Camera3D = head if xr_active else camera
			view.add_child(source_fade_overlay)
		source_fade_state = preload("res://source_transition_fade.gd").start(8)
		source_fade_phase = "password-out"
	return true

func apply_source_password_return() -> bool:
	var decision := preload("res://source_password_return.gd").decide(13,int(source_password_entry_state.return_flag),true,true)
	if not bool(decision.get("return",false)): return false
	if int(decision.target_mode) == 5:
		update_source_menu_unlocks()
		return apply_source_island_selection()
	return apply_source_demo_title_return()

func advance_source_password_entry(pressed: int) -> bool:
	var prior: Array = []
	for index in range(80): prior.append(int(source_menu_progress_flags.get(index,0)))
	var result := preload("res://source_password_validation.gd").advance(source_password_entry_state,pressed,runtime_tables.get("menuLevels",{}).get("values",[]),prior)
	if result.has("fault") or not refresh_source_password_entry(result): return false
	source_password_entry_state = result
	if result.has("progress"):
		var progress: Dictionary = result.progress
		for index in range(80): source_menu_progress_flags[index] = int(progress.flags[index])
		source_stage_pickup_slots = progress.pickup_words.duplicate()
		source_menu_announcement_history = progress.announcements.duplicate()
		source_menu_state.selected_index = int(progress.selected_index)
		source_pickup_counts[3] = int(progress.lives)
		if progress.has("crystal_bank"): source_stage_crystal_bank = int(progress.crystal_bank)
		source_password_entry_destination = {"level":int(progress.level),"room":int(progress.room)}
	for event in result.events:
		var sound := "START" if int(event.sound_handle) == 20264 else "SELECT" if int(event.sound_handle) == 20436 else "BON_BEEP" if int(event.sound_handle) == 20432 else ""
		if not sound.is_empty(): play_source_menu_sound(sound,float(event.volume),int(event.pitch))
	return true
var source_game_over_confirm_requires_release := false

func clear_source_game_over_screen() -> void:
	if is_instance_valid(source_game_over_renderer):
		source_game_over_renderer.hide()
		source_game_over_renderer.queue_free()
	source_game_over_renderer = null

func enter_source_game_over() -> bool:
	source_continue_state = preload("res://source_main_menu.gd").initialize(0,1)
	if not refresh_source_continue_screen(): return false
	# Outer12e08 calls2da98/2edd0(1);12e90 clears shared dialog20956.
	for slot in source_voice_nodes.keys().duplicate():
		if is_instance_valid(source_voice_nodes[slot]):
			retire_imported_voice(source_voice_nodes[slot])
	for slot in range(4,24): source_voice_pool.release(slot)
	source_menu_state.dialog_mode = 0
	source_main_mode = 14
	source_game_over_confirm_requires_release = false
	source_controller_enabled = false
	source_transition_state = 0
	source_fade_phase = ""
	source_fade_state = {"kind":8,"active":false,"ready":false,"counter":0,"level":0}
	if is_instance_valid(source_fade_overlay): source_fade_overlay.set_source_level(0)
	source_pending_exit.clear()
	source_transition_fault = ""
	return true

func refresh_source_continue_screen() -> bool:
	var font := material_for_texture("FONT.BIN")
	if font.is_empty(): return false
	if not is_instance_valid(source_game_over_renderer):
		source_game_over_renderer = preload("res://source_game_over_renderer.gd").new()
		var view: Camera3D = head if xr_active else camera
		view.add_child(source_game_over_renderer)
	source_game_over_renderer.configure_vr_panel(xr_active)
	return source_game_over_renderer.update_continue(runtime_tables,source_continue_state,{"font":{"data":font.data,"texture":texture_cache["FONT.BIN"]}})

func process_source_game_over() -> bool:
	if source_main_mode != 14: return true
	if source_fade_phase != "": return advance_source_transition()
	var held := int(source_input_held_mask) if source_input_held_mask != null else 0
	source_continue_state = preload("res://source_main_menu.gd").advance(source_continue_state,held,int(source_input_pressed_mask) if source_input_pressed_mask != null else 0)
	source_menu_state.dialog_mode = int(source_continue_state.selected)
	for change in range(int(source_continue_state.changes)): play_source_menu_sound("SELECT")
	if not refresh_source_continue_screen(): return false
	if source_game_over_confirm_requires_release:
		if (held & 0xf00200) == 0: source_game_over_confirm_requires_release = false
		return true
	var decision := preload("res://source_game_over_display_return.gd").decide(14,held,int(source_menu_state.dialog_mode),false,false)
	if int(decision.start) != 0:
		play_source_menu_sound("START")
		source_fade_state = preload("res://source_transition_fade.gd").start(8)
		source_fade_phase = "game-over-out"
	return true

func apply_source_game_over_return() -> bool:
	var decision := preload("res://source_game_over_display_return.gd").decide(14,0,int(source_menu_state.dialog_mode),true,true)
	if int(decision.target_mode) == 6: return enter_source_sad_cutscene()
	if int(decision.target_mode) != 5:
		source_transition_fault = "Unimplemented original game-over dialog destination"
		return false
	source_pickup_counts[3] = int(decision.lives)
	source_stage_crystal_bank = int(decision.crystal_bank)
	return apply_source_island_selection()

func refresh_source_game_over_screen() -> bool:
	if is_instance_valid(source_game_over_renderer): source_game_over_renderer.hide()
	var resource: Dictionary = manifest.get("levelNames",{})
	if not resource.has("file"):
		source_transition_fault = "Missing original level-name resource"
		return false
	var name_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(content_root.path_join(str(resource.file))))
	if not name_data is Dictionary or not name_data.has("names"):
		source_transition_fault = "Invalid original level-name resource"
		return false
	var bindings := {}
	for key in ["font","backdrop"]:
		var filename := "FONT.BIN" if key == "font" else "STILLGOH.BIN"
		var binding := material_for_texture(filename)
		if binding.is_empty():
			source_transition_fault = "Missing original password-screen atlas"
			return false
		bindings[key] = {"data":binding.data,"texture":texture_cache[filename]}
	if not is_instance_valid(source_game_over_renderer):
		source_game_over_renderer = preload("res://source_game_over_renderer.gd").new()
		var view: Camera3D = head if xr_active else camera
		view.add_child(source_game_over_renderer)
	source_game_over_renderer.configure_vr_panel(xr_active)
	var progress: Array = []
	for index in range(45): progress.append(int(source_menu_progress_flags.get(index,0)))
	if not source_game_over_renderer.update_screen(runtime_tables,name_data.names,progress,int(source_menu_state.selected_index),source_stage_pickup_slots,bindings):
		source_transition_fault = "Original password-screen composition failed"
		return false
	return true

func initialize_source_stage_stats(pickup_slots: Array = source_stage_pickup_slots) -> bool:
	var result: Dictionary = preload("res://source_stage_stats.gd").initialize(int(source_menu_state.selected_index),int(source_pickup_counts[1]),int(source_pickup_counts[2]),source_stage_crystal_bank,int(source_pickup_counts[3]),pickup_slots)
	if result.has("fault"):
		return false
	if not runtime_tables.has("stageResults"):
		return false
	var bindings := {}
	var names := {"font":"TK%02d_TRK.BIN"%int(room_data.style),"track":"TK%02d_TRK.BIN"%int(room_data.style),"shared":preload("res://source_stage_stats.gd").shared_texture_name(int(room_data.style))}
	for key in names:
		var binding := material_for_texture(names[key])
		if binding.is_empty(): return false
		bindings[key] = {"data":binding.data,"texture":texture_cache[names[key]]}
	var renderer := preload("res://source_stage_stats_renderer.gd").new()
	var view: Camera3D = head if xr_active else camera
	view.add_child(renderer)
	renderer.configure_vr_panel(xr_active)
	if not renderer.update_stats(result,runtime_tables.stageResults,bindings):
		renderer.queue_free()
		return false
	clear_source_stage_stats()
	source_stage_stats_renderer = renderer
	source_stage_stats_bindings = bindings
	source_stage_stats_state = result
	pulse_vr_feedback("complete")
	source_stage_crystal_bank = result.bank
	source_pickup_counts[3] = result.lives
	# Original LevelStats539d0 stops room music then starts cue64/loop0/seek0.
	if is_instance_valid(source_gameplay_music):
		var started: Dictionary=source_gameplay_music.start_request(self,64)
		if started.has("fault"):source_transition_fault=str(started.fault);return false
	return true
func clear_source_stage_stats() -> void:
	if is_instance_valid(source_stage_stats_renderer):
		source_stage_stats_renderer.hide()
		source_stage_stats_renderer.queue_free()
	source_stage_stats_renderer = null
	source_stage_stats_bindings.clear()
	source_stage_stats_state.clear()

func advance_source_stage_stats(pressed: int) -> void:
	source_stage_stats_state = preload("res://source_stage_stats.gd").advance(source_stage_stats_state,pressed,int(source_pickup_counts[1]))
	source_pickup_counts[1] = source_stage_stats_state.current_crystals
	for event in source_stage_stats_state.events:
		if runtime_tables.stageResults.get("sounds",{}).has(event):
			var sound: Dictionary = runtime_tables.stageResults.sounds[event]
			play_source_menu_sound(str(sound.name),float(sound.volume),int(sound.pitch))
	if is_instance_valid(source_stage_stats_renderer):
		if not source_stage_stats_renderer.update_stats(source_stage_stats_state,runtime_tables.stageResults,source_stage_stats_bindings):
			source_transition_fault = "Original stage-results renderer update failed"
var source_menu_state := {"selection_changes":0,"return_mode":0,"secret_return":0,"selected_index":0,"input_lock":0,"save_mode":0,"dialog_mode":0} # Fresh CRT menu words.
var source_menu_progress_flags: Dictionary = {} # Progress-array halfwords; fresh CRT state is zero.
var source_menu_announcement_history: Array = [0,0,0,0,0,0,0,0] # Source0x80074fc0; new-game clear3aee8.
var source_menu_reveal_state := 0 # Loaded raw word0x80074f88; reset on previous navigation142a0.
var source_main_menu_animation_state: Dictionary = preload("res://source_main_menu.gd").initialize(0,4)
var source_main_menu_credits_available := false # Shared main flaggp8, fresh CRT zero.
var source_main_menu_text: MeshInstance3D = null
var source_main_menu_font_data: Dictionary = {}
var source_title_logo_state: Dictionary = preload("res://source_title_logo.gd").initialize()
var source_title_scene_index := -1 # Loaded source wordgp620/0x80074b4c.

func source_title_destination(mode: int, frame_seed: Variant = null) -> Dictionary:
	var seed: int = source_frame_clock.counter if frame_seed == null else int(frame_seed)
	var result: Dictionary = preload("res://source_title_selection.gd").select_scene(mode,source_title_scene_index,seed,source_random)
	if not manifest.linkage.rooms.has(str(result.map)):
		return {"fault":"Original selected title scene is missing"}
	source_title_scene_index = int(result.index)
	return result
var source_title_logo_nodes: Array[MeshInstance3D] = []
var source_title_effect_state: Dictionary = preload("res://source_title_particles.gd").initialize()
var source_title_effect_nodes: Array[MeshInstance3D] = []
var source_title_effect_atlas: Dictionary = {}

func refresh_source_title_effects() -> bool:
	if source_title_effect_atlas.is_empty():
		var binding := material_for_texture("FRONTEND.BIN")
		if binding.is_empty():
			source_transition_fault = "Missing original title effect atlas"
			return false
		source_title_effect_atlas = binding.data
	if source_title_effect_nodes.is_empty():
		var view: Camera3D = head if xr_active else camera
		for index in range(2):
			var node = preload("res://source_menu_text_renderer.gd").new()
			node.text_material.render_priority = 125 if index == 0 else 124
			if index == 1:
				node.text_material.shader = preload("res://source_title_trail.gdshader")
			node.configure_vr_panel(xr_active)
			view.add_child(node)
			source_title_effect_nodes.append(node)
		if xr_active:
			var placement:Transform3D=preload("res://source_title_logo.gd").vr_effect_transform(source_title_logo_nodes)
			for effect in source_title_effect_nodes:effect.transform=placement
	source_title_effect_state = preload("res://source_title_particles.gd").advance(source_title_effect_state,int(source_title_logo_state.positions[1].z),source_random)
	for index in range(2):
		var glyphs: Array = source_title_effect_state.central if index == 0 else source_title_effect_state.quads
		if not source_title_effect_nodes[index].set_text({"labels":[{"glyphs":glyphs}]},source_title_effect_atlas,texture_cache["FRONTEND.BIN"]):
			source_transition_fault = "Original title effect sprite rendering failed"
			return false
	return true

func refresh_source_title_logo() -> bool:
	if source_title_logo_nodes.is_empty():
		var title: Dictionary = manifest.get("frontendTitle",{})
		var binding := material_for_texture(str(title.get("texture","")))
		if title.get("models",[]).size() != 2 or binding.is_empty():
			source_transition_fault = "Missing original 3D title logo assets"
			return false
		var view: Camera3D = head if xr_active else camera
		for resource in title.models:
			var model := read_json(resource.file)
			var node := MeshInstance3D.new()
			node.mesh = geometry(model.models[0],binding.data)
			var material: StandardMaterial3D = binding.material.duplicate()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.add_child(node)
			source_title_logo_nodes.append(node)
	for index in range(2):
		var pose: Vector3i = source_title_logo_state.positions[index]
		# View1663c uses roll2048; model yaw2048. Converted camera axes cancel.
		source_title_logo_nodes[index].position = Vector3(pose.x,pose.y,-pose.z)*CELL_METERS/4096.0
		if xr_active:
			source_title_logo_nodes[index].position = preload("res://source_title_logo.gd").vr_position(pose,CELL_METERS)
		source_title_logo_nodes[index].visible = source_main_mode in [0,1]
	return true
var source_main_mode := 4 # Current direct gameplay entry; selector5/title7 when those scenes load.

func reset_source_new_game() -> Dictionary:
	# Native3ae9c..3af24 resets progression; per-level pickup clears are separate.
	source_map_entity_flags.clear()
	source_menu_state.selected_index = 0
	source_pickup_counts[3] = 3
	source_stage_crystal_bank = 0
	source_stage_pickup_slots = [0,0,0,0,0,0,0,0]
	source_menu_announcement_history = [0,0,0,0,0,0,0,0]
	source_menu_progress_flags.clear()
	for index in range(80):
		source_menu_progress_flags[index] = 0
	# The original sets current chapter/room words10/0 before selector entry.
	return {"level":10,"room":0}

func update_source_menu_unlocks() -> Dictionary:
	var result: Dictionary = preload("res://source_menu_progress.gd").update_unlocks(int(source_menu_state.selected_index),source_menu_progress_flags)
	source_menu_progress_flags = result.flags
	return result

func record_source_stage_result() -> void:
	source_menu_progress_flags = preload("res://source_menu_progress.gd").record_completion(int(source_menu_state.selected_index),int(source_pickup_counts[2]),source_menu_progress_flags)

func source_stage_end_selection(level: int) -> int:
	var ending = preload("res://source_stage_end.gd")
	return ending.next_selection(int(source_menu_state.selected_index),source_menu_progress_flags,ending.sequence_id(level))
func request_source_next_level() -> bool:
	record_source_stage_result()
	var next := preload("res://source_stage_end.gd").next_level_selection(int(source_menu_state.selected_index),source_menu_progress_flags)
	var lookup := preload("res://source_menu_selection.gd").level_for_index(next,runtime_tables.get("menuLevels",{}).get("values",[]))
	if lookup.has("fault"): return false
	source_pending_exit = {"source_level":int(map_name.substr(2,3)),"target_level":int(lookup.level),"target_room":0}
	source_menu_state.selected_index = next
	source_transition_state = 3
	return true
func apply_source_next_level_return(after_story: bool = false) -> bool:
	var ending_level := int(source_pending_exit.get("source_level",int(map_name.substr(2,3))))
	if not after_story:
		var unlock := preload("res://source_secret_island_unlock.gd").decide(source_menu_progress_flags,source_stage_pickup_slots)
		if unlock.has("fault"): source_transition_fault = str(unlock.fault); return false
		if bool(unlock.play): return enter_source_secret_unlock(ending_level)
	if ending_level in [47,54]: return enter_source_final_ending(ending_level)
	if not after_story and preload("res://source_stage_end.gd").sequence_id(ending_level) != 0: return enter_source_story_return("next-level",ending_level)
	if int(source_pending_exit.get("target_level",0)) == 0:
		source_transition_fault = "Unimplemented original final-stage next-level return"
		return false
	for slot in source_voice_nodes.keys().duplicate():
		if is_instance_valid(source_voice_nodes[slot]):
			retire_imported_voice(source_voice_nodes[slot])
	for slot in range(4,24): source_voice_pool.release(slot)
	if not apply_source_island_selection(): return false
	source_resume_input_baseline_pending = true
	return true
func apply_source_stage_return(after_story: bool = false) -> bool:
	var level := int(map_name.substr(2,3))
	if not after_story:
		var unlock := preload("res://source_secret_island_unlock.gd").decide(source_menu_progress_flags,source_stage_pickup_slots)
		if unlock.has("fault"): source_transition_fault = str(unlock.fault); return false
		if bool(unlock.play): return enter_source_secret_unlock(level)
	if level in [47,54]:
		var prior_selection := int(source_menu_state.selected_index)
		source_menu_state.selected_index = source_stage_end_selection(level)
		if enter_source_final_ending(level): return true
		source_menu_state.selected_index = prior_selection
		return false
	if not after_story and preload("res://source_stage_end.gd").sequence_id(level) != 0: return enter_source_story_return("stage",level)
	var selected := int(source_menu_state.selected_index)
	var next := source_stage_end_selection(level)
	var lookup := preload("res://source_menu_selection.gd").level_for_index(next,runtime_tables.get("menuLevels",{}).get("values",[]))
	if lookup.has("fault") or int(lookup.level) == 0:
		source_transition_fault = "Unimplemented source final-stage/invalid selector return"
		return false
	var destination := "MP100_%02d.MAP"%int(int(lookup.level)/10)
	if not manifest.linkage.rooms.has(destination):
		source_transition_fault = "Original stage-return selector scene is missing"
		return false
	# Source158b4/15980 key-off all voices; dynamic held flags4..23 clear.
	for slot in source_voice_nodes.keys().duplicate():
		if is_instance_valid(source_voice_nodes[slot]):
			retire_imported_voice(source_voice_nodes[slot])
	for slot in range(4,24): source_voice_pool.release(slot)
	source_menu_state.selected_index = next
	if not apply_source_island_selection():
		source_menu_state.selected_index = selected
		return false
	source_resume_input_baseline_pending = true
	return true

func apply_source_menu_navigation(buttons: int, locked: int) -> Dictionary:
	var selected := int(source_menu_state.selected_index)
	if selected < 0 or selected > 45:
		return {"fault":"Invalid source menu selection index"}
	var result: Dictionary = preload("res://source_menu_selection.gd").navigate(selected,source_menu_progress_flags,buttons,locked)
	source_menu_state.selected_index = result.index
	source_menu_state.selection_changes = SourceCollision.VM.signed32(int(source_menu_state.selection_changes)+int(result.changes))
	if locked == 0 and (buttons&0x20000) != 0 and preload("res://source_menu_selection.gd").previous(selected,source_menu_progress_flags) != selected:
		source_menu_reveal_state = 0
	return result

func source_selected_menu_destination() -> Dictionary:
	var result: Dictionary = preload("res://source_menu_selection.gd").level_for_index(int(source_menu_state.selected_index),runtime_tables.get("menuLevels",{}).get("values",[]))
	if result.has("fault"):
		return result
	if int(result.level) == 0:
		return {"fault":"Source menu sentinel is not a gameplay destination"}
	var destination := "MP%03d_00.MAP" % int(result.level)
	for candidate in manifest.maps:
		if candidate.name == destination:
			return {"level":int(result.level),"room":0,"map":destination}
	return {"fault":"Source menu destination is missing from imported maps"}

func source_selected_selector_destination() -> Dictionary:
	var result: Dictionary = preload("res://source_menu_selection.gd").level_for_index(int(source_menu_state.selected_index),runtime_tables.get("menuLevels",{}).get("values",[]))
	if result.has("fault"):
		return result
	var island := int(int(result.level)/10)
	var destination := "MP100_%02d.MAP" % island
	if island < 1 or island > 5 or not manifest.linkage.rooms.has(destination):
		return {"fault":"Source selected island scene is missing"}
	return {"map":destination,"island":island}

func apply_source_island_selection() -> bool:
	var destination := source_selected_selector_destination()
	if destination.has("fault"):
		source_transition_fault = str(destination.fault)
		return false
	# Main147d0 clears the lock before the outer selector-entry/load path.
	source_selector_action_state.clear()
	source_menu_state.dialog_mode=0;source_menu_state.save_mode=0
	source_menu_state.input_lock = 0
	source_input_suppression_count = 0
	source_player_movement_state = preload("res://source_player_movement.gd").reset_motion_state(source_player_movement_state)
	source_camera_override_one = null
	source_camera_target = null
	if not load_room(str(destination.map)):
		source_transition_fault = "Source island selection load failed"
		return false
	source_transition_state = 0
	source_controller_enabled = false
	source_transition_fault = ""
	return true

func apply_source_confirmed_new_game() -> bool:
	# Main14c6c->13ad8 is the menu-mode1, selection0, transition-ready branch.
	if source_main_mode != 1:
		source_transition_fault = "Source New Game action requires main-menu mode1"
		return false
	if int(source_menu_state.dialog_mode) != 0:
		source_transition_fault = "Source New Game action requires current menu selection0"
		return false
	reset_source_new_game()
	source_menu_state.input_lock = 0 # Main13ae4.
	return apply_source_island_selection()

func enter_source_main_menu() -> void:
	# Main151a8..151c8 and53610: selection0, five items, highlight reset.
	var repeat_timer := int(source_main_menu_animation_state.cooldown)
	source_main_mode = 1
	source_menu_state.dialog_mode = 0
	source_menu_state.save_mode = 0
	source_main_menu_animation_state = preload("res://source_main_menu.gd").initialize(0,4)
	source_main_menu_animation_state.cooldown = repeat_timer
	source_controller_enabled = false
	source_resume_input_baseline_pending = true
	if not is_instance_valid(source_fade_overlay):
		source_fade_overlay = preload("res://source_fade_overlay.gd").new()
		var view: Camera3D = head if xr_active else camera
		view.add_child(source_fade_overlay)
	refresh_source_main_menu_text()
	# Main1330c plays the primary cue11 with looping enabled.
	if manifest.has("musicIndex") and runtime_tables.has("musicCues"):
		if not is_instance_valid(source_options_music_backend):
			source_options_music_backend=preload("res://source_options_music_backend.gd").new();add_child(source_options_music_backend)
		var started: Dictionary=source_options_music_backend.play_track(self,11,false,true,1)
		if started.has("fault"):source_transition_fault=str(started.fault)

func process_source_title_confirmation(buttons: int) -> bool:
	if source_main_mode != 0:
		return true
	if source_fade_phase == "in" and not advance_source_transition():
		return false
	if int(source_main_menu_animation_state.cooldown) != 0:
		source_main_menu_animation_state.cooldown = SourceCollision.VM.signed32(int(source_main_menu_animation_state.cooldown)-1)
	# Main15054/15158 accepts face buttons or Start during the first901 ticks.
	if source_tick_count > 900:
		source_cd_mix_state = preload("res://source_cd_fade.gd").advance(source_cd_fade_counter,source_cd_stereo_flag)
		source_cd_fade_counter = int(source_cd_mix_state.counter)
		if source_cd_fade_counter != 0:
			return true
		if source_fade_phase == "attract-out":
			return advance_source_transition()
		source_fade_state = preload("res://source_transition_fade.gd").start(8)
		source_fade_phase = "attract-out"
		return true
	if (buttons&0xf00200) != 0:
		play_source_menu_sound("START")
		enter_source_main_menu()
	return true

func source_attract_demo_destination(frame_seed: Variant = null) -> Dictionary:
	var seed: int = source_frame_clock.counter if frame_seed == null else int(frame_seed)
	var result: Dictionary = preload("res://source_attract_demo.gd").select_destination(seed,runtime_tables.get("attractDemos",{}).get("destinations",[]),source_random)
	if result.has("fault"):
		return result
	var destination := "MP%03d_%02d.MAP" % [int(result.level),int(result.room)]
	if not manifest.linkage.rooms.has(destination):
		return {"fault":"Original attract demo map is missing"}
	result.map = destination
	return result

func apply_source_attract_demo_entry() -> bool:
	var destination := source_attract_demo_destination()
	if destination.has("fault"):
		source_transition_fault = str(destination.fault)
		return false
	# Main150a8..150d8 clears level counters/bonus before entering demo3.
	source_pickup_counts[1] = 0
	source_pickup_counts[2] = 0
	source_bonus_mask = 0
	source_level_script_state = 0
	return initialize_source_demo_scene(destination) and start_source_demo_playback()

func source_demo_exit_decision(live_buttons: int) -> Dictionary:
	return preload("res://source_demo_exit.gd").decide(source_tick_count,source_transition_state,live_buttons,bool(source_fade_state.get("active",false)),bool(source_fade_state.get("ready",false)))

func process_source_demo_exit(live_buttons: int) -> bool:
	if source_main_mode != 3:
		return true
	if source_fade_phase != "":
		if not advance_source_transition():
			return false
		if source_main_mode != 3:
			return true
	var decision := source_demo_exit_decision(live_buttons)
	if decision.action == "continue":
		return true
	source_tick_count = int(decision.tick)
	if decision.action == "fade":
		if bool(decision.sound):
			play_source_menu_sound("START")
		source_fade_state = preload("res://source_transition_fade.gd").start(8)
		source_fade_phase = "demo-out"
	elif decision.action == "return":
		return apply_source_demo_title_return()
	return true

func apply_source_demo_title_return() -> bool:
	source_demo_playing = false
	# Main14de0 enters0, then outer movement/suppression/RNG reset and4ac0c load.
	source_random.bios_seed = 0
	source_player_movement_state = preload("res://source_player_movement.gd").reset_motion_state(source_player_movement_state)
	source_input_suppression_count = 0
	var destination := source_title_destination(0)
	if destination.has("fault"):
		source_transition_fault = str(destination.fault)
		return false
	if not load_room(str(destination.map)):
		source_transition_fault = "Original demo return title load failed"
		return false
	source_controller_enabled = false
	source_transition_state = 0
	update_source_input(0,0)
	source_player_input_state = {"pad_mode":1}
	source_transition_fault = ""
	return true

func refresh_source_main_menu_text() -> bool:
	var layout: Dictionary = preload("res://source_menu_text.gd").layout(runtime_tables.get("mainMenu",{}),source_main_menu_animation_state.sizes,source_main_menu_credits_available)
	return render_source_frontend_text(layout)

func refresh_source_title_prompt() -> bool:
	var data: Dictionary=runtime_tables.get("mainMenu",{})
	if xr_active:
		data=data.duplicate(true);data.titlePrompt=data.titlePrompt.duplicate();data.titlePrompt.text="{ START"
		data.glyphs["123"]={"sprite":0,"width":20,"height":20,"advance":24}
	return render_source_frontend_text(preload("res://source_menu_text.gd").title_layout(data,source_tick_count))

func render_source_frontend_text(layout: Dictionary) -> bool:
	if source_main_menu_font_data.is_empty():
		var font := material_for_texture("FONT.BIN")
		if font.is_empty():
			source_transition_fault = "Missing original menu font atlas"
			return false
		source_main_menu_font_data = font.data
	if not is_instance_valid(source_main_menu_text):
		source_main_menu_text = preload("res://source_menu_text_renderer.gd").new()
		var view: Camera3D = head if xr_active else camera
		view.add_child(source_main_menu_text)
	source_main_menu_text.configure_vr_panel(xr_active)
	if not source_main_menu_text.set_text(layout,source_main_menu_font_data,texture_cache.get("FONT.BIN")):
		source_transition_fault = "Original menu glyph layout/rendering failed"
		return false
	return true

func advance_source_main_menu_navigation(held: int, pressed: int) -> Dictionary:
	if source_main_mode != 1:
		return source_main_menu_animation_state.duplicate(true)
	source_main_menu_animation_state.selected = int(source_menu_state.dialog_mode)
	source_main_menu_animation_state = preload("res://source_main_menu.gd").advance(source_main_menu_animation_state,held,pressed)
	source_menu_state.dialog_mode = source_main_menu_animation_state.selected
	if int(source_main_menu_animation_state.last_index) != 0:
		for change in range(int(source_main_menu_animation_state.changes)):
			play_source_menu_sound("SELECT")
	return source_main_menu_animation_state

var vr_haptics=preload("res://vr_haptics.gd").new()
func pulse_vr_feedback(event: String) -> void:
	if not xr_active or not xr_gameplay_is_focused():return
	for pulse in vr_haptics.request(event,Time.get_ticks_msec()/1000.0,vr_controls.haptics_enabled):
		var hand:XRController3D=left if pulse.hand=="left" else right
		if is_instance_valid(hand) and hand.get_has_tracking_data():
			hand.trigger_haptic_pulse("haptic",0.0,pulse.amplitude,pulse.duration,0.0)
func source_animation_feedback(player: Node, previous: String, current: String) -> void:
	if player!=source_player_actor or source_main_mode!=4:return
	var palette=preload("res://modern_motion_palette.gd")
	var family:String=palette.family(current)
	if family==palette.family(previous):return
	var event:String={"jump":"jump","attack":"attack","reaction":"damage","celebration":"complete"}.get(family,"")
	if not event.is_empty():pulse_vr_feedback(event)
func play_source_menu_sound(name: String, volume: float = 80.0, pitch: int = 24) -> void:
	if name in ["SELECT","START"]:pulse_vr_feedback("confirm" if name=="START" else "menu")
	# Native53344/14c18 use2e824(sample,80,24,0,0), ignoring its result.
	var view: Camera3D = head if xr_active else camera
	for asset in manifest.get("linkage",{}).get("bootstrap",[]):
		if int(asset.kind) == 3 and asset.name == name:
			var slot := play_imported_sound_voice(asset,to_local(view.global_position),volume,pitch,false,0)
			if slot >= 0:
				var voice: Node3D = source_voice_nodes[slot]
				voice.reparent(view)
				voice.position = Vector3.ZERO
			return

func process_source_main_menu_confirmation(buttons: int) -> bool:
	if source_main_mode != 1:
		return true
	if source_fade_phase != "":
		return advance_source_transition()
	if (buttons&0x800200) == 0:
		return true
	# Main14bc8/14c6c use the shared selection/dialog word0x800751dc.
	var selected := int(source_menu_state.dialog_mode)
	if selected not in [0,1,2,3,4]:
		source_transition_fault = "Unimplemented source main-menu selection action"
		return false
	play_source_menu_sound("START")
	if not is_instance_valid(source_fade_overlay):
		source_fade_overlay = preload("res://source_fade_overlay.gd").new()
		var view: Camera3D = head if xr_active else camera
		view.add_child(source_fade_overlay)
	source_fade_state = preload("res://source_transition_fade.gd").start(12 if selected in [1,2] else 5)
	source_fade_phase = "options-menu-out" if selected==1 else "load-menu-out" if selected==2 else "show-intro-out" if selected==4 else (("credits-menu-out" if source_main_menu_credits_available else "password-menu-out") if selected == 3 else "new-game-out")
	return true

func process_source_menu_confirmation(buttons: int, locked: int, save_mode: int, dialog_mode: int) -> bool:
	if source_main_mode == 5:
		# Selector render0x800141b8 clears these every frame, before confirmation.
		source_pickup_counts[1] = 0
		source_pickup_counts[2] = 0
		source_level_script_state = 0
	if source_fade_phase != "":
		return advance_source_transition()
	if source_main_mode == 5:
		var island := source_selected_selector_destination()
		if island.has("fault"):
			source_transition_fault = str(island.fault)
			return false
		if str(island.map) != map_name:
			# Main147dc..147f8: state3, fade8, increment navigation/confirm lock.
			source_transition_state = 3
			source_menu_state.input_lock = SourceCollision.VM.signed32(int(source_menu_state.input_lock)+1)
			source_fade_state = preload("res://source_transition_fade.gd").start(8)
			source_fade_phase = "island-out"
			return true
	if source_main_mode != 5 or (buttons&0x800200) == 0 or locked != 0:
		return true
	if save_mode==0 and dialog_mode==1:
		play_source_menu_sound("START");source_menu_state.save_mode=1;source_menu_state.dialog_mode=0;source_selector_action_state.clear();return advance_source_selector_actions(0,0)
	if save_mode==1 and dialog_mode==2:
		play_source_menu_sound("START");source_menu_state.save_mode=0;source_menu_state.dialog_mode=1;source_selector_action_state.clear();return advance_source_selector_actions(0,0)
	if save_mode==1 and dialog_mode==0:
		play_source_menu_sound("START");source_fade_state=preload("res://source_transition_fade.gd").start(8);source_fade_phase="selector-options-out";return true
	if save_mode==1 and dialog_mode==1:
		play_source_menu_sound("START");source_menu_state.save_mode=2;source_menu_state.dialog_mode=0;source_selector_action_state.clear();return advance_source_selector_actions(0,0)
	if save_mode==2 and dialog_mode==0:
		play_source_menu_sound("START");source_menu_state.save_mode=1;source_menu_state.dialog_mode=1;source_selector_action_state.clear();return advance_source_selector_actions(0,0)
	if save_mode==2 and dialog_mode==1:
		play_source_menu_sound("START");source_fade_state=preload("res://source_transition_fade.gd").start(8);source_fade_phase="selector-quit-out";return true
	if save_mode==0 and dialog_mode==2:
		play_source_menu_sound("START")
		source_fade_state=preload("res://source_transition_fade.gd").start(8);source_fade_phase="save-menu-out";return true
	if save_mode==0 and dialog_mode==3:
		play_source_menu_sound("START");source_fade_state=preload("res://source_transition_fade.gd").start(8);source_fade_phase="password-display-menu-out";return true
	if save_mode != 0 or dialog_mode != 0:
		source_transition_fault = "Unimplemented source menu save/dialog confirmation branch"
		return false
	var destination := source_selected_menu_destination()
	if destination.has("fault"):
		source_transition_fault = str(destination.fault)
		return false
	source_pending_exit = destination.duplicate(true)
	source_fade_state = preload("res://source_transition_fade.gd").start(8)
	source_fade_phase = "menu-out"
	return true

func apply_source_menu_launch(request: Dictionary) -> bool:
	if is_instance_valid(source_main_menu_text):source_main_menu_text.hide()
	# Selection remains mutable during selector fade; main uses the current map word.
	var current := source_selected_menu_destination()
	if current.has("fault"):
		source_transition_fault = str(current.fault)
		return false
	# Ready branch0x80013aa4 enters mode4, clears bonus, then outer-loop movement reset.
	source_main_mode = 4
	source_bonus_mask = 0
	source_transition_state = 0 # Common new-mode entry0x80013a30.
	source_pickup_display_timer = 240 # Gameplay entry0x80013838..0x8001384c.
	source_bonus_display_timer = 60
	source_input_suppression_count = 0
	source_player_movement_state = preload("res://source_player_movement.gd").reset_motion_state(source_player_movement_state)
	# Build the selected room with source actors, including ordinary Crystal.
	source_controller_enabled = true
	source_runtime_enabled = true
	# A selector launch rebuilds the stage's WAD state. Keep room-revisit marks
	# during a run, but respawn its rescues/pickups for a fresh attempt.
	var stage_prefix := str(current.map).substr(0,6)
	for previous_room in source_map_entity_flags.keys():
		if str(previous_room).begins_with(stage_prefix): source_map_entity_flags.erase(previous_room)
	if not load_room(str(current.map)):
		source_transition_fault = "Source selected-stage load failed"
		return false
	# The virtual digital-pad adapter must exist before the first player script.
	if source_input_held_mask == null:
		update_source_input(0,0)
	if source_player_input_state.is_empty():
		source_player_input_state = {"pad_mode":1}
	var incoming = create_source_player()
	if incoming == null or incoming.vm.fault != "":
		source_transition_fault = "Source selected-stage controller initialization failed"
		return false
	visual.hide()
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.position = incoming.position
	actor.velocity = Vector3.ZERO
	source_transition_fault = ""
	return true
var source_bonus_display_timer: Variant = null
var source_pickup_display_timer: Variant = null
var source_map_entity_flags: Dictionary = {}

func remove_source_map_entity(rider: Node3D, mask: int = 1, clear_mask: bool = false) -> bool:
	var index := int(rider.source_map_entity_index)
	if index < 0:
		return true # Original null entity pointer leaves map state untouched.
	if index >= room_data.entities.size():
		return false
	if not source_map_entity_flags.has(map_name):
		source_map_entity_flags[map_name] = {}
	var previous := int(source_map_entity_flags[map_name].get(index,0))
	source_map_entity_flags[map_name][index] = previous & ~mask if clear_mask else previous | mask
	return true

func add_source_pickup(kind: int) -> void:
	if source_hud_pickup_revisions.has(kind):source_hud_pickup_revisions[kind]=int(source_hud_pickup_revisions[kind])+1
	pulse_vr_feedback("pickup" if kind==1 else "rescue")
	if kind == 1:
		if (int(source_pickup_counts[1])&0xffffffff) < 99:
			source_pickup_counts[1] = SourceCollision.VM.signed32(int(source_pickup_counts[1])+1)
		source_pickup_display_timer = 0
	elif kind == 2:
		source_pickup_counts[2] = SourceCollision.VM.signed32(int(source_pickup_counts[2])+1)
	elif kind == 3:
		source_pickup_counts[3] = SourceCollision.VM.signed32(int(source_pickup_counts[3])+1)
		source_pickup_display_timer = 60

func turn_source_player(rider: Node3D) -> bool:
	if not source_player_input_state.has("pad_mode") or source_input_held_mask == null or not source_player_movement_state.has("turn_history") or not source_player_movement_state.has("mode"):
		rider.vm.fail("Unknown source PlayerTurn state")
		return false
	if bool(source_player_input_state.get("modern",false)):
		var animation_turn: bool = rider.clip_name in ["CROC1801.ANI","CROC1802.ANI","CROCT180.ANI","CROCJ180.ANI"]
		if animation_turn or (bool(source_player_input_state.get("turn_requested",false)) and (int(source_input_pressed_mask)&0x1000)!=0):
			# The flip's root frames own the turn until the animation finishes.
			source_player_movement_state.turn_history = 0
			return true
		var responsive: Dictionary = vr_controls.responsive_turn(int(rider.source_angles.y),source_player_input_state,0 if animation_turn else source_input_suppression_count,int(source_player_movement_state.mode))
		source_player_movement_state.turn_history = responsive.history
		rider.source_angles.y = int(responsive.yaw)
		rider.source_rotation_y = int(responsive.yaw)
		rider.rotation = Vector3(rider.source_angles)*TAU/4096.0
		return true
	if int(source_player_input_state.pad_mode) == 2:
		if (int(rider.secondary_flags)&2) != 0:
			for key in ["magnitude","idle_threshold","camera_yaw","stick_yaw"]:
				if not source_player_input_state.has(key):
					rider.vm.fail("Unknown source analog PlayerTurn field: "+key)
					return false
		var analog_result: Dictionary = preload("res://source_player_movement.gd").analog_turn(int(rider.source_angles.y),int(source_player_movement_state.turn_history),int(source_player_movement_state.mode),source_input_suppression_count,int(rider.secondary_flags),int(source_input_held_mask),int(source_player_input_state.get("magnitude",0)),int(source_player_input_state.get("idle_threshold",0)),int(source_player_input_state.get("camera_yaw",0)),int(source_player_input_state.get("stick_yaw",0)))
		source_player_movement_state.turn_history = analog_result.history
		rider.source_angles.y = int(analog_result.yaw)
		rider.source_rotation_y = int(analog_result.yaw)
		rider.rotation = Vector3(rider.source_angles)*TAU/4096.0
		return true
	var math = preload("res://source_player_movement.gd")
	var mode := int(source_player_movement_state.mode)
	var history := int(source_player_movement_state.turn_history)
	var direction := math.digital_turn_direction(mode,source_input_suppression_count,int(rider.secondary_flags),int(source_input_held_mask),history)
	var result: Dictionary = math.digital_turn_history(mode,direction,history)
	source_player_movement_state.turn_history = result.history
	if direction != 0:
		rider.source_angles.y = (int(rider.source_angles.y)+int(result.yaw_delta))&4095
		rider.source_rotation_y = int(rider.source_angles.y)
		rider.rotation = Vector3(rider.source_angles)*TAU/4096.0
	return true

func move_source_player(rider: Node3D) -> bool:
	if source_input_held_mask == null or not source_player_entry_state.has("flags"):
		rider.vm.fail("Unknown source PlayerMove input/arrival state")
		return false
	var input := source_player_input_state.duplicate(true)
	input.buttons = source_input_held_mask
	input.suppression = source_input_suppression_count
	input.intent_override = bool(input.get("modern",false)) and rider.clip_name in ["CROC1801.ANI","CROC1802.ANI","CROCT180.ANI","CROCJ180.ANI"]
	if input.intent_override:
		var progress := (float(rider.clip_frame)+float(rider.clip_fraction)/256.0)/maxf(1.0,float(int(rider.clip.get("frameCount",1))-1))
		input.turn_translation_scale = 0.025+0.975*smoothstep(0.65,0.95,progress)
	elif bool(input.get("modern",false)) and bool(input.get("turn_requested",false)) and (int(source_input_pressed_mask)&0x1000)!=0 and (int(rider.secondary_flags)&2)!=0:
		input.turn_translation_scale = 0.025
	var state := {"position":Vector3i(roundi(rider.position.x/CELL_METERS*4096.0),roundi(rider.position.y/CELL_METERS*4096.0),roundi(rider.position.z/CELL_METERS*4096.0)),"yaw":rider.source_angles.y,"primary":rider.primary_flags,"secondary":rider.secondary_flags,"surface_type":int(rider.source_ground.get("surface_type",0)),"status":rider.source_movement_status,"entry_flags":int(source_player_entry_state.flags)}
	var will_rise := ((int(state.entry_flags)&2) != 0) if bool(source_player_movement_state.reset_pending) else int(source_player_movement_state.get("forced",0)) == 1
	var gradient := {"x":0,"z":0,"yaw":0} if will_rise and int(state.surface_type) != 15 else source_player_gradient(rider)
	if gradient.has("fault"):
		rider.vm.fail(str(gradient.fault))
		return false
	var result: Dictionary = preload("res://source_player_movement.gd").step(source_player_movement_state,state,input,gradient,runtime_tables)
	if result.has("fault"):
		rider.vm.fail(str(result.fault))
		return false
	source_player_movement_state = result.state
	source_input_suppression_count = int(result.state.suppression)
	rider.position = Vector3(result.position)*CELL_METERS/4096.0
	rider.source_angles.y = int(result.yaw)
	rider.source_rotation_y = int(result.yaw)
	rider.rotation = Vector3(rider.source_angles)*TAU/4096.0
	rider.primary_flags = int(result.primary)
	rider.secondary_flags = int(result.secondary)
	rider.clip_speed_offset = int(result.clip_offset)
	if result.has("rise_remaining"):
		rider.source_rise_remaining = int(result.rise_remaining)
		rider.source_vertical_speed = int(result.vertical_speed)
	return true

func update_source_input(current: int, previous: int) -> void:
	# 0x80015e78..0x80015ea0: edge words and current pad word are distinct.
	source_input_held_mask = SourceCollision.VM.signed32(current)
	source_input_pressed_mask = SourceCollision.VM.signed32((~previous)&current)
	source_input_released_mask = SourceCollision.VM.signed32((~current)&previous)

func update_source_digital_pad(active_low: int, scheme: int, game_mode: int, previous: int) -> void:
	var mapper = preload("res://source_input.gd")
	var current: int = mapper.digital_pad(active_low,scheme,game_mode)
	if source_resume_input_baseline_pending:
		previous = current
		source_resume_input_baseline_pending = false
	update_source_input(current,previous)
# Empty means the original entry globals have not been reconstructed yet.
func source_analog_input_context() -> Dictionary:
	if not room_data.has("style") or not source_camera_state.has("yaw"):return {"fault":"Missing original analog room/view context"}
	var present := is_instance_valid(source_player_actor)
	return {"player_present":present,"room_type":int(room_data.style),"camera_yaw":int(source_camera_state.yaw),"player_yaw":int(source_player_actor.source_angles.y) if present else 0}
func update_source_analog_packet(packet: PackedByteArray, previous: int, context: Dictionary = {}) -> Dictionary:
	if context.is_empty():
		context=source_analog_input_context()
		if context.has("fault"):return context
	var calibration: Dictionary=source_options_state.get("calibration",preload("res://source_controller_calibration.gd").normalize(Vector2i(128,128),Vector2i.ZERO,Vector2i(255,255)))
	var mapper=preload("res://source_input.gd")
	var decoded: Dictionary=mapper.analog_packet(packet,int(source_options_state.get("scheme",0)),source_main_mode,calibration,context,runtime_tables.get("distanceRoot",{}).get("values",[]),runtime_tables.get("wallAngles",{}).get("values",[]))
	if decoded.has("fault"):return decoded
	var held: int=int(decoded.held)
	if source_resume_input_baseline_pending:
		previous=held;source_resume_input_baseline_pending=false
	update_source_input(held,previous)
	if int(decoded.pad_kind)==2:
		source_player_input_state={"pad_mode":2,"buttons":held,"magnitude":int(decoded.magnitude),"stick_yaw":int(decoded.angle),"camera_yaw":int(context.get("camera_yaw",0)),"idle_threshold":int(calibration.half_radius),"run_threshold":int(calibration.radius)}
	else:source_player_input_state={"pad_mode":0,"buttons":held}
	return decoded
var source_player_entry_state: Dictionary = {}
var source_checkpoint_entry: Dictionary = {}

func request_source_death() -> bool:
	if source_transition_state != 0:
		return true
	if not source_checkpoint_entry.has("present"):
		return false
	var pattern := RegEx.new()
	pattern.compile("^MP([0-9]{3})_([0-9]{2})\\.MAP$")
	var matched := pattern.search(map_name)
	if matched == null:
		return false
	var prefix := "MP%s_" % matched.get_string(1)
	var lives := int(source_pickup_counts[3])
	if lives != 0:
		source_pickup_counts[3] = SourceCollision.VM.signed32(lives-1)
		for room_name in source_map_entity_flags.keys():
			if str(room_name).begins_with(prefix):
				for index in source_map_entity_flags[room_name].keys():
					source_map_entity_flags[room_name][index] = int(source_map_entity_flags[room_name][index])&~4
	source_transition_state = 1
	source_player_entry_state = source_checkpoint_entry.duplicate(true)
	source_pickup_counts[1] = 0
	source_pickup_display_timer = 240
	source_bonus_display_timer = 30
	return true
static func initial_extended_globals() -> Dictionary:
	# Original startup 0x80012d80..0x80012db0 clears exactly 256 words.
	var values: Dictionary = {}
	for index in range(256):
		values[index] = 0
	return values
var source_extended_globals: Dictionary = initial_extended_globals()
var source_camera_target: Node3D = null
var source_camera_override_one: Node3D = null # Source word0x8007509c.
var source_camera_state: Dictionary = {"yaw":0} # Initialized halfword0x8006b89e.
var source_camera_hold_counter := 0 # Source75260 / gp2432.
func accelerate_source_player_angle(angle: int) -> bool:
	# Source42f80 always targets the registered player, regardless of script owner.
	var player = source_player_actor
	if not is_instance_valid(player) or (int(player.primary_flags)&0x1000) != 0: return true
	var quarter: Array = runtime_tables.get("trigonometry",{}).get("quarterSine",[])
	var roots: Array = runtime_tables.get("distanceRoot",{}).get("values",[])
	if quarter.size() != 1025 or roots.size() != 192: return false
	var math = preload("res://source_player_movement.gd")
	var target := Vector2i(SourceCollision.sine(angle,quarter)*60,SourceCollision.sine(angle+1024,quarter)*60)
	var motion := math.accumulate_motion(source_player_movement_state.motion,target,2)
	var units := Vector3i(roundi(player.position.x/CELL_METERS*4096.0),roundi(player.position.y/CELL_METERS*4096.0),roundi(player.position.z/CELL_METERS*4096.0))
	var committed := math.final_position(units,motion,roots)
	if committed.has("fault"):
		source_transition_fault = str(committed.fault)+" motion="+str(motion)
		return false
	source_player_movement_state.motion = motion
	source_player_movement_state.magnitude = int(committed.magnitude)
	player.position = Vector3(committed.position)*CELL_METERS/4096.0
	return true
var source_camera_height_units: Variant = null
var source_camera_distance_units: Variant = null
var source_camera_distance_copy_units: Variant = null
var source_camera_offset_words: Dictionary = {}

func commit_source_camera_update(result: Dictionary, query_entry_stack: int, spawn_pose_address: int) -> bool:
	if result.has("fault") or not result.has("camera_state"):
		return false
	var next: Dictionary = result.camera_state
	var query_commit: Dictionary = source_spawn_scratch.camera_update_queries(result.get("query_modes",[]),query_entry_stack,spawn_pose_address)
	if query_commit.has("fault"): return false
	source_camera_state = next.duplicate(true)
	source_camera_hold_counter = int(next.get("hold_counter",source_camera_hold_counter))
	if next.has("distance_target"): source_camera_distance_units = int(next.distance_target)
	if next.has("desired_look_offset"):
		source_camera_offset_words[37] = int(next.desired_look_offset.x)
		source_camera_offset_words[39] = int(next.desired_look_offset.y)
	return true

func publish_source_camera_view_direction() -> bool:
	if not source_camera_state.has_all(["position","look_position","yaw"]): return false
	var view := preload("res://source_camera_view_direction.gd").angles(source_camera_state.position,source_camera_state.look_position,int(source_camera_state.yaw),runtime_tables.distanceRoot.values,runtime_tables.wallAngles.values)
	if view.has("fault"): return false
	source_camera_state.pitch = int(view.pitch)
	source_camera_state.yaw = int(view.yaw)
	source_camera_state.roll = int(view.roll)
	return true

func advance_source_camera() -> bool:
	if not is_instance_valid(source_camera_target):
		if source_camera_hold_counter != 0: source_camera_hold_counter = SourceCollision.VM.signed32(source_camera_hold_counter-1)
		return true
	var target = source_camera_target
	if not source_camera_state.has("position") or source_camera_height_units == null or source_camera_distance_copy_units == null:
		source_transition_fault = "Missing initialized source camera state";return false
	var units := Vector3i(roundi(target.position.x/CELL_METERS*4096.0),roundi(target.position.y/CELL_METERS*4096.0),roundi(target.position.z/CELL_METERS*4096.0))
	var state := source_camera_state.duplicate(true)
	state.hold_counter = source_camera_hold_counter
	state.main_mode = source_main_mode
	state.primary_flags = int(target.primary_flags);state.secondary_flags = int(target.secondary_flags)
	state.last_ground_y = int(target.source_ground.height_units)
	state.lower_tile_actor = int(target.source_terrain_cache.get("tile",-1))
	state.upper_height_actor = int(target.source_field_180)
	state.target_roll = int(target.source_angles.z)
	state.target_pose_words = target.source_camera_pose_words()
	state.look_offset_y = int(source_camera_offset_words.get(38,1280))
	state.held = int(source_input_held_mask) if source_input_held_mask != null else 0
	state.pressed = int(source_input_pressed_mask) if source_input_pressed_mask != null else 0
	state.override_present = is_instance_valid(source_camera_override_one)
	if state.override_present:
		state.override_position = Vector3i(roundi(source_camera_override_one.position.x/CELL_METERS*4096.0),roundi(source_camera_override_one.position.y/CELL_METERS*4096.0),roundi(source_camera_override_one.position.z/CELL_METERS*4096.0))
	var result := preload("res://source_camera_update_pipeline.gd").step(self,state,units,int(target.source_angles.y),int(source_camera_distance_copy_units),int(source_camera_height_units),int(source_player_input_state.get("pad_mode",1)),preload("res://source_camera_motion.gd").SHAKE_WAVEFORM)
	if result.has("fault"):
		source_transition_fault = str(result.fault);return false
	if not commit_source_camera_update(result,0x807fea30,0x807fe980) or not publish_source_camera_view_direction():
		source_transition_fault = "Source camera commit/view publication failed";return false
	return true

func reset_source_camera(target: Node3D) -> bool:
	var quarter: Array = runtime_tables.get("trigonometry",{}).get("quarterSine",[])
	if target == null or quarter.size() != 1025 or not room_data.has("style"):
		return false
	# CamTarget72 calls412e4, which initializes these camera globals.
	var retained_camera := source_camera_state
	source_camera_hold_counter = 0
	source_camera_height_units = 0 # gp1860.
	source_camera_distance_units = 0 # gp2072.
	source_camera_distance_copy_units = 0 # gp2452.
	var units := Vector3i(roundi(target.position.x/CELL_METERS*4096.0),roundi(target.position.y/CELL_METERS*4096.0),roundi(target.position.z/CELL_METERS*4096.0))
	var angle: int = target.source_angles.y
	var sin_value := SourceCollision.sine(angle,quarter)
	var cos_value := SourceCollision.sine(angle+1024,quarter)
	var swimming := int(room_data.style) == 1
	var dx := SourceCollision.VM.signed32(SourceCollision.VM.signed32(sin_value*3)<<11)>>12 if swimming else SourceCollision.VM.signed32(sin_value<<8)>>12
	var dz := SourceCollision.VM.signed32(SourceCollision.VM.signed32(cos_value*3)<<11)>>12 if swimming else SourceCollision.VM.signed32(cos_value<<8)>>12
	var caches: Array = []
	for index in range(6):
		caches.append({"lower":{"tile":-1},"upper":{"tile":-1}})
	source_camera_target = target
	source_camera_offset_words = {37:0,38:1280,39:0}
	source_camera_state = {"position":Vector3i(SourceCollision.VM.signed32(units.x+dx if swimming else units.x-dx),SourceCollision.VM.signed32(units.y+1536),SourceCollision.VM.signed32(units.z+dz if swimming else units.z-dz)),"yaw":(angle+2048)&4095 if swimming else angle&65535,"target_position":units,"point_caches":caches,"lower_tile":-1,"upper_tile":-1,"offset":Vector3i(0,1280,0),"renderer":"unimplemented"}
	source_camera_state["orbit_offset"] = 0 # Halfword gp1856,413c8.
	source_camera_state["yaw_velocity"] = 0 # Halfword gp440,41570.
	source_camera_state["distance_velocity"] = 0 # Word gp444,41574.
	source_camera_state["height_velocity"] = 0 # Camera velocity vector+4,4130c.
	source_camera_state["query_counter"] = 0 # Word gp2188,41578.
	# Native41314..41380 resets look offsets and their velocities before
	# installing the 1280-unit desired Y offset. Native41508 initializes
	# the current look target to the actor's position, not the camera position.
	source_camera_state["look_offset_y"] = 1280
	source_camera_state["look_offset"] = Vector2i.ZERO
	source_camera_state["look_offset_velocity"] = Vector2i.ZERO
	source_camera_state["look_velocity_y"] = 0
	source_camera_state["look_position"] = units
	source_camera_state["center_cache"] = {"lower":{"tile":-1,"record":0},"upper":{"tile":-1,"record":0}}
	# These globals are not written by CamTarget's native reset routine.
	for retained_key in ["manual_yaw","height_copy","collision_status","shake_index","shake_strength"]:
		source_camera_state[retained_key] = int(retained_camera.get(retained_key,0))
	if not swimming:
		var horizontal: Dictionary = preload("res://source_camera_motion.gd").horizontal_position(units,angle,256,quarter)
		if horizontal.has("fault"): return false
		source_camera_state.position.x = horizontal.position.x
		source_camera_state.position.z = horizontal.position.y
	return true

func source_exit_context(exit_id: int, camera_yaw_units: int) -> Dictionary:
	# 0x8003c0d4 saves the exiting door ID and current level/room before loading.
	var pattern := RegEx.new()
	pattern.compile("^MP([0-9]{3})_([0-9]{2})\\.MAP$")
	var matched := pattern.search(map_name)
	if matched == null or not source_player_entry_state.has("present"):
		return {"fault":"Unresolved source exit room or prior arrival"}
	return {"id":SourceCollision.VM.signed32(exit_id),"level":int(matched.get_string(1)),"room":int(matched.get_string(2)),"yaw":camera_yaw_units&65535,"previous_entry":source_player_entry_state.duplicate(true)}

func initial_source_player_entry(data: Dictionary, incoming: Dictionary = {}) -> Dictionary:
	var scales: Array = runtime_tables.get("mapYScale",{}).get("values",[])
	var style := int(data.get("style",-1))
	if style < 0 or style >= scales.size():
		return {"fault":"Missing initial arrival map scale"}
	var factor := int(scales[style])
	if not incoming.is_empty() and (not incoming.has("id") or not incoming.has("level") or not incoming.has("room") or not incoming.has("yaw") or not incoming.has("previous_entry")):
		return {"fault":"Incomplete incoming door context"}
	for door in data.get("doors",[]):
		if incoming.is_empty():
			if (int(door.flags) & 8) == 0:
				continue
		elif int(door.id) != int(incoming.id) or int(door.level) != int(incoming.level) or int(door.room) != int(incoming.room):
			continue
		var p: Array = door.position
		var camera_y := SourceCollision.VM.signed32(SourceCollision.VM.signed32(int(p[1])*factor)<<3)
		var y := camera_y
		if (int(door.flags) & 4) != 0:
			y = SourceCollision.VM.signed32(y+SourceCollision.VM.signed32(factor*7))
		var x := SourceCollision.VM.signed32(int(p[0])<<12)
		var z := SourceCollision.VM.signed32(int(p[2])<<12)
		var arrival_yaw := roundi(float(data.startRotation)*4096.0)&4095 if incoming.is_empty() else int(incoming.yaw)&65535
		for track in data.get("tracks",[]):
			var tp: Array = track.position
			var ty := SourceCollision.VM.signed32(int(track.get("source_height",tp[1]))*factor)
			var step := SourceCollision.VM.signed32(factor<<3)
			var lower := SourceCollision.VM.signed32((ty>>16)*step)
			var upper := SourceCollision.VM.signed32(SourceCollision.VM.signed32(step+ty)-1)
			if x == SourceCollision.VM.signed32(int(tp[0])<<12) and z == SourceCollision.VM.signed32(int(tp[2])<<12) and camera_y >= lower and camera_y <= upper:
				y = ty
				if not incoming.is_empty():
					arrival_yaw = roundi(float(track.rotation)*4096.0)&65535
				break
		if not incoming.is_empty() and (int(door.flags) & 4) != 0:
			arrival_yaw = roundi(float(data.startRotation)*4096.0)&65535
		return {"present":true,"position":Vector3i(x,y,z),"restore_yaw":true,"yaw":arrival_yaw,"flags":int(door.flags)}
	if not incoming.is_empty():
		var previous: Dictionary = incoming.previous_entry.duplicate(true)
		if bool(previous.get("present",false)):
			previous.restore_yaw = false
		return previous
	return {"present":false,"flags":0}
var runtime_started_at := Time.get_unix_time_from_system()

func spawn_source_actor(parent: Node3D, wanted: String, params: Array, detached_pose: Dictionary = {}, attached: bool = false) -> Node3D:
	var definition: Dictionary = {}
	for candidate in manifest.linkage.definitions:
		if str(candidate.name).begins_with(wanted):
			definition = candidate
			break
	if definition.is_empty():
		return null
	var binding: Dictionary = {}
	for asset in parent.bindings:
		if int(asset.kind) == 1 and asset.name == definition.file:
			binding = asset
			break
	if binding.is_empty():
		return null
	var program := read_source_asset(binding.file)
	if program.is_empty():
		return null
	var index: int = source_pool.allocate({"name":wanted,"node":null})
	if index < 0:
		return null
	var node = ASLActor.new()
	node.source_pool_id = index
	restore_source_actor_pose_memory(node,index)
	node.source_parent_id = parent.source_pool_id if detached_pose.is_empty() or bool(detached_pose.get("retain_parent",false)) else -1
	source_pool.slots[index].node = node
	terrain.add_child(node)
	node.set_physics_process(false)
	parent.ensure_source_waypoint_chain()
	var entity := {"name":wanted,"position":[parent.position.x/CELL_METERS,parent.position.y/CELL_METERS,parent.position.z/CELL_METERS],"rotation":[parent.source_angles.x/4096.0,parent.source_angles.y/4096.0,parent.source_angles.z/4096.0],"params":params,"waypoints":parent.source_waypoints}
	entity.runtime_waypoint_chain = parent.source_waypoint_chain
	entity["runtime_position"] = Vector3i(roundi(parent.position.x/CELL_METERS*4096.0),roundi(parent.position.y/CELL_METERS*4096.0),roundi(parent.position.z/CELL_METERS*4096.0))
	if not detached_pose.is_empty():
		entity.runtime_position = detached_pose.position
		var angles: Vector3i = detached_pose.get("angles",Vector3i(0,int(detached_pose.get("yaw",0)),0))
		entity.rotation = [angles.x/4096.0,angles.y/4096.0,angles.z/4096.0]
		if not bool(detached_pose.get("retain_waypoints",false)):
			entity.waypoints = []
			entity.runtime_waypoint_chain = preload("res://source_waypoint_chain.gd").initialize(0)
	if attached:
		# SpawnChild2a288 supplies a zero local transform and factory child flag1.
		entity.runtime_skip_reference_queue = true
		entity.runtime_position = Vector3i.ZERO
		entity.position = [0,0,0]
		entity.rotation = [0,0,0]
	node.configure(self,definition,program,entity,parent.bindings,false)
	if attached:
		node.primary_flags = SourceCollision.VM.signed32(node.primary_flags|0x04000000)
		parent.source_child_id = index
		node.source_references_registered = true
		for reference in range(4):
			if parent.source_reference_slots.has(reference): node.source_reference_slots[reference] = parent.source_reference_slots[reference]
	source_actors.push_front(node)
	if not attached and (detached_pose.is_empty() or bool(detached_pose.get("refresh_references",false))): source_actor_references.refresh(source_actors)
	return node

func lose_source_pickups() -> bool:
	# Source0x80044888..0x80044950 scatters at most ten and clears the full count.
	var count := mini(int(source_pickup_counts[1])&0xffffffff,10)
	if count == 0:
		return true
	if source_player_actor == null or not is_instance_valid(source_player_actor):
		return false
	var player = source_player_actor
	var definition: Dictionary = {}
	for candidate in manifest.linkage.definitions:
		if candidate.name == "PickUpScatter":
			definition = candidate
	var available := false
	for binding in player.bindings:
		available = available or (int(binding.kind) == 1 and str(binding.name) == str(definition.get("file","")))
	if not available:
		return false
	var pose := Vector3i(roundi(player.position.x/CELL_METERS*4096.0),roundi(player.position.y/CELL_METERS*4096.0),roundi(player.position.z/CELL_METERS*4096.0))
	var step := int(4096/count)
	for index in range(count):
		# Null parent/waypoint/parameter pointers, source ignored allocation result.
		spawn_source_actor(player,"PickUpScatter",[0,0,0,0,0,0,0,0],{"position":pose,"yaw":index*step})
	source_pickup_counts[1] = 0
	return true
var source_actor_order_fault := ""
var player_source_terrain_cache: Dictionary = {}
var source_tick_accumulator := 0.0
var source_tick_count := 0
var source_player_contact_fault := ""
var source_player_contact_counts: Dictionary = {}
var source_transition_state := 0
var source_transition_fault := ""
var source_fade_state: Dictionary = {}
var source_fade_overlay: MeshInstance3D = null
var source_fade_phase := ""
var source_fade_override := 0 # Initialized word0x80074904.
var source_pending_exit: Dictionary = {}
var source_exit_door_id := 0
var source_spawn_scratch = preload("res://source_spawn_scratch.gd").new()

func request_source_script_room(level: int, room: int, force_door: bool = false) -> bool:
	var destination := "MP%03d_%02d.MAP" % [level,room]
	if not manifest.get("linkage",{}).get("rooms",{}).has(destination):
		source_transition_fault = "Missing script-requested room: "+destination
		return false
	if not source_camera_state.has("yaw"): return false
	var same_level := level == int(map_name.substr(2,3))
	var door_id := 0 if force_door or same_level else source_exit_door_id
	var origin := source_exit_context(door_id,int(source_camera_state.yaw))
	if origin.has("fault"): source_transition_fault = str(origin.fault);return false
	source_exit_door_id = door_id
	source_transition_state = 2 if force_door or same_level else 5
	source_pending_exit = {"destination":destination,"origin":origin,"state":source_transition_state}
	return true
var source_transition_polygon_data: Dictionary = {}

func advance_source_transition() -> bool:
	var fade = preload("res://source_transition_fade.gd")
	if source_fade_override != 1:
		var math = preload("res://source_audio_math.gd")
		if int(source_fade_state.kind) in [1,3,7]:
			source_audio_master_gain = math.fade_half_up(source_audio_master_gain,source_audio_master_step,source_audio_master_maximum)
		elif math.should_fade_out(source_transition_state,int(source_pickup_counts[3]),source_main_mode,0):
			source_audio_master_gain = math.fade_half_down(source_audio_master_gain,source_audio_master_step)
	source_fade_state = fade.advance(source_fade_state,source_fade_override)
	if is_instance_valid(source_fade_overlay):
		if int(source_fade_state.kind) in [5,12]:
			if source_transition_polygon_data.is_empty():
				for resource in manifest.resources:
					if resource.owner == "EXCLUDE.WAD" and resource.type == "unknown-table" and resource.has("file"):
						source_transition_polygon_data = read_json(resource.file)
			if source_transition_polygon_data.get("count",0) != 10:
				source_transition_fault = "Missing original transition polygon table"
				return false
			var projected: Dictionary = preload("res://source_transition_polygons.gd").project(source_transition_polygon_data.triangles,int(source_fade_state.rotation),int(source_fade_state.render_scale),runtime_tables.trigonometry.quarterSine)
			if projected.has("fault") or not source_fade_overlay.set_source_polygons(projected.triangles,bool(source_fade_state.ready)):
				source_transition_fault = "Original transition polygon projection failed"
				return false
		else:
			if int(source_fade_state.kind) in [2,3]:
				source_fade_overlay.set_source_white_level(int(source_fade_state.level))
			else:
				source_fade_overlay.set_source_level(int(source_fade_state.level))
	if not bool(source_fade_state.ready):
		return true
	if source_fade_phase == "in":
		source_fade_phase = ""
		return true
	if source_fade_phase == "password-out":
		if not apply_source_password_return(): return false
		source_fade_state = fade.start(7)
		source_fade_phase = "in"
		return true
	if source_fade_phase == "options-menu-out":
		if not enter_source_title_options():return false
		source_fade_state=fade.start(7);source_fade_phase="in"
		return true
	if source_fade_phase == "load-menu-out":
		if not enter_source_load_menu():return false
		source_fade_state=fade.start(15);source_fade_phase="in";return true
	if source_fade_phase == "show-intro-out":
		return enter_source_opening()
	if source_fade_phase == "save-menu-out":
		if not enter_source_save_menu():return false
		source_fade_state=fade.start(7);source_fade_phase="in";return true
	if source_fade_phase == "selector-options-out":
		if not enter_source_title_options(1,5):return false
		source_fade_state=fade.start(7);source_fade_phase="in";return true
	if source_fade_phase == "selector-quit-out":
		if is_instance_valid(source_main_menu_text):source_main_menu_text.hide()
		source_selector_action_state.clear();source_menu_state.save_mode=0;source_menu_state.dialog_mode=0
		if not apply_source_demo_title_return():return false
		source_fade_state=fade.start(7);source_fade_phase="in";return true
	if source_fade_phase == "password-display-menu-out":
		if not enter_source_password_display():return false
		source_fade_state=fade.start(7);source_fade_phase="in";return true
	if source_fade_phase == "password-display-out":
		source_game_over_renderer.hide()
		if not apply_source_island_selection():return false
		source_fade_state=fade.start(7);source_fade_phase="in";return true
	if source_fade_phase == "credits-menu-out":
		return enter_source_credits(0,true)
	if source_fade_phase == "password-menu-out":
		if not enter_source_password_entry(): return false
		source_fade_state = fade.start(7)
		source_fade_phase = "in"
		return true
	if source_transition_state == 1 and int(source_pickup_counts[3]) == 0:
		return enter_source_game_over()
	if source_fade_phase == "game-over-out":
		if not apply_source_game_over_return(): return false
		if source_main_mode == 6: return true
		source_fade_state = fade.start(7)
		source_fade_phase = "in"
		return true
	var loaded := apply_source_next_level_return() if source_fade_phase == "next-level-out" else apply_source_stage_return() if source_fade_phase == "stage-out" else apply_source_attract_demo_entry() if source_fade_phase == "attract-out" else apply_source_demo_title_return() if source_fade_phase == "demo-out" else apply_source_confirmed_new_game() if source_fade_phase == "new-game-out" else apply_source_island_selection() if source_fade_phase == "island-out" else apply_source_menu_launch(source_pending_exit) if source_fade_phase == "menu-out" else respawn_source_player() if source_transition_state == 1 else apply_source_room_request(source_pending_exit)
	if not loaded:
		return false
	if is_instance_valid(source_cutscene_screen): return true
	source_pending_exit.clear()
	source_fade_state = fade.start(1)
	source_fade_phase = "in"
	return true

func process_source_exit() -> bool:
	if source_fade_phase == "" and source_transition_state in [2,5] and source_pending_exit.has("destination"):
		source_fade_state = preload("res://source_transition_fade.gd").start(8)
		source_fade_phase = "out"
		return advance_source_transition()
	if source_fade_phase != "":
		return advance_source_transition()
	if source_transition_state == 3 and source_pending_exit.has("target_level"):
		var decision := preload("res://source_stage_stats_exit.gd").decide_for_level(3,int(source_pending_exit.source_level),int(source_stage_stats_state.get("busy",0)),bool(source_fade_state.get("active",false)),bool(source_fade_state.get("ready",false)))
		if int(decision.start) != 0:
			if not is_instance_valid(source_fade_overlay):
				var view: Camera3D = head if xr_active else camera
				if not is_instance_valid(view):
					source_transition_fault = "Missing source transition camera"
					return false
				source_fade_overlay = preload("res://source_fade_overlay.gd").new()
				view.add_child(source_fade_overlay)
			source_fade_state = preload("res://source_transition_fade.gd").start(int(decision.start))
			source_fade_phase = "next-level-out"
			return advance_source_transition()
		if bool(decision.get("return",false)):
			if not apply_source_next_level_return(): return false
			if is_instance_valid(source_cutscene_screen): return true
			source_fade_state = preload("res://source_transition_fade.gd").start(1)
			source_fade_phase = "in"
		return true
	if source_transition_state == 4:
		var decision := preload("res://source_stage_stats_exit.gd").decide_for_level(4,int(map_name.substr(2,3)),int(source_stage_stats_state.get("busy",0)),bool(source_fade_state.get("active",false)),bool(source_fade_state.get("ready",false)))
		if int(decision.start) != 0:
			if not is_instance_valid(source_fade_overlay):
				var view: Camera3D = head if xr_active else camera
				if not is_instance_valid(view):
					source_transition_fault = "Missing source transition camera"
					return false
				source_fade_overlay = preload("res://source_fade_overlay.gd").new()
				view.add_child(source_fade_overlay)
			source_fade_state = preload("res://source_transition_fade.gd").start(int(decision.start))
			source_fade_phase = "stage-out"
			return advance_source_transition()
		if bool(decision.get("return",false)):
			if not apply_source_stage_return(): return false
			if is_instance_valid(source_cutscene_screen): return true
			source_fade_state = preload("res://source_transition_fade.gd").start(1)
			source_fade_phase = "in"
			return true
		return true
	if source_transition_state == 1:
		source_fade_state = preload("res://source_transition_fade.gd").start(8)
		source_fade_phase = "out"
		return advance_source_transition()
	if source_player_actor == null or not is_instance_valid(source_player_actor):
		return false
	var outgoing = source_player_actor
	var request := source_exit_request(outgoing)
	if request.has("fault"):
		source_transition_fault = str(request.fault)
		outgoing.vm.fail(source_transition_fault)
		return false
	if request.has("counter"):
		source_ground_mode_80_value = request.counter
	if not bool(request.get("transition",false)):
		return true
	if int(request.state) not in [2,5] or not bool(request.capture_origin):
		source_transition_fault = "Unimplemented source transition state %d" % int(request.state)
		outgoing.vm.fail(source_transition_fault)
		return false
	source_pending_exit = request.duplicate(true)
	source_transition_state = int(request.state)
	source_fade_state = preload("res://source_transition_fade.gd").start(8)
	source_fade_phase = "out"
	return advance_source_transition()

func apply_source_room_request(request: Dictionary) -> bool:
	var destination: String = request.destination
	var origin: Dictionary = request.origin
	source_transition_state = int(request.state)
	if not load_room(destination,int(origin.id),origin):
		source_transition_fault = "Source destination load failed"
		return false
	if int(request.state) == 5:
		# Outer-loop0x80013034/0x80013064 resets these before destination scripts.
		source_player_movement_state = preload("res://source_player_movement.gd").reset_motion_state(source_player_movement_state)
	# Native13064 clears PausePlayer's counter on room initialization, including
	# same-level ForceDoor returns where the elevator's unpause never executes.
	source_input_suppression_count = 0
	var incoming = create_source_player()
	if incoming == null or incoming.vm.status == "unsupported":
		source_transition_fault = "Source destination player initialization failed"
		return false
	# Transition presentation is still pending; subsequent updates use the normal clock.
	source_transition_state = 0
	source_transition_fault = str(incoming.vm.fault)
	actor.position = incoming.position
	actor.velocity = Vector3.ZERO
	return source_transition_fault == ""

func respawn_source_player() -> bool:
	if int(source_pickup_counts[3]) == 0:
		source_transition_fault = "Unimplemented source game-over flow"
		return false
	if not source_checkpoint_entry.has("present"):
		source_transition_fault = "Missing source respawn checkpoint"
		return false
	var saved := source_checkpoint_entry.duplicate(true)
	if not load_room(map_name,-1,{},saved):
		source_transition_fault = "Source respawn room rebuild failed"
		return false
	# Actor allocation precedes reset in source, but its script executes afterward.
	source_player_movement_state = preload("res://source_player_movement.gd").reset_motion_state(source_player_movement_state)
	var incoming = create_source_player()
	if incoming == null or incoming.vm.fault != "":
		source_transition_fault = "Source respawn initialization failed"
		return false
	source_transition_state = 0
	source_transition_fault = ""
	actor.position = incoming.position
	actor.velocity = Vector3.ZERO
	return true

func source_exit_request(rider: Node3D) -> Dictionary:
	if source_transition_state != 0 or (int(rider.source_ground.get("surface_type",0))&0x80) == 0:
		return {"transition":false}
	var factors: Array = runtime_tables.get("mapYScale",{}).get("values",[])
	var style := int(room_data.style)
	if style < 0 or style >= factors.size():
		return {"fault":"Missing source exit map scale"}
	var position := Vector3i(roundi(rider.position.x/CELL_METERS*4096.0),roundi(rider.position.y/CELL_METERS*4096.0),roundi(rider.position.z/CELL_METERS*4096.0))
	var math = preload("res://source_doors.gd")
	var match_result: Dictionary = math.matching_exit(position,int(factors[style]),int(rider.secondary_flags),room_data.doors)
	if match_result.has("fault") or not bool(match_result.get("matched",false)):
		return match_result
	var door: Dictionary = match_result.door
	var destination := "MP%03d_%02d.MAP" % [int(door.level),int(door.room)]
	# Source room-style lookup indexes the current chapter's room pointer array.
	var style_room := "MP%03d_%02d.MAP" % [int(map_name.substr(2,3)),int(door.room)]
	var destination_style := -1
	for candidate in manifest.maps:
		if candidate.name == style_room:
			destination_style = int(candidate.style)
			break
	if destination_style < 0:
		return {"fault":"Unknown source exit destination style"}
	var request: Dictionary = math.transition_request(door,int(map_name.substr(2,3)),style,destination_style,bool(source_player_entry_state.get("present",false)),source_ground_mode_80_value)
	request["destination"] = destination
	if bool(request.get("transition",false)) and bool(request.get("capture_origin",false)):
		if not source_camera_state.has("yaw"): return {"fault":"Unknown source exit camera state"}
		var origin := source_exit_context(int(door.id),int(source_camera_state.yaw))
		source_exit_door_id = int(door.id)
		if origin.has("fault"): return origin
		request["origin"] = origin
	return request

func run_source_player_contacts() -> bool:
	if source_player_actor == null or not is_instance_valid(source_player_actor) or source_actors.is_empty() or source_player_actor.model_data.is_empty():
		return true
	var player = source_player_actor
	if player.source_render_matrix.size() != 9:
		source_player_contact_fault = "Missing source player contact pose matrix"
		return false
	var rotation_math = preload("res://source_rotation.gd")
	var sample: Dictionary = rotation_math.model_contact_points(rotation_math.scaled_matrix(player.source_render_matrix,player.source_scale),player.source_render_position,player.model_data.models,player.clip,player.clip_frame)
	if sample.has("fault"):
		source_player_contact_fault = str(sample.fault)
		return false
	var radii: Array = []
	for model in player.model_data.models:
		radii.append(roundi(float(model.radius)*4096.0))
	for candidate in source_actors:
		var contact: Dictionary = candidate.evaluate_player_contact(sample.points,radii,int(player.primary_flags))
		if contact.has("fault"):
			source_player_contact_fault = str(contact.fault)
			return false
		if bool(contact.contact):
			var key := int(candidate.source_pool_id)
			source_player_contact_counts[key] = int(source_player_contact_counts.get(key,0))+1
		candidate.primary_flags = int(contact.actor)
		candidate.secondary_flags = int(contact.secondary)
		player.primary_flags = int(contact.player)
	source_player_contact_fault = ""
	return true

func tick_source_actors() -> void:
	var performance_start:=Time.get_ticks_usec()
	source_tick_count += 1
	var texture_start := Time.get_ticks_usec()
	for player in active_texture_animations.values(): player.advance(source_main_mode==5)
	source_texture_animation_max_us = maxi(source_texture_animation_max_us,Time.get_ticks_usec()-texture_start)
	var root_table: Array = runtime_tables.get("distanceRoot",{}).get("values",[])
	if actor != null and root_table.size() == 192:
		var player_units := Vector3i(roundi(actor.position.x / CELL_METERS * 4096.0),roundi(actor.position.y / CELL_METERS * 4096.0),roundi(actor.position.z / CELL_METERS * 4096.0))
		if source_player_actor != null and is_instance_valid(source_player_actor):
			player_units = source_player_actor.source_render_position
		for source_actor in source_actors:
			var units: Vector3i = source_actor.source_render_position
			source_actor.source_player_distance = 0 if (source_actor.primary_flags & 0x800) != 0 else SourceCollision.player_distance(Vector3i(SourceCollision.VM.signed32(player_units.x-units.x),SourceCollision.VM.signed32(player_units.y-units.y),SourceCollision.VM.signed32(player_units.z-units.z)),root_table)
			source_actor.source_player_distance_valid = true
	# Source0x8002c770..0x8002c79c: distances, contacts, then pose/animation snapshots.
	if not run_source_player_contacts():
		source_player_actor.vm.fail(source_player_contact_fault)
		return
	for source_actor in source_actors:
		source_actor.begin_source_tick()
	# Retail 0x8002cb44..0x8002cc0c stably promotes secondary-bit-0x10 actors.
	var promoted: Array[Node3D] = []
	var remaining: Array[Node3D] = []
	for source_actor in source_actors:
		if (source_actor.secondary_flags & 0x10) != 0:
			promoted.append(source_actor)
		else:
			remaining.append(source_actor)
	source_actors.assign(promoted + remaining)
	for source_actor in source_actors.duplicate():
		if (source_actor.primary_flags & 4) != 0:
			remove_source_actor(source_actor)
		else:
			# Retail updates rise/fall before the trigger scan and script pass.
			var before_script_position: Vector3 = source_actor.position
			var turn_travel_limit := -1.0
			if source_actor == source_player_actor and bool(source_player_input_state.get("modern",false)) and source_actor.clip_name in ["CROC1801.ANI","CROC1802.ANI","CROCT180.ANI","CROCJ180.ANI"]:
				var turn_progress := (float(source_actor.clip_frame)+float(source_actor.clip_fraction)/256.0)/maxf(1.0,float(int(source_actor.clip.frameCount)-1))
				var turn_scale := 0.025+0.975*smoothstep(0.65,0.95,turn_progress)
				var stick_amount := clampf(float(int(source_player_input_state.get("magnitude",0))-16)/111.0,0.0,1.0)
				var limited := Vector2(source_player_movement_state.motion).limit_length(140.0*4096.0*stick_amount*turn_scale)
				source_player_movement_state.motion = Vector2i(roundi(limited.x),roundi(limited.y))
				turn_travel_limit = 140.0*CELL_METERS/4096.0*stick_amount*turn_scale
			source_actor.run_source_scripts({"map_style":int(room_data.get("style",0)),"jump_held":jump_held})
			if turn_travel_limit >= 0.0:
				var travel := Vector2(source_actor.position.x-before_script_position.x,source_actor.position.z-before_script_position.z).limit_length(turn_travel_limit)
				source_actor.position.x = before_script_position.x+travel.x
				source_actor.position.z = before_script_position.z+travel.y
			# Source0x8002cfc8..0x8002d004 clears arrival only outside door surfaces.
			if source_actor == source_player_actor and source_transition_state == 0 and (int(source_actor.source_ground.get("surface_type",0))&0x80) == 0:
				source_player_entry_state["present"] = false
	for source_actor in source_actors:
		if source_actor.has_method("advance_source_blink"):
			source_actor.advance_source_blink()
			source_actor.apply_pose()
		source_actor.refresh_source_render_pose()
		if source_actor == source_player_actor: source_actor.update_modern_motion()
	if int(source_stage_stats_state.get("active",0)) != 0:
		advance_source_stage_stats(int(source_input_pressed_mask) if source_input_pressed_mask != null else 0)
	# Native41590 camera pass follows actor scripts; newly issued CamHold149
	# is observed and decremented here, rather than before its issuing script.
	if not advance_source_camera() and is_instance_valid(source_camera_target):
		source_camera_target.vm.fail(source_transition_fault)
	record_runtime_cost("source_tick",Time.get_ticks_usec()-performance_start)

func remove_source_actor(source_actor: Node3D) -> bool:
	var index := int(source_actor.source_pool_id)
	if not source_pool.slots.has(index) or source_pool.slots[index].node != source_actor:
		source_actor.vm.fail("Invalid source actor pool removal")
		return false
	source_actors.erase(source_actor)
	# Free27110 leaves inline parameters340..371 intact until slot reuse.
	source_actor_parameter_memory[index] = source_actor.vm.parameters.duplicate()
	# Free27110 releases bank ownership without clearing actor+8 or bank words.
	source_actor_global_memory[index] = source_actor.vm.globals
	source_actor_pose_memory[index] = {"current":source_actor.source_pose_padding.duplicate(true),"saved":source_actor.source_saved_pose_padding.duplicate(true)}
	source_pool.release(index)
	source_actor.primary_flags = 0
	source_actor.secondary_flags = 0
	source_actor.vm.status = "finished"
	source_actor.set_physics_process(false)
	for body in source_actor.camera_bodies:
		if is_instance_valid(body):
			body.collision_layer = 0
	source_actor.queue_free()
	return true

func source_resolve_actor_push(response: Dictionary, owner: Node3D) -> Dictionary:
	var probes := source_actor_push_probes(owner,response.world_delta)
	var origin := Vector3i(roundi(owner.position.x/CELL_METERS*4096.0),roundi(owner.position.y/CELL_METERS*4096.0),roundi(owner.position.z/CELL_METERS*4096.0))
	return SourceCollision.resolve_actor_push(response,origin,probes)

func source_actor_push_probes(owner: Node3D, correction: Vector2i) -> Dictionary:
	var rotation_math = preload("res://source_rotation.gd")
	var matrix := rotation_math.matrix(owner.source_angles,runtime_tables.get("rotation",{}).get("pairs",[]))
	var origin := Vector3i(roundi(owner.position.x/CELL_METERS*4096.0),roundi(owner.position.y/CELL_METERS*4096.0),roundi(owner.position.z/CELL_METERS*4096.0))
	var probes: Array[Dictionary] = []
	for index in range(int(owner.collision_point_count)):
		var point := rotation_math.actor_push_probe(matrix,owner.collision_points[index],owner.source_scale,origin,correction)
		if point.has("fault"):
			return point
		var location: Vector3 = Vector3(point.position)*CELL_METERS/4096.0
		var terrain_hit := source_floor_at(location)
		var contacts := source_contacts_at(location,owner)
		probes.append({"position":point.position,"terrain":terrain_hit,"actor_lower":contacts.lower,"actor_upper":contacts.upper})
		if not SourceCollision.actor_push_probe_clear(terrain_hit,contacts.lower,origin.y):
			return {"move_owner":false,"tested":probes.size(),"failed_probe":index,"probes":probes}
	return {"move_owner":true,"tested":probes.size(),"failed_probe":-1,"probes":probes}

func source_contacts_at(location: Vector3, query_actor: Node3D = null, clearance_units: int = 256) -> Dictionary:
	var candidates: Array = []
	for index in range(source_actors.size()):
		var actor_hits: Array = source_actors[index].model_surface_candidates_at(location,query_actor)
		for hit in actor_hits:
			hit["actor"] = source_actors[index].source_pool_id
			hit["actor_name"] = source_actors[index].source_name
		candidates.append(actor_hits)
	return SourceCollision.select_actor_contacts(candidates,roundi(location.y / CELL_METERS * 4096.0),clearance_units)

func source_floor_at(location: Vector3, skip_type_17: bool = false) -> Dictionary:
	return SourceCollision.select_floor(terrain_surfaces_at(location),roundi(location.y / CELL_METERS * 4096.0),skip_type_17)

func source_ceiling_at(location: Vector3) -> Dictionary:
	return source_cached_ceiling_at(location)

func source_cached_ceiling_at(location: Vector3, cache: Dictionary = {}) -> Dictionary:
	return source_ceiling_query_result(location,cache).hit

func source_raw_ceiling_query(location: Vector3, cache: Dictionary = {}, previous: Dictionary = {}) -> Dictionary:
	var query := source_ceiling_query_result(location,cache)
	return SourceCollision.terrain_query_state(previous,query.hit,"query_field_18",int(query.cache_match))

func source_map_position(position: Array) -> Dictionary:
	var factors: Array = runtime_tables.get("mapYScale",{}).get("values",[])
	var style := int(room_data.style)
	if style < 0 or style >= factors.size():
		return {"fault":"Missing source map placement scale"}
	return preload("res://source_rotation.gd").map_position(position,int(factors[style]))

func source_terrain_wall_data(identity: Dictionary) -> Dictionary:
	var tile_index := int(identity.get("tile",-1))
	var record_index := int(identity.get("record",-1))
	if tile_index < 0 or tile_index >= room_data.tracks.size():
		return {"fault":"Missing source wall tile identity"}
	var tile: Dictionary = room_data.tracks[tile_index]
	var groups: Array = terrain_models[int(tile.index)].get("collision",{}).get("groups",[])
	if groups.is_empty() or record_index < 0 or record_index >= groups[0].size():
		return {"fault":"Missing source wall record identity"}
	return {"record":groups[0][record_index],"position":Vector3i(int(tile.position[0])*4096,roundi(float(tile.position[1])*4096.0),int(tile.position[2])*4096),"angle":roundi(float(tile.rotation)*4096.0)}

func source_player_gradient(rider: Node3D) -> Dictionary:
	# PlayerMove byte60 is surface type; byte62 contains terrain/actor mode bits.
	if (int(rider.secondary_flags)&2) == 0 and int(rider.source_ground.get("surface_type",0)) != 15:
		return {"x":0,"z":0,"yaw":0}
	if (int(rider.source_ground.mode)&1) != 0:
		var data := source_terrain_wall_data(rider.source_ground)
		if data.has("fault"):
			return data
		var words: Array = data.record.get("halfwords",[])
		if words.size() != 22:
			return {"fault":"Missing PlayerMove terrain gradient record"}
		return {"x":int(words[18]),"z":int(words[19]),"yaw":int(data.angle)&65535}
	if not rider.source_ground.has("actor"):
		return {"fault":"Missing PlayerMove gradient owner"}
	var owner_index := int(rider.source_ground.actor)&255
	if not source_pool.slots.has(owner_index):
		# Native Free27110 zeroes372/376 but cached owner bytes can survive.
		# A known free slot is inactive; an unknown identity remains an error.
		if source_pool.free_slots.has(owner_index): return {"x":0,"z":0,"yaw":0}
		return {"fault":"Missing PlayerMove gradient owner"}
	var owner = source_pool.slots[owner_index].node
	if owner == null or not is_instance_valid(owner):
		return {"fault":"Invalid PlayerMove gradient owner"}
	if (int(owner.secondary_flags)&0x20) == 0 or (int(owner.primary_flags)&1) == 0:
		return {"x":0,"z":0,"yaw":0}
	var models: Array = owner.model_data.get("models",[])
	if models.is_empty() or not rider.source_ground.has("record"):
		return {"fault":"Missing PlayerMove owner model/record"}
	var records: Array = []
	for group in models[0].get("collision",{}).get("groups",[]):
		records.append_array(group)
	var index := int(rider.source_ground.record)&65535
	if index >= records.size():
		return {"fault":"Invalid PlayerMove owner record"}
	var words: Array = records[index].get("halfwords",[])
	if words.size() != 22:
		return {"fault":"Missing PlayerMove owner gradient words"}
	return {"x":int(words[18]),"z":int(words[19]),"yaw":int(owner.source_angles.y)&65535}

func source_lower_wall_stage(input: Dictionary) -> Dictionary:
	var state := input.duplicate(true)
	var quarter: Array = runtime_tables.trigonometry.quarterSine
	var angles: Array = runtime_tables.wallAngles.values
	state.lower = source_raw_floor_query(Vector3(state.forward)*CELL_METERS/4096.0,state.cache.get("lower",{}),state.get("lower",{}))
	state.lower_clearance = 512 if int(state.lower.tile) >= 0 and int(state.lower.get("surface_type",0)) in [13,14] else 256
	if SourceCollision.lower_sample_guard(int(state.sample_index),int(state.get("secondary",0)),int(state.lower.tile),int(state.cache.get("lower",{}).get("tile",-1)),int(state.get("previous_mode",0))):
		state.edge_transition = true
		return state
	var hit: Dictionary = state.lower if int(state.lower.tile) >= 0 else {}
	var response: Dictionary
	if hit.is_empty():
		if int(state.cache.get("lower",{}).get("tile",-1)) < 0:
			return state
		var old := source_terrain_wall_data(state.cache.lower)
		if old.has("fault"):
			return old
		response = SourceCollision.solve_cached_tile_wall(old.record,state.forward,state.opposite,state.actor_position,old.position,old.angle,int(state.sample_index),int(room_data.style),quarter,angles)
		if response.has("fault"):
			return response
		state.actor_position = response.actor_position
		state.forward = response.forward
		state.opposite = response.opposite
		state.status = int(state.status) | int(response.status_set)
		state.contact_bits = int(state.contact_bits) | int(response.contact_bits)
		if response.wall_angle_valid:
			state.wall_angle = response.wall_angle
		if int(response.contact_bits) != 0:
			state.lower.tile = state.cache.lower.tile
			state.lower.record = state.cache.lower.record
		return state
	var entry := SourceCollision.fresh_wall_entry(hit,int(state.actor_position.y),int(state.sample_index))
	if not entry.blocked:
		return state
	var current := source_terrain_wall_data(hit)
	if current.has("fault"):
		return current
	response = SourceCollision.solve_fresh_slope_wall(current.record,hit,state.forward,state.opposite,state.actor_position,current.position,current.angle,int(state.sample_index),quarter,angles)
	if response.has("fault"):
		return response
	state.actor_position = response.actor_position
	state.forward = response.forward
	state.opposite = response.opposite
	state.status = int(state.status) | int(response.status_set)
	state.contact_bits = int(state.contact_bits) | int(response.contact_bits)
	if response.get("wall_angle_valid",false):
		state.wall_angle = response.wall_angle
	var route := SourceCollision.fresh_wall_route(current.record,int(state.cache.get("lower",{}).get("tile",-1)),int(state.ground_type),int(hit.query_field_6),bool(response.handled))
	if route == 1:
		return state
	if route == 3:
		var old := source_terrain_wall_data(state.cache.lower)
		if old.has("fault"):
			return old
		response = SourceCollision.solve_cached_tile_wall(old.record,state.forward,state.opposite,state.actor_position,old.position,old.angle,int(state.sample_index),int(room_data.style),quarter,angles,false)
		if response.has("fault"):
			return response
		state.status = int(state.status) | int(response.status_set)
		if response.wall_angle_valid:
			state.wall_angle = response.wall_angle
		if int(response.contact_bits) != 0:
			state.actor_position = response.actor_position
			state.forward = response.forward
			state.opposite = response.opposite
			return state
	response = SourceCollision.solve_opposite_tile_wall(current.record,state.forward,state.opposite,state.actor_position,current.position,current.angle,int(hit.height_units),quarter,angles,int(state.status))
	if response.has("fault"):
		return response
	state.actor_position = response.actor_position
	state.forward = response.forward
	state.opposite = response.opposite
	state.status = response.status
	if response.wall_angle_valid:
		state.wall_angle = response.wall_angle
	if response.ground_override != null:
		state.ground_height = response.ground_override
	if response.requery:
		state.lower = source_raw_floor_query(Vector3(state.forward)*CELL_METERS/4096.0,state.cache.get("lower",{}),state.lower)
	return state

func source_movement_sample_loop(rider: Node3D, input: Dictionary) -> Dictionary:
	var state := input.duplicate(true)
	state.actor_clearance = 256
	var rotation_math = preload("res://source_rotation.gd")
	state.samples_processed = 0
	for index in range(int(rider.collision_point_count)):
		var pair := rotation_math.wall_sample_pair(int(rider.source_angles.y),state.actor_position,rider.collision_points[index],runtime_tables.rotation.pairs)
		if pair.has("fault"):
			return pair
		state.forward = pair.forward
		state.opposite = pair.opposite
		state.sample_index = index
		state.cache = rider.source_point_cache(index)
		state = source_lower_wall_stage(state)
		if state.has("fault"):
			return state
		rider.position = Vector3(state.actor_position)*CELL_METERS/4096.0
		state = source_upper_wall_stage(state)
		if state.has("fault"):
			return state
		rider.position = Vector3(state.actor_position)*CELL_METERS/4096.0
		state = source_actor_wall_stage(state,rider)
		if state.has("fault"):
			return state
		rider.position = Vector3(state.actor_position)*CELL_METERS/4096.0
		if not rider.store_source_movement_cache(index,state.lower,state.upper):
			return {"fault":"Unresolved movement sample cache words","sample":index}
		state.samples_processed = index+1
	return state

func source_finalize_movement(rider: Node3D, input: Dictionary, center_cache: Dictionary, previous_ground: Dictionary) -> Dictionary:
	var state := input.duplicate(true)
	var location: Vector3 = Vector3(state.actor_position)*CELL_METERS/4096.0
	var lower := source_raw_floor_query(location,center_cache.get("lower",{}),state.get("lower",{}))
	var upper := source_raw_ceiling_query(location,center_cache.get("upper",{}),state.get("upper",{}))
	var contacts := source_contacts_at(location,rider,256)
	var upper_hit: Dictionary = upper if int(upper.tile) >= 0 else {}
	var tail := SourceCollision.movement_response_tail(int(state.actor_position.y),lower,upper_hit,contacts.lower,contacts.upper,int(room_data.style),256,int(state.status),int(state.contact_bits),center_cache.get("lower",{"tile":-2}),previous_ground)
	var lower_identity: Dictionary = tail.lower_cache
	if lower_identity.is_empty():
		lower_identity = {"tile":int(lower.tile)}
		if lower.has("record"):
			lower_identity.record = lower.record
	var upper_identity := {"tile":int(upper.tile)}
	if upper.has("record"):
		upper_identity.record = upper.record
	var cache := SourceCollision.movement_point_cache(lower_identity,upper_identity)
	if cache.has("fault"):
		return cache
	if state.get("edge_transition",false):
		if (int(state.get("previous_mode",0)) & 4) == 0 and not state.has("contact_owner"):
			return {"fault":"Missing source edge contact-owner state"}
		tail = SourceCollision.movement_edge_transition(tail,int(state.get("previous_mode",0)),rider.source_point_cache(0).get("lower",{}),int(state.get("contact_owner",0)),true)
		if tail.has("fault"):
			return tail
	state.actor_position.y = int(tail.y)
	state.ground = tail.ground
	state.status = tail.status
	state.ceiling_type = tail.ceiling_type
	state.center_cache = cache
	state.center_actor_contacts = contacts
	state.ceiling_owner = tail.contact_actor
	state.ceiling_owner_secondary_set = tail.actor_secondary_set
	state.field_180 = upper.get("height_units",null)
	state.lower = lower
	state.upper = upper
	return state

func source_actor_wall_stage(input: Dictionary, rider: Node3D) -> Dictionary:
	var state := input.duplicate(true)
	var contacts := source_contacts_at(Vector3(state.forward)*CELL_METERS/4096.0,rider)
	state.actor_contacts = contacts
	if int(state.sample_index) == 0 and (int(state.get("secondary",0)) & 0x1000) != 0 and not contacts.lower.is_empty() and int(contacts.lower.actor) == int(state.get("contact_owner",-1)) and (int(state.get("previous_mode",0)) & 8) != 0:
		state.edge_transition = true
		return state
	if not SourceCollision.actor_wall_entry(contacts.lower,contacts.upper,int(state.actor_position.y),int(state.get("actor_clearance",256))):
		return state
	var index := int(contacts.lower.actor)
	if not source_pool.slots.has(index):
		return {"fault":"Unresolved source actor wall owner"}
	var owner = source_pool.slots[index].node
	if owner == null or not is_instance_valid(owner) or not owner.has_method("source_point_cache") or owner.model_data.is_empty():
		return {"fault":"Unimplemented source actor wall owner"}
	var records: Array = []
	for group in owner.model_data.models[0].get("collision",{}).get("groups",[]):
		records.append_array(group)
	var record_index := int(contacts.lower.record)
	if record_index < 0 or record_index >= records.size():
		return {"fault":"Missing source actor wall record"}
	var owner_position := Vector3i(roundi(owner.position.x/CELL_METERS*4096.0),roundi(owner.position.y/CELL_METERS*4096.0),roundi(owner.position.z/CELL_METERS*4096.0))
	var descriptor := {"position":owner_position,"scale":Vector2i(owner.source_scale.x,owner.source_scale.z),"yaw":owner.source_angles.y,"primary":owner.primary_flags,"secondary":owner.secondary_flags}
	var response := SourceCollision.actor_wall_response(records[record_index],contacts.lower,contacts.upper,state.forward,state.opposite,state.actor_position,int(state.primary),descriptor,int(state.sample_index),runtime_tables.trigonometry.quarterSine,runtime_tables.wallAngles.values,int(state.get("actor_clearance",256)),int(state.status),int(state.ground_height))
	if response.has("fault"):
		return response
	owner.secondary_flags = response.owner_secondary
	if response.needs_push_probes:
		response = source_resolve_actor_push(response,owner)
		if response.has("fault"):
			return response
		owner.position = Vector3(response.owner_position)*CELL_METERS/4096.0
	state.actor_position = response.rider_position
	state.forward = response.forward
	state.opposite = response.opposite
	state.status = response.status
	state.contact_bits = int(state.contact_bits) | int(response.contact_bits)
	state.ground_height = response.ground_height
	if response.wall_angle_valid:
		state.wall_angle = response.wall_angle
	if response.write_contact_owner:
		state.contact_owner = response.contact_owner
	if response.has("last_push_probe"):
		state.lower = SourceCollision.terrain_query_state(state.lower,response.last_push_probe.terrain,"query_field_6",0)
		state.actor_contacts.lower = response.last_push_probe.actor_lower
		state.actor_contacts.upper = response.last_push_probe.actor_upper
	return state

func source_upper_wall_stage(input: Dictionary) -> Dictionary:
	var state := input.duplicate(true)
	var quarter: Array = runtime_tables.trigonometry.quarterSine
	var angles: Array = runtime_tables.wallAngles.values
	state.upper = source_raw_ceiling_query(Vector3(state.forward)*CELL_METERS/4096.0,state.cache.get("upper",{}),state.get("upper",{}))
	var lower: Dictionary = state.lower if int(state.lower.tile) >= 0 else {}
	var upper: Dictionary = state.upper if int(state.upper.tile) >= 0 else {}
	var response: Dictionary
	if upper.is_empty():
		if not lower.is_empty() or int(room_data.style) != 1 or int(state.cache.get("upper",{}).get("tile",-1)) < 0:
			return state
		var old := source_terrain_wall_data(state.cache.upper)
		if old.has("fault"):
			return old
		response = SourceCollision.solve_cached_tile_wall(old.record,state.forward,state.opposite,state.actor_position,old.position,old.angle,int(state.sample_index),1,quarter,angles,true,true)
		if response.has("fault"):
			return response
		state.actor_position = response.actor_position
		state.forward = response.forward
		state.opposite = response.opposite
		if response.wall_angle_valid:
			state.wall_angle = response.wall_angle
		if response.moved:
			state.upper.tile = state.cache.upper.tile
			state.upper.record = state.cache.upper.record
		return state
	var clearance := int(state.get("lower_clearance",256))
	if not SourceCollision.upper_wall_entry(upper,lower,int(state.actor_position.y),clearance):
		return state
	var current := source_terrain_wall_data(upper)
	if current.has("fault"):
		return current
	response = SourceCollision.solve_upper_slope_wall(current.record,upper,lower,state.forward,state.opposite,state.actor_position,current.position,current.angle,int(state.sample_index),quarter,clearance)
	if response.has("fault"):
		return response
	state.actor_position = response.actor_position
	state.forward = response.forward
	state.opposite = response.opposite
	state.status = int(state.status) | int(response.status_set)
	state.contact_bits = int(state.contact_bits) | int(response.contact_bits)
	var route := SourceCollision.upper_wall_route(int(state.cache.get("upper",{}).get("tile",-1)),int(state.upper.query_field_18),bool(response.handled))
	if route == 1:
		return state
	if route == 3:
		var old := source_terrain_wall_data(state.cache.upper)
		if old.has("fault"):
			return old
		response = SourceCollision.solve_upper_cached_tile_wall(old.record,state.forward,state.opposite,state.actor_position,old.position,old.angle,quarter,angles)
		if response.has("fault"):
			return response
		if response.wall_angle_valid:
			state.wall_angle = response.wall_angle
		if not response.current_record_fallback:
			state.actor_position = response.actor_position
			state.forward = response.forward
			state.opposite = response.opposite
			state.upper = source_raw_ceiling_query(Vector3(state.forward)*CELL_METERS/4096.0,state.cache.get("upper",{}),state.upper)
			return state
	response = SourceCollision.solve_upper_opposite_tile_wall(current.record,state.forward,state.opposite,state.actor_position,current.position,current.angle,quarter)
	if response.has("fault"):
		return response
	state.actor_position = response.actor_position
	state.forward = response.forward
	state.opposite = response.opposite
	if response.requery_upper:
		state.upper = source_raw_ceiling_query(Vector3(state.forward)*CELL_METERS/4096.0,state.cache.get("upper",{}),state.upper)
	return state

func source_camera_alternate_query(position_units: Vector3i, cache: Dictionary = {}) -> Dictionary:
	# Native378b4: centered terrain-only query, lower then upper, Y reduced512.
	if not room_data.has("tracks") or runtime_tables.get("trigonometry",{}).get("quarterSine",[]).size() != 1025:
		return {"fault":"Missing source camera terrain query data"}
	var point := Vector3i(position_units.x,SourceCollision.VM.signed32(position_units.y-512),position_units.z)
	var location := Vector3(point)*CELL_METERS/4096.0
	var geometry := source_camera_geometry()
	if geometry.has("fault"): return geometry
	var lower: Dictionary = source_cached_floor_at(location,cache.get("lower",{}),geometry)
	var upper: Dictionary = source_ceiling_query_result(location,cache.get("upper",{}),geometry).hit
	var refreshed := cache.duplicate(true)
	for pair in [["lower",lower],["upper",upper]]:
		var record: Dictionary = refreshed.get(pair[0],{}).duplicate()
		record["tile"] = int(pair[1].get("tile",-1))
		if pair[1].has("record"): record["record"] = int(pair[1].record)
		refreshed[pair[0]] = record
	return {"height":int(lower.get("height_units",0)) if int(lower.get("tile",-1)) >= 0 else 0,"collision_bits":0,"cache":refreshed}

func source_camera_probe_points(position_units: Vector3i, yaw: int) -> Array[Vector3i]:
	# Native362b0..363a8: yaw-only view matrix and six short camera probes.
	var matrix := preload("res://source_cutscene_view.gd").matrix(Vector3i(0,yaw,0),runtime_tables.rotation.pairs)
	var result: Array[Vector3i] = []
	for offset in [Vector3i(384,0,192),Vector3i(-384,0,192),Vector3i(0,0,192),Vector3i(256,0,-128),Vector3i(-256,0,-128),Vector3i(0,0,-128)]:
		var rotated: Vector3i = preload("res://source_rotation.gd").transform_short(matrix,offset).position
		result.append(Vector3i(SourceCollision.VM.signed32(position_units.x+rotated.x),SourceCollision.VM.signed32(position_units.y-512),SourceCollision.VM.signed32(position_units.z+rotated.z)))
	return result

func source_camera_probe_lower_queries(position_units: Vector3i, yaw: int, caches: Array = []) -> Dictionary:
	var geometry := source_camera_geometry()
	if geometry.has("fault"): return geometry
	var points := source_camera_probe_points(position_units,yaw)
	var results: Array = []
	var refreshed: Array = []
	var blocking_bits := 0
	var routes: Array[int] = []
	for index in range(points.size()):
		var previous: Dictionary = caches[index] if index < caches.size() else {"tile":-1,"record":0}
		var hit := source_cached_floor_at(Vector3(points[index])*CELL_METERS/4096.0,previous,geometry)
		var cache := previous.duplicate()
		cache.tile = int(hit.get("tile",-1))
		if hit.has("record"): cache.record = int(hit.record)
		refreshed.append(cache);results.append(hit)
		routes.append(preload("res://source_camera_wall.gd").lower_route(int(previous.get("tile",-1)),int(hit.get("query_field_6",0))))
		# Native36870..368b0: a lower plane blocks only above queryY+256.
		if cache.tile >= 0 and points[index].y < SourceCollision.VM.signed32(int(hit.height_units)-256):
			blocking_bits |= 1<<index
	return {"points":points,"lower":results,"cache":refreshed,"lower_blocking_bits":blocking_bits,"routes":routes}

func source_camera_fresh_query(position_units: Vector3i, yaw: int, center_cache: Dictionary = {}) -> Dictionary:
	return source_camera_normal_query(position_units,yaw,[],center_cache)

func source_camera_collision_phase(camera_state: Dictionary) -> Dictionary:
	# Native41ab4..41afc: query counter selects the helper; decrement belongs
	# later to41d28, once per update, rather than to each query invocation.
	if not camera_state.has("position"): return {"fault":"Missing camera query position"}
	var next := camera_state.duplicate(true)
	var points: Array = next.get("point_caches",[])
	if points.is_empty():
		for index in range(6): points.append({"lower":{"tile":-1,"record":0},"upper":{"tile":-1,"record":0}})
	if points.size() != 6: return {"fault":"Invalid camera probe cache count"}
	var center: Dictionary = next.get("center_cache",{"lower":{"tile":int(next.get("lower_tile",-1)),"record":int(next.get("lower_record",0))},"upper":{"tile":int(next.get("upper_tile",-1)),"record":int(next.get("upper_record",0))}})
	var result: Dictionary
	if int(next.get("query_counter",0)) != 0:
		result = source_camera_alternate_query(next.position,center)
		if result.has("fault"): return result
		for point in points: point.lower.tile = -1 # Native37924..37944 only clears tile halfword.
		result.position = next.position
	else:
		var lower: Array = []
		for point in points: lower.append(point.lower)
		result = source_camera_normal_query(next.position,int(next.get("yaw",0)),lower,center)
		if result.has("fault"): return result
		for index in range(6): points[index].lower = result.probe_cache[index].duplicate()
	next.position = result.position;next.point_caches = points;next.center_cache = result.cache
	next.lower_tile = result.cache.lower.tile;next.upper_tile = result.cache.upper.tile
	next.lower_record = int(result.cache.lower.get("record",0));next.upper_record = int(result.cache.upper.get("record",0))
	result.camera_state = next
	return result

func source_camera_retained_push(point: Vector3i, previous: Dictionary, geometry: Dictionary, missed: bool = false) -> Dictionary:
	# Native36a3c..37368: tentative enabled-edge pushes are retained only
	# when their lower requery clears; otherwise roll back and use route4.
	var tile_index := int(previous.get("tile",-1));var record_index := int(previous.get("record",-1))
	if tile_index < 0 or tile_index >= geometry.tracks.size(): return {"fault":"Invalid retained camera tile"}
	var tile: Dictionary = geometry.tracks[tile_index]
	var model: Dictionary = geometry.models[int(tile.index)]
	if record_index < 0 or record_index >= model.collision.groups[0].size(): return {"fault":"Invalid retained camera record"}
	var record: Dictionary = model.collision.groups[0][record_index]
	var h: Array = record.halfwords
	var quarter: Array = runtime_tables.trigonometry.quarterSine
	var angle := roundi(float(tile.rotation)*4096.0)
	var local := SourceCollision.local_point(Vector2i(point.x-int(tile.position[0])*4096,point.z-int(tile.position[2])*4096),angle,quarter)
	if missed: return preload("res://source_camera_wall.gd").miss_accumulated_push(record,local,angle,quarter)
	var accumulated := Vector2i.ZERO
	for edge in range(4 if (int(h[0])&4) else 3):
		if ((int(h[1])>>(edge+8))&1) == 0: continue
		var correction := preload("res://source_camera_wall.gd").edge_push(record,local,edge,6)
		if correction.has("fault"): return correction
		if int(correction.distance) > 0: continue
		accumulated = Vector2i(preload("res://source_rotation.gd").halfword(accumulated.x+correction.delta.x),preload("res://source_rotation.gd").halfword(accumulated.y+correction.delta.y))
		var delta := SourceCollision.local_point(accumulated,-angle,quarter)
		var candidate := Vector3i(SourceCollision.VM.signed32(point.x+delta.x),point.y,SourceCollision.VM.signed32(point.z+delta.y))
		var hit := source_cached_floor_at(Vector3(candidate)*CELL_METERS/4096.0,previous,geometry)
		if hit.is_empty() or candidate.y >= SourceCollision.VM.signed32(int(hit.height_units)-256): return {"world_delta":delta}
	return preload("res://source_camera_wall.gd").accumulated_edge_push(record,local,angle,quarter)

func source_camera_normal_query(position_units: Vector3i, yaw: int, probe_caches: Array = [], center_cache: Dictionary = {}) -> Dictionary:
	# Native normal query, including retained lower misses and routes2/3/4.
	var geometry := source_camera_geometry()
	if geometry.has("fault"): return geometry
	var position := position_units
	var caches: Array = []
	var bits := 0
	var quarter: Array = runtime_tables.trigonometry.quarterSine
	for index in range(6):
		var point: Vector3i = source_camera_probe_points(position,yaw)[index]
		var previous: Dictionary = probe_caches[index] if index < probe_caches.size() else {"tile":-1,"record":0}
		var hit := source_cached_floor_at(Vector3(point)*CELL_METERS/4096.0,previous,geometry)
		if hit.is_empty() and int(previous.get("tile",-1)) >= 0:
			var miss := source_camera_retained_push(point,previous,geometry,true)
			if miss.has("fault"): return miss
			if bool(miss.blocked): bits |= 1<<index
			var miss_delta: Vector2i = miss.world_delta
			position.x = SourceCollision.VM.signed32(position.x+miss_delta.x)
			position.z = SourceCollision.VM.signed32(position.z+miss_delta.y)
			caches.append(previous.duplicate() if miss_delta != Vector2i.ZERO else {"tile":-1,"record":0})
			continue
		if not hit.is_empty() and point.y < SourceCollision.VM.signed32(int(hit.height_units)-256):
			bits |= 1<<index
			var tile: Dictionary = geometry.tracks[int(hit.tile)]
			var model: Dictionary = geometry.models[int(tile.index)]
			var record: Dictionary = model.collision.groups[0][int(hit.record)]
			var origin := Vector2i(int(tile.position[0])*4096,int(tile.position[2])*4096)
			var angle := roundi(float(tile.rotation)*4096.0)
			var center := SourceCollision.local_point(Vector2i(position.x-origin.x,position.z-origin.y),angle,quarter)
			var probe := SourceCollision.local_point(Vector2i(point.x-origin.x,point.z-origin.y),angle,quarter)
			var route := preload("res://source_camera_wall.gd").lower_route(int(previous.get("tile",-1)),int(hit.get("query_field_6",0)))
			var response: Dictionary = source_camera_retained_push(point,previous,geometry) if route == 3 else preload("res://source_camera_wall.gd").fresh_accumulated_push(record,center,probe,angle,quarter)
			if response.has("fault"): return response
			var delta: Vector2i = response.world_delta
			position.x = SourceCollision.VM.signed32(position.x+delta.x)
			position.z = SourceCollision.VM.signed32(position.z+delta.y)
			if delta != Vector2i.ZERO:
				point.x = SourceCollision.VM.signed32(point.x+delta.x);point.z = SourceCollision.VM.signed32(point.z+delta.y)
				hit = source_cached_floor_at(Vector3(point)*CELL_METERS/4096.0,previous,geometry)
		caches.append({"tile":int(hit.get("tile",-1)),"record":int(hit.get("record",0))})
	var center_result := source_camera_alternate_query(position,center_cache)
	if center_result.has("fault"): return center_result
	return {"position":position,"height":center_result.height,"collision_bits":bits,"cache":center_result.cache,"probe_cache":caches}

func source_camera_geometry() -> Dictionary:
	if source_camera_geometry_cache.has(map_name): return source_camera_geometry_cache[map_name]
	var link: Dictionary = manifest.get("linkage",{}).get("rooms",{}).get(map_name,{})
	if link.get("camera",null) == null or link.get("redirectOffset",null) == null:
		return {"fault":"Missing authored camera geometry for "+map_name}
	var file := str(link.camera)
	var redirect_file := file.substr(0,file.rfind("-"))+"-%d.json"%int(link.redirectOffset)
	var redirect := read_shared_content(redirect_file)
	var camera_models := read_shared_content(file)
	if redirect.get("values",[]).size() != 256 or not camera_models.has("models"):
		return {"fault":"Missing camera model redirect or model bank for "+map_name}
	var tracks: Array = room_data.tracks.duplicate(true)
	for tile in tracks:
		var index := int(tile.index)
		if index < 0 or index >= 256: return {"fault":"Camera source tile index outside redirect"}
		tile.index = int(redirect.values[index])
		if tile.index >= camera_models.models.size(): return {"fault":"Camera redirect outside model bank"}
	var result := {"tracks":tracks,"models":camera_models.models}
	source_camera_geometry_cache[map_name] = result
	return result

func source_raw_floor_query(location: Vector3, cache: Dictionary = {}, previous: Dictionary = {}) -> Dictionary:
	var hit := source_cached_floor_at(location,cache)
	return SourceCollision.terrain_query_state(previous,hit,"query_field_6",int(hit.get("query_field_6",0)))

func source_ceiling_query_result(location: Vector3, cache: Dictionary = {}, geometry: Dictionary = {}) -> Dictionary:
	var tracks: Array = geometry.get("tracks",room_data.tracks)
	var models: Array = geometry.get("models",terrain_models)
	var reused := 0
	var tile_index := int(cache.get("tile",-1))
	var record_index := int(cache.get("record",-1))
	var quarter: Array = runtime_tables.get("trigonometry",{}).get("quarterSine",[])
	if tile_index >= 0 and tile_index < tracks.size() and quarter.size() == 1025:
		var tile: Dictionary = tracks[tile_index]
		var groups: Array = models[int(tile.index)].get("collision",{}).get("groups",[])
		if not groups.is_empty() and record_index >= 0 and record_index < groups[0].size():
			var x := SourceCollision.VM.signed32(roundi(location.x / CELL_METERS * 4096.0)-int(tile.position[0])*4096)
			var z := SourceCollision.VM.signed32(roundi(location.z / CELL_METERS * 4096.0)-int(tile.position[2])*4096)
			var mx := SourceCollision.VM.signed32(-x) if x < 0 else x
			var mz := SourceCollision.VM.signed32(-z) if z < 0 else z
			if mx < 2176 and mz < 2176:
				var point := SourceCollision.local_point(Vector2i(x,z),roundi(float(tile.rotation)*4096.0),quarter)
				reused = int(not SourceCollision.surface(groups[0][record_index],point,true,true).is_empty())
	# Cached match marks the query; it does not seed or short-circuit the upper scan.
	return {"hit":SourceCollision.select_ceiling(terrain_surfaces_at(location,geometry),roundi(location.y / CELL_METERS * 4096.0),reused),"cache_match":reused}

func source_cached_floor_at(location: Vector3, cache: Dictionary = {}, geometry: Dictionary = {}) -> Dictionary:
	var tracks: Array = geometry.get("tracks",room_data.tracks)
	var models: Array = geometry.get("models",terrain_models)
	var hits := terrain_surfaces_at(location,geometry)
	var tile_index := int(cache.get("tile",-2))
	var record_index := int(cache.get("record",-1))
	var skip_type_17 := false
	var initial: Dictionary = {}
	if tile_index >= 0 and tile_index < tracks.size():
		var model_index := int(tracks[tile_index].index)
		var model: Dictionary = models[model_index]
		var groups: Array = model.get("collision",{}).get("groups",[])
		if not groups.is_empty() and record_index >= 0 and record_index < groups[0].size():
			var record: Dictionary = groups[0][record_index]
			skip_type_17 = ((int(record.halfwords[0]) >> 8) & 255) != 17
			for hit in hits:
				if int(hit.tile) == tile_index and int(hit.group) == 0 and int(hit.record) == record_index:
					initial = hit
					initial["query_field_6"] = 1
					break
			if not initial.is_empty() and groups[1].is_empty():
				return initial.duplicate()
	return SourceCollision.select_floor(hits,roundi(location.y / CELL_METERS * 4096.0),skip_type_17,initial)

func source_ground_at(location: Vector3, query_actor: Node3D = null, terrain_cache: Dictionary = {}) -> Dictionary:
	var contacts := source_contacts_at(location,query_actor)
	return SourceCollision.choose_ground(source_cached_floor_at(location,terrain_cache),contacts.lower,roundi(location.y / CELL_METERS * 4096.0))

func terrain_surfaces_at(location: Vector3, geometry: Dictionary = {}) -> Array[Dictionary]:
	var tracks: Array = geometry.get("tracks",room_data.get("tracks",[]))
	var models: Array = geometry.get("models",terrain_models)
	var hits: Array[Dictionary] = []
	var point := Vector3i(roundi(location.x / CELL_METERS * 4096.0),roundi(location.y / CELL_METERS * 4096.0),roundi(location.z / CELL_METERS * 4096.0))
	var quarter: Array = runtime_tables.get("trigonometry",{}).get("quarterSine",[])
	var candidates:Array=terrain_query_index.candidates(tracks,point) if geometry.is_empty() else range(tracks.size())
	for index in candidates:
		var tile: Dictionary = tracks[index]
		var model_index := int(tile.index)
		if model_index < 0 or model_index >= models.size():
			continue
		for hit in SourceCollision.tile_surfaces(tile,models[model_index],point,quarter):
			hit["tile"] = index
			hits.append(hit)
	return hits
var room_data: Dictionary
var terrain_query_index=preload("res://source_terrain_index.gd").new()
var map_name := "MP010_00.MAP"
var imported := false
var terrain: Node3D
var triggers: Array[Dictionary] = []
var total_gems := 0
var transition_cooldown := 0.0
var collected: Dictionary = {}
var mesh_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var debug_status := ""
var character_data: Dictionary
var character_parts: Array[MeshInstance3D] = []
var character_animations: Dictionary = {}
var actor_animation_paths: Dictionary = {}
var idle_animation := "CROCWA4.ANI"
var character_texture: Dictionary
var character_frame_cache: Dictionary = {}
var animation_name := ""
var animation_time := 0.0
var animation_frame := -1
var report_elapsed := 0.0
var source_actors: Array[Node3D] = []
var audio_cache: Dictionary = {}
var sound_voices: Array[Node3D] = []
var source_resource_handles: Array[Dictionary] = [{}]
var source_asset_json: Dictionary = {}
var source_static_meshes: Dictionary = {}
var source_deformed_meshes: Dictionary = {}
var source_material_bindings: Dictionary = {}
var shared_content_metadata:Dictionary={}
func read_shared_content(relative:String) -> Dictionary:
	# Persistent, read-only banks shared by rooms and music requests.
	if not shared_content_metadata.has(relative):shared_content_metadata[relative]=read_json(relative)
	return shared_content_metadata[relative]
var runtime_costs:Dictionary={}
var runtime_slow_events:Array=[]
var performance_history=preload("res://runtime_performance_history.gd").new()
var performance_history_error:=OK
func record_runtime_cost(category:String, elapsed:int, asset:String = "") -> void:
	if not runtime_costs.has(category):runtime_costs[category]={"calls":0,"total_us":0,"max_us":0}
	var sample:Dictionary=runtime_costs[category]
	sample.calls+=1;sample.total_us+=elapsed;sample.max_us=maxi(sample.max_us,elapsed)
	if elapsed>(20000 if category=="frame_interval" else 4000):
		if runtime_slow_events.size()>=20:runtime_slow_events.pop_front()
		runtime_slow_events.append({"elapsed_us":Time.get_ticks_usec(),"category":category,"duration_us":elapsed,"room":map_name,"mode":source_main_mode,"actors":source_actors.size(),"animation":source_player_actor.clip_name if is_instance_valid(source_player_actor) else "","asset":asset})
func read_source_asset(relative: String) -> Dictionary:
	# Actor assets are immutable. Keep mutable world/session JSON on read_json.
	if not source_asset_json.has(relative):source_asset_json[relative]=read_json(relative)
	return source_asset_json[relative]
func source_static_mesh(file: String, index: int, model: Dictionary, texture: Dictionary) -> ArrayMesh:
	var key:=file+":"+str(room_data.style)+":"+str(index)
	if not source_static_meshes.has(key):source_static_meshes[key]=geometry(model,texture)
	return source_static_meshes[key]
func source_deformed_mesh(key: String, model: Dictionary, texture: Dictionary) -> ArrayMesh:
	key=str(room_data.style)+":"+key
	if not source_deformed_meshes.has(key):
		if source_deformed_meshes.size()>=512:source_deformed_meshes.erase(source_deformed_meshes.keys()[0])
		source_deformed_meshes[key]=geometry(model,texture)
	return source_deformed_meshes[key]

func source_resource_handle_bank() -> Array[Dictionary]:
	return source_resource_handles
var source_voice_pool = preload("res://source_voice_pool.gd").new()
var source_voice_nodes: Dictionary = {}
var source_spu_layout = preload("res://source_spu_layout.gd").new()
var source_spu_layout_fault := ""
var source_sound_request_fault := ""
var source_sample_volumes: Dictionary = {}
var source_audio_master_gain: int: # Compatibility name for active effects halfword80074b42.
	get: return source_effects_volume
	set(value): source_effects_volume = value
var source_effects_restore_volume := 127 # Saved level gp1724 /80074f9c.
var source_audio_master_maximum := 127
var source_audio_master_step := 15
var source_audio_muted := false
func apply_source_effects_option_state(state: Dictionary) -> bool:
	if not state.has_all(["audio","effects_restore_volume","effects_maximum","effects_step"]) or not state.audio.has("effects"): return false
	for value in [state.audio.effects,state.effects_restore_volume,state.effects_maximum]:
		if not value is int or value < 0 or value > 127: return false
	if int(state.effects_step) != preload("res://source_audio_math.gd").fade_step(int(state.effects_maximum)): return false
	source_effects_volume = int(state.audio.effects)
	source_effects_restore_volume = int(state.effects_restore_volume)
	source_audio_master_maximum = int(state.effects_maximum)
	source_audio_master_step = int(state.effects_step)
	return true

func stop_imported_audio() -> void:
	if is_instance_valid(source_gameplay_music):source_gameplay_music.stop_room()
	if is_instance_valid(source_options_music_backend) and source_options_music_backend.playback_state!=0:source_options_music_backend.stop_track()
	for voice in sound_voices:
		if is_instance_valid(voice):
			stop_imported_voice_playback(voice)
			voice.queue_free()
	sound_voices.clear()
	source_voice_nodes.clear()
	source_voice_pool.reserved.fill(false)
	audio_cache.clear()

func _exit_tree() -> void:
	if source_sequence_load!=null and source_sequence_load.is_started():source_sequence_load.wait_to_finish()
	stop_imported_audio()
const ASLActor = preload("res://asl_actor.gd")
const SPUVoiceNode = preload("res://source_spu_voice_node.gd")
func source_sound_channels(location: Vector3, volume: int) -> Dictionary:
	if source_cd_stereo_flag == 0: return {"left":volume,"right":volume,"flags":1}
	var listener: Node3D = head if xr_active else camera
	if not is_instance_valid(listener) or not listener.is_inside_tree(): return {"fault":"Missing sound listener"}
	var quarter_angles: Array = runtime_tables.get("wallAngles",{}).get("values",[])
	var forward: Vector3 = -listener.global_basis.z
	var horizontal := Vector2i(roundi(forward.x*4096.0),roundi(forward.z*4096.0))
	var heading: Dictionary = SourceCollision.wall_normal_angle(horizontal,quarter_angles)
	if heading.has("fault"): return heading
	var yaw_units := int(source_camera_state.get("yaw",0)) if horizontal == Vector2i.ZERO else int(heading.angle)
	var emitter := Vector3i(roundi(location.x/CELL_METERS*4096.0),roundi(location.y/CELL_METERS*4096.0),roundi(location.z/CELL_METERS*4096.0))
	var ear := Vector3i(roundi(listener.global_position.x/CELL_METERS*4096.0),roundi(listener.global_position.y/CELL_METERS*4096.0),roundi(listener.global_position.z/CELL_METERS*4096.0))
	var sound = preload("res://source_audio_math.gd")
	var bearing := sound.listener_bearing(emitter,ear,yaw_units,quarter_angles)
	if bearing.has("fault"): return bearing
	return sound.panning(volume,int(bearing.angle),source_cd_stereo_flag)
func stop_imported_voice_playback(voice: Node3D) -> void:
	if voice is SPUVoiceNode:
		(voice as SPUVoiceNode).stop_voice()
	elif voice is AudioStreamPlayer3D:
		var spatial := voice as AudioStreamPlayer3D
		spatial.stop();spatial.stream = null

func retire_imported_voice(voice: Node3D) -> void:
	if not is_instance_valid(voice):
		return
	stop_imported_voice_playback(voice)
	sound_voices.erase(voice)
	for index in source_voice_nodes.keys():
		if source_voice_nodes[index] == voice:
			source_voice_nodes.erase(index)
	# A finished sample does not release the source's held channel reservation.
	voice.queue_free()

func play_imported_sound(asset: Dictionary, location: Vector3, volume_percent: float = 100.0, pitch_steps: int = 0, command_scratch: bool = false) -> bool:
	if source_transition_state in [2,5] or source_audio_master_gain == 0 or volume_percent == 0:
		return true # Source allocation rejection does not halt a void PlaySound command.
	var slot := play_imported_sound_voice(asset,location,volume_percent,pitch_steps,command_scratch)
	# Native PlaySound is void: inaudibility and allocator exhaustion are no-ops.
	return slot >= 0 or source_sound_request_fault.is_empty()

func stop_imported_sound_voice(index: int) -> bool:
	if index<0:return true
	# Stop2ed84 uses MIPS sllv: the hardware key mask uses low five bits.
	# Only an actual dynamic-slot index names a managed reservation entry.
	if index<24 and not source_voice_pool.release(index):return false
	var keyed_channel := index&31
	if keyed_channel<24 and source_voice_nodes.has(keyed_channel):
		var node = source_voice_nodes[keyed_channel]
		if is_instance_valid(node):
			retire_imported_voice(node)
		source_voice_nodes.erase(keyed_channel)
	return true

func update_imported_loop_sound(asset: Dictionary, index: int, location: Vector3) -> bool:
	if index < 0:
		return true
	if index >= 24 or not asset.has("file"):
		return false
	var listener: Node3D = head if xr_active else camera
	if listener == null or not is_instance_valid(listener) or not listener.is_inside_tree():
		return false
	var listener_position := listener.global_position
	var units := Vector3i(roundi(location.x/CELL_METERS*4096.0),roundi(location.y/CELL_METERS*4096.0),roundi(location.z/CELL_METERS*4096.0))
	var ear := Vector3i(roundi(listener_position.x/CELL_METERS*4096.0),roundi(listener_position.y/CELL_METERS*4096.0),roundi(listener_position.z/CELL_METERS*4096.0))
	var math = preload("res://source_audio_math.gd")
	var metrics := math.listener_metrics(units,ear,runtime_tables.get("distanceRoot",{}).get("values",[]))
	if metrics.has("fault"):
		return false
	# A loaded, never-played sample has a zero base-volume word. Native2ebd8
	# writes voice registers even when that channel has no playing sample.
	var volume := math.loop_volume(int(source_sample_volumes.get(asset.file,0)),source_effects_volume,int(metrics.distance),source_audio_muted)
	source_voice_pool.volume_registers[index] = volume
	if source_voice_nodes.has(index) and is_instance_valid(source_voice_nodes[index]):
		var voice = source_voice_nodes[index]
		voice.global_position = location
		if voice is SPUVoiceNode:
			var channels := source_sound_channels(location,volume)
			if channels.has("fault") or channels.get("ignored",false): return false
			(voice as SPUVoiceNode).set_channels(int(channels.left),int(channels.right))
		else:
			voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
			voice.volume_db = linear_to_db(float(volume)/16384.0) if volume != 0 else -INF
	return true

func shift_imported_sound_pitch(index: int, delta: int) -> bool:
	var shifted: Dictionary = source_voice_pool.shift_pitch(index,delta)
	if shifted.has("fault"):
		return false
	if shifted.get("ignored",false):
		return true
	if source_voice_nodes.has(index) and is_instance_valid(source_voice_nodes[index]):
		var voice = source_voice_nodes[index]
		apply_imported_voice_pitch(voice,int(shifted.effective))
	return true

func apply_imported_voice_pitch(voice: Node3D, pitch: int) -> void:
	if voice is SPUVoiceNode:
		(voice as SPUVoiceNode).set_source_pitch(pitch)
		return
	var spatial := voice as AudioStreamPlayer3D
	# Godot requires a positive scale. Freeze its sample cursor for SPU pitch0;
	# this preserves channel allocation, but does not reconstruct the SPU envelope.
	spatial.pitch_scale = float(maxi(pitch,1))*44100.0/4096.0/float(spatial.stream.mix_rate)
	spatial.set_meta("source_zero_pitch",pitch == 0)
	spatial.stream_paused = pitch == 0
	if pitch > 0 and not spatial.playing:
		spatial.play()

func play_imported_sound_voice(asset: Dictionary, location: Vector3, volume_percent: float = 100.0, pitch_steps: int = 0, command_scratch: bool = false, angle_override: Variant = null) -> int:
	source_sound_request_fault = ""
	if source_transition_state in [2,5] or source_audio_master_gain == 0 or volume_percent == 0:
		return -1
	var signed_pitch := pitch_steps & 65535
	if signed_pitch >= 32768:
		signed_pitch -= 65536
	var raw_pitch := (2048+signed_pitch*85) & 65535
	var pitch := mini(raw_pitch,16384)
	if not asset.has("audio") or not asset.has("file"):
		source_sound_request_fault = "Missing sound asset metadata"
		return -1
	var info := read_source_asset(asset.file)
	if not info.has("held"):
		source_sound_request_fault = "Missing sound header"
		return -1
	var listener: Node3D = head if xr_active else camera
	if not is_instance_valid(listener) or not listener.is_inside_tree():
		source_sound_request_fault = "Missing sound listener";return -1
	var units := Vector3i(roundi(location.x/CELL_METERS*4096.0),roundi(location.y/CELL_METERS*4096.0),roundi(location.z/CELL_METERS*4096.0))
	var ear := Vector3i(roundi(listener.global_position.x/CELL_METERS*4096.0),roundi(listener.global_position.y/CELL_METERS*4096.0),roundi(listener.global_position.z/CELL_METERS*4096.0))
	var math = preload("res://source_audio_math.gd")
	var metrics := math.listener_metrics(units,ear,runtime_tables.get("distanceRoot",{}).get("values",[]))
	if metrics.has("fault"):
		source_sound_request_fault = str(metrics.fault);return -1
	var attenuation := math.one_shot_volume(int(volume_percent),source_effects_volume,int(metrics.distance),source_audio_muted)
	if bool(attenuation.blocked) or (not bool(attenuation.audible) and not bool(info.held)): return -1
	# Native2eb20 starts held channels silently; LoopSound updates them later.
	var initial_volume := 0 if bool(info.held) else int(attenuation.volume)
	if not audio_cache.has(asset.file):
		var stream := AudioStreamWAV.load_from_file(content_root.path_join(info.file))
		if stream == null:
			source_sound_request_fault = "Missing decoded sound sample"
			return -1
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if info.loop else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin = int(info.loopBegin)
		stream.loop_end = int(info.loopEnd)
		audio_cache[asset.file] = stream
	for i in range(sound_voices.size() - 1,-1,-1):
		if not is_instance_valid(sound_voices[i]):
			sound_voices.remove_at(i)
	var scratch_sample: Dictionary = {}
	if command_scratch:
		scratch_sample = source_spu_layout.sample_address(str(asset.file))
		if scratch_sample.has("fault"):
			source_spu_layout_fault = str(scratch_sample.fault)
			source_sound_request_fault = source_spu_layout_fault
			return -1
	var slot: int = source_voice_pool.allocate(bool(info.held))
	if slot < 0:
		return -1
	if command_scratch:
		# Only command9's frame56 + helper112/local60 reaches this scratch word.
		source_spawn_scratch.stack_write(168,60,int(scratch_sample.address),"sound_header_address")
	if source_voice_nodes.has(slot) and is_instance_valid(source_voice_nodes[slot]):
		retire_imported_voice(source_voice_nodes[slot])
	var channels: Dictionary = source_sound_channels(location,initial_volume) if angle_override==null else math.panning(initial_volume,int(angle_override),source_cd_stereo_flag)
	if channels.has("fault") or channels.get("ignored",false):
		source_sound_request_fault = str(channels.get("fault","Invalid sound bearing"))
		source_voice_pool.release(slot)
		return -1
	var voice := SPUVoiceNode.new()
	add_child(voice)
	voice.position = location
	if not voice.start_voice(audio_cache[asset.file],int(channels.left),int(channels.right),raw_pitch):
		source_sound_request_fault = "Unsupported decoded sound sample"
		source_voice_pool.release(slot);voice.queue_free()
		return -1
	voice.finished.connect(retire_imported_voice.bind(voice))
	sound_voices.append(voice)
	source_voice_nodes[slot] = voice
	source_sample_volumes[asset.file] = int(volume_percent)
	source_voice_pool.set_pitch(slot,raw_pitch)
	source_voice_pool.volume_registers[slot] = initial_volume
	apply_imported_voice_pitch(voice,pitch)
	return slot

func play_named_sound(name: String, location: Vector3, pitch_steps: int = 0) -> bool:
	for asset in manifest.get("linkage", {}).get("bootstrap", []):
		if int(asset.kind) == 3 and asset.name == name:
			return play_imported_sound(asset,location,100.0,pitch_steps)
	return false

func report_runtime() -> void:
	var status := {"room":map_name,"xr_active":xr_active,"use_xr":get_viewport().use_xr,"frames_drawn":Engine.get_frames_drawn(),"fps":Engine.get_frames_per_second(),"character_parts":character_parts.size(),"animation":animation_name,"texture_bindings":texture_cache.size(),"physics_frames":Engine.get_physics_frames(),"renderer":RenderingServer.get_video_adapter_name(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
	var file := FileAccess.open("user://runtime-status.json", FileAccess.WRITE)
	var scripts: Array = []
	for source_actor in source_actors:
		var collision_records := 0
		for model in source_actor.model_data.get("models",[]):
			for group in model.get("collision",{}).get("groups",[]):
				collision_records += group.size()
		scripts.append({"name":source_actor.source_name,"model":source_actor.model_name,"status":source_actor.vm.status,"pc":source_actor.vm.pc,"fault":source_actor.vm.fault,"animation":source_actor.clip_name,"animation_frame":source_actor.clip_frame,"animation_playing":source_actor.clip_playing,"primary_flags":source_actor.primary_flags,"secondary_flags":source_actor.secondary_flags,"collision_records":collision_records,"collision_point_count":source_actor.collision_point_count})
	status["source_actors"] = scripts
	status["source_controller_enabled"] = source_controller_enabled
	status["source_main_mode"] = source_main_mode
	status["source_cutscene"] = source_cutscene_progress
	var texture_frames := {}
	for name in active_texture_animations:
		var frames: Array = []
		for stream in active_texture_animations[name].streams: frames.append(int(stream.displayed))
		texture_frames[name] = frames
	status["source_texture_animation"] = {"frames":texture_frames,"max_cpu_us":source_texture_animation_max_us}
	status["xr_session"] = xr_session_snapshot()
	var xr_interface := XRServer.find_interface("OpenXR")
	status["vr_presentation"] = {"menu_distance":preload("res://vr_frontend_panel.gd").DISTANCE,"camera_anchor":str(vr_camera_anchor),"camera_pitch":vr_camera_pitch,"vrs_mode":get_viewport().vrs_mode,"eye_gaze_supported":xr_interface != null and xr_interface.is_initialized() and xr_interface.is_eye_gaze_interaction_supported()}
	status.vr_presentation.merge({"head_local":str(head.position),"head_overlap":vr_head_collision_overlapping,"head_fade":vr_head_collision_fade,"recenter_count":vr_recenter_count,"initial_center_pending":vr_initial_center_pending,"camera_guard_radius":VR_CAMERA_GUARD_RADIUS,"head_clip_radius":VR_HEAD_CLIP_RADIUS})
	if is_instance_valid(vr_settings):status["vr_presentation"].merge({"gaze_ready":vr_settings.foveation.gaze_ready,"foveation_active":vr_settings.foveation.active_density,"foveation_status":vr_settings.foveation.suspension_reason})
	if is_instance_valid(source_cutscene_screen):status["vr_presentation"]["cutscene_portal"]=bool(source_cutscene_screen.get("uses_portal"))
	if is_instance_valid(source_cutscene_screen) and source_cutscene_screen.get("uses_portal"):
		status["performance_cinematic"]=source_cutscene_screen.session.portal_performance.duplicate()
		status["performance_cinematic"].part=source_cutscene_screen.session.player.current_part
	status["xr_gameplay_focused"] = xr_gameplay_is_focused()
	status["source_transition"] = {"state":source_transition_state,"fault":source_transition_fault}
	status["source_fade"] = {"phase":source_fade_phase,"state":source_fade_state,"renderer":"subtractive_3d_quad" if is_instance_valid(source_fade_overlay) else "uninitialized"}
	status["source_inventory"] = {"counts":source_pickup_counts,"bonus_mask":source_bonus_mask,"key":source_key_collected}
	status["source_gobbo_display"] = source_gobbo_display_state
	status["source_audio"] = {"master":source_audio_master_gain,"maximum":source_audio_master_maximum,"step":source_audio_master_step,"music_cd_fade":"local XA packet callbacks; hardware timing pending"}
	if is_instance_valid(source_gameplay_music):
		var music: Dictionary=source_gameplay_music.transport.session.current
		status["source_gameplay_music"]={"running":source_gameplay_music.running,"cue":music.get("cue",0),"logical":music.get("logical",0),"cursor":music.get("cursor",0),"cursor_source":"local packet receipt callbacks","fault":source_gameplay_music.fault}
	status["source_shadow_renderer"] = "source_enm_contact_shadows"
	status["source_random"] = {"seed":source_random.bios_seed,"accumulator":source_random.accumulator,"draws":source_random.draws}
	status["source_terrain_surfaces"] = terrain_surfaces_at(actor.position)
	status["source_floor"] = source_floor_at(actor.position)
	status["source_actor_contacts"] = source_contacts_at(actor.position,actor)
	status["source_actor_order_fault"] = source_actor_order_fault
	status["source_ground"] = source_ground_at(actor.position,actor,player_source_terrain_cache)
	player_source_terrain_cache = source_cached_floor_at(actor.position,player_source_terrain_cache)
	status["source_cached_floor"] = player_source_terrain_cache
	status["source_ticks"] = source_tick_count
	status["process_id"] = OS.get_process_id()
	status["runtime_started_at"] = runtime_started_at
	status["performance_cpu"] = runtime_costs.duplicate(true)
	status["performance_caches"]={"assets":source_asset_json.size(),"materials":source_material_bindings.size(),"static_meshes":source_static_meshes.size(),"deformed_meshes":source_deformed_meshes.size(),"shared_metadata":shared_content_metadata.size()}
	performance_history_error=performance_history.append(status,runtime_slow_events)
	status["performance_history_error"]=performance_history_error
	if file != null:
		file.store_string(JSON.stringify(status))
	runtime_costs.clear()
	runtime_slow_events.clear()

var active_texture_animations: Dictionary = {}
var gameplay_mask_cache: Dictionary = {}
var source_texture_animation_max_us := 0
func material_for_texture(name: String) -> Dictionary:
	if source_material_bindings.has(name):return source_material_bindings[name]
	for entry in manifest.get("textures", []):
		if entry.name == name:
			var data := read_shared_content(entry.file).duplicate()
			if not texture_cache.has(name):
				var bitmap := Image.load_from_file(content_root.path_join(entry.image))
				texture_cache[name] = ImageTexture.create_from_image(bitmap)
			var animation_patches:Array=data.get("animationPatches",[]).duplicate()
			for cycle in manifest.get("paletteCycleTextures",[]):
				if cycle.name==name:
					var cycle_data:=read_shared_content(str(cycle.file))
					if str(cycle_data.get("sourceSha256",""))!=str(cycle.sourceSha256):push_error("Invalid palette cycle provenance");return {}
					animation_patches.append_array(cycle_data.patches)
			if not active_texture_animations.has(name) and not animation_patches.is_empty():
				var player := preload("res://source_texture_animation.gd").new()
				var bitmap := Image.load_from_file(content_root.path_join(entry.image))
				texture_cache[name].update(bitmap)
				if not player.setup(texture_cache[name],bitmap,animation_patches,content_root):
					push_error("Invalid texture animation: "+name); return {}
				active_texture_animations[name] = player
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			# Source RGB bytes and atlas RGB use the same display color space.
			mat.vertex_color_is_srgb = true
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_texture = texture_cache[name]
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			data["runtime_material"] = mat
			var blend := ShaderMaterial.new()
			blend.shader = preload("res://source_gameplay_blend.gdshader")
			blend.set_shader_parameter("atlas_texture",texture_cache[name])
			if entry.has("maskImage"):
				if not gameplay_mask_cache.has(name): gameplay_mask_cache[name] = ImageTexture.create_from_image(Image.load_from_file(content_root.path_join(entry.maskImage)))
				blend.set_shader_parameter("source_mask",gameplay_mask_cache[name])
				blend.set_shader_parameter("has_mask",true)
			data["runtime_blend_material"] = blend
			var additive:ShaderMaterial=blend.duplicate()
			additive.shader=preload("res://source_gameplay_additive.gdshader")
			additive.render_priority=1
			data["runtime_additive_material"]=additive
			source_material_bindings[name]={"data":data,"material":mat}
			return source_material_bindings[name]
	return {}

func setup_character(style: int) -> void:
	if not manifest.get("character", {}).has("model"):
		return
	if character_data.is_empty():
		character_data = read_json(manifest.character.model)
		for child in visual.get_children():
			child.queue_free()
		for part in character_data.models:
			var node := MeshInstance3D.new()
			visual.add_child(node)
			character_parts.append(node)
		var collision: CollisionShape3D = actor.get_child(0)
		var shape := CapsuleShape3D.new()
		shape.radius = 0.18
		shape.height = 0.65
		collision.shape = shape
		collision.position.y = 0.325
	var binding := material_for_texture("TK%02d_ENM.BIN" % style)
	if binding.is_empty():
		return
	character_texture = binding.data.duplicate()
	var character_material:StandardMaterial3D=binding.material.duplicate()
	character_material.cull_mode = BaseMaterial3D.CULL_BACK
	character_texture.runtime_material=character_material
	character_frame_cache.clear()
	for i in range(character_parts.size()):
		character_parts[i].mesh = geometry(character_data.models[i], character_texture)
		character_parts[i].material_override = null
	animation_frame = -1
	actor_animation_paths = manifest.character.animations.duplicate()
	var linkage: Dictionary = manifest.get("linkage", {})
	var room_link: Dictionary = linkage.get("rooms", {}).get(map_name, {})
	if not room_link.is_empty():
		var controller: Dictionary = linkage.controllers[room_link.profile]
		for asset in controller.assets + room_link.assets:
			if int(asset.kind) == 4:
				actor_animation_paths[asset.name] = asset.file
		if room_link.profile == "swim":
			idle_animation = "SWIMWAIT.ANI"
		elif room_link.profile == "slide":
			idle_animation = "CROCSURF.ANI"
		else:
			var requested := "CROCWA%d.ANI" % int(room_data.get("waitAnimation", 4))
			idle_animation = requested if actor_animation_paths.has(requested) else "CROCWA4.ANI"

func play_character(name: String, delta: float) -> void:
	if character_parts.is_empty() or not actor_animation_paths.has(name):
		return
	if not character_animations.has(name):
		character_animations[name] = read_json(actor_animation_paths[name])
	var animation: Dictionary = character_animations[name]
	if animation_name != name:
		animation_name = name
		animation_time = 0.0
		animation_frame = -1
	animation_time += delta * 30.0 * float(animation.speed) / 256.0
	var frame := int(animation_time) % int(animation.frameCount)
	if animation_frame == frame:
		return
	animation_frame = frame
	if int(animation.vertexCount) == character_data.models[0].vertices.size():
		var key := name + ":" + str(frame)
		if not character_frame_cache.has(key):
			var posed: Dictionary = character_data.models[0].duplicate(true)
			var points: Array = []
			for packed_value in animation.vertices[frame]:
				var packed := int(packed_value)
				var coords: Array = []
				for shift in [0,10,20]:
					var value: int = (packed >> int(shift)) & 1023
					if value >= 512:
						value -= 1024
					coords.append(float(value) / 1024.0)
				points.append(coords)
			posed.vertices = points
			character_frame_cache[key] = geometry(posed,character_texture)
		character_parts[0].mesh = character_frame_cache[key]
	for i in range(mini(int(animation.boneCount), character_parts.size() - 1)):
		var m: Array = animation.bones[frame][i]
		var basis := Basis(Vector3(m[0],m[3],m[6])/4096.0,Vector3(m[1],m[4],m[7])/4096.0,Vector3(m[2],m[5],m[8])/4096.0)
		character_parts[i + 1].transform = Transform3D(basis, Vector3(m[9],m[10],m[11]) * CELL_METERS / 4096.0)

func _ready() -> void:
	vr_controls.load_settings()
	vr_camera_pitch=vr_controls.camera_tilt
	super._ready()
	vr_settings = preload("res://vr_settings_panel.gd").new()
	add_child(vr_settings)
	vr_settings.setup(vr_controls,head if xr_active else camera)
	connect_vr_recenter()
	if xr_active:
		vr_head_collision_overlay = preload("res://source_fade_overlay.gd").new()
		head.add_child(vr_head_collision_overlay)
	var args := OS.get_cmdline_user_args()
	var bundled_root:=str(ProjectSettings.get_setting("croc/bundled_content_root",""))
	if OS.has_feature("android") or not bundled_root.is_empty():
		if not args.has("--content"):args.append_array(["--content",bundled_root if not bundled_root.is_empty() else ProjectSettings.globalize_path("user://content")])
		if not args.has("--source-player"):args.append("--source-player")
		if not args.has("--original-start"):args.append("--original-start")
	source_controller_enabled = args.has("--source-player")
	source_runtime_enabled = source_controller_enabled
	var layout_option := args.find("--control-layout")
	if layout_option >= 0 and layout_option+1 < args.size():
		vr_controls.layout = "classic" if args[layout_option+1] == "classic" else "modern"
	if source_controller_enabled:
		source_fade_overlay = preload("res://source_fade_overlay.gd").new()
		var view: Camera3D = head if xr_active else camera
		view.add_child(source_fade_overlay)
	for i in range(args.size() - 1):
		if args[i] == "--content":
			content_root = args[i + 1].simplify_path()
		if args[i] == "--map":
			map_name = args[i + 1]
	if content_root.is_empty():
		return
	manifest = read_json("manifest.json")
	if manifest.get("schema", 0) != 1:
		push_error("Unsupported or missing local content manifest")
		return
	if manifest.has("runtimeTables"):
		runtime_tables = read_json(manifest.runtimeTables)
		if not initialize_source_audio_options():
			push_error("Missing original startup audio options")
			return
		# Invalid saves retain startup defaults and remain available for diagnosis.
		restore_source_saved_options()
	imported = load_room(map_name)
	if imported:
		hide_missing_data_message()
	if imported and source_controller_enabled:
		update_source_input(0,0)
		source_player_input_state = {"pad_mode":1}
		if source_main_mode in [0,1,5,7]:
			source_controller_enabled = false
		else:
			var source_player = create_source_player()
			if source_player == null:
				push_error("Source controller initialization failed")
				return
		visual.hide()
		actor.collision_layer = 0
		actor.collision_mask = 0
		if args.has("--original-start") and not enter_source_startup():
			push_error(source_transition_fault)
		if args.has("--probe-options-flow"):call_deferred("probe_exported_options_flow")

func probe_exported_options_flow() -> void:
	set_process(false);set_physics_process(false)
	source_main_mode=1;source_menu_state.dialog_mode=1
	var valid := process_source_main_menu_confirmation(0x800000)
	for tick in range(150):
		if not valid or source_fade_phase=="":break
		valid=advance_source_transition()
	valid=valid and source_main_mode==8 and is_instance_valid(source_options_screen) and source_options_screen.visible
	if valid:
		source_options_state.navigation.selected=1
		valid=process_source_options(0,0x800000) and int(source_options_state.page)==3
	if valid:
		source_options_state.navigation.selected=0
		var prior_music := source_music_volume
		valid=process_source_options(0,0x80000) and source_music_volume==mini(prior_music+8,127)
	if valid:
		source_options_state.navigation.selected=3
		valid=process_source_options(0,0x800000) and int(source_options_state.page)==1
	if valid:valid=process_source_options(0,0x100000) and source_main_mode==1 and int(source_menu_state.dialog_mode)==1
	var result := {"process_id":OS.get_process_id(),"verified":valid,"mode":source_main_mode,"selected":source_menu_state.dialog_mode,"music":source_music_volume,"fault":source_transition_fault,"scope":"controlled packaged title Options/audio/return flow; no opening traversal or pixel proof"}
	var file := FileAccess.open("user://options-flow-probe.json",FileAccess.WRITE)
	if file==null:valid=false
	else:file.store_string(JSON.stringify(result));file.close()
	print("PACKAGED_OPTIONS_FLOW: ",JSON.stringify(result))
	stop_imported_audio()
	if not await preload("res://source_spu_stream_retirement.gd").drain(get_tree()):valid=false
	get_tree().quit(0 if valid else 1)

func read_json(relative: String) -> Dictionary:
	var performance_start:=Time.get_ticks_usec()
	if relative.contains("..") or relative.is_absolute_path():
		push_error("Unsafe imported content path")
		return {}
	var file := FileAccess.open(content_root.path_join(relative), FileAccess.READ)
	if file == null:
		push_error("Cannot read local content: " + relative)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	record_runtime_cost("asset_parse",Time.get_ticks_usec()-performance_start,relative)
	return data if data is Dictionary else {}

func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2]) * CELL_METERS

func update_camera() -> void:
	if (source_sequence_loading or is_instance_valid(source_cutscene_screen) or is_instance_valid(source_startup_movie)) and not vr_cinematic_view.is_empty():
		camera.global_transform=vr_cinematic_view.camera
		rig.global_transform=vr_cinematic_view.rig
		return
	var traversal_mode := player_traversal_mode()
	var hanging := traversal_mode in [7,8,9]
	if source_main_mode in [8,9,10,11] and not vr_menu_view.is_empty():
		camera.global_transform=vr_menu_view.camera;rig.global_transform=vr_menu_view.rig
		return
	var title_pose: bool = imported and source_main_mode in [0,1] and is_instance_valid(source_player_actor) and source_player_actor.source_name == "TitleCamera"
	if title_pose or (imported and source_main_mode in [5,7] and is_instance_valid(source_camera_target)):
		# The authored frontend camera supplies position and angles directly.
		var pose = source_player_actor if title_pose else source_camera_target
		var direct: bool = title_pose or (int(pose.primary_flags)&0x800) == 0
		var eye_position: Vector3 = pose.global_position if direct else Vector3(source_camera_state.position)*CELL_METERS/4096.0
		if title_pose:
			var floor_data := source_floor_at(pose.global_position)
			var floor_y: float = float(floor_data.get("height_units",roundi(pose.position.y/CELL_METERS*4096.0)))*CELL_METERS/4096.0
			eye_position.y = maxf(eye_position.y,floor_y)+1.6
		var angles: Vector3i = pose.source_angles if direct else Vector3i(int(source_camera_state.get("pitch",0)),int(source_camera_state.get("yaw",0)),int(source_camera_state.get("roll",0)))
		var view := preload("res://source_cutscene_view.gd").matrix(angles,runtime_tables.rotation.pairs)
		var native_view := Basis(Vector3(view[0],view[3],view[6])/4096.0,Vector3(view[1],view[4],view[7])/4096.0,Vector3(view[2],view[5],view[8])/4096.0)
		var axes := Basis(Vector3(1,0,0),Vector3(0,-1,0),Vector3(0,0,-1))
		var orientation := (axes*native_view).transposed().orthonormalized()
		if title_pose: orientation = Basis.from_euler(Vector3(angles)*TAU/4096.0)
		camera.global_transform = Transform3D(orientation,eye_position)
		rig.global_transform = Transform3D(orientation,eye_position- orientation*Vector3(0,head.position.y,0))
		if title_pose:
			# Keep ordinary tracked head motion; reserve clearance for startup/crouching.
			rig.global_position=eye_position-Vector3.UP*1.6+Vector3.UP*maxf(0.0,1.2-head.position.y)
		if is_instance_valid(vr_head_collision_overlay): vr_head_collision_overlay.set_source_level(0)
		vr_menu_view={"camera":camera.global_transform,"rig":rig.global_transform}
		return
	if not imported or not vr_camera_anchor_initialized:
		super.update_camera()
	else:
		var orbit := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-vr_camera_pitch)
		var offset := (Basis(Vector3.UP,yaw) if hanging else orbit)*Vector3(0,0,5)
		# Source ledge hangs put the root about0.65m below the ledge. Keep the
		# eye envelope beneath it instead of sweeping from above Croc's hands.
		var rig_height := lerpf(0.5,0.25-head.position.y,vr_traversal_view_blend)
		rig.position = vr_camera_anchor+offset+Vector3(0,rig_height,0)
		rig.rotation = Vector3(-vr_camera_pitch,yaw,0)
		camera.position = vr_camera_anchor+offset+Vector3(0,lerpf(3.3,0.25,vr_traversal_view_blend),0)
		camera.look_at(vr_camera_anchor+(Vector3(0,0.4,0) if hanging else Vector3(0,0.7,-2)),Vector3.UP)
	if not imported or not is_inside_tree():
		return
	# Constrain virtual locomotion; physical horizontal head lean retains its tracking.
	var eye: Vector3 = rig.to_global(Vector3(0,head.position.y,0)) if xr_active else camera.global_position
	var start := actor.global_position+Vector3(0,0.22 if hanging else 0.6 if traversal_mode == 11 else 1.2,0)
	var motion := eye-start
	var shape := SphereShape3D.new()
	shape.radius = VR_CAMERA_GUARD_RADIUS if xr_active else 0.15
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,start)
	query.motion = motion
	query.collision_mask = 257 # Terrain and camera-only collidable actor meshes.
	query.exclude = [actor.get_rid()]
	if is_instance_valid(source_player_actor):
		for body in source_player_actor.camera_bodies:
			if is_instance_valid(body):
				query.exclude.append(body.get_rid())
	var result := get_world_3d().direct_space_state.cast_motion(query)
	var safe_eye:=eye
	if result.size() == 2 and float(result[0]) < 1.0:
		# World-space clearance stays consistent for both long and short arms.
		var margin:float=VR_CAMERA_WALL_MARGIN/motion.length() if xr_active and motion.length()>0.0001 else 0.02
		safe_eye = start+motion*maxf(0.0,float(result[0])-margin)
	if xr_active and motion.length_squared()>0.0001:
		# Shape sweeps ignore bodies already intersecting the starting sphere.
		# A center-line ray catches that case when Croc stands close to a wall.
		var ray:=PhysicsRayQueryParameters3D.create(start,eye,257,query.exclude)
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			var normal:Vector3=hit.normal
			if normal.dot(motion)>0:normal=-normal
			var ray_eye:Vector3=hit.position+normal*(VR_CAMERA_GUARD_RADIUS+VR_CAMERA_WALL_MARGIN)
			if (ray_eye-start).dot(motion)<(safe_eye-start).dot(motion):safe_eye=ray_eye
		# Resolve the neutral envelope against adjacent walls/ceilings too. A ray
		# can hit just one face of a corner while its sphere overlaps the other.
		query.motion=Vector3.ZERO
		for correction in range(4):
			query.transform.origin=safe_eye
			var contact:=get_world_3d().direct_space_state.get_rest_info(query)
			if contact.is_empty():break
			var normal:Vector3=contact.normal
			if normal.length_squared()<0.0001:break
			var gap:float=(safe_eye-Vector3(contact.point)).dot(normal)
			safe_eye+=normal*maxf(0.0,VR_CAMERA_GUARD_RADIUS+VR_CAMERA_WALL_MARGIN-gap)
	if hanging and Vector2(safe_eye.x-start.x,safe_eye.z-start.z).length()<Vector2(eye.x-start.x,eye.z-start.z).length()*0.95:
		# During grab/pull-up transitions the smoothed eye can still lie above
		# the ledge. Prefer a clear path below it over collapsing the orbit.
		var lower_eye := Vector3(eye.x,minf(eye.y,actor.global_position.y+0.25),eye.z)
		query.transform.origin=start
		query.motion=lower_eye-start
		var lower_sweep := get_world_3d().direct_space_state.cast_motion(query)
		var lower_ray := PhysicsRayQueryParameters3D.create(start,lower_eye,257,query.exclude)
		if lower_sweep.size()==2 and float(lower_sweep[0])>=0.999 and get_world_3d().direct_space_state.intersect_ray(lower_ray).is_empty():
			query.motion=Vector3.ZERO;query.transform.origin=lower_eye
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():safe_eye=lower_eye
	if xr_active:rig.global_position+=safe_eye-eye
	else:camera.global_position=safe_eye
	if xr_active and is_instance_valid(vr_head_collision_overlay):
		# Reserve leaning room with the outer sweep; only fade the inner volume
		# covering the eyes/near plane, rather than any touch of that outer shell.
		shape.radius=VR_HEAD_CLIP_RADIUS
		query.motion = Vector3.ZERO
		query.transform.origin = head.global_position
		vr_head_collision_overlapping = not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
		if vr_head_collision_overlapping:
			vr_head_collision_fade = 255.0
		vr_head_collision_overlay.set_source_level(ceili(vr_head_collision_fade))
	vr_menu_view={"camera":camera.global_transform,"rig":rig.global_transform}

func geometry(data: Dictionary, texture: Dictionary = {}) -> ArrayMesh:
	var performance_start:=Time.get_ticks_usec()
	var builders: Array[SurfaceTool] = []
	for group in range(3):
		var builder := SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES); builders.append(builder)
	var counts := [0,0,0]
	var points: Array = data.vertices
	for face in data.faces:
		var group := 1 if (int(face.flags)&32) != 0 else 0
		var st: SurfaceTool = builders[group]
		var ids: Array = face.indices
		var color := Color.WHITE if int(face.flags) & 1 else Color(float(face.color[0])/255.0,float(face.color[1])/255.0,float(face.color[2])/255.0)
		# PSX quads use a strip: the two final corners follow the first pair.
		var triangles := [0,1,2,1,3,2] if ids.size() == 4 else [0,1,2]
		var uvs: Array = []
		if not texture.is_empty() and int(face.flags) & 1:
			var id := int(face.material)
			if id >= 0 and id < texture.polygons.size():
				uvs = texture.polygons[id].uv
		var uv_order := [0,1,2,3] if int(face.flags) & 16 else [1,0,3,2]
		if ids.size() == 3:
			uv_order = [0,2,3]
		for corner in triangles:
			st.set_color(color)
			var blend_mode := int(texture.polygons[int(face.material)].get("blend",0)) if not uvs.is_empty() else 0
			st.set_uv2(Vector2(int(face.flags),int(face.material) if texture.get("bonus_door_feedback",false) else blend_mode))
			var uv := Vector2(0.5 / float(texture.get("width", 1)), 0.5 / float(texture.get("height", 1)))
			if not uvs.is_empty():
				var values: Array = uvs[uv_order[corner]]
				uv = Vector2(values[0], values[1])
			st.set_uv(uv)
			st.add_vertex(vector(points[int(ids[corner])]))
			counts[group] += 1
			if group==1 and blend_mode==1:
				var additive:SurfaceTool=builders[2]
				additive.set_color(color);additive.set_uv2(Vector2(int(face.flags),blend_mode));additive.set_uv(uv)
				additive.add_vertex(vector(points[int(ids[corner])]))
				counts[2]+=1
	var mesh := ArrayMesh.new()
	for group in range(3):
		if counts[group] == 0: continue
		builders[group].generate_normals()
		builders[group].commit(mesh)
		var key:String=["runtime_material","runtime_blend_material","runtime_additive_material"][group]
		if texture.has(key): mesh.surface_set_material(mesh.get_surface_count()-1,texture[key])
	record_runtime_cost("mesh_build",Time.get_ticks_usec()-performance_start)
	return mesh

func load_room(name: String, incoming_id: int = -1, source_origin: Dictionary = {}, arrival_override: Dictionary = {}) -> bool:
	source_asset_json.clear();source_static_meshes.clear();source_material_bindings.clear();source_deformed_meshes.clear()
	source_shadow_meshes.clear()
	active_texture_animations.clear()
	source_texture_animation_max_us = 0
	var selected: Dictionary
	for entry in manifest.get("maps", []):
		if entry.name == name:
			selected = entry
			break
	if selected.is_empty():
		push_error("Room not imported: " + name)
		return false
	var data := read_json(selected.file)
	if data.is_empty():
		return false
	# Original track loader 0x80023ed0: X/Z << 12, Y * mapYScale.
	# Keep the shared tile positions in cell units for rendering and queries.
	data = data.duplicate(true)
	var track_height_unit := float(runtime_tables.mapYScale.values[int(data.style)])/4096.0
	for tile in data.tracks:
		tile.source_height = tile.position[1]
		tile.position[1] = float(tile.position[1])*track_height_unit
	clear_source_stage_stats()
	var track_name := "TK%02d_TRK.MOD" % int(data.style)
	clear_source_game_over_screen()
	clear_source_password_entry()
	var models: Dictionary
	for entry in manifest.get("models", []):
		if entry.name == track_name:
			models = read_shared_content(entry.file)
			break
	if models.is_empty():
		push_error("Room geometry pack missing: " + track_name)
		return false
	var room_link: Dictionary = manifest.get("linkage", {}).get("rooms", {}).get(name, {})
	if bool(room_link.get("menu",false)): source_runtime_enabled = true
	if not room_link.is_empty():
		var local_terrain := read_json(room_link.terrain)
		if local_terrain.models.size() != models.models.size():
			push_error("Room terrain model count disagrees with style bank")
			return false
		for index in local_terrain.selected:
			models.models[int(index)] = local_terrain.models[int(index)]
	if not room_link.is_empty():
		var sound_bank: Dictionary = source_spu_layout.enter_room(content_root,manifest,name)
		source_spu_layout_fault = str(sound_bank.get("fault",""))
		if not source_spu_layout_fault.is_empty():
			push_error(source_spu_layout_fault)
			return false
	stop_imported_audio()
	if is_instance_valid(source_gameplay_music) and source_transition_state!=2:source_gameplay_music.reset_rooms()
	if terrain != null:
		remove_child(terrain)
		terrain.queue_free()
	for p in pickups:
		p.queue_free()
	pickups.clear()
	triggers.clear()
	source_actors.clear()
	source_player_contact_counts.clear()
	source_player_actor = null
	source_player_entry_state.clear()
	if not arrival_override.is_empty():
		source_player_entry_state = arrival_override.duplicate(true)
	elif incoming_id < 0:
		var entry_state := initial_source_player_entry(data)
		if not entry_state.has("fault"):
			source_player_entry_state = entry_state
	elif not source_origin.is_empty():
		var entry_state := initial_source_player_entry(data,source_origin)
		if entry_state.has("fault"):
			push_error(str(entry_state.fault))
			return false
		source_player_entry_state = entry_state
	if source_player_entry_state.has("present"):
		source_checkpoint_entry = source_player_entry_state.duplicate(true)
	terrain = Node3D.new()
	add_child(terrain)
	map_name = name
	vr_camera_anchor_initialized = false
	vr_traversal_view_blend = 0.0
	modern_previous_traversal = 0
	vr_controls.reset_gestures()
	room_data = data
	terrain_query_index.build(room_data.tracks)
	source_main_mode = (5 if int(name.substr(2,3)) == 100 else 7 if int(name.substr(2,3)) == 94 else 0) if bool(room_link.get("menu",false)) else 4
	if source_main_mode in [0,7]:
		source_title_scene_index = int(name.substr(2,3))-90
	if source_main_mode == 0:
		source_main_menu_credits_available = false # Native title entry13178 clears gp8.
		source_title_logo_state = preload("res://source_title_logo.gd").initialize()
		source_title_effect_state = preload("res://source_title_particles.gd").initialize()
	if is_instance_valid(source_main_menu_text):
		source_main_menu_text.visible = source_main_mode == 1
	for logo in source_title_logo_nodes:
		logo.visible = source_main_mode in [0,1]
	for effect in source_title_effect_nodes:
		effect.visible = false
	if source_main_mode == 5:
		var selection_entry: Dictionary = preload("res://source_menu_progress.gd").enter_selector(int(source_menu_state.selected_index),source_menu_progress_flags,source_menu_announcement_history)
		if selection_entry.has("fault"):
			source_transition_fault = str(selection_entry.fault)
			return false
		source_menu_progress_flags = selection_entry.flags
		source_menu_announcement_history = selection_entry.history
		source_menu_state.selected_index = selection_entry.selected_index
		source_menu_state.return_mode = selection_entry.return_mode
		source_menu_state.secret_return = selection_entry.secret_return
	source_pool.reset(128)
	source_actor_references.reset()
	source_actor_parameter_memory.clear()
	source_actor_pose_memory.clear()
	source_actor_global_memory.clear()
	source_player_id = source_pool.allocate({"name":"SwimmingCroc" if int(data.style) in [1,11] else "Croc","node":actor})
	player_source_terrain_cache = {}
	source_tick_accumulator = 0.0
	source_tick_count = 0
	terrain_models = models.models
	var sky := preload("res://source_gameplay_sky.gd").new()
	terrain.add_child(sky)
	if not sky.setup(self):return false
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var texture_data: Dictionary
	var texture_name := track_name.replace(".MOD", ".BIN")
	var binding := material_for_texture(texture_name)
	if not binding.is_empty():
		texture_data = binding.data
		mat = binding.material
	var terrain_batches: Array[SurfaceTool] = []
	var terrain_counts := [0,0,0]
	for group in range(3):
		var batch := SurfaceTool.new(); batch.begin(Mesh.PRIMITIVE_TRIANGLES); terrain_batches.append(batch)
	for tile in data.tracks:
		var index := int(tile.index)
		if index < 0 or index >= models.models.size():
			push_error("Map tile index outside model pack")
			continue
		var key := name + ":" + track_name + ":" + str(index)
		if not mesh_cache.has(key):
			mesh_cache[key] = geometry(models.models[index], texture_data)
		if mesh_cache[key] == null or mesh_cache[key].get_surface_count() == 0:
			continue # Empty source tiles still participate in metadata-based queries.
		var body := StaticBody3D.new()
		terrain.add_child(body)
		body.position = vector(tile.position)
		body.rotation.y = float(tile.rotation) * TAU
		for mesh_surface in range(mesh_cache[key].get_surface_count()):
			var material=mesh_cache[key].surface_get_material(mesh_surface)
			var group := 2 if material==texture_data.get("runtime_additive_material") else 1 if material is ShaderMaterial else 0
			terrain_batches[group].append_from(mesh_cache[key],mesh_surface,body.transform)
			terrain_counts[group] += 1
		var collision := CollisionShape3D.new()
		var tile_mesh: ArrayMesh = mesh_cache[key]
		var shape: ConcavePolygonShape3D = tile_mesh.create_trimesh_shape()
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
	for group in range(3):
		if terrain_counts[group] == 0: continue
		var surface := MeshInstance3D.new()
		surface.mesh = terrain_batches[group].commit()
		surface.material_override = texture_data.get("runtime_additive_material",mat) if group==2 else texture_data.get("runtime_blend_material",mat) if group == 1 else mat
		terrain.add_child(surface)
	var start := Vector3.ZERO
	var found_start := false
	for door in data.doors:
		if int(door.flags) & 8 or (incoming_id >= 0 and int(door.id) == incoming_id and int(door.flags) & 1):
			start = vector(door.position)
			found_start = true
			if incoming_id >= 0:
				break
	if not found_start and not data.tracks.is_empty():
		start = vector(data.tracks[0].position)
	checkpoint = start + Vector3(0, 0.2, 0)
	actor.position = checkpoint
	actor.velocity = Vector3.ZERO
	yaw = PI + float(data.startRotation) * TAU
	for door in data.doors:
		if int(door.flags) & 1:
			triggers.append({"position":vector(door.position),"target":"MP%03d_%02d.MAP" % [int(door.level),int(door.room)],"id":int(door.id)})
	total_gems = 0
	var crystal_model: Dictionary
	for asset in manifest.get("linkage", {}).get("bootstrap", []):
		if asset.name == "CRYSTAL1.MOD":
			crystal_model = read_json(asset.file)
			break
	var crystal_texture := material_for_texture("TK%02d_ENM.BIN" % int(data.style))
	for entity_index in range(data.entities.size()):
		var entity: Dictionary = data.entities[entity_index]
		if (int(source_map_entity_flags.get(name,{}).get(entity_index,0))&5) != 0:
			continue
		entity["source_map_index"] = entity_index
		var source_id: int = source_pool.allocate({"name":entity.name,"node":null})
		if source_id < 0:
			push_error("Source actor pool exhausted during map creation")
			return false
		if entity.name == "Crystal" and not source_runtime_enabled:
			total_gems += 1
			var key := name + ":" + str(total_gems)
			if collected.has(key):
				continue
			var pick := Node3D.new()
			terrain.add_child(pick)
			pick.position = vector(entity.position)
			pick.set_meta("key",key)
			if not crystal_model.is_empty() and not crystal_texture.is_empty():
				var gem := MeshInstance3D.new()
				gem.mesh = geometry(crystal_model.models[0],crystal_texture.data)
				var sprite_material: StandardMaterial3D = crystal_texture.material.duplicate()
				sprite_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				gem.material_override = sprite_material
				pick.add_child(gem)
			pickups.append(pick)
		elif not room_link.is_empty():
			var definitions: Array = manifest.linkage.definitions
			var definition: Dictionary
			for candidate in definitions:
				if str(candidate.name).begins_with(entity.name):
					definition = candidate
					break
			if definition.is_empty():
				continue
			var assets: Array = manifest.linkage.bootstrap + manifest.linkage.controllers[room_link.profile].assets + room_link.assets
			for asset in assets:
				if int(asset.kind) == 1 and asset.name == definition.file:
					var node = ASLActor.new()
					node.source_pool_id = source_id
					restore_source_actor_pose_memory(node,source_id)
					source_pool.slots[source_id].node = node
					terrain.add_child(node)
					node.set_physics_process(false)
					node.configure(self,definition,read_json(asset.file),entity,assets,false)
					source_actors.push_front(node)
					break
	var ordered := SourceActorList.order(source_actors,CELL_METERS,true)
	source_actor_order_fault = ordered.fault
	if not ordered.ok:
		for source_actor in source_actors:
			source_actor.set_physics_process(false)
		push_error(source_actor_order_fault)
		return false
	source_actors.assign(ordered.actors)
	if bool(room_link.get("menu",false)): source_actor_references.refresh(source_actors)
	if source_main_mode == 0 and bool(source_fade_state.get("ready",false)):
		# Title entry13278..1328c starts incoming1 only if prior handler is ready.
		if not is_instance_valid(source_fade_overlay):
			source_fade_overlay = preload("res://source_fade_overlay.gd").new()
			var view: Camera3D = head if xr_active else camera
			view.add_child(source_fade_overlay)
		source_fade_state = preload("res://source_transition_fade.gd").start(1)
		source_fade_phase = "in"
		source_fade_overlay.set_source_level(255)
	if source_main_mode == 5:
		# Selector1373c calls camera reset427b0;427e0 sets the raw reveal word1.
		source_camera_hold_counter = 0
		source_menu_reveal_state = 1
	transition_cooldown = 2.0
	debug_status = "%s | %s | %d tiles, %d source entities" % [name,data.title,data.tracks.size(),data.entities.size()]
	setup_character(int(data.style))
	print("IMPORTED_ROOM: " + debug_status)
	report_runtime()
	update_camera()
	return true

func _physics_process(delta: float) -> void:
	if vr_settings != null:
		if xr_active:
			vr_settings.xr_input(left,right,xr_gameplay_is_focused())
	if not imported:
		if content_root.is_empty():
			super._physics_process(delta)
		return
	if is_instance_valid(source_credits_screen):
		process_source_credits(delta)
		return
	if is_instance_valid(source_cutscene_screen):
		process_source_sad_cutscene(delta)
		return
	if source_sequence_loading:
		if is_instance_valid(source_startup_movie):
			source_startup_movie.video.paused=not xr_gameplay_is_focused()
			sample_source_player_controls()
			if (int(source_input_pressed_mask)&0x800200)!=0:finish_source_startup_movie()
		return
	if source_main_mode == 3:
		if not source_demo_playing:
			return
		if not xr_gameplay_is_focused():
			source_tick_accumulator = 0.0
			return
		source_tick_accumulator += delta
		while source_tick_accumulator >= 1.0/30.0:
			source_tick_accumulator -= 1.0/30.0
			if not sample_source_demo_controls(source_tick_count):
				break
			tick_source_actors()
			if source_transition_state == 0:
				var request := source_exit_request(source_player_actor)
				if request.has("fault"):
					source_transition_fault = str(request.fault)
					break
				if request.has("counter"):
					source_ground_mode_80_value = request.counter
				if bool(request.get("transition",false)):
					source_transition_state = int(request.state)
			if not process_source_demo_exit(source_live_demo_buttons()) or source_main_mode != 3:
				break
		if source_main_mode == 3 and is_instance_valid(source_player_actor):
			actor.position = source_player_actor.position
			actor.velocity = Vector3.ZERO
		update_camera()
		return
	if source_main_mode in [12,13,14]:
		if not xr_gameplay_is_focused():
			source_resume_input_baseline_pending = true
			source_tick_accumulator = 0.0
			return
		source_tick_accumulator += delta
		while source_tick_accumulator >= 1.0/30.0:
			source_tick_accumulator -= 1.0/30.0
			if source_main_mode == 14 and source_resume_input_baseline_pending: source_game_over_confirm_requires_release = true
			sample_source_player_controls()
			var mode := source_main_mode
			var okay := process_source_password_display() if mode==12 else process_source_password_entry() if mode == 13 else process_source_game_over()
			if not okay or source_main_mode != mode: break
		update_camera()
		return
	if source_main_mode in [0,1,5,8,9,10,11]:
		var sampled_menu_mode := source_main_mode
		if not xr_gameplay_is_focused():
			source_resume_input_baseline_pending = true
			source_tick_accumulator = 0.0
			update_source_input(0,0)
			jump_held = false
			report_elapsed += delta
			if report_elapsed >= 5.0:
				report_elapsed = 0.0
				report_runtime()
			return
		source_tick_accumulator += delta
		while source_tick_accumulator >= 1.0/30.0:
			source_tick_accumulator -= 1.0/30.0
			sample_source_player_controls()
			if not (source_options_parent_mode==4 and sampled_menu_mode in [8,9,10,11]):tick_source_actors()
			var buttons := int(source_input_pressed_mask)
			if sampled_menu_mode in [0,1]:
				source_title_logo_state = preload("res://source_title_logo.gd").advance(source_title_logo_state)
				if not refresh_source_title_logo():
					break
				if not refresh_source_title_effects():
					break
			if sampled_menu_mode == 0:
				if not refresh_source_title_prompt():
					break
				if not process_source_title_confirmation(buttons):
					break
			elif sampled_menu_mode == 1:
				advance_source_main_menu_navigation(int(source_input_held_mask),buttons)
				if not refresh_source_main_menu_text():
					break
				if not process_source_main_menu_confirmation(buttons):
					break
			elif sampled_menu_mode==8:
				if not process_source_options(int(source_input_held_mask),buttons):break
			elif sampled_menu_mode==9:
				if not process_source_load_menu(int(source_input_held_mask),buttons):break
			elif sampled_menu_mode==11:
				if not process_source_save_menu(int(source_input_held_mask),buttons):break
			elif sampled_menu_mode==10:
				if not process_source_delete_menu(int(source_input_held_mask),buttons):break
			else:
				if not advance_source_selector_actions(int(source_input_held_mask),buttons):break
				apply_source_menu_navigation(buttons,int(source_menu_state.input_lock))
				if not process_source_menu_confirmation(buttons,int(source_menu_state.input_lock),int(source_menu_state.save_mode),int(source_menu_state.dialog_mode)):
					break
			if source_main_mode != sampled_menu_mode:
				break
		visual.hide()
		actor.collision_layer = 0
		actor.collision_mask = 0
		if source_main_mode == 5 and is_instance_valid(source_camera_override_one):
			actor.position = source_camera_override_one.position
		update_camera()
		report_elapsed += delta
		if report_elapsed >= 5.0:
			report_elapsed = 0.0
			report_runtime()
		return
	if source_controller_enabled:
		if not xr_gameplay_is_focused():
			source_resume_input_baseline_pending = true
			source_tick_accumulator = 0.0
			update_source_input(0,0)
			jump_held = false
			report_elapsed += delta
			if report_elapsed >= 5.0:
				report_elapsed = 0.0
				report_runtime()
			return
		if source_player_actor == null or not is_instance_valid(source_player_actor):
			return
		source_tick_accumulator += delta
		while source_tick_accumulator >= 1.0/30.0:
			source_tick_accumulator -= 1.0/30.0
			sample_source_player_controls()
			tick_source_actors()
			if not process_source_exit():
				break
			if source_main_mode == 14: break
		actor.position = source_player_actor.position
		actor.velocity = Vector3.ZERO
		report_elapsed += delta
		if report_elapsed >= 5.0:
			report_elapsed = 0.0
			report_runtime()
		hud.hide()
		board.hide()
		update_camera()
		return
	source_tick_accumulator += delta
	while source_tick_accumulator >= 1.0 / 30.0:
		source_tick_accumulator -= 1.0 / 30.0
		tick_source_actors()
	report_elapsed += delta
	if report_elapsed >= 5.0:
		report_elapsed = 0.0
		report_runtime()
	transition_cooldown = maxf(0,transition_cooldown-delta)
	var stick := Input.get_vector("move_left","move_right","move_forward","move_back")
	var jump := Input.is_action_pressed("jump")
	var turn := Input.get_axis("turn_left","turn_right")
	if xr_active:
		stick = left.get_vector2("primary")
		stick.y = -stick.y
		jump = jump or right.is_button_pressed("ax_button") or right.is_button_pressed("trigger_click")
		turn = right.get_vector2("primary").x
	if absf(turn) < 0.25:
		snap_armed = true
	elif absf(turn) > 0.7 and snap_armed:
		yaw -= signf(turn) * PI / 6
		snap_armed = false
	var direction := Basis(Vector3.UP,yaw) * Vector3(stick.x,0,stick.y)
	actor.velocity.x = direction.x * 3.5
	actor.velocity.z = direction.z * 3.5
	if not actor.is_on_floor():
		actor.velocity.y -= 18 * delta
	elif jump and not jump_held:
		actor.velocity.y = 7.5
	jump_held = jump
	if direction.length() > 0.1:
		visual.rotation.y = atan2(direction.x,direction.z)
	actor.move_and_slide()
	play_character("CROCWALK.ANI" if direction.length() > 0.1 else idle_animation, delta)
	if actor.position.y < -10 or Input.is_action_just_pressed("reset"):
		actor.position = checkpoint
		actor.velocity = Vector3.ZERO
	for p in pickups:
		if p.visible and p.position.distance_to(actor.position+Vector3(0,0.5,0)) < 0.65:
			p.hide()
			play_named_sound("CRYS", p.global_position)
			collected[p.get_meta("key")] = true
			gems += 1
	for trigger in triggers:
		if transition_cooldown <= 0 and actor.position.distance_to(trigger.position) < 0.8:
			load_room(trigger.target,int(trigger.id))
			break
	hud.text = debug_status + "\nImported geometry | provisional controls | Crystals %d\nWASD / left stick move | Space / A jump | Q,C / right stick snap turn" % gems
	board.show()
	board.position = actor.position + Vector3(0,2.0,0)
	board.text = "%s | Crystals %d" % [room_data.title,gems]
	board.rotation.y = yaw
	update_camera()

