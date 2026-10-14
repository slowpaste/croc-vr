extends RefCounted
static func calibration_layout(font: Dictionary, session: Dictionary, supplement: Dictionary) -> Dictionary:
	if int(session.page)!=6:return {"labels":[]}
	var phase := int(session.capture.phase)
	if phase not in [0,1]:return {"fault":"Invalid calibration prompt phase"}
	var data := font.duplicate(true);data.glyphs.merge(supplement.get("glyphs",{}),false)
	data.labels=[{"text":"Center Left Controller","y":150},{"text":"and Press {","y":165}] if phase==0 else [{"text":"Move left stick in a","y":135},{"text":"complete circle 3","y":150},{"text":"times then press {","y":165}]
	while data.labels.size()<5:data.labels.append({"text":"","y":0})
	return preload("res://source_menu_text.gd").layout(data,[65536,65536,65536,65536,65536],false)
static func controller_directions_layout(font: Dictionary, session: Dictionary, supplement: Dictionary) -> Dictionary:
	if int(session.page)!=2 or int(session.navigation.selected)!=1 or int(session.scheme) not in [0,1,2]:return {"labels":[]}
	if int(session.pad_kind)==2 and int(session.scheme)==1:return {"labels":[]}
	var glyphs: Dictionary=font.glyphs.duplicate(true);glyphs.merge(supplement.get("glyphs",{}),true)
	var texts: Array=["; Forward","] Turn Left","[ Turn Right","\\ Backward"] if int(session.scheme)!=1 else ["; Jump","] Turn Left","[ Turn Right","\\ Flip"]
	if int(session.pad_kind)==2:texts=["Left stick","moves Croc","Right stick","moves camera"]
	texts.append_array([["Jump","Attack","Camera","Flip"],["Forward","Attack","Camera","Backward"],["Flip","Camera","Attack","Jump"]][int(session.scheme)])
	var labels: Array=[]
	for row in range(8):
		var positions: Array=[];var x:=60 if row<4 else 328
		var y: int=[100,114,134,148][row] if int(session.pad_kind)==2 and row<4 else 100+(row%4)*16
		for character in texts[row]:
			var code: int=character.unicode_at(0);var key:=str(code)
			if not glyphs.has(key):return {"fault":"Missing controller direction glyph"}
			var glyph: Dictionary=glyphs[key]
			if code>32:
				if not glyph.has("verticalOffset"):return {"fault":"Missing native instruction baseline"}
				var height: int=(int(glyph.height)*51200)>>16
				positions.append({"sprite":int(glyph.sprite),"position":Vector2i(x,y+int(glyph.verticalOffset)+8-(height>>1)),"size":Vector2i((int(glyph.width)*51200)>>16,height)})
			x+=(int(glyph.advance)*51200)>>16
		labels.append({"text":texts[row],"glyphs":positions})
	for row in range(4):
		var icon: String=["{","}","|","~"][row]
		var glyph: Dictionary=glyphs[str(icon.unicode_at(0))]
		labels.append({"text":icon,"glyphs":[{"sprite":int(glyph.sprite),"position":Vector2i(300,100+row*16+int(glyph.verticalOffset)+8-(int(glyph.height)>>1)),"size":Vector2i(int(glyph.width),int(glyph.height))}]})
	return {"labels":labels}
static func controller_scheme_layout(font: Dictionary, session: Dictionary, supplement: Dictionary) -> Dictionary:
	if int(session.page)!=2 or int(session.navigation.selected)!=1:return {"labels":[]}
	var scheme := int(session.scheme)
	if scheme not in [0,1,2]:return {"fault":"Invalid controller configuration"}
	var data := font.duplicate(true);data.glyphs.merge(supplement.get("glyphs",{}),false)
	data.labels=[{"text":"Control Method "+["A","B","C"][scheme],"y":80}]
	while data.labels.size()<5:data.labels.append({"text":"","y":0})
	return preload("res://source_menu_text.gd").layout(data,[65536,65536,65536,65536,65536],false)
static func controller_status_layout(session: Dictionary, supplement: Dictionary) -> Dictionary:
	if int(session.page)!=2:return {"labels":[]}
	var missing := int(session.navigation.selected)==0 and int(session.pad_kind)!=2
	var unavailable := int(session.navigation.selected)==1 and int(session.pad_kind)==2 and int(session.scheme)==1
	if not missing and not unavailable:return {"labels":[]}
	if not supplement.has("muteGlyphs"):return {"fault":"Missing original controller status font"}
	var labels: Array=[{"text":"No analog controller found" if missing else "Not available for analog controller","y":130 if missing else 148}]
	while labels.size()<5:labels.append({"text":"","y":0})
	return preload("res://source_menu_text.gd").layout({"glyphs":supplement.muteGlyphs,"labels":labels,"centerX":256},[65536,65536,65536,65536,65536],false)
static func notice_layout(font: Dictionary, session: Dictionary, supplement: Dictionary) -> Dictionary:
	var labels: Array=[]
	if int(session.page)==2 and int(session.get("calibration_notice_display",0))!=0:
		labels=[{"text":"Calibration Successful" if int(session.calibration_notice_display)>0 else "Calibration Failed","y":100}]
		if int(session.calibration_notice_display)<0:labels.append({"text":"Using Defaults","y":115})
	elif int(session.page)==4 and bool(session.get("reset_notice_visible",false)):labels=[{"text":"OPTIONS RESET","y":100}]
	elif int(session.page)==4 and int(session.get("write_notice_display",0))!=0:
		labels=[{"text":"CURRENT OPTIONS SAVED" if int(session.write_notice_display)>0 else "MEMORY CARD PROBLEM","y":100}]
	else:return {"labels":[]}
	var data := font.duplicate(true);data.glyphs.merge(supplement.get("glyphs",{}),false)
	data.labels=labels
	while data.labels.size()<5:data.labels.append({"text":"","y":0})
	return preload("res://source_menu_text.gd").layout(data,[65536,65536,65536,65536,65536],false)
static func mute_layout(session: Dictionary, supplement: Dictionary) -> Dictionary:
	if int(session.page)!=3 or int(session.navigation.selected) not in [0,1]:return {"labels":[]}
	var volume := int(session.audio.music) if int(session.navigation.selected)==0 else int(session.audio.effects)
	if volume!=0:return {"labels":[]}
	if not supplement.has("muteGlyphs"):return {"fault":"Missing original MUTE font"}
	var labels: Array=[{"text":"MUTE","y":132 if bool(session.music_player_available) else 147}]
	while labels.size()<5:labels.append({"text":"","y":0})
	return preload("res://source_menu_text.gd").layout({"glyphs":supplement.muteGlyphs,"labels":labels,"centerX":256},[65536,65536,65536,65536,65536],false)
static func audio_bar_layout(font: Dictionary, session: Dictionary, supplement: Dictionary) -> Dictionary:
	if int(session.page)!=3 or int(session.navigation.selected) not in [0,1]:return {"labels":[]}
	var volume := int(session.audio.music) if int(session.navigation.selected)==0 else int(session.audio.effects)
	if volume<0 or volume>127:return {"fault":"Invalid Audio bar volume"}
	var filled := 16 if volume==127 else (volume+7)>>3
	var text := ""
	for index in range(16):text += ("$" if index<11 else "^") if index<filled else ("#" if index<11 else "&")
	var data := font.duplicate(true);data.glyphs.merge(supplement.get("glyphs",{}),false)
	data.labels=[{"text":text,"y":125 if bool(session.music_player_available) else 140}]
	while data.labels.size()<5:data.labels.append({"text":"","y":0})
	return preload("res://source_menu_text.gd").layout(data,[65536,65536,65536,65536,65536],false)
static func legend_layout(font: Dictionary, page: int, selected: int, supplement: Dictionary) -> Dictionary:
	if page not in [1,2,3,4,5,6,7]:return {"labels":[]}
	var data := font.duplicate(true)
	data.glyphs.merge(supplement.get("glyphs",{}),false)
	var adjust := (page==2 and selected==1) or (page==3 and selected<3)
	data.labels=[{"text":"* :" if adjust else "@ :","y":66 if page==2 else 46}]
	while data.labels.size()<5:data.labels.append({"text":"","y":0})
	return preload("res://source_menu_text.gd").layout(data,[65536,65536,65536,65536,65536],false)
static func heading_layout(page: int, supplement: Dictionary) -> Dictionary:
	if not supplement.has("headingGlyphs"):return {"fault":"Missing original Options heading font"}
	var labels: Array=[]
	match page:
		1:labels=[{"text":"OPTIONS","y":24}]
		2:labels=[{"text":"CONTROLLER","y":24},{"text":"SET-UP","y":44}]
		3:labels=[{"text":"AUDIO OPTIONS","y":24}]
		4:labels=[{"text":"MISC OPTIONS","y":24}]
		5:labels=[{"text":"MUSIC PLAYER","y":24}]
		7:labels=[{"text":"CENTER SCREEN","y":24}]
		6:labels=[{"text":"CALIBRATE ANALOG","y":24}]
		_:return {"labels":[]}
	while labels.size()<5:labels.append({"text":"","y":0})
	return preload("res://source_menu_text.gd").layout({"glyphs":supplement.headingGlyphs,"labels":labels,"centerX":256},[65536,65536,65536,65536,65536],false)
static func layout(font: Dictionary, page: int, selected: int, sizes: Array, music_player_available: bool = false, parent_mode: int = 0, supplement: Dictionary = {}) -> Dictionary:
	if page==6:return {"labels":[]}
	var texts: Array = []
	var first_y := 165
	match page:
		1: texts = ["CONTROLLER SET-UP","AUDIO OPTIONS ","MISC OPTIONS","RETURN TO MAP" if parent_mode == 5 else "RETURN TO MAIN MENU"]
		2:
			# Native4b488..4b4d4 draws these three centered rows.
			first_y = 180
			texts = ["CALIBRATE ANALOG","< CHANGE CONFIGURATION >","RETURN TO OPTIONS MENU"]
		3:
			first_y = 150 if music_player_available else 165
			texts = ["< MUSIC VOLUME >" if selected == 0 else "MUSIC VOLUME","< SOUND EFFECT VOLUME >" if selected == 1 else "SOUND EFFECT VOLUME","< AUDIO MODE >" if selected == 2 else "AUDIO MODE"]
			if music_player_available: texts.append("MUSIC PLAYER")
			texts.append("RETURN TO OPTIONS MENU")
		4:
			first_y = 150
			texts = ["DELETE SAVED GAME","WRITE CURRENT OPTIONS","RESET OPTIONS TO DEFAULT","CENTER SCREEN","RETURN TO OPTIONS MENU"]
		5:
			first_y=150
			texts=["PLAY TRACK","STOP TRACK","NEXT TRACK","PREVIOUS TRACK","RETURN TO AUDIO OPTIONS"]
		7:
			var center_data: Dictionary=font.duplicate(true);center_data.glyphs.merge(supplement.get("glyphs",{}),false)
			center_data.labels=[{"text":"Use directional buttons","y":175},{"text":"to center","y":190},{"text":"Press { when finished","y":205},{"text":"","y":0},{"text":"","y":0}]
			return preload("res://source_menu_text.gd").layout(center_data,[65536,65536,65536,65536,65536],false)
		_: return {"fault":"Options page text is not yet qualified"}
	var data := font.duplicate(true)
	data.glyphs.merge(supplement.get("glyphs",{}),false)
	data.labels = []
	for index in range(5):
		data.labels.append({"text":texts[index] if index < texts.size() else "","y":first_y+index*15})
	return preload("res://source_menu_text.gd").layout(data,sizes,false)
