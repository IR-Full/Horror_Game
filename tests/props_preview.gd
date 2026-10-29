extends Node
## Bake inventory art from actual shipped GLBs, then capture the first-person equipment.
const ART:=preload("res://scripts/art/art_factory.gd")
const ITEMS:=preload("res://scripts/world/item_system.gd")
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var cards: GridContainer
func _ready() -> void: run.call_deferred()
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func model_bounds(model: Node3D) -> AABB:
	var result:=AABB();var first: bool=true
	for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var box: AABB=part.transform*part.get_aabb()
		var parent: Node3D=part.get_parent()
		while parent!=model:
			box=parent.transform*box;parent=parent.get_parent()
		result=box if first else result.merge(box);first=false
	return result
func render_prop(kind: String) -> Image:
	var model: Node3D=ART.model(kind);stage.add_child(model)
	if kind in ["shotgun","scalpel"]:model.rotation.y=PI/2
	var bounds: AABB=model.transform*model_bounds(model)
	var center: Vector3=bounds.get_center();var extent: float=bounds.size.length()
	camera.position=center+Vector3(1.3,1.1,1.65).normalized()*extent*2
	camera.look_at(center);camera.size=extent*1.08
	await get_tree().process_frame;await get_tree().process_frame;await RenderingServer.frame_post_draw
	var img: Image=viewport.get_texture().get_image()
	model.queue_free();await get_tree().process_frame
	return img
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1440,1000))
	GameManager.interface.ui.hide()
	var background:=ColorRect.new();background.color=Color("182221");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	cards=GridContainer.new();cards.columns=6;cards.position=Vector2(14,14);cards.add_theme_constant_override("h_separation",8);cards.add_theme_constant_override("v_separation",8);add_child(cards)
	viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.own_world_3d=true;viewport.transparent_bg=true
	viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();stage.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	environment.environment.ambient_light_energy=.7
	var sky:=Sky.new();var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("778d9a");sky_material.sky_horizon_color=Color("c1c9c9")
	sky_material.ground_bottom_color=Color("30312d");sky_material.ground_horizon_color=Color("8c918d")
	sky.sky_material=sky_material;environment.environment.sky=sky
	environment.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	for data: Array in [[Vector3(-2,3,2),2.4,Color("f2e6ce")],[Vector3(2,1,-2),1.3,Color("b2cad5")]]:
		var light:=DirectionalLight3D.new();stage.add_child(light);light.position=data[0];light.look_at(Vector3.ZERO);light.light_energy=data[1];light.light_color=data[2]
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.001;camera.far=20;stage.add_child(camera)
	DirAccess.make_dir_recursive_absolute("res://assets/ui/items")
	var kinds: Array=[]
	if "--equipment-only" not in OS.get_cmdline_user_args():
		kinds=["shotgun","flashlight","hand"];kinds.append_array(ITEMS.NAMES.keys())
	for kind: String in kinds:
		var img: Image=await render_prop(kind)
		var card:=VBoxContainer.new();card.custom_minimum_size=Vector2(190,125);cards.add_child(card)
		var picture:=TextureRect.new();picture.texture=ImageTexture.create_from_image(img);picture.custom_minimum_size=Vector2(190,98)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;card.add_child(picture)
		var caption:=Label.new();caption.text=ITEMS.NAMES.get(kind,kind);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.clip_text=true;caption.add_theme_font_size_override("font_size",13);card.add_child(caption)
		img.save_png("res://test-results/v13-"+kind+".png")
		if ITEMS.NAMES.has(kind):
			img.resize(256,256,Image.INTERPOLATE_LANCZOS);img.save_png("res://assets/ui/items/"+kind+".png")
	if not kinds.is_empty():await capture("res://test-results/v13-props-board.png")
	background.queue_free();cards.queue_free();viewport.queue_free()
	GameManager.interface.ui.show()
	if "--bake-only" in OS.get_cmdline_user_args():print("PROPS_BAKE_PASS");get_tree().quit();return
	NetworkManager.host_room("Охотник",27998);NetworkManager.choose_role(2);NetworkManager.choose_map(2);NetworkManager.start_round(true)
	await get_tree().create_timer(.8).timeout
	var player: Node3D=GameManager.local_player();player.input_enabled=false;GameManager.world.monster.set_physics_process(false)
	player.position=Vector3(54,.05,-19);player.net_position=player.position;player.local_aim=Vector2(0,-.15)
	player.inventory=["medkit","battery","car_key","thermos"]
	await get_tree().create_timer(.5).timeout;await capture("res://test-results/v13-held-shotgun.png")
	player.apply_action("shoot",0);player.reserve_shells=1;await get_tree().create_timer(.25).timeout;player.apply_action("reload",0)
	await get_tree().create_timer(.75).timeout;await capture("res://test-results/v13-reload.png")
	await get_tree().create_timer(1.6).timeout
	NetworkManager.leave();await get_tree().process_frame
	NetworkManager.host_room("Техник",27998);NetworkManager.choose_role(0);NetworkManager.start_round(true)
	await get_tree().create_timer(.7).timeout;GameManager.world.monster.set_physics_process(false)
	player=GameManager.local_player();player.input_enabled=false;player.local_aim=Vector2(0,-.12)
	await get_tree().create_timer(.4).timeout;await capture("res://test-results/v13-held-flashlight.png")
	NetworkManager.leave();print("PROPS_UI_PASS");get_tree().quit()
