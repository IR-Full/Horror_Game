extends Node
var vehicle: Node3D
var wheels: Array[Node3D] = []
var escape_visual: float = 0
var engine: AudioStreamPlayer3D
var headlights: Array[SpotLight3D] = []
func _ready() -> void:
	for part: Node3D in vehicle.mesh.find_children("*","MeshInstance3D",true,false):
		if str(part.name).begins_with("Wheel_") or str(part.name).begins_with("Hub_"): wheels.append(part)
	if DisplayServer.get_name() != "headless":
		engine = AudioStreamPlayer3D.new()
		engine.stream = AudioManager.stream_for("motor")
		engine.bus = "Effects"; engine.volume_db = -13; engine.max_distance = 35
		vehicle.add_child.call_deferred(engine)
		for x: float in [-.7,.7]:
			var light := SpotLight3D.new()
			light.position = Vector3(x,.1,2.25)
			light.rotation.y = PI
			light.spot_range = 28
			light.spot_angle = 32
			light.light_energy = 2
			light.light_color = Color(1,.91,.72)
			light.shadow_enabled = false
			light.visible = false
			vehicle.add_child.call_deferred(light)
			headlights.append(light)
func _process(delta: float) -> void:
	if not is_instance_valid(GameManager.world): return
	var goals: Node = GameManager.world.objectives
	for light: SpotLight3D in headlights: light.visible = goals.escape_time >= 0
	if is_instance_valid(engine) and engine.is_inside_tree() and goals.escape_time >= 0 and not engine.playing: engine.play()
	if goals.escape_time >= 0 and not multiplayer.is_server():
		if absf(escape_visual-goals.escape_time) > .6: escape_visual = goals.escape_time
		escape_visual = minf(escape_visual+delta,goals.escape_time+.25)
		vehicle.position = goals.car_origin+Vector3(0,0,minf(escape_visual,4)*5)
	for part: Node3D in wheels:
		if str(part.name) in ["Wheel_LF","Hub_LF"]: part.visible = "wheel" in goals.installed
		if goals.escape_time >= 0: part.rotate_x(delta*12)

func _exit_tree() -> void:
	if is_instance_valid(engine): engine.stop(); engine.stream = null
