extends Node3D
## Bounded instanced boot impressions: alternating feet, tread, aging and blood transfer.
var stamps: MultiMeshInstance3D
var born: Array[float] = []
var lifetime: Array[float] = []
var shades: Array[Color] = []
var count: int = 160
var cursor: int = 0
var clock: float = 0.0
var total_stamps: int = 0

func _ready() -> void:
	name = "Footprints"
	stamps = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(.18, .33)
	mm.mesh = plane
	mm.instance_count = count
	stamps.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/footprint.gdshader")
	mat.set_shader_parameter("stamp", load("res://assets/textures/decals/bootprint.png"))
	stamps.material_override = mat
	stamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stamps)
	for i: int in range(count):
		born.append(-1000)
		lifetime.append(0)
		shades.append(Color.TRANSPARENT)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0,-20,0)))
	# Evidence trails, laid out with plausible heel-to-toe spacing, not dots.
	for i: int in range(15):
		stamp(Vector3(1.35+sin(i*.22)*.18, .034, 1.5-i*.45), .03, i%2 == 0, true, 1800)
	for i: int in range(12):
		stamp(Vector3(-48+i*.44, .034, -32.3), -PI/2, i%2 == 0, false, 1800)

func stamp(at: Vector3, yaw: float, left: bool, bloody: bool, duration: float = 75) -> void:
	var index: int = cursor%count
	cursor += 1
	total_stamps += 1
	var angle: float = yaw+(.065 if left else -.065)
	var basis := Basis(Vector3.UP, angle)
	at += basis*Vector3(-.11 if left else .11, 0, 0)
	stamps.multimesh.set_instance_transform(index, Transform3D(basis, at))
	shades[index] = Color(.16,.012,.008,.85) if bloody else Color(.055,.045,.03,.65)
	if not left: shades[index].a = -shades[index].a
	stamps.multimesh.set_instance_custom_data(index, shades[index])
	born[index] = Time.get_ticks_msec()*.001
	lifetime[index] = duration

func _process(delta: float) -> void:
	clock -= delta
	if clock > 0: return
	clock = .25
	var now: float = Time.get_ticks_msec()*.001
	for i: int in range(count):
		if lifetime[i] <= 0: continue
		var remaining: float = 1.0-(now-born[i])/lifetime[i]
		var shade: Color = shades[i]
		shade.a *= clampf(remaining*4,0,1)
		stamps.multimesh.set_instance_custom_data(i, shade)
		if remaining <= 0: lifetime[i] = 0
