extends Node
## Cosmetic break-action and a weak view-only fill; no gameplay authority or world light.
const VIEW_LAYER: int=1<<19
var actor: CharacterBody3D
var breech: Node3D
var fill: OmniLight3D
var opening: float=0

func _ready() -> void:
	if is_instance_valid(actor.shotgun): breech=actor.shotgun.find_child("BreechPivot",true,false)
	if not actor.is_local(): return
	for part: MeshInstance3D in actor.camera.find_children("*","MeshInstance3D",true,false):
		part.layers=VIEW_LAYER
	fill=OmniLight3D.new(); fill.name="EquipmentFill"
	fill.position=Vector3(-.12,.06,-.15)
	fill.omni_range=1.7; fill.light_color=Color("e1e5de")
	fill.light_cull_mask=VIEW_LAYER; fill.shadow_enabled=false
	fill.light_specular=.45; actor.camera.add_child(fill)

func _process(delta: float) -> void:
	var phase: float=2.0-actor.reload_left
	var target: float=0
	if actor.reload_left>0: target=clampf(phase/.28,0,1)*clampf(actor.reload_left/.42,0,1)
	opening=move_toward(opening,target,delta*7)
	if is_instance_valid(breech): breech.rotation.x=-.82*opening
	if actor.is_local():
		fill.light_energy=.38 if actor.lamp_on and actor.health>0 else .035
		if is_instance_valid(actor.shotgun):
			actor.shotgun.rotation=Vector3(actor.recoil*-.25+.14*opening,-.12*opening,.16*opening)
			actor.shotgun.position=Vector3(.18,-.24-.055*opening,-.34+actor.recoil*.12+.06*opening)
