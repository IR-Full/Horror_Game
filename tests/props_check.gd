extends Node
const ART:=preload("res://scripts/art/art_factory.gd")
const ITEMS:=preload("res://scripts/world/item_system.gd")
var failures: int=0
func _ready() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if ok: print("PROPS_CHECK "+label)
	else: failures+=1; push_error("PROPS_FAIL "+label)
func run() -> void:
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/catalog.json"))
	var detailed: Array=[]
	for entry: Dictionary in catalog:
		if entry.get("detail_version",0)==13:
			detailed.append(entry.model)
			check(int(entry.triangles)<10000,"bounded close-up geometry: "+str(entry.model))
	check(detailed.size()==35,"supplies, key variants, equipment and nine environment props are updated")
	for kind: String in ITEMS.NAMES:
		check(kind in detailed,"updated pickup: "+kind)
		var model: Node3D=ART.model(kind)
		check(not model.find_children("*","MeshInstance3D",true,false).is_empty(),"imported pickup geometry: "+kind)
		check(ResourceLoader.exists("res://assets/ui/items/%s.png" % kind),"baked inventory image: "+kind)
		model.free()
	var gun: Node3D=ART.model("shotgun")
	check(gun.find_child("BreechPivot",true,false)!=null,"break-action hinge is separate from the stock")
	var textured: int=0
	for part: MeshInstance3D in gun.find_children("*","MeshInstance3D",true,false):
		for i: int in range(part.mesh.get_surface_count()):
			var mat: Material=part.get_active_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture: textured+=1
			var tiles: Dictionary={"Prop Walnut":Rect2(0,0,.5,.5),"Prop Blued steel":Rect2(.5,0,.5,.5),"Prop Rubber":Rect2(.5,.5,.5,.5)}
			if mat.resource_name in tiles:
				var correct: bool=true
				var coordinates: PackedVector2Array=part.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV]
				for uv: Vector2 in coordinates:
					if not tiles[mat.resource_name].has_point(uv):correct=false
				check(correct,"exported UVs stay inside the correct material tile: "+mat.resource_name)
	check(textured>=3,"gun retains UV-mapped wood, gunmetal and rubber instead of generic wear")
	gun.free()
	NetworkManager.host_room("Props QA",27997);NetworkManager.choose_role(2);NetworkManager.start_round(true)
	await get_tree().create_timer(.4).timeout
	var player: Node3D=GameManager.local_player();player.input_enabled=false
	GameManager.world.monster.set_physics_process(false)
	var view: Node=player.get_node("EquipmentView")
	check(view.breech!=null and view.fill.light_cull_mask==1<<19,"view fill lights equipment only, not the map")
	player.apply_action("shoot",0);player.reserve_shells=1
	await get_tree().create_timer(.25).timeout
	player.apply_action("reload",0)
	await get_tree().create_timer(.75).timeout
	check(view.breech.rotation.x<-.5 and player.loaded_shells==1,"real reload opens the hinge before ammunition is inserted")
	await get_tree().create_timer(1.6).timeout
	check(absf(view.breech.rotation.x)<.03 and player.loaded_shells==2 and player.reserve_shells==0,"hinge closes and authoritative two-shell reload completes")
	for kind: String in ["service_key","car_key","yard_key","hospital_key"]:
		var pickup: Node3D=GameManager.world.add_object("prop_qa_"+kind,kind,kind,Vector3(0,.3,-5))
		check(pickup.mesh.name==kind.capitalize() and pickup.collision_layer==16,"distinct key model stays ray-targetable and nonblocking: "+kind)
	for quality: int in [0,2]:
		SettingsManager.quality=quality;SettingsManager.apply()
		check(ART.worn_materials["Prop Walnut"].normal_enabled==(quality>0),"new materials follow graphics quality "+str(quality))
	NetworkManager.leave();await get_tree().process_frame
	print("PROPS_PASS" if failures==0 else "PROPS_FAIL %d" % failures);get_tree().quit(0 if failures==0 else 1)
