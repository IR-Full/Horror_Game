extends Node3D
## Opaque world-space blood, restrained lamp failure, authored surgical props.
const BLOOD := preload("res://scripts/art/blood_traces.gd")
var pool_count: int = 0
var message_count: int = 0
func build(s: Node3D,blood: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 13011
	# Pools are offset from walls to avoid coplanar stripes under flashlight shadows.
	for side: float in [-1,1]:
		for row: int in range(3):
			for edge: float in [-1,1]:
				var at := Vector3(side*41+edge*13,.028,-44+row*20)
				for offset: Vector3 in [Vector3(2,0,0),Vector3(-1,0,3),Vector3(0,0,-2)]:
					var pool: MeshInstance3D = BLOOD.make_pool(at+offset,Vector2(rng.randf_range(.6,1.35),rng.randf_range(.4,.85)),rng.randf_range(0,100))
					blood.add_child(pool); pool_count += 1
		for z: float in [-98,-85,-72,25,41,57]:
			blood.add_child(BLOOD.make_pool(Vector3(side*15,.028,z),Vector2(.8,.5),rng.randf_range(0,100))); pool_count += 1
	for z: float in [-101,-83,-59,-42,-15,1,23,48]:
		blood.add_child(BLOOD.make_pool(Vector3(sin(z)*.9,.028,z),Vector2(.7,.4),z)); pool_count += 1
	var marks := Node3D.new(); marks.set_script(BLOOD); add_child(marks)
	marks.wall_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.roughness = .48
	marks.wall_tool.set_material(mat)
	for side: float in [-1,1]:
		for z: float in [-61,-46,-32,-11,4]:
			for i: int in range(9): marks._wall_streak(side*3.855,rng.randf_range(.6,1.7),z+rng.randf_range(-.6,.6),rng.randf_range(.01,.065),rng.randf_range(.15,.9),side)
	var smear := MeshInstance3D.new(); smear.mesh = marks.wall_tool.commit(); smear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; marks.add_child(smear)
	for data: Array in [[Vector3(-3.84,1.8,-8),PI/2,"ОН НЕ ЛЕЧИТ"],[Vector3(3.84,1.75,-33),-PI/2,"ОБХОД В ТЕМНОТЕ"],[Vector3(-3.84,1.8,-57),PI/2,"НЕ ЛОЖИСЬ НА СТОЛ"],[Vector3(3.84,1.75,-62),-PI/2,"ДОКТОР СЛЫШИТ"],[Vector3(-29.84,1.7,-99),PI/2,"СМЕНА НЕ КОНЧИТСЯ"],[Vector3(29.84,1.7,-86),-PI/2,"НЕ ДАВАЙ ЕМУ ДОПУСК"]]:
		marks._message(data[0],data[1],data[2],.007); message_count += 1
	for at: Vector3 in [Vector3(28,1.055,-44),Vector3(54,1.055,-24),Vector3(28,1.055,-4)]:
		var knife: Node3D = s.ART.model("scalpel"); knife.position = at; knife.rotation.y = .4; add_child(knife)
	for room: Array in s.layout.map_rooms():
		var rect: Rect2 = room[0]
		# The plate is readable at the doorway and uses no emissive lamp.
		var x: float = rect.end.x if rect.get_center().x<0 else rect.position.x
		var z: float = rect.get_center().y
		s.sign_text(room[1],Vector3(x+(.18 if x<0 else -.18),2.25,z+2),PI/2 if x<0 else -PI/2,16)
