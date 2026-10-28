extends Node3D
## Original opaque blood meshes with small light bounds; no physics or extra lights.
var floor_tool := SurfaceTool.new()
var wall_tool := SurfaceTool.new()
var pool_count: int = 0
var message_count: int = 0
var floor_material: StandardMaterial3D

func build() -> void:
	name = "BloodTraces"
	for surface: SurfaceTool in [floor_tool, wall_tool]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = .22 if surface == floor_tool else .85
		mat.metallic_specular = .6
		surface.set_material(mat)
		if surface == floor_tool:
			floor_material = mat
	var rng := RandomNumberGenerator.new()
	rng.seed = 170431
	for data: Array in [[Vector3(1.45, .027, 1.9), Vector2(1.1, .55)], [Vector3(5.3, .027, -.8), Vector2(.7, .44)], [Vector3(10.4, .027, 9.7), Vector2(.9, .55)], [Vector3(-10.4, .027, -7.8), Vector2(.95, .55)], [Vector3(-12.7, .027, 1.1), Vector2(.7, .4)], [Vector3(8.2, .027, -6.8), Vector2(.65, .35)]]:
		_pool(data[0], data[1], rng)
		_flush_floor()
	# Sparse drops lead out of sight, instead of filling every floor tile.
	for i: int in range(25):
		var pos := Vector3(1.3 + sin(i * .42) * .3, .027, 1.8 - i * .23)
		_pool(pos, Vector2(rng.randf_range(.012, .045), rng.randf_range(.02, .07)), rng, false)
	_flush_floor()
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
	for side: float in [-1, 1]:
		for i: int in range(7):
			var z: float = (-4.3 if side < 0 else 4.7) + rng.randf_range(-.5, .5)
			_wall_streak(side * 2.865, rng.randf_range(1.4, 1.65), z, .007, rng.randf_range(.16, .25), side)
	var walls := MeshInstance3D.new()
	walls.mesh = wall_tool.commit()
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(walls)

func _flush_floor() -> void:
	# Small light bounds keep the local flashlight inside Compatibility's light budget.
	var object := MeshInstance3D.new()
	object.mesh = floor_tool.commit()
	object.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(object)
	floor_tool = SurfaceTool.new()
	floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	floor_tool.set_material(floor_material)

func _pool(at: Vector3, radius: Vector2, rng: RandomNumberGenerator, count: bool = true) -> void:
	if count:
		pool_count += 1
	var points: Array[Vector3] = []
	var colors: Array[Color] = []
	for i: int in range(18):
		var angle: float = float(i) / 18.0 * TAU
		var edge: float = rng.randf_range(.78, 1.08)
		points.append(at + Vector3(cos(angle) * radius.x * edge, 0, sin(angle) * radius.y * edge))
		colors.append(Color(.32, .025, .018).darkened(rng.randf_range(0, .08)))
	points.append(points[0])
	colors.append(colors[0])
	for i: int in range(18):
		var vertices: Array[Vector3] = [at, points[i], points[i + 1]]
		var shades: Array[Color] = [Color(.20, .011, .008), colors[i], colors[i + 1]]
		for vertex: int in range(3):
			floor_tool.set_color(shades[vertex])
			floor_tool.set_normal(Vector3.UP)
			floor_tool.add_vertex(vertices[vertex])

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
