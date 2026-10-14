extends SceneTree
# Development trace of the imported controller; unsupported state is diagnostic.
func _initialize() -> void:
	call_deferred("probe")
func probe() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	# Controlled neutral input fixture; this is not a live pad-input qualification.
	world.update_source_input(0,0)
	world.source_player_input_state = {"pad_mode":1}
	var actor = world.create_source_player()
	if actor == null:
		push_error("Source player factory failed")
		world.queue_free()
		await process_frame
		quit(1)
		return
	if world.create_source_player() != actor or world.source_actors.count(actor) != 1 or world.source_pool.slots[world.source_player_id].node != actor:
		push_error("Source player factory duplicated or lost its registered slot")
		world.queue_free()
		await process_frame
		quit(1)
		return
	var scenario := "idle"
	var arguments := OS.get_cmdline_user_args()
	var selected_scheme := -1
	var scheme_option := arguments.find("--probe-scheme")
	if scheme_option>=0 and scheme_option+1<arguments.size():
		selected_scheme=int(arguments[scheme_option+1])
		if selected_scheme not in [0,1,2]:push_error("Invalid probe controller scheme");quit(1);return
		world.source_options_state.scheme=selected_scheme
	var option := arguments.find("--probe-input")
	if option >= 0 and option+1 < arguments.size():
		scenario = arguments[option+1]
	var tick_count := 120
	var retreat_tick := -1
	option = arguments.find("--probe-retreat")
	if option >= 0 and option+1 < arguments.size():
		retreat_tick = int(arguments[option+1])
	option = arguments.find("--probe-ticks")
	if option >= 0 and option+1 < arguments.size():
		tick_count = clampi(int(arguments[option+1]),1,3600)
	var previous := 0
	var input_tick := 30
	option = arguments.find("--probe-input-at")
	if option >= 0 and option+1 < arguments.size():
		input_tick = maxi(0,int(arguments[option+1]))
	var action_start: Vector3 = actor.position
	var action_start_yaw: int = actor.source_angles.y
	var action_start_pitch: int = actor.source_angles.x
	var action_pitch_delta := 0
	var action_clips: Array = []
	var start_position: Vector3 = actor.position
	var peak_y: float = actor.position.y
	var rising_ticks := 0
	var attacking_ticks := 0
	var clips: Array = []
	var target: Node3D = null
	var contact_placed := false
	var target_contact_y: Variant = null
	var target_low_y: Variant = null
	var riding_ticks := 0
	var platform_start: Variant = null
	var platform_distance := 0.0
	var riding_offset: Variant = null
	var riding_error := 0.0
	var attached_offset: Variant = null
	var attached_error := 0.0
	var drift_events: Array = []
	var unexplained_riding_error := 0.0
	var airborne_ticks := 0
	var airborne_owner_flag_ticks := 0
	var platform_jump_peak: Variant = null
	var platform_jump_start: Variant = null
	var respawn_count := 0
	var target_name := ""
	option = arguments.find("--probe-target")
	if option >= 0 and option+1 < arguments.size():
		target_name = arguments[option+1]
	option = arguments.find("--probe-gems")
	if option >= 0 and option+1 < arguments.size():
		world.source_pickup_counts[1] = int(arguments[option+1])
	for candidate in world.source_actors:
		var wanted := "PlatformNormal" if scenario.begins_with("ride-platform") else "Crystal" if scenario == "ordinary-pickup" else "Crystal_S" if scenario == "pickup" else ("GobboWater" if actor.source_name == "SwimmingCroc" else "Gobbo") if scenario == "rescue" else "DantiniWalk"
		if not target_name.is_empty():
			wanted = target_name
		if candidate.source_name == wanted:
			target = candidate
			break
	for tick in range(tick_count):
		if actor.vm.status == "unsupported":
			break
		var current := 0
		if tick == 30 and scenario.begins_with("ride-platform") and is_instance_valid(target):
			var contacts: Dictionary = world.source_contacts_at(target.position,actor)
			if not contacts.lower.is_empty() and int(contacts.lower.get("actor",-1)) == int(target.source_pool_id):
				actor.position = Vector3(target.position.x,int(contacts.lower.height_units)*world.CELL_METERS/4096.0,target.position.z)
				actor.refresh_source_render_pose()
				actor.run_source_collision_response()
				platform_start = target.position
				riding_offset = actor.position-target.position
		if tick == retreat_tick and contact_placed:
			actor.position = start_position
			actor.refresh_source_render_pose()
		if ((tick == 30 and scenario in ["touch-enemy","pickup","ordinary-pickup","rescue"]) or (scenario == "attack-enemy" and not contact_placed and (actor.primary_flags&0x10000000) != 0)) and is_instance_valid(target):
			actor.position = target.position
			target_contact_y = target.position.y
			actor.refresh_source_render_pose()
			contact_placed = true
		if tick == input_tick:
			action_start = actor.position
			action_start_yaw = actor.source_angles.y
			action_start_pitch = actor.source_angles.x
		if tick >= input_tick and tick < input_tick+30:
			current = 1 if scenario == "walk" else 4 if scenario == "turn" else 0x10 if scenario == "jump" and tick < input_tick+6 else 0x800 if scenario in ["attack","attack-enemy"] and tick < input_tick+6 else 0
			if scenario == "backward":
				current = 2
			elif scenario == "turn-right":
				current = 8
			elif scenario in ["dive","surface"]:
				current = 1 if scenario == "dive" else 2
				if tick >= input_tick+15 and tick < input_tick+21:
					current |= 0x10
		if scenario == "ride-platform-jump" and tick >= 120 and tick < 128:
			current = 0x10
			if platform_jump_start == null:
				platform_jump_start = actor.position.y
				platform_jump_peak = actor.position.y
		world.update_source_input(current,previous)
		world.jump_held = (current&0x10) != 0
		previous = current
		var before_rider: Vector3 = actor.position
		var before_target: Vector3 = target.position if is_instance_valid(target) else Vector3.ZERO
		world.tick_source_actors()
		if tick >= input_tick and tick < input_tick+30:
			action_pitch_delta = ((int(actor.source_angles.x)-action_start_pitch+2048)&4095)-2048
		if arguments.has("--probe-dispatch"):
			var was_dead: bool = world.source_transition_state == 1
			if not world.process_source_exit():
				break
			if world.source_player_actor != actor:
				respawn_count += 1 if was_dead else 0
				actor = world.source_player_actor
		if scenario.begins_with("ride-platform") and is_instance_valid(target) and platform_start != null:
			if platform_jump_peak != null:
				platform_jump_peak = maxf(float(platform_jump_peak),actor.position.y)
			if (actor.primary_flags&0x600) != 0 and (actor.secondary_flags&2) == 0:
				airborne_ticks += 1
				if (actor.source_movement_status&0x100) == 0 or actor.source_ceiling_type != 5:
					airborne_owner_flag_ticks += 1 if (target.primary_flags&0x400000) != 0 or (target.secondary_flags&0x200) != 0 else 0
			var expected_animation: Vector3 = Vector3(actor.source_animation_delta_this_tick)*world.CELL_METERS/4096.0
			var unexplained: Vector3 = (actor.position-before_rider)-(target.position-before_target)-expected_animation
			unexplained_riding_error = maxf(unexplained_riding_error,Vector2(unexplained.x,unexplained.z).length())
			platform_distance = maxf(platform_distance,target.position.distance_to(platform_start))
			if int(actor.source_ground.get("actor",-1)) == int(target.source_pool_id) and (actor.secondary_flags&2) != 0:
				riding_ticks += 1
				if attached_offset == null:
					attached_offset = actor.position-target.position
				var attached_relative: Vector3 = actor.position-target.position-attached_offset
				var error := Vector2(attached_relative.x,attached_relative.z).length()
				if error > attached_error and drift_events.size() < 6:
					drift_events.append({"tick":tick,"rider_delta":str(actor.position-before_rider),"owner_delta":str(target.position-before_target),"animation_delta":str(expected_animation),"clip":actor.clip_name,"owner_yaw":target.source_angles.y,"rider_yaw":actor.source_angles.y,"motion":str(world.source_player_movement_state.motion),"rider_flags":actor.primary_flags,"relative":str(attached_relative)})
				attached_error = maxf(attached_error,Vector2(attached_relative.x,attached_relative.z).length())
				var relative: Vector3 = actor.position-target.position-riding_offset
				riding_error = maxf(riding_error,Vector2(relative.x,relative.z).length())
		if contact_placed and is_instance_valid(target):
			target_low_y = target.position.y if target_low_y == null else minf(float(target_low_y),target.position.y)
		peak_y = maxf(peak_y,actor.position.y)
		rising_ticks += 1 if (actor.primary_flags&0x200) != 0 else 0
		attacking_ticks += 1 if (actor.primary_flags&0x10000000) != 0 else 0
		if not clips.has(actor.clip_name):
			clips.append(actor.clip_name)
		if tick >= input_tick and not action_clips.has(actor.clip_name):
			action_clips.append(actor.clip_name)
	print("SOURCE_PLAYER_ACTION: ",JSON.stringify({"scenario":scenario,"start":str(start_position),"peak_y":peak_y,"rising_ticks":rising_ticks,"attacking_ticks":attacking_ticks,"clips":clips}))
	if scenario.begins_with("ride-platform"):
		print("SOURCE_RIDING_DRIFT: ",JSON.stringify(drift_events))
		print("SOURCE_RIDING_PROBE: ",JSON.stringify({"riding_ticks":riding_ticks,"platform_distance":platform_distance,"relative_xz_error":riding_error,"attached_xz_error":attached_error,"unexplained_step_error":unexplained_riding_error,"placed":platform_start != null}))
		print("SOURCE_PLATFORM_JUMP: ",JSON.stringify({"airborne_ticks":airborne_ticks,"invalid_owner_flag_ticks":airborne_owner_flag_ticks,"jump_start":platform_jump_start,"jump_peak":platform_jump_peak}))
	print("SOURCE_INVENTORY_PROBE: ",JSON.stringify({"counts":world.source_pickup_counts,"pickup_slots":world.source_stage_pickup_slots,"bonus_mask":world.source_bonus_mask,"display_timer":world.source_pickup_display_timer}))
	if arguments.has("--probe-dispatch"):
		print("SOURCE_RESPAWN_PROBE: ",JSON.stringify({"respawns":respawn_count,"state":world.source_transition_state,"fault":world.source_transition_fault}))
	var faults: Array = []
	for candidate in world.source_actors:
		if candidate.vm.fault != "":
			faults.append({"name":candidate.source_name,"pc":candidate.vm.pc,"fault":candidate.vm.fault})
	print("SOURCE_CONTACT_PROBE: ",JSON.stringify({"scenario":scenario,"contact_fault":world.source_player_contact_fault,"actor_faults":faults,"target_present":is_instance_valid(target) and world.source_actors.has(target),"target_contacts":world.source_player_contact_counts.get(target.source_pool_id,0) if is_instance_valid(target) else 0,"target_contact_y":target_contact_y,"target_low_y":target_low_y,"target_y":target.position.y if is_instance_valid(target) else null,"target_model":target.model_name if is_instance_valid(target) else "","target_pc":target.vm.pc if is_instance_valid(target) else -1}))
	print("SOURCE_PLAYER_PROBE: ",JSON.stringify({"scenario":scenario,"status":actor.vm.status,"pc":actor.vm.pc,"fault":actor.vm.fault,"primary":actor.primary_flags,"secondary":actor.secondary_flags,"registered":world.source_player_actor==actor,"model":actor.model_name,"position":str(actor.position),"yaw":actor.source_angles.y,"animation":actor.clip_name}))
	if arguments.has("--probe-reload") and is_instance_valid(target):
		var removed_index := int(target.source_map_entity_index)
		var loaded: bool = world.load_room(world.map_name)
		var respawned := false
		for candidate in world.source_actors:
			respawned = respawned or int(candidate.source_map_entity_index) == removed_index
		print("SOURCE_RELOAD_PROBE: ",JSON.stringify({"loaded":loaded,"entity_index":removed_index,"respawned":respawned}))
	world.stop_imported_audio()
	var verified := true
	if arguments.has("--verify") and scenario == "rescue":
		verified = is_instance_valid(target) and not world.source_actors.has(target) and world.source_pickup_counts[2] == 1 and faults.is_empty() and actor.vm.fault == "" and world.source_player_contact_fault == ""
		if not verified:
			push_error("Original rescue did not increment the count and remove the Gobbo")
	if arguments.has("--verify-damage"):
		verified = scenario == "touch-enemy" and world.source_pickup_counts[1] == 0 and world.source_pickup_counts[3] == 3 and faults.is_empty() and actor.vm.fault == "" and world.source_transition_state == 0 and (actor.primary_flags&0x40000000) == 0 and (clips.has("CROCGHIT.ANI") or clips.has("SWIMCRHT.ANI"))
		if not verified:
			push_error("Single enemy hit with crystals did not scatter, survive and recover")
	if arguments.has("--verify-swim"):
		verified = actor.source_name == "SwimmingCroc" and faults.is_empty() and actor.vm.fault == "" and world.source_player_actor == actor and world.source_player_contact_fault == "" and clips.has("SWIMWAIT.ANI")
		if scenario == "jump":
			verified = verified and actor.position.distance_to(action_start) > 0.5 and action_clips.has("SWIM.ANI")
		elif scenario == "walk":
			verified = verified and action_pitch_delta > 0
		elif scenario == "turn":
			verified = verified and action_clips.has("SWIMTRNL.ANI") and actor.source_angles.y != action_start_yaw
		elif scenario == "turn-right":
			verified = verified and action_clips.has("SWIMTRNR.ANI") and actor.source_angles.y != action_start_yaw
		elif scenario == "backward":
			verified = verified and action_pitch_delta < 0
		elif scenario == "dive":
			verified = verified and actor.position.y < action_start.y-0.1 and action_clips.has("SWIM.ANI")
		elif scenario == "surface":
			verified = verified and actor.position.y > action_start.y+0.1 and action_clips.has("SWIM.ANI")
		elif scenario == "attack":
			verified = verified and attacking_ticks > 0 and (action_clips.has("SWIMATTK.ANI") or action_clips.has("SWIMATT2.ANI")) and (actor.primary_flags&0x10000000) == 0
		print("SOURCE_SWIM_ACTION: ",JSON.stringify({"input_tick":input_tick,"start":str(action_start),"end":str(actor.position),"pitch_delta":action_pitch_delta,"clips":action_clips,"verified":verified}))
		if not verified:
			push_error("Original swimming controller scenario failed")
	if arguments.has("--verify") and scenario == "touch-enemy" and arguments.has("--probe-dispatch"):
		verified = respawn_count == 1 and world.source_pickup_counts[3] == 2 and world.source_transition_state == 0 and world.source_transition_fault == "" and faults.is_empty() and actor.vm.fault == "" and actor.position == start_position and (actor.primary_flags&0x40000000) == 0
		if selected_scheme>=0:verified=verified and int(world.source_options_state.get("scheme",-1))==selected_scheme
		if not verified:
			push_error("Original death/respawn cycle did not preserve checkpoint/life rules")
	if arguments.has("--verify") and scenario.begins_with("ride-platform"):
		verified = platform_start != null and riding_ticks+airborne_ticks >= tick_count-30 and platform_distance > 0 and unexplained_riding_error == 0 and faults.is_empty() and actor.vm.fault == ""
		if scenario == "ride-platform-jump":
			verified = verified and airborne_ticks > 0 and airborne_owner_flag_ticks == 0 and platform_jump_peak != null and float(platform_jump_peak)-float(platform_jump_start) > 0.3 and (actor.secondary_flags&2) != 0 and int(actor.source_ground.get("actor",-1)) == int(target.source_pool_id)
		if not verified:
			push_error("Imported platform carry differs from motion plus original animation displacement")
	world.queue_free()
	await process_frame
	quit(0 if verified else 1)
