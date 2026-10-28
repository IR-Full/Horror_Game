extends Node3D
## A local first-person duct sequence; the server owns travel duration/destination.
var actor: Node3D
var view: Camera3D
var active: bool = false
var hands: Array[Node3D] = []
var tunnel: Node3D

func _ready() -> void:
	tunnel = Node3D.new()
	tunnel.position = Vector3(2000,-50,2000)
	top_level = true
	add_child(tunnel)
	var metal: StandardMaterial3D = preload("res://scripts/art/art_factory.gd").surface("metal_wear").duplicate()
	metal.albedo_color = Color(.23,.26,.25)
	for spec: Array in [[Vector3(0,0,-4),Vector3(1.3,.04,10)], [Vector3(0,.95,-4),Vector3(1.3,.04,10)], [Vector3(-.65,.47,-4),Vector3(.04,.95,10)], [Vector3(.65,.47,-4),Vector3(.04,.95,10)]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[1]
		mesh.mesh = box
		mesh.position = spec[0]
		mesh.material_override = metal
		tunnel.add_child(mesh)
	for i: int in range(18):
		for x: float in [-.62,.62]:
			var rib := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(.05,.92,.045)
			rib.mesh = box
			rib.position = Vector3(x,.47,.5-i*.5)
			rib.material_override = metal
			tunnel.add_child(rib)
	var end := MeshInstance3D.new()
	var end_box := BoxMesh.new()
	end_box.size = Vector3(1.3,.95,.05)
	end.mesh = end_box
	end.position = Vector3(0,.47,-9.1)
	end.material_override = metal
	tunnel.add_child(end)
	view = Camera3D.new()
	view.fov = 66
	view.near = .025
	tunnel.add_child(view)
	var light := SpotLight3D.new()
	light.light_energy = 1.1
	light.spot_range = 5
	light.spot_angle = 40
	light.position.x = .18
	view.add_child(light)
	for side: float in [-1,1]:
		var hand: Node3D = preload("res://scripts/art/art_factory.gd").model("hand")
		hand.position = Vector3(side*.29,-.24,-.34)
		hand.rotation.z = side*.3
		view.add_child(hand)
		hands.append(hand)
	tunnel.hide()

func _process(_delta: float) -> void:
	var traveling: bool = actor.vent_time > 0 and actor.health > 0
	if traveling and not active:
		active = true
		tunnel.show()
		view.make_current()
	elif active and not traveling:
		active = false
		tunnel.hide()
		actor.camera.make_current()
	if not active: return
	var progress: float = 1.0-actor.vent_time/3.6
	for i: int in range(hands.size()):
		hands[i].position.z = -.34+sin(progress*40+i*PI)*.08
		hands[i].position.y = -.24+maxf(0,sin(progress*40+i*PI))*.035
	view.position = Vector3(sin(progress*48)*.028,.4+sin(progress*55)*.022,-progress*7)
	view.rotation = Vector3(sin(progress*30)*.015,sin(progress*27)*.035,sin(progress*48)*.018)
