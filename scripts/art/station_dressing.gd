extends Node3D
## Batched wear and small props; no gameplay colliders or network state.
const ART := preload("res://scripts/art/art_factory.gd")
var station: Node3D
var geometry := SurfaceTool.new()
var fan_rotor: Node3D
var screens: ShaderMaterial
var moon_lights: Array[SpotLight3D] = []
var paper_count: int = 0

func build(world: Node3D) -> void:
	station = world
	name = "StationDressing"
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = .98
	geometry.set_material(mat)
	_weather()
	_equipment()
	var detail := MeshInstance3D.new()
	detail.name = "BatchedWearAndPapers"
	detail.mesh = geometry.commit()
	add_child(detail)
	SettingsManager.changed.connect(_quality)
	_quality()

func _quad(points: Array[Vector3], color: Color, normal: Vector3) -> void:
	# Godot's front faces use clockwise winding, even with explicit normals.
	var flip: bool = (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0
	var indices: Array = [0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]
	for index: int in indices:
		geometry.set_color(color)
		geometry.set_normal(normal)
		geometry.add_vertex(points[index])

func _weather() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 171741
	# Irregular paint losses lie flush with the wall and share one mesh/material.
	for side: float in [-1, 1]:
		for center: float in [-11, -4, 4, 11]:
			for chip: int in range(13):
				var z: float = center + rng.randf_range(-1.3, 1.3)
				var y: float = rng.randf_range(.15, 1.12)
				var h: float = rng.randf_range(.025, .19)
				var w: float = rng.randf_range(.025, .18)
				var x: float = side * 2.872
				_quad([Vector3(x, y, z - w), Vector3(x, y + h, z - w * .6), Vector3(x, y + h * .7, z + w), Vector3(x, y - h * .1, z + w * .7)], Color("716f5a") * rng.randf_range(.7, 1.0), Vector3(-side, 0, 0))
			for drip: int in range(5):
				var z: float = center + rng.randf_range(-1.0, 1.0)
				var length: float = rng.randf_range(.18, .6)
				var x: float = side * 2.882
				_quad([Vector3(x, 2.9, z), Vector3(x, 2.9, z + .07), Vector3(x, 2.9 - length, z + .025), Vector3(x, 2.9 - length * .8, z + .008)], Color("4e5141"), Vector3(-side, 0, 0))
	# Faded papers are clustered beside walls, keeping the main route readable.
	for center: Vector3 in [Vector3(-2.1, 0, 3.8), Vector3(2.1, 0, -4.4), Vector3(11, 0, -9.3), Vector3(-11, 0, -6.5), Vector3(10, 0, 1.2)]:
		for sheet: int in range(9):
			var pos: Vector3 = center + Vector3(rng.randf_range(-.65, .65), .025 + sheet * .0005, rng.randf_range(-.6, .6))
			var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI))
			var points: Array[Vector3] = []
			for p: Vector3 in [Vector3(-.1, 0, -.15), Vector3(-.1, 0, .15), Vector3(.1, 0, .15), Vector3(.1, 0, -.15)]:
				points.append(pos + basis * p)
			_quad(points, Color("b2a47e") * rng.randf_range(.65, 1.0), Vector3.UP)
			paper_count += 1
			for line: int in range(4):
				var offset: float = -.09 + line * .035
				var ink: Array[Vector3] = []
				for p: Vector3 in [Vector3(-.07, .001, offset), Vector3(-.07, .001, offset + .006), Vector3(.06, .001, offset + .006), Vector3(.06, .001, offset)]:
					ink.append(pos + basis * p)
				_quad(ink, Color("666651"), Vector3.UP)
	# Broken tiles and scuffs use the same static mesh, without physics bodies.
	for i: int in range(18):
		var pos := Vector3(rng.randf_range(-2.3, 2.3), .018, rng.randf_range(-11, 11))
		var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI))
		var points: Array[Vector3] = []
		for p: Vector3 in [Vector3(-.004, 0, -.14), Vector3(.004, 0, -.14), Vector3(.028, 0, .17), Vector3(.018, 0, .12)]:
			points.append(pos + basis * p)
		_quad(points, Color("17251f"), Vector3.UP)

func _prop(kind: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var object := ART.model(kind)
	object.position = at
	object.rotation.y = yaw
	add_child(object)
	return object

func _equipment() -> void:
	_prop("rotary_phone", Vector3(9.1, 1.06, -10.3), .25)
	_prop("wall_clock", Vector3(0, 2.95, -12.68), PI)
	for x: float in [-11, 11]:
		_prop("radiator", Vector3(x, .02, -12.54), PI)
	_prop("fan_housing", Vector3(-12.8, 2.4, -3.79), PI)
	fan_rotor = _prop("fan_blades", Vector3(-12.8, 2.4, -3.79), PI)
	# Wall noticeboard made from a shared opaque frame and short readable notes.
	station.block(Vector3(2.81, 1.8, 3.9), Vector3(.05, .95, 1.4), "65523b", false)
	station.block(Vector3(2.77, 1.8, 3.9), Vector3(.025, .83, 1.28), "363c2d", false)
	for z: float in [3.5, 3.9, 4.3]:
		station.block(Vector3(2.74, 1.84, z), Vector3(.01, .49, .29), "ae9f7c", false)
	station.sign_text("ОБХОД В 03:17\n\nНЕ ИДТИ ОДНОМУ", Vector3(2.72, 1.84, 3.9), -PI / 2, 7)
	# Soft contact darkening remains available without dynamic shadow maps.
	for data: Array in [[Vector3(-10, 0, 0), Vector2(2.3, 1.5)], [Vector3(10, 0, -8), Vector2(2.1, 1.4)], [Vector3(-11, 0, -10.5), Vector2(3.7, 1.8)], [Vector3(-11, 0, -5.4), Vector2(3.7, 1.8)], [Vector3(11.5, 0, 6.3), Vector2(3, 1.8)], [Vector3(-12, 0, 10.3), Vector2(2.8, 1.4)], [Vector3(-7, 0, 10.3), Vector2(2.8, 1.4)]]:
		ART.contact_shadow(self, data[0], data[1])
	for x: float in [-11, 11]:
		var moon := SpotLight3D.new()
		moon.position = Vector3(x, 2.3, -12.4)
		moon.light_color = Color("799bab")
		moon.light_energy = .7
		moon.spot_range = 7.0
		moon.spot_angle = 24.0
		add_child(moon)
		moon.look_at(Vector3(x - 1.0, .05, -8.5))
		moon_lights.append(moon)
	screens = ShaderMaterial.new()
	screens.shader = preload("res://assets/shaders/crt.gdshader")
	_screen(station.objects.transmitter.mesh, Vector3(0, -.025, -.398), Vector2(1.0, .065))

func _screen(parent: Node3D, pos: Vector3, size: Vector2) -> void:
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	surface.mesh = quad
	surface.position = pos
	surface.rotation.y = PI
	surface.material_override = screens
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(surface)

func _quality() -> void:
	for light: SpotLight3D in moon_lights:
		light.shadow_enabled = SettingsManager.quality == 2

func _process(delta: float) -> void:
	if not is_instance_valid(station) or not NetworkManager.in_match:
		return
	if station.objectives.generator_on:
		fan_rotor.rotation.z += delta * 5.0
	screens.set_shader_parameter("signal_strength", .9 if station.objectives.generator_on else .24)
