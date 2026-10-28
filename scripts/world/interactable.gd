extends StaticBody3D
## Visual/collision representation. Authoritative state lives in Station/ItemSystem.
var object_id: String = ""
var kind: String = ""
var title: String = ""
var taken: bool = false
var opened: bool = false
var locked: bool = false
const ART := preload("res://scripts/art/art_factory.gd")
var mesh: Node3D
var collider: CollisionShape3D
var label: Label3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.22, 0.32)
	var color := Color("d8ba70")
	match kind:
		"door": box.size = Vector3(0.16, 2.5, 1.9); color = Color("355251")
		"generator": box.size = Vector3(1.6, 1.2, 1.0); color = Color("5e7154")
		"transmitter": box.size = Vector3(1.5, 1.1, 0.65); color = Color("516e79")
		"power": box.size = Vector3(0.6, 0.9, 0.35); color = Color("bb723c")
		"fuel": box.size = Vector3(0.4, 0.55, 0.25); color = Color("9c4938")
		"cassette": box.size = Vector3(0.32, 0.14, 0.22); color = Color("70a4a7")
		"medkit": color = Color("9dcccc")
		"battery": color = Color("cfb746")
	if kind == "door":
		mesh = Node3D.new()
		mesh.position.z = .95
		var leaf := ART.model(kind)
		leaf.position.z = -.95
		mesh.add_child(leaf)
	else:
		mesh = ART.model(kind)
		if kind in ["generator", "transmitter", "power"]:
			mesh.rotation.y = PI
	add_child(mesh)
	collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collider.shape = shape
	add_child(collider)
	label = Label3D.new()
	label.text = title
	label.position.y = box.size.y * 0.5 + 0.2
	label.font_size = 23
	label.pixel_size = 0.0035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("b9ccc2")
	label.visibility_range_end = 3.2
	add_child(label)
	if kind in ["generator", "power", "transmitter"]:
		label.hide()
	if kind == "door":
		# The wall switch stays targetable while the actual door collision is open.
		var switch := StaticBody3D.new()
		switch.collision_layer = 4
		switch.collision_mask = 0
		switch.set_meta("door_switch", true)
		switch.position = Vector3(0.0, 0.15, 1.1)
		add_child(switch)
		var button_mesh := ART.model("power")
		button_mesh.scale = Vector3.ONE * .32
		button_mesh.rotation.y = signf(position.x) * PI / 2
		switch.add_child(button_mesh)
		var button_shape := CollisionShape3D.new()
		var button_collision := BoxShape3D.new()
		button_collision.size = Vector3(.3, .35, .22)
		button_shape.shape = button_collision
		switch.add_child(button_shape)
		label.hide()
	refresh()

func refresh() -> void:
	visible = not taken
	if is_instance_valid(collider):
		collider.set_deferred("disabled", taken)
	if is_instance_valid(mesh) and kind == "door":
		mesh.rotation.y = -signf(position.x) * PI / 2 if opened else 0.0
		collider.rotation.y = mesh.rotation.y
		collider.position = mesh.position + Basis(Vector3.UP, mesh.rotation.y) * Vector3(0, 0, -.95)
	if is_instance_valid(label) and kind == "door":
		label.text = ("[E] Закрыть" if opened else "[E] Открыть") + (" • нужен ключ" if locked else "")
