extends Node
## Distance-based gait: opposite arms, articulated knees/ankles, planted stance and view arms.
var actor: CharacterBody3D
var skeleton: Skeleton3D
var bones: Dictionary = {}
var base_positions: Dictionary = {}
var base_rotations: Dictionary = {}
var phase: float = 0
var blend: float = 0
var lean: float = 0
var view_root: Node3D
var left_hand: Node3D
var left_sleeve: MeshInstance3D
var right_sleeve: MeshInstance3D
var last_yaw: float = 0

func _ready() -> void:
	var found: Array[Node] = actor.body_mesh.find_children("*","Skeleton3D",true,false)
	if not found.is_empty():
		skeleton = found[0]
		for i: int in range(skeleton.get_bone_count()):
			var key: String = skeleton.get_bone_name(i)
			bones[key] = i
			base_positions[key] = skeleton.get_bone_pose_position(i)
			base_rotations[key] = skeleton.get_bone_pose_rotation(i)
	if not actor.is_local(): return
	for part: Node3D in actor.body_mesh.find_children("*","MeshInstance3D",true,false):
		if str(part.name).begins_with("SelfHead") or str(part.name).begins_with("SelfArm") or str(part.name) in ["Jacket","Pack","Chest panel","Belt","Pelvis"]: part.hide()
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view_root = Node3D.new(); view_root.name = "ViewArms"
	actor.camera.add_child(view_root)
	var originals: Array[Node] = actor.camera.get_children()
	for node: Node in originals:
		if node is Node3D and node != view_root:
			node.reparent(view_root)
			if str(node.name) == "Hand": node.position = Vector3(.24,-.24,-.36)
	left_hand = preload("res://scripts/art/art_factory.gd").model("hand")
	left_hand.position = Vector3(-.25,-.28,-.42)
	left_hand.rotation.z = PI
	view_root.add_child(left_hand)
	left_sleeve = sleeve(); right_sleeve = sleeve()
	view_root.add_child(left_sleeve); view_root.add_child(right_sleeve)
	for part: Node3D in view_root.find_children("*","MeshInstance3D",true,false): part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func sleeve() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .055; cylinder.bottom_radius = .075; cylinder.height = 1
	cylinder.radial_segments = 12
	mesh.mesh = cylinder
	var material := StandardMaterial3D.new(); material.albedo_color = Color("303c35"); material.roughness = .95
	mesh.material_override = material
	return mesh

func rotate_bone(key: String,angles: Vector3) -> void:
	if skeleton and bones.has(key): skeleton.set_bone_pose_rotation(int(bones[key]),base_rotations[key]*Quaternion.from_euler(angles))

func _process(delta: float) -> void:
	var speed: float = actor.motion_speed if actor.health > 0 and not actor.in_vehicle and actor.vent_time <= 0 else 0.0
	blend = move_toward(blend,1.0 if speed > .15 else 0.0,delta*7)
	var running: bool = actor.running_motion and speed > 3.0
	phase += speed/(1.3 if actor.crouched else (2.25 if running else 2.0))*TAU*delta
	var swing: float = sin(phase)*blend
	lean = lerpf(lean,.2 if running else (.12 if actor.crouched else 0.0),minf(1,delta*8))
	rotate_bone("Spine",Vector3(-lean,0,sin(phase)*blend*.025))
	rotate_bone("Chest",Vector3(0,sin(phase)*blend*.045,0))
	for side: String in ["L","R"]:
		var wave: float = swing*(1 if side == "L" else -1)
		var thigh: float = wave*(.2 if actor.crouched else (.88 if running else .46))-(.95 if actor.crouched else 0.0)
		var knee: float = maxf(0,-wave)*(.25 if actor.crouched else (1.25 if running else .7))+(1.9 if actor.crouched else .04)
		rotate_bone("Thigh_"+side,Vector3(thigh,0,0))
		rotate_bone("Shin_"+side,Vector3(knee,0,0))
		rotate_bone("Foot_"+side,Vector3(-knee*.5-thigh*.3,0,0))
		rotate_bone("UpperArm_"+side,Vector3(-wave*(.75 if running else .36)-(.25 if actor.role == "hunter" else 0),0,0))
		rotate_bone("Forearm_"+side,Vector3(-1.25 if running else (-.9 if actor.role == "hunter" else -.25),0,0))
	var pelvis_drop: float = -.32 if actor.crouched else (absf(sin(phase))*blend*.025 if running else -(1-cos(swing*.46))*.73)
	if skeleton and bones.has("Hips"): skeleton.set_bone_pose_position(int(bones.Hips),base_positions.Hips+Vector3(0,pelvis_drop,0))
	if not is_instance_valid(view_root): return
	view_root.visible = actor.health > 0 and actor.vent_time <= 0 and not actor.in_vehicle
	var yaw_delta: float = angle_difference(last_yaw,actor.local_aim.x)
	last_yaw = actor.local_aim.x
	var panic: float = clampf((actor.stress-60)/40,0,1)
	var shake: float = sin(Time.get_ticks_msec()*.031)*panic*.003
	view_root.position = Vector3(swing*(.023 if running else .01)+shake,absf(cos(phase))*blend*(-.045 if running else -.015),0)
	view_root.rotation = Vector3(lean*.15,clampf(-yaw_delta*2,-.09,.09),swing*(.045 if running else .015))
	actor.camera.position.y = absf(sin(phase))*blend*(.025 if running else .01)
	actor.camera.rotation.z = .18*actor.fall_amount+swing*blend*.006
	var wrist: Vector3 = Vector3(-.25,-.28,-.42)+Vector3(0,-wave_value(swing,running),swing*.07*blend)
	if actor.role == "hunter": wrist = Vector3(-.12,-.32,-.5)
	left_hand.position = wrist
	place_sleeve(left_sleeve,Vector3(-.32,-.52,-.04),wrist)
	place_sleeve(right_sleeve,Vector3(.32,-.52,-.04),Vector3(.24,-.24,-.36))

func wave_value(wave: float,running: bool) -> float:
	return maxf(0,wave)*(.06 if running else .015)

func place_sleeve(mesh: MeshInstance3D,a: Vector3,b: Vector3) -> void:
	mesh.position = (a+b)*.5
	mesh.scale.y = a.distance_to(b)
	mesh.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
