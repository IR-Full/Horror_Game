extends RefCounted
## Shared imported meshes and materials. All assets are authored in this project.
static var models: Dictionary = {}
static var surfaces: Dictionary = {}

static func model(kind: String) -> Node3D:
	if not models.has(kind):
		models[kind] = load("res://assets/models/%s.glb" % kind)
	var packed: PackedScene = models[kind]
	var node: Node3D = packed.instantiate()
	node.name = kind.capitalize()
	return node

static func surface(kind: String) -> StandardMaterial3D:
	if surfaces.has(kind):
		return surfaces[kind]
	var result := StandardMaterial3D.new()
	result.albedo_texture = load("res://assets/textures/%s.png" % kind)
	result.roughness = 0.88
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_scale = Vector3.ONE * (0.25 if kind == "floor" else 0.4)
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	surfaces[kind] = result
	return result
