extends RefCounted
## Six rooms and an unobstructed central route. South-facing storage remains searchable.
const TITLES := ["ДЕЖУРНАЯ", "ЗАПАСНЫЕ ЧАСТИ", "КОНТАКТОРНАЯ", "МАШИННЫЙ ЗАЛ", "ПРИЁМНИК", "АВАРИЙНЫЙ СКЛАД"]

static func build(s: Node3D) -> void:
	s.block(Vector3(0,-.2,19),Vector3(6,.4,12),"313c3e")
	s.block(Vector3(0,3.4,19),Vector3(6,.2,12),"202c30")
	for x: float in [-3,3]: s.block(Vector3(x,1.6,19),Vector3(.25,3.2,12),"465354")
	s.block(Vector3(0,-.2,46),Vector3(48,.4,42),"313c3e")
	s.block(Vector3(0,3.4,46),Vector3(48,.2,42),"202c30")
	for x: float in [-24,24]: s.block(Vector3(x,1.6,46),Vector3(.3,3.2,42),"465354")
	s.block(Vector3(0,1.6,67),Vector3(48,3.2,.3),"465354")
	for side: float in [-1,1]:
		s.block(Vector3(side*13.5,1.6,25),Vector3(21,3.2,.3),"465354")
		for z: float in [39,53]: s.block(Vector3(side*13.5,1.6,z),Vector3(21,3.2,.25),"475653")
		for row: int in range(3):
			var z: float = 32+row*14
			for sign_z: float in [-1,1]: s.block(Vector3(side*3,1.6,z+sign_z*4.05),Vector3(.25,3.2,5.9),"4c5b58")
			s.door_frame(side*3,z)
			var door: Node3D = s.add_object("door_e_%d_%d" % [int(side),row],"door","Дверь насосного комплекса",Vector3(side*3,1.44,z))
			door.opened = true
			door.refresh()
			var index: int = row*2+(0 if side<0 else 1)
			s.sign_text("E—%02d • " % (index+1)+TITLES[index],Vector3(side*13,2.4,z-6.7),0,27)
			s.LAYOUT._light(s,Vector3(side*13,2.9,z),Color("87a4a0"))
			s.LAYOUT._prop(s,"shelf" if index%2 else "radio_rack",Vector3(side*20,0,z-4),0,Vector3(2.4,1.8,.8))
		if side < 0:
			for z: float in [28,42,56,64]: s.LAYOUT._light(s,Vector3(0,2.9,z),Color("b89469"))
	s.sign_text("СЕКТОР E • ДРЕНАЖНЫЙ КОМПЛЕКС\nОПАСНО: ВОДА ПОД НАПРЯЖЕНИЕМ",Vector3(0,2.7,22),PI,23)
	s.LAYOUT._prop(s,"desk",Vector3(-13,0,29),0,Vector3(2.5,1.05,.85))
	s.LAYOUT._note(s,"drain_note","Журнал запуска насоса",Vector3(-13,1.08,29),"Порядок запуска меняется каждую смену.")
	for i: int in range(4):
		var at: Vector3 = [Vector3(10,1.2,29),Vector3(-10,1.2,43),Vector3(-10,1.2,57),Vector3(10,1.2,57)][i]
		s.add_object("drain_switch_%d" % i,"drain_switch",s.drainage.BUTTONS[i]+" • контактор",at)
		s.block(at-Vector3(0,.65,0),Vector3(.12,1.1,.12),"293e40",false)
	var pump: Node3D = s.add_object("drain_pump","drain_pump","ДРЕНАЖ E • удерживать E",Vector3(5.3,.9,46))
	pump.rotation.y = -PI/2
	for at: Vector3 in [Vector3(14,0,43),Vector3(20,0,48)]: s.LAYOUT._prop(s,"boiler",at,0,Vector3(2,2.8,2))
	var locker: Node3D = s.add_object("drain_reward","locker_container","Аварийный запас • нужен дренаж E",Vector3(20,1.05,62))
	locker.locked = true
	locker.gate_rule = "drainage"
	for i: int in range(2):
		var item: Node3D = s.add_object("drain_supply_%d" % i,"battery" if i == 0 else "medkit","Аварийный запас",locker.position+Vector3(0,-.4+i*.5,.1))
		item.container_id = "drain_reward"
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(19,12)
	water.mesh = plane
	water.position = Vector3(13.5,.087,46)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode blend_mix; void fragment(){ float ripple = sin(UV.x*100.0+TIME*1.3)*sin(UV.y*90.0-TIME); ALBEDO=vec3(.025,.065,.06)+ripple*.008; ROUGHNESS=.2; METALLIC=.35; ALPHA=.83; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	water.material_override = material
	s.add_child(water)
	s.drainage.water = water
