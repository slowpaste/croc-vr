extends RefCounted
const Menu = preload("res://source_main_menu.gd")
const Route = preload("res://source_options_route.gd")
const Audio = preload("res://source_audio_options.gd")
const Calibration = preload("res://source_controller_calibration.gd")
const Center = preload("res://source_screen_center.gd")
const Music = preload("res://source_options_music_player.gd")
const SoundMath = preload("res://source_audio_math.gd")
const Fade = preload("res://source_cd_fade.gd")
static func initialize(audio: Dictionary, selected: int = 0, pad_kind: int = 1) -> Dictionary:
	return {"page":1,"navigation":Menu.initialize(selected,3),"audio":audio.duplicate(true),"effects_restore_volume":int(audio.effects),"effects_maximum":int(audio.effects),"effects_step":SoundMath.fade_step(int(audio.effects)),"music_player_available":false,"exit_requested":false,"scheme":0,"pad_kind":pad_kind,"screen_offset":Vector2i.ZERO,"pending_action":"","calibration":Calibration.normalize(Vector2i(128,128),Vector2i.ZERO,Vector2i(255,255))}
static func advance(state: Dictionary, held: int, pressed: int, sample: Variant = null, playback: Variant = null) -> Dictionary:
	if not state.has_all(["page","navigation","audio"]): return {"fault":"Missing Options session state"}
	if bool(state.get("exit_requested",false)): return state.duplicate(true)
	if not str(state.get("pending_action","")).is_empty(): return {"fault":"Options backend action has not completed"}
	var next := state.duplicate(true)
	next.effects_preview_requested = false;next.effects_preview_volumes = []
	next.cd_mix_events = []
	next.adjustment_previews = []
	next.last_action = ""
	next.calibration_notice_display = 0
	next.write_notice_display=0
	if int(next.page)==4:
		var write_notice := int(next.get("write_notice_ticks",0))
		next.write_notice_display=write_notice
		next.write_notice_ticks=write_notice-1 if write_notice>0 else write_notice+1 if write_notice<0 else 0
	next.reset_notice_visible = int(next.page)==4 and int(next.get("reset_notice_ticks",0))>0
	if int(next.page) == 4 and int(next.get("reset_notice_ticks",0)) > 0:
		next.reset_notice_ticks = int(next.reset_notice_ticks)-1
	# Native4b070 skips generic row navigation on calibration/centering pages.
	if int(next.page) not in [6,7]: next.navigation = Menu.advance(next.navigation,held,pressed)
	var selected := int(next.navigation.selected)
	match int(next.page):
		1:
			var route := Route.root_action(selected,pressed)
			if int(next.get("parent_mode",0))==4 and selected==3 and (pressed&0x800000)!=0:
				next.last_action="return_to_title"
			if route.has("fault"): return route
			next.exit_requested = bool(route.exit_requested)
			if bool(route.retain_effects): next.effects_restore_volume = int(next.audio.effects)
			if bool(route.reset_menu):
				next.page = int(route.page);next.navigation = Menu.initialize(int(route.selected),int(route.last_index))
				if route.has("music_player_available"): next.music_player_available = bool(route.music_player_available)
		2:
			var notice := int(next.get("calibration_notice_counter",0))
			if int(next.pad_kind)==2 and notice!=0:
				next.calibration_notice_display=notice
				var updated := notice+1 if notice>0 else notice-1
				next.calibration_notice_counter=0 if updated>150 or updated< -150 else updated
			if selected==1:next.calibration_notice_counter=0
			var route := Route.controller_action(selected,int(next.scheme),int(next.pad_kind),pressed)
			if route.has("fault"): return route
			next.scheme = int(route.scheme);next.last_action = str(route.action)
			if int(route.page) != 2:
				next.page = int(route.page)
				if next.page == 6:
					next.capture = {"phase":0,"center":next.calibration.center,"minimum":next.calibration.minimum,"maximum":next.calibration.maximum}
				else: next.navigation = Menu.initialize(int(route.selected),int(route.last_index))
		6:
			if sample == null or not sample is Vector2i: return {"fault":"Missing original pad-byte calibration sample"}
			var capture := Calibration.advance(next.capture,sample,pressed)
			if capture.has("fault"): return capture
			next.capture = capture
			if bool(capture.commit):
				next.calibration = Calibration.normalize(capture.center,capture.minimum,capture.maximum)
				next.calibration_notice_counter=int(next.calibration.status)
			if bool(capture.back): next.page = 2;next.navigation = Menu.initialize(0,2)
		4:
			var route := Route.misc_action(selected,pressed)
			if route.has("fault"): return route
			if int(route.page) != 4:
				next.page = int(route.page)
				if next.page == 1: next.navigation = Menu.initialize(int(route.selected),int(route.last_index))
			if route.action in ["delete_saved_game","write_options","reset_defaults"]:
				next.pending_action = str(route.action)
		7:
			var centered := Center.advance(next.screen_offset,held,pressed)
			next.screen_offset = centered.offset;next.apply_display = bool(centered.apply_display)
			if bool(centered.back): next.page = 4;next.navigation = Menu.initialize(3,4)
		3:
			var route := Audio.page_action(selected,bool(next.music_player_available),pressed,int(next.navigation.last_index))
			if route.has("fault"): return route
			var revealed := bool(route.music_player_available) != bool(next.music_player_available)
			next.music_player_available = bool(route.music_player_available)
			if revealed: next.navigation = Menu.initialize(int(route.selected),int(route.last_index))
			else:
				next.navigation.selected = int(route.selected);next.navigation.last_index = int(route.last_index)
			var adjusted := Audio.advance(next.audio,int(route.selected),pressed)
			if adjusted.has("fault"): return adjusted
			next.audio = adjusted
			for update in adjusted.volume_updates:
				next.adjustment_previews.append({"effects":int(update.preview_effects),"mode":int(update.preview_mode)})
				if update.kind == "music":
					next.cd_mix = Fade.restore(int(update.volume),int(adjusted.mode))
					var event: Dictionary = next.cd_mix.duplicate(true)
					event.option_volume = int(update.option_volume);event.stereo_flag = int(adjusted.mode)
					next.cd_mix_events.append(event)
				elif update.kind == "mode":
					# Native2f090 applies mono/stereo and invokes516d4 using
					# the current option, including prior menu-only rounding.
					next.effects_mono = int(update.mode) == 0
					next.cd_mix = Fade.restore(int(adjusted.music),int(update.mode))
					var event: Dictionary = next.cd_mix.duplicate(true)
					event.option_volume = int(adjusted.music);event.stereo_flag = int(update.mode)
					next.cd_mix_events.append(event)
				elif update.kind == "effects":
					next.effects_maximum = int(update.volume)
					next.effects_step = SoundMath.fade_step(int(update.volume))
					next.effects_preview_requested = true;next.effects_preview_volumes.append(int(update.volume))
			if route.action == "back":
				next.effects_restore_volume = int(next.audio.effects)
				next.page = 1;next.navigation = Menu.initialize(1,3)
			elif route.action == "music_player":
				next.page = 5;next.navigation = Menu.initialize(0,4);next.track = 1
				# Original4cb00 stops the menu soundtrack on Music Player entry.
				next.pending_action="music_player";next.audio_commands=["stop"]
		5:
			if playback == null: return {"fault":"Missing original CD playback state"}
			var route := Music.action(selected,int(next.track),int(playback),pressed)
			if route.has("fault"): return route
			next.track = int(route.track)
			if not route.commands.is_empty():
				next.pending_action = "music_player";next.audio_commands = route.commands.duplicate()
			if int(route.page) != 5:
				next.page = int(route.page);next.navigation = Menu.initialize(int(route.selected),int(route.last_index))
				if route.has("music_player_available"): next.music_player_available = bool(route.music_player_available)
		_: return {"fault":"Options session page is not yet connected"}
	return next

static func default_values(state: Dictionary) -> Dictionary:
	# Native4f9ac resets settings, not menu position, CD track selection,
	# campaign progress or the connected controller's detected pad kind.
	var next := state.duplicate(true)
	next.audio = {"music":80,"effects":127,"mode":1}
	next.cd_mix = Fade.restore(80,1);next.effects_mono = false
	next.effects_restore_volume = 127
	next.effects_restore_volume = 127;next.effects_maximum = 127;next.effects_step = 15
	next.scheme = 0;next.screen_offset = Vector2i.ZERO
	next.calibration = Calibration.normalize(Vector2i(128,128),Vector2i.ZERO,Vector2i(255,255))
	next.saved_game_selection = 0
	return next

static func complete_defaults(state: Dictionary, backend_applied: bool) -> Dictionary:
	if str(state.get("pending_action","")) != "reset_defaults" or not backend_applied:
		return {"fault":"Default settings have not been applied by the backend"}
	var next := default_values(state)
	next.pending_action = "";next.reset_notice_ticks = 30
	return next

