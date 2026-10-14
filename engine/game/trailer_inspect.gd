extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if OS.get_cmdline_user_args().has("--slopes"):
		var w=load("res://imported.tscn").instantiate();root.add_child(w);w.set_process(false);w.set_physics_process(false)
		var count:=0
		for z in range(24,96):
			for x in range(12,84):
				var point:=Vector3(float(x)/4,8,float(z)/4)
				var f:Dictionary=w.source_raw_floor_query(point)
				var n:Vector3=preload("res://modern_character_pose.gd").floor_normal(w,f)
				var h:float=float(f.get("height_units",0))*3/4096
				if n.y>.8 and n.y<.99 and h<2 and int(f.get("surface_type",4))!=4:
					print("SLOPE_POINT ",Vector3(point.x,h,point.z)," normal ",n," type ",f.get("surface_type"));count+=1
					if count>=30:quit(0);return
		quit(0);return
	for map in ["MP010_01.MAP","MP010_03.MAP","MP010_02.MAP","MP020_00.MAP","MP011_00.MAP"]:
		var w=load("res://imported.tscn").instantiate();w.map_name=map;root.add_child(w)
		w.set_process(false);w.set_physics_process(false)
		for i in range(20):w.sample_source_player_controls();w.tick_source_actors()
		print("SHOT_INSPECT ",map," player ",w.source_player_actor.position)
		for a in w.source_actors:
			if a.source_name.begins_with("Platform") or a.source_name in ["Crystal","BonusDoor","Croc"]:print(a.source_name," ",a.position," angles ",a.source_angles)
		for z in range(3,25,3):
			var row=[]
			for x in range(3,25,3):
				var f:Dictionary=w.source_raw_floor_query(Vector3(x,10,z))
				row.append([x,f.get("surface_type",-1),snappedf(float(f.get("height_units",0))*3/4096,.01)])
			print("FLOOR ",z," ",row)
		w.stop_imported_audio();w.queue_free();await process_frame
	quit(0)
