extends RefCounted
## Shared imported meshes and materials. All assets are authored in this project.
static var models: Dictionary = {}
static var surfaces: Dictionary = {}
static var worn_materials: Dictionary = {}

static func model(kind: String) -> Node3D:
	if not models.has(kind):
		models[kind] = load("res://assets/models/%s.glb" % kind)
	var packed: PackedScene = models[kind]
	var node: Node3D = packed.instantiate()
	node.name = kind.capitalize()
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		for index: int in range(child.mesh.get_surface_count()):
			var original: StandardMaterial3D = child.mesh.surface_get_material(index)
			if original and original.resource_name in ["muscle", "muscle_dark", "tendon"]:
				var flesh_key: String = "flesh_" + original.resource_name
				if not worn_materials.has(flesh_key):
					var flesh := ShaderMaterial.new()
					flesh.shader = preload("res://assets/shaders/flesh.gdshader")
					flesh.set_shader_parameter("tint", original.albedo_color)
					flesh.set_shader_parameter("detail", 1.0 if SettingsManager.quality > 0 else 0.0)
					worn_materials[flesh_key] = flesh
				child.set_surface_override_material(index, worn_materials[flesh_key])
			if original and original.resource_name in ["enamel", "steel", "rust", "cream", "wood", "fabric", "red"]:
				var key: String = original.resource_name
				if not worn_materials.has(key):
					var worn: StandardMaterial3D = original.duplicate()
					var texture_name: String = key if key in ["wood", "fabric"] else "metal_wear"
					worn.albedo_texture = load("res://assets/textures/%s.png" % texture_name)
					worn.normal_enabled = SettingsManager.quality > 0
					worn.normal_texture = load("res://assets/textures/%s_normal.png" % texture_name)
					worn.normal_scale = .45
					worn.uv1_triplanar = true
					worn.uv1_scale = Vector3.ONE * 2.0
					worn_materials[key] = worn
				child.set_surface_override_material(index, worn_materials[key])
	return node

static func surface(kind: String) -> StandardMaterial3D:
	if surfaces.has(kind):
		return surfaces[kind]
	var result := StandardMaterial3D.new()
	result.albedo_texture = load("res://assets/textures/%s.png" % kind)
	result.roughness = 0.88
	result.roughness_texture = load("res://assets/textures/%s_roughness.png" % kind) if SettingsManager.quality > 0 else null
	result.normal_enabled = SettingsManager.quality > 0
	result.normal_texture = load("res://assets/textures/%s_normal.png" % kind)
	result.normal_scale = .65 if kind == "floor" else .45
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_scale = Vector3.ONE * (0.25 if kind == "floor" else 0.4)
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	surfaces[kind] = result
	return result

static func apply_quality() -> void:
	for kind: String in surfaces:
		surfaces[kind].normal_enabled = SettingsManager.quality > 0
		surfaces[kind].roughness_texture = load("res://assets/textures/%s_roughness.png" % kind) if SettingsManager.quality > 0 else null
	for material: Material in worn_materials.values():
		if material is ShaderMaterial:
			material.set_shader_parameter("detail", 1.0 if SettingsManager.quality > 0 else 0.0)
		else:
			material.normal_enabled = SettingsManager.quality > 0

static func contact_shadow(parent: Node3D, at: Vector3, size: Vector2) -> Node3D:
	var shadow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	shadow.mesh = plane
	shadow.position = at + Vector3.UP * .021
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/contact_shadow.gdshader")
	shadow.material_override = material
	parent.add_child(shadow)
	return shadow
