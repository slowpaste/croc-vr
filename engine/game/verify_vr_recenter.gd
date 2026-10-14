extends SceneTree
class Backend extends RefCounted:
	signal pose_recentered
class World extends "res://imported_main.gd":
	var centers:=0
	func _ready() -> void:pass
	func center_stage_tracking() -> void:
		centers+=1
		head.position=Vector3(0,head.position.y,0)
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world:=World.new();root.add_child(world)
	world.actor=CharacterBody3D.new();world.add_child(world.actor);world.actor.position=Vector3(3,2,4)
	world.rig=XROrigin3D.new();world.add_child(world.rig)
	world.head=XRCamera3D.new();world.rig.add_child(world.head)
	world.head.position=Vector3(0.8,1.65,-0.4);world.xr_active=true;world.yaw=0.7
	world.vr_camera_anchor=world.actor.position;world.vr_camera_anchor_initialized=true
	world.vr_head_collision_overlay=preload("res://source_fade_overlay.gd").new();world.head.add_child(world.vr_head_collision_overlay)
	world.vr_head_collision_fade=255;world.vr_head_collision_overlapping=true
	world.vr_head_collision_overlay.set_source_level(255)
	var original_actor:=world.actor.transform;var original_rig:=world.rig.transform
	var backend:=Backend.new();world.connect_vr_recenter(backend);world.connect_vr_recenter(backend)
	assert(backend.get_signal_connection_list("pose_recentered").size()==1)
	backend.pose_recentered.emit();await process_frame
	assert(world.centers==1 and world.vr_recenter_count==1 and not world.vr_initial_center_pending)
	assert(world.head.position==Vector3(0,1.65,0))
	assert(world.actor.transform==original_actor and world.rig.transform==original_rig and world.yaw==0.7)
	assert(not world.vr_head_collision_overlapping and world.vr_head_collision_fade==0 and not world.vr_head_collision_overlay.visible)
	assert(world.source_resume_input_baseline_pending)
	world.vr_head_collision_fade=128;world.vr_head_collision_overlapping=true
	XRServer.reference_frame_changed.emit();await process_frame
	assert(world.vr_head_collision_fade==0 and not world.vr_head_collision_overlapping and world.centers==1)
	world.recenter_vr_view();assert(world.centers==2)
	# Startup waits for a valid tracked pose and centers only once.
	world.vr_initial_center_pending=true;world.center_initial_vr_pose();assert(world.centers==2)
	var tracker:=XRPositionalTracker.new();tracker.type=XRServer.TRACKER_HEAD;tracker.name="head"
	tracker.set_pose("default",Transform3D(Basis.IDENTITY,Vector3(0.8,1.65,-0.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	XRServer.add_tracker(tracker)
	world.center_initial_vr_pose();assert(world.centers==3 and not world.vr_initial_center_pending)
	world.center_initial_vr_pose();assert(world.centers==3)
	XRServer.remove_tracker(tracker)
	world.queue_free();await process_frame
	print("PASS: headset recenter signal, no duplicate handlers, floor height/player/orbit preservation, blackout reset and reference-frame changes")
	quit()
