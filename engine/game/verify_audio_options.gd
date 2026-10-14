extends SceneTree
const Options = preload("res://source_audio_options.gd")
func _initialize() -> void:
	# Expectations derive from original4c868..4c9f0 and volume helpers,
	# including menu-only snapping and sequential simultaneous presses.
	var cases := [
		[0,127,127,1,0x20000,120,127,1],
		[1,80,127,1,0x20000,80,120,1],
		[0,14,80,1,0x20000,0,80,1],
		[0,15,80,1,0x20000,7,80,1],
		[0,120,80,1,0x20000,112,80,1],
		[0,120,80,1,0x80000,127,80,1],
		[0,6,80,1,0xa0000,8,80,1],
		[1,80,127,1,0xa0000,80,127,1],
		[2,80,127,0,0x20000,80,127,2],
		[2,80,127,2,0x80000,80,127,0],
		[2,80,127,0,0xa0000,80,127,0],
		[3,80,127,1,0xa0000,80,127,1]
	]
	for sample in cases:
		var result := Options.advance({"music":sample[1],"effects":sample[2],"mode":sample[3]},sample[0],sample[4])
		if result.has("fault") or result.music!=sample[5] or result.effects!=sample[6] or result.mode!=sample[7]:
			push_error("Original audio-option boundary mismatch: "+str(sample)+" got="+str(result));quit(1);return
	var reveal := Options.page_action(3,false,0x400)
	if reveal.selected!=4 or not reveal.music_player_available or reveal.last_index!=4: quit(1);return
	if Options.page_action(3,false,0x800000).action!="back" or Options.page_action(3,true,0x800000).action!="music_player": quit(1);return
	if Options.page_action(4,true,0x800000).action!="back" or Options.page_action(0,false,0x800000).action!="none": quit(1);return
	if Options.page_action(3,true,0x900000).action!="back": quit(1);return
	var route = preload("res://source_options_route.gd")
	for selected in range(3):
		var entry: Dictionary = route.root_action(selected,0x800000)
		if entry.page!=selected+2 or entry.selected!=selected+2 or entry.last_index!=selected+2 or not entry.reset_menu or entry.exit_requested: quit(1);return
	if not route.root_action(3,0x800000).exit_requested: quit(1);return
	var simultaneous: Dictionary = route.root_action(1,0x900000)
	if not simultaneous.exit_requested or simultaneous.page!=3: quit(1);return
	var misc_actions := ["delete_saved_game","write_options","reset_defaults","center_screen","back"]
	for selected in range(5):
		if route.misc_action(selected,0x800000).action!=misc_actions[selected]: quit(1);return
	var misc_dual: Dictionary = route.misc_action(0,0x900000)
	if misc_dual.action!="reset_defaults" or misc_dual.page!=1 or misc_dual.reset_notice_ticks!=30: quit(1);return
	if route.controller_action(1,2,1,0x80000).scheme!=0 or route.controller_action(1,0,1,0x20000).scheme!=2: quit(1);return
	if route.controller_action(1,0,1,0xa0000).scheme!=0: quit(1);return
	if route.controller_action(0,0,1,0x800000).action!="controller_error_sound": quit(1);return
	if route.controller_action(0,0,2,0x800000).page!=6 or route.controller_action(2,0,1,0x800000).page!=1: quit(1);return
	var music = preload("res://source_options_music_player.gd")
	if music.action(2,64,1,0x800000).track!=1 or music.action(3,1,1,0x800000).track!=64: quit(1);return
	if music.action(0,1,1,0x800000).commands!=["pause"] or music.action(0,1,2,0x800000).commands!=["resume"]: quit(1);return
	if music.action(2,2,2,0x800000).commands!=["stop","play","pause"]: quit(1);return
	var music_dual: Dictionary = music.action(0,1,1,0x900000)
	if music_dual.page!=3 or music_dual.track!=64: quit(1);return
	var volume_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-options-music-volume.json"))
	# These menu results add the independently inspected4c870..4c898
	# snap rules to the measured helper outputs; they aren't full-menu traces.
	var menu_volumes := [120,0,7,127,112,0,8,88]
	for index in range(0,volume_fixture.observations.size(),2):
		var before: Dictionary = volume_fixture.observations[index]
		var after: Dictionary = volume_fixture.observations[index+1]
		if int(after.level)!=(int(after.volume)>>3): quit(1);return
		var result := Options.advance({"music":int(before.volume),"effects":127,"mode":1},0,0x20000 if int(before.delta)<0 else 0x80000)
		if result.music!=menu_volumes[int(index/2)]: push_error("Options value differs from original helper plus menu snap rules");quit(1);return
	var effects_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-options-effects-volume.json"))
	for index in range(0,effects_fixture.observations.size(),2):
		var before: Dictionary = effects_fixture.observations[index]
		var result := Options.advance({"music":80,"effects":int(before.volume),"mode":1},1,0x20000 if int(before.delta)<0 else 0x80000)
		if result.effects!=menu_volumes[int(index/2)]: push_error("Effects option differs from original helper plus menu snap rules");quit(1);return
	print("PASS: source-derived Options rules and original music/effects helper captures; full menu runtime pending")
	quit(0)

