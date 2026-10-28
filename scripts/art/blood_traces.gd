extends Node3D
## Original opaque blood meshes with small light bounds; no physics or extra lights.
var wall_tool := SurfaceTool.new()
var pool_count: int = 0
var message_count: int = 0

func build() -> void:
	name = "BloodTraces"
	wall_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = .85
	wall_tool.set_material(mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 170431
	for data: Array in [[Vector3(1.45, .027, 1.9), Vector2(1.1, .55)], [Vector3(5.3, .027, -.8), Vector2(.7, .44)], [Vector3(10.4, .027, 9.7), Vector2(.9, .55)], [Vector3(-10.4, .027, -7.8), Vector2(.95, .55)], [Vector3(-12.7, .027, 1.1), Vector2(.7, .4)], [Vector3(8.2, .027, -6.8), Vector2(.65, .35)]]:
		_pool(data[0], data[1], rng)
	for data: Array in [[Vector3(9, .027, -20.4), Vector2(.9, .4)], [Vector3(-8.2, .027, -35.4), Vector2(.65, .4)], [Vector3(-10.9, .027, -43.4), Vector2(1.1, .55)], [Vector3(8.2, .027, -46.4), Vector2(1, .45)]]:
		_pool(data[0], data[1], rng)
	# Sparse drops lead out of sight, instead of filling every floor tile.
	for i: int in range(25):
		var pos := Vector3(1.3 + sin(i * .42) * .3, .027, 1.8 - i * .23)
		_pool(pos, Vector2(rng.randf_range(.012, .045), rng.randf_range(.02, .07)), rng, false)
	for side: float in [-1, 1]:
		var x: float = side * 2.865
		var z: float = 4.7 if side < 0 else -4.2
		for i: int in range(12):
			var y: float = 1.45 + rng.randf_range(-.2, .35)
			var zz: float = z + rng.randf_range(-.2, .2)
			_wall_streak(x, y, zz, rng.randf_range(.015, .055), rng.randf_range(.18, .65), side)
		# Palm and five finger smears on each side wall.
		_wall_streak(x, 1.75, z, .13, .18, side)
		for finger: int in range(5):
			_wall_streak(x, 1.92 + sin(finger * .7) * .04, z - .11 + finger * .055, .014, .18 + sin(finger) * .035, side)
	_message(Vector3(-2.853, 1.9, -4.3), PI / 2, "ОН СЛЫШИТ", .008)
	_message(Vector3(2.853, 1.82, 4.7), -PI / 2, "НЕ БЕГИ", .009)
	_message(Vector3(-9.5, 1.4, -12.7), 0, "МЫ НЕ ОДНИ", .008)
	_message(Vector3(2.853, 1.8, -27.5), -PI/2, "ОН НЕ УМЕР", .008)
	for side: float in [-1, 1]:
		for i: int in range(7):
			var z: float = (-4.3 if side < 0 else 4.7) + rng.randf_range(-.5, .5)
			_wall_streak(side * 2.865, rng.randf_range(1.4, 1.65), z, .007, rng.randf_range(.16, .25), side)
	var walls := MeshInstance3D.new()
	walls.mesh = wall_tool.commit()
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(walls)

static func make_pool(at: Vector3, radius: Vector2, seed_value: float = 1.0) -> MeshInstance3D:
	var object := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = radius * 2.25
	object.mesh = plane
	object.position = at
	object.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/blood_pool.gdshader")
	mat.set_shader_parameter("seed", seed_value)
	object.material_override = mat
	return object

func _pool(at: Vector3, radius: Vector2, rng: RandomNumberGenerator, count: bool = true) -> void:
	if count:
		pool_count += 1
	var object := make_pool(at, radius, rng.randf_range(0, 100))
	object.rotation.y = rng.randf_range(-PI, PI)
	add_child(object)

func _wall_streak(x: float, y: float, z: float, width: float, length: float, side: float) -> void:
	var points: Array[Vector3] = [Vector3(x, y, z - width), Vector3(x, y + length, z - width * .6), Vector3(x, y + length * .9, z + width), Vector3(x, y - .05, z + width * .2)]
	var indices: Array = [0, 2, 1, 0, 3, 2] if side < 0 else [0, 1, 2, 0, 2, 3]
	for index: int in indices:
		wall_tool.set_color(Color("4d100c"))
		wall_tool.set_normal(Vector3(-side, 0, 0))
		wall_tool.add_vertex(points[index])

func _message(at: Vector3, yaw: float, text: String, pixel: float) -> void:
	var label := Label3D.new()
	var handwriting := SystemFont.new()
	handwriting.font_names = PackedStringArray(["Segoe Print", "Comic Sans MS", "cursive"])
	label.font = handwriting
	label.text = text
	label.position = at
	label.rotation = Vector3(0, yaw, -.025)
	label.font_size = 42
	label.pixel_size = pixel
	label.modulate = Color("681b13")
	label.outline_size = 0
	label.shaded = true
	add_child(label)
	message_count += 1
