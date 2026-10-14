extends RefCounted
# HUD45ac0..46634: changed counters reveal for60 updates; zero crystals stay
# visible. Lives display spare lives (total minus one), and bonus commands can
# hold the collected-color row open until their collection effect finishes.
static func step(state: Dictionary, input: Dictionary, tick: int, active: bool, paused: bool = false) -> Dictionary:
	var next := state.duplicate(true)
	var elapsed := maxi(0,tick-int(state.get("tick",tick)))
	next.tick=tick
	next.active=active
	if not active:return next
	if bool(input.get("hidden",false)):elapsed=0
	var entry: bool = not bool(state.get("active",false)) or int(next.get("level",-1))!=int(input.level)
	for key in ["crystals","gobbos","lives"]:
		var changed: bool = entry or int(next.get(key,-1))!=int(input[key]) or int(next.get(key+"_revision",-1))!=int(input.get(key+"_revision",0))
		next[key+"_time"]=60 if changed or paused else maxi(0,int(next.get(key+"_time",0))-elapsed)
		next[key]=int(input[key])
		next[key+"_revision"]=int(input.get(key+"_revision",0))
	if int(input.crystals)==0:next.crystals_time=60
	var requested: bool = entry or int(next.get("bonus_revision",-1))!=int(input.bonus_revision) or int(next.get("bonus_request",0))!=int(input.bonus_request)
	if requested:
		next.bonus_time=int(input.bonus_request)
	elif int(next.get("mask",0))!=int(input.mask):next.bonus_time=60
	elif int(next.get("bonus_time",0))>0 and not paused:next.bonus_time=maxi(0,int(next.bonus_time)-elapsed)
	if entry or int(next.get("life_request",0))!=int(input.life_request):
		if int(input.life_request) in [60,240]:next.lives_time=60
	next.merge(input,true)
	return next

static func alpha(time: int, paused: bool) -> float:
	return 1.0 if paused or time<0 else clampf(float(time)/8.0,0.0,1.0)

static func number(glyphs: Array, value: int, x: int, y: int, tint: Color) -> void:
	for character in str(clampi(value,0,999)):
		glyphs.append({"sprite":int(character),"position":Vector2(x,y),"size":Vector2(18,17),"tint":tint})
		x+=18

static func layout(state: Dictionary, paused: bool = false, vr: bool = false) -> Dictionary:
	var track: Array=[]
	var bonus: Array=[]
	var lives_visible: bool = paused or int(state.get("lives_time",0))>0
	if paused or int(state.get("crystals_time",0))>0:
		var tint:=Color(1,1,1,alpha(int(state.crystals_time),paused))
		track.append({"sprite":12,"position":Vector2(24,20),"size":Vector2(45,27),"tint":tint})
		number(track,int(state.crystals),54,34,tint)
	if lives_visible:
		var tint:=Color(1,1,1,alpha(int(state.lives_time),paused))
		var spare:=maxi(0,int(state.lives)-1)
		track.append({"sprite":10,"position":Vector2(414,20),"size":Vector2(74,35),"tint":tint})
		number(track,spare,378 if spare>=10 else 396,34,tint)
	if bool(state.get("gobbo_enabled",false)) and (paused or int(state.get("gobbos_time",0))>0):
		var tint:=Color(1,1,1,alpha(int(state.gobbos_time),paused))
		var row:=40 if lives_visible else 0
		track.append({"sprite":11,"position":Vector2(410,20+row),"size":Vector2(61,24),"tint":tint})
		number(track,int(state.gobbos),396,35+row,tint)
	if paused or int(state.get("bonus_time",0))!=0:
		for index in range(5):
			if (int(state.mask)&(1<<index))!=0:
				bonus.append({"sprite":2+index,"position":Vector2(24+index*20,68),"size":Vector2(18,18),"tint":Color(1,1,1,alpha(int(state.bonus_time),paused))})
	if vr:
		# Bring the original corner groups into comfortable eye-only reach and
		# below the level-title banner, keeping the central play area clear.
		for glyph in track+bonus:
			glyph.position.x+=48 if glyph.position.x<256 else -36
			glyph.position.y+=28
	return {"track":{"labels":[{"glyphs":track}]},"bonus":{"labels":[{"glyphs":bonus}]}}
