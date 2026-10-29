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
	for x: float in [28,54]:
		for z: float in [-44,-24,-4]:
			for step: int in range(4):
				blood.add_child(BLOOD.make_pool(Vector3(x-1.3+step*.35,.029,z+1+step*1.2),Vector2(.26,.75),float(step)+z)); pool_count+=1
	for z: float in [-100,-95,-87,-72]:
		blood.add_child(BLOOD.make_pool(Vector3(-18,.029,z),Vector2(1.3,.64),z)); pool_count+=1
	var marks := Node3D.new(); marks.set_script(BLOOD); add_child(marks)
	marks.wall_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.roughness = .48
	marks.wall_tool.set_material(mat)
	for side: float in [-1,1]:
		for z: float in [-61,-46,-32,-11,4]:
			for i: int in range(9): marks._wall_streak(side*3.855,rng.randf_range(.6,1.7),z+rng.randf_range(-.6,.6),rng.randf_range(.01,.065),rng.randf_range(.15,.9),side)
	for wall: Vector2 in [Vector2(36.855,1),Vector2(45.145,-1)]:
		for z: float in [-44,-24,-4]:
			marks._wall_streak(wall.x,1.45,z,.12,.23,wall.y)
			for finger: int in range(5): marks._wall_streak(wall.x,1.72,z-.11+finger*.055,.014,.22+finger*.01,wall.y)
			for i: int in range(9): marks._wall_streak(wall.x,rng.randf_range(.2,1.4),z+rng.randf_range(-1,1),.02,rng.randf_range(.25,1.1),wall.y)
	var smear := MeshInstance3D.new(); smear.mesh = marks.wall_tool.commit(); smear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; marks.add_child(smear)
	for data: Array in [[Vector3(-3.84,1.8,-8),PI/2,"ОН НЕ ЛЕЧИТ"],[Vector3(3.84,1.75,-33),-PI/2,"ОБХОД В ТЕМНОТЕ"],[Vector3(-3.84,1.8,-57),PI/2,"НЕ ЛОЖИСЬ НА СТОЛ"],[Vector3(3.84,1.75,-62),-PI/2,"ДОКТОР СЛЫШИТ"],[Vector3(-29.84,1.7,-99),PI/2,"СМЕНА НЕ КОНЧИТСЯ"],[Vector3(29.84,1.7,-86),-PI/2,"НЕ ДАВАЙ ЕМУ ДОПУСК"]]:
		marks._message(data[0],data[1],data[2],.007); message_count += 1
	for data: Array in [[Vector3(36.84,1.9,-43),-PI/2,"НЕ СМОТРИ ПОД ПРОСТЫНЮ"],[Vector3(45.16,1.8,-43),PI/2,"МЫ ЖДАЛИ ЛЕКАРСТВО"],[Vector3(36.84,1.8,-23),-PI/2,"ПОСЛЕДНЯЯ ОПЕРАЦИЯ"],[Vector3(45.16,1.8,-23),PI/2,"ЕГО СМЕНА ВЕЧНА"],[Vector3(36.84,1.8,-3),-PI/2,"НЕ ВЕРЬ ХАЛАТУ"],[Vector3(45.16,1.8,-3),PI/2,"КРОВЬ НЕ ВЫСЫХАЕТ"],[Vector3(-29.84,1.8,-83),PI/2,"ЗАВЕДУЮЩИЙ НЕ СПИТ"],[Vector3(-29.84,1.8,-70),PI/2,"ВЫХОД НЕ ДЛЯ НАС"],[Vector3(29.84,1.8,-98),-PI/2,"НЕ ШЕПЧИ ОН РЯДОМ"],[Vector3(-29.84,1.8,27),PI/2,"ТИШЕ"]]:
		marks._message(data[0],data[1],data[2],.007); message_count+=1
	for data: Array in [[Vector3(28,0,-44),0.0],[Vector3(54,0,-24),0.0],[Vector3(-19,0,-96),PI/2]]:
		var shroud: Node3D=s.ART.model("hospital_shroud"); shroud.position=data[0]; shroud.rotation.y=data[1]; add_child(shroud)
	for at: Vector3 in [Vector3(61.9,0,-36),Vector3(20.1,0,-16),Vector3(-28.9,0,-80)]:
		var curtain: Node3D=s.ART.model("hospital_curtain"); curtain.position=at; curtain.rotation.y=PI/2; add_child(curtain)
		s._prop_collision(at+Vector3.UP*1.2,Vector3(.45,2.4,2.1))
	for at: Vector3 in [Vector3(28,1.055,-44),Vector3(54,1.055,-24),Vector3(28,1.055,-4)]:
		var knife: Node3D = s.ART.model("scalpel"); knife.position = at; knife.rotation.y = .4; add_child(knife)
	for room: Array in s.layout.map_rooms():
		var rect: Rect2 = room[0]
		# The plate is readable at the doorway and uses no emissive lamp.
		var x: float = rect.end.x if rect.get_center().x<0 else rect.position.x
		var z: float = rect.get_center().y
		s.sign_text(room[1],Vector3(x+(.18 if x<0 else -.18),2.25,z+2),PI/2 if x<0 else -PI/2,16)
