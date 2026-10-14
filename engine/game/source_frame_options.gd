extends RefCounted
const CAMERA := 21
const DISPLAY := 22
const Menu=preload("res://source_main_menu.gd")
static func rows(world: Node, page: int) -> Array:
	var c=world.vr_controls
	match page:
		2:return ["CONTROL STYLE - "+c.layout.to_upper(),"CAMERA OPTIONS","HAPTIC FEEDBACK - "+("ON" if c.haptics_enabled else "OFF"),"RETURN TO OPTIONS MENU"]
		4:return ["DELETE SAVED GAME","WRITE CURRENT OPTIONS","RESET OPTIONS TO DEFAULT","DISPLAY OPTIONS","RETURN TO OPTIONS MENU"]
		CAMERA:return ["TURN MODE - "+c.turn_mode.to_upper(),"SNAP ANGLE - %d"%c.snap_degrees if c.turn_mode=="snap" else "TURN SPEED - %d"%int(c.smooth_degrees_per_second),"JUMP CAMERA - "+c.jump_camera.to_upper(),"CAMERA TILT - %d"%roundi(rad_to_deg(world.vr_camera_pitch)),"RETURN TO CONTROLLER SET-UP"]
		DISPLAY:return ["FOVEATED RENDERING - "+["OFF","LOW","MEDIUM","HIGH"][c.foveation_level],"RECENTER VIEW","RETURN TO MISC OPTIONS"]
	return []
static func text(world: Node, state: Dictionary, supplement: Dictionary, labels: Array, first_y: int = 150, spacing: int = 15, sizes: Array = []) -> Dictionary:
	var data: Dictionary=world.runtime_tables.mainMenu.duplicate(true)
	data.glyphs.merge(supplement.glyphs,false)
	for code in [123,125,124,126]:data.glyphs[str(code)]={"sprite":0,"width":20,"height":20,"advance":24}
	data.labels=[]
	var scaled:Array=(state.navigation.sizes if sizes.is_empty() else sizes).duplicate()
	for i in range(5):
		var line:String=str(labels[i]) if i<labels.size() else ""
		if sizes.is_empty() and i==int(state.navigation.selected):line="> "+line
		data.labels.append({"text":line,"y":first_y+i*spacing})
		var width:=0
		for character in line:
			var glyph:Dictionary=data.glyphs.get(str(character.unicode_at(0)),{})
			width+=int(glyph.get("advance",0))
		if width>0:scaled[i]=mini(int(scaled[i]),int(440.0*65536.0/width))
	var result:=preload("res://source_menu_text.gd").layout(data,scaled,false)
	if not result.has("fault") and sizes.is_empty():
		for glyph in result.labels[int(state.navigation.selected)].glyphs:glyph["tint"]=Color(1.0,0.85,0.35)
	return result
static func advance(world: Node, state: Dictionary, held: int, pressed: int, sample: Variant, playback: int) -> Dictionary:
	if not world.xr_active and not OS.get_cmdline_user_args().has("--frame-menu-preview"):
		return preload("res://source_options_session.gd").advance(state,held,pressed,sample,playback)
	var page:=int(state.page)
	if page not in [2,CAMERA,DISPLAY]:
		var next := preload("res://source_options_session.gd").advance(state,held,pressed,sample,playback)
		if page==1 and int(next.get("page",0))==2:next.navigation=Menu.initialize(0,3)
		if page==1 and int(next.get("page",0))==3:next.navigation=Menu.initialize(0,3)
		if page==1 and int(next.get("page",0))==4:next.navigation=Menu.initialize(3,4)
		if page==4 and int(next.get("page",0))==7:next.page=DISPLAY;next.navigation=Menu.initialize(0,2)
		return next
	var next:=state.duplicate(true)
	next.navigation=Menu.advance(next.navigation,held,pressed)
	var selected:=int(next.navigation.selected)
	var confirm:bool=(pressed&0x800000)!=0
	var back:bool=(pressed&0x100000)!=0
	var direction:=1 if (pressed&0x80000)!=0 or confirm else -1 if (pressed&0x20000)!=0 else 0
	var c=world.vr_controls
	var changed:=false
	if back or (confirm and selected==rows(world,page).size()-1):
		next.page=1 if page==2 else 2 if page==CAMERA else 4
		next.navigation=Menu.initialize(0 if page==2 else 1 if page==CAMERA else 3,3 if page in [2,CAMERA] else 4)
	elif page==2:
		if selected==0 and direction!=0:c.layout="classic" if c.layout=="modern" else "modern";changed=true
		elif selected==1 and confirm:next.page=CAMERA;next.navigation=Menu.initialize(0,4)
		elif selected==2 and direction!=0:c.haptics_enabled=not c.haptics_enabled;changed=true
	elif page==CAMERA and direction!=0:
		match selected:
			0:c.turn_mode="smooth" if c.turn_mode=="snap" else "snap";changed=true
			1:
				if c.turn_mode=="snap":
					var angles: Array=[15,30,45,90];c.snap_degrees=angles[posmod(angles.find(c.snap_degrees)+direction,4)]
				else:c.smooth_degrees_per_second=clampf(c.smooth_degrees_per_second+direction*30,30,180)
				changed=true
			2:c.jump_camera="follow" if c.jump_camera=="steady" else "steady";changed=true
			3:world.vr_camera_pitch=clampf(world.vr_camera_pitch+direction*deg_to_rad(5),-0.35,0.55);c.camera_tilt=world.vr_camera_pitch;changed=true
	elif page==DISPLAY:
		if selected==0 and direction!=0:c.foveation_level=posmod(c.foveation_level+direction,4);changed=true
		elif selected==1 and confirm:
			if world.has_method("recenter_vr_view"):world.recenter_vr_view()
			else:XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT,true)
	if changed:world.vr_settings.save_changes()
	return next
