extends Node
const PLACEMENT:=preload("res://scripts/art/prop_placement.gd")
var failures: int=0
func _ready() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if ok:print("MAP_FINISH_CHECK "+label)
	else:failures+=1;push_error("MAP_FINISH_FAIL "+label)
func ray(world: Node3D,from: Vector3,to: Vector3,mask: int,exclude: Array[RID]=[]) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,mask,exclude))
func run() -> void:
	for id: int in range(3):
		NetworkManager.host_room("Map QA",27999);NetworkManager.choose_map(id);NetworkManager.choose_role(2);NetworkManager.start_round(true)
		await get_tree().create_timer(.6).timeout
		var w: Node3D=GameManager.world;w.monster.set_physics_process(false)
		var player: Node3D=GameManager.local_player();player.input_enabled=false
		var roof_samples: int=0
		for rect: Rect2 in w.layout.FLOORS:
			for x: float in [.13,.5,.87]:
				for z: float in [.13,.5,.87]:
					var at:=Vector3(lerpf(rect.position.x,rect.end.x,x),2.6,lerpf(rect.position.y,rect.end.y,z))
					if ray(w,at,at+Vector3.UP*1.3,1).is_empty():check(false,"roof gap map %d at %s" % [id,at])
					roof_samples+=1
		check(roof_samples>=80,"roof coverage sampled over every sector and connector on map "+str(id))
		var supported: int=0
		for object: Node3D in w.objects.values():
			if object.kind not in PLACEMENT.FLOOR_EQUIPMENT and not w.items.NAMES.has(object.kind) and object.kind not in ["note","safe","cage","locker_container"]:continue
			if object.taken:continue
			var box: AABB=PLACEMENT.bounds(object if object.kind in ["safe","cage","locker_container"] else object.mesh)
			var point:=Vector3(box.get_center().x,box.position.y,box.get_center().z)
			var hit: Dictionary=ray(w,point+Vector3.UP*.04,point-Vector3.UP*.06,1|4,[object.get_rid()])
			check(not hit.is_empty(),"physical support map %d: %s at %s" % [id,object.object_id,point])
			supported+=1
		check(supported>15,"furniture, containers and equipment share supported placements on map "+str(id))
		for model: Node3D in w.find_children("*","Node3D",true,false):
			if model.get_meta("art_kind","") not in PLACEMENT.FLOOR_PROPS or model.get_parent() is StaticBody3D:continue
			var box: AABB=PLACEMENT.bounds(model)
			check(absf(box.position.y-w.support_height(model.global_position))<.015,"scenery rests on a surface: "+str(model.get_meta("art_kind")))
		check(w.environment.fog_light_color.srgb_to_linear().get_luminance()<.01,"distant fog cannot become a blue sky on map "+str(id))
		if id==1:
			var gate: Node3D=w.objects.exit_gate
			check(not ray(w,Vector3(.75,1.2,29),Vector3(.75,1.2,31),5).is_empty(),"closed garage shutter blocks the car lane")
			check(ray(w,Vector3(-3.1,1.2,29),Vector3(-3.1,1.2,31),5).is_empty(),"marked pedestrian passage stays physically clear")
			check(w.find_path(Vector3(-3.1,0,28),Vector3(-3.1,0,34)).size()>1,"guard dormitory remains reachable before the car is ready")
			gate.opened=true;gate.refresh();w._update_doors_navigation();await get_tree().physics_frame
			check(ray(w,Vector3(.75,1.2,29),Vector3(.75,1.2,31),5).is_empty(),"raised shutter clears the departure lane")
		player.motion_speed=5;player.running_motion=true;player.motion.phase=PI/2;player.motion.blend=1
		player.motion._process(.001);player.motion.skeleton.force_update_all_bone_transforms()
		var lowest_ankle: float=INF
		for side: String in ["L","R"]:
			var s: Skeleton3D=player.motion.skeleton
			var elbow: Vector3=s.get_bone_global_pose(s.find_bone("Forearm_"+side)).origin
			var hand: Vector3=s.get_bone_global_pose(s.find_bone("Hand_"+side)).origin
			check(hand.z<elbow.z-.035,"running elbow bends toward the front: "+side)
			lowest_ankle=minf(lowest_ankle,s.get_bone_global_pose(s.find_bone("Foot_"+side)).origin.y)
		check(absf(lowest_ankle-player.motion.ankle_height)<.015,"running stance foot stays at the ground instead of lifting the whole body")
		check(absf(player.motion.left_hand.rotation.z)<.01,"first-person left hand is not inverted")
		var hand_model: Node3D=player.motion.left_hand
		check(hand_model.find_children("*","MeshInstance3D",true,false)[0].get_aabb().size.z<.20,"glove has no camera-facing sleeve endcap")
		NetworkManager.leave();await get_tree().process_frame;await get_tree().process_frame
	print("MAP_FINISH_PASS" if failures==0 else "MAP_FINISH_FAIL %d" % failures);get_tree().quit(0 if failures==0 else 1)
