extends Node3D
## Sparse storm, hanging work lights, oil slicks and physical forestry detail.
var station: Node3D
var rain: MultiMeshInstance3D
var clock: float=0
var seeds: Array[Vector3]=[]
func build(world: Node3D,blood: Node3D) -> void:
	station=world;name="ForestDressing"
	for at: Vector3 in [Vector3(40,.028,-30),Vector3(-48,.028,-84),Vector3(0,.028,-46),Vector3(42,.028,55)]:blood.add_child(preload("res://scripts/art/blood_traces.gd").make_pool(at,Vector2(1.1,.5),at.z))
	for data: Array in [["НЕ СЧИТАЙ ДЕРЕВЬЯ",Vector3(40,1.7,-42.82)],["МАСТЕР НЕ ЗАКОНЧИЛ СМЕНУ",Vector3(42,1.7,35.18)],["В ЛЕС УШЛО ДВЕНАДЦАТЬ. ВЕРНУЛОСЬ ТРИНАДЦАТЬ.",Vector3(-16,1.8,14.18)]]:
		station.sign_text(data[0],data[1],0,21)
	# Flooded cutting, outside the raised pump-house footprint; it cannot strand quest items.
	var water:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(16,9);water.mesh=plane;water.position=Vector3(-23,.009,-89)
	var wet:=StandardMaterial3D.new();wet.albedo_color=Color("101d1a");wet.metallic=.25;wet.roughness=.16;water.material_override=wet;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(water)
	for i: int in range(8):
		var at:=Vector3(-30+i*2,.035,-83);station.block(at,Vector3(1.85,.07,.65),"333e2c",false)
	# A sagging cable visibly links the source to the winch. No suspended loose props.
	var previous:=Vector3(-12,3.1,19)
	for i: int in range(1,25):
		var t: float=float(i)/24;var at:=Vector3(lerpf(-12,-40,t),3.1-sin(t*PI)*.6,lerpf(19,-20,t))
		var cable: Node3D=station.block((previous+at)*.5,Vector3(.025,.025,previous.distance_to(at)+.015),"131a17",false)
		cable.look_at(at);previous=at
	var needle:=BoxMesh.new();needle.size=Vector3(.006,.25,.006)
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.26,.34,.36);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;needle.material=material
	rain=MultiMeshInstance3D.new();var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=needle;multi.instance_count=90;rain.multimesh=multi;rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(rain)
	var rng:=RandomNumberGenerator.new();rng.seed=731
	for i: int in range(90):seeds.append(Vector3(rng.randf_range(-11,11),rng.randf_range(0,8),rng.randf_range(-11,11)))
func _process(delta: float) -> void:
	if not is_instance_valid(GameManager.local_player()) or not rain:return
	clock+=delta;var p: Node3D=GameManager.local_player();rain.position=Vector3(p.position.x,0,p.position.z)
	var indoors: bool=false
	for rect: Rect2 in station.layout.ROOFS:
		if rect.has_point(Vector2(p.position.x,p.position.z)):indoors=true;break
	rain.visible=not indoors;rain.multimesh.visible_instance_count=40 if SettingsManager.quality==0 else 90
	if not rain.visible:return
	for i: int in range(rain.multimesh.visible_instance_count):
		var at: Vector3=seeds[i];at.y=fposmod(at.y-clock*8,8);at.x+=sin(clock*.7)*.4;rain.multimesh.set_instance_transform(i,Transform3D(Basis(),at))
