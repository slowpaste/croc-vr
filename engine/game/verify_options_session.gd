extends SceneTree
const Session = preload("res://source_options_session.gd")
func _initialize() -> void:
	var state := Session.initialize({"music":80,"effects":127,"mode":1})
	state = Session.advance(state,0x40000,0x40000)
	state = Session.advance(state,0,0x800000)
	if state.page!=3 or state.navigation.selected!=3: push_error("Original Audio submenu entry differs");quit(1);return
	var revealed := Session.advance(state,0,0x400)
	if revealed.navigation.selected!=4 or revealed.navigation.last_index!=4 or revealed.navigation.sizes[4]!=65536:quit(1);return
	for tick in range(3): state = Session.advance(state,0x10000,0x10000)
	if state.navigation.selected!=0:quit(1);return
	state = Session.advance(state,0,0x20000)
	if state.audio.music!=72 or state.audio.effects!=127:quit(1);return
	if state.cd_mix.mix!=[72,72,0,0] or state.cd_mix.decrement!=9:quit(1);return
	state = Session.advance(state,0,0x100000)
	if state.page!=1 or state.navigation.selected!=1 or state.audio.music!=72:quit(1);return
	state = Session.advance(state,0,0x100000)
	if not state.exit_requested:quit(1);return
	var effects := Session.initialize({"music":80,"effects":127,"mode":1},1)
	effects = Session.advance(effects,0,0x800000)
	for tick in range(2): effects = Session.advance(effects,0x10000,0x10000)
	effects = Session.advance(effects,0,0x20000)
	if effects.audio.effects!=120 or effects.effects_restore_volume!=127 or effects.effects_maximum!=119 or effects.effects_step!=14 or effects.effects_preview_volumes!=[119]:quit(1);return
	effects = Session.advance(effects,0,0x100000)
	if effects.effects_restore_volume!=120 or effects.effects_maximum!=119 or effects.effects_preview_requested:quit(1);return
	var mix := Session.initialize({"music":127,"effects":127,"mode":1})
	mix.page = 3;mix.navigation = preload("res://source_main_menu.gd").initialize(0,3)
	mix = Session.advance(mix,0,0x20000)
	if mix.audio.music!=120 or mix.cd_mix.mix!=[119,119,0,0] or mix.cd_mix.decrement!=14:quit(1);return
	mix.navigation = preload("res://source_main_menu.gd").initialize(2,3)
	mix = Session.advance(mix,0,0x20000)
	if mix.audio.mode!=0 or not mix.effects_mono or mix.cd_mix.mix!=[120,120,120,120]:quit(1);return
	var controller := Session.initialize({"music":80,"effects":127,"mode":1},0,2)
	controller = Session.advance(controller,0,0x800000)
	if controller.page!=2 or controller.navigation.selected!=2:quit(1);return
	for tick in range(2): controller = Session.advance(controller,0x10000,0x10000)
	controller = Session.advance(controller,0,0x800000)
	if controller.page!=6:quit(1);return
	controller = Session.advance(controller,0,0x800000,Vector2i(127,129))
	var navigation: Dictionary = controller.navigation.duplicate(true)
	controller = Session.advance(controller,0xf0000,0,Vector2i(0,255))
	if controller.navigation!=navigation:push_error("Calibration advanced generic navigation");quit(1);return
	controller = Session.advance(controller,0,0,Vector2i(255,0))
	controller = Session.advance(controller,0,0x800000,Vector2i(128,128))
	if controller.page!=2 or controller.navigation.selected!=0 or controller.calibration.center!=Vector2i(127,129) or controller.calibration.radius!=122:quit(1);return
	var misc := Session.initialize({"music":80,"effects":127,"mode":1},2)
	misc = Session.advance(misc,0,0x800000)
	if misc.page!=4 or misc.navigation.selected!=4:quit(1);return
	misc = Session.advance(misc,0x10000,0x10000)
	misc = Session.advance(misc,0,0x800000)
	if misc.page!=7:quit(1);return
	for tick in range(30): misc = Session.advance(misc,0x80000,0)
	if misc.screen_offset!=Vector2i(24,0):quit(1);return
	misc = Session.advance(misc,0,0x100000)
	if misc.page!=4 or misc.navigation.selected!=3 or misc.screen_offset!=Vector2i(24,0):quit(1);return
	misc = Session.advance(misc,0x10000,0x10000)
	misc = Session.advance(misc,0,0x800000)
	if misc.pending_action!="reset_defaults" or not Session.advance(misc,0,0).has("fault"):quit(1);return
	misc.audio = {"music":8,"effects":16,"mode":2};misc.scheme = 2;misc.track = 42
	if not Session.complete_defaults(misc,false).has("fault"):quit(1);return
	var reset := Session.complete_defaults(misc,true) # Controlled backend acknowledgment, not live application proof.
	if reset.audio!={"music":80,"effects":127,"mode":1} or reset.scheme!=0 or reset.screen_offset!=Vector2i.ZERO or reset.calibration.radius!=123 or reset.track!=42 or reset.navigation.selected!=2 or reset.reset_notice_ticks!=30:quit(1);return
	reset = Session.advance(reset,0,0)
	if reset.reset_notice_ticks!=29:quit(1);return
	var player := Session.initialize({"music":80,"effects":127,"mode":1},1)
	player = Session.advance(player,0,0x800000)
	player = Session.advance(player,0,0x400)
	player = Session.advance(player,0x10000,0x10000)
	player = Session.advance(player,0,0x800000)
	if player.page!=5 or player.track!=1:quit(1);return
	if player.pending_action!="music_player" or player.audio_commands!=["stop"]:quit(1);return
	# The live world executes this stop; this numerical fixture acknowledges it.
	player.pending_action=""
	var play_requested := Session.advance(player,0,0x800000,null,0)
	if play_requested.pending_action!="music_player" or play_requested.audio_commands!=["play"] or not Session.advance(play_requested,0,0).has("fault"):quit(1);return
	player = Session.advance(player,0,0x100000,null,0)
	if player.page!=3 or player.navigation.selected!=3 or player.navigation.last_index!=4 or player.music_player_available:quit(1);return
	player = Session.advance(player,0x40000,0x40000)
	if player.has("fault") or player.navigation.selected!=4:quit(1);return
	player = Session.advance(player,0,0x800000)
	if player.page!=1 or player.navigation.selected!=1:quit(1);return
	var effects_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-options-effects-state.json"))
	for index in range(0,effects_fixture.observations.size(),2):
		var before: Dictionary = effects_fixture.observations[index]
		var after: Dictionary = effects_fixture.observations[index+1]
		var input := Session.initialize({"music":80,"effects":int(before.volume),"mode":1})
		input.page = 3;input.navigation = preload("res://source_main_menu.gd").initialize(1,3);input.effects_restore_volume = int(before.gain)
		var result := Session.advance(input,0,0x20000 if int(before.delta)<0 else 0x80000)
		if result.effects_restore_volume!=int(after.gain) or result.effects_maximum!=int(after.maximum) or result.effects_step!=int(after.step) or result.effects_preview_volumes!=[int(after.volume)]:
			push_error("Original effects gain/maximum/step ordering mismatch");quit(1);return
	print("PASS: composed Options page sequences and eight original effects-state captures")
	quit(0)

