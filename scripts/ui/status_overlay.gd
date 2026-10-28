extends Control
## Cosmetic HUD reads replicated server state; never decides health or ammunition.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func bar(at: Vector2, width: float, fraction: float, text: String, tint: Color) -> void:
	draw_rect(Rect2(at,Vector2(width,6)),Color("172427"))
	draw_rect(Rect2(at,Vector2(width*clampf(fraction,0,1),6)),tint)
	draw_string(ThemeDB.fallback_font,at+Vector2(0,-8),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,tint)

func _draw() -> void:
	var actor: Node3D = GameManager.local_player()
	if not actor: return
	var font: Font = ThemeDB.fallback_font
	if VoiceManager.transmitting:
		var text: String = "В ЭФИРЕ"+(" • ГРОМКО" if VoiceManager.local_level >= VoiceManager.LOUD_LEVEL else "")
		var width: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		draw_string(font,Vector2((size.x-width)*.5,28),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e6a17c") if VoiceManager.local_level >= VoiceManager.LOUD_LEVEL else Color("94d0b5"))
	var speakers: PackedStringArray = VoiceManager.speakers()
	if SettingsManager.voice_enabled and not speakers.is_empty():
		var text: String = "Говорят: "+", ".join(speakers)
		var width: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(font,Vector2((size.x-width)*.5,48),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b5dccb"))
	var center := Vector2(size.x-460,size.y-45)
	bar(Vector2(28,size.y-24),180,actor.stamina/100.0,"ВЫНОСЛИВОСТЬ • %d%%" % int(actor.stamina),Color("bd9269") if actor.exhausted else Color("90b5a0"))
	if actor.healing_progress > 0 or actor.rescue_progress > 0:
		bar(Vector2(size.x*.5-135,size.y*.60),270,maxf(actor.healing_progress,actor.rescue_progress),"ПОДНЯТИЕ РАНЕНОГО • %d%%" % int(maxf(actor.healing_progress,actor.rescue_progress)*100),Color("a5dac5"))
	if actor.role == "hunter":
		var text: String = "ПЕРЕЗАРЯДКА %.1f сек." % actor.reload_left if actor.reload_left > 0 else ("ГОТОВ" if actor.loaded_shells > 0 and actor.shot_cooldown <= 0 else ("ПУСТО" if actor.loaded_shells == 0 else "ВЗВОД"))
		var tint := Color("dfb77c") if text == "ГОТОВ" else Color("bf7464")
		for i: int in range(2):
			draw_rect(Rect2(center+Vector2(155+i*22,-6),Vector2(14,25)),tint if i < actor.loaded_shells else Color("344546"),i < actor.loaded_shells,-1 if i < actor.loaded_shells else 2)
		draw_string(font,center+Vector2(205,10),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,tint)
	if actor.vent_time > 0:
		bar(Vector2(size.x*.5-150,80),300,1.0-actor.vent_time/3.6,"ВЕНТИЛЯЦИЯ • ПОЛЗКОМ",Color("c8d4ca"))
	if not is_instance_valid(GameManager.world): return
	for other: Node3D in GameManager.world.players.get_children():
		if other == actor or other.health > 0 or other.dead or other.sos_left <= 0: continue
		var target: Vector3 = other.global_position+Vector3.UP*.6
		var screen: Vector2 = actor.camera.unproject_position(target)
		var behind: bool = actor.camera.is_position_behind(target)
		if behind: screen = size-screen
		var direction: Vector2 = (screen-size*.5).normalized()
		if behind and direction.length_squared() < .01: direction = Vector2.DOWN
		var inside: bool = not behind and Rect2(Vector2(45,70),size-Vector2(90,200)).has_point(screen)
		if not inside:
			var radius: float = minf((size.x*.5-65)/maxf(absf(direction.x),.01),(size.y*.5-105)/maxf(absf(direction.y),.01))
			screen = size*.5+direction*radius
			draw_line(screen-direction*16,screen,Color("f49e83"),4)
			draw_line(screen,screen-direction.rotated(.65)*11,Color("f49e83"),3)
			draw_line(screen,screen-direction.rotated(-.65)*11,Color("f49e83"),3)
		else: draw_arc(screen,12,0,TAU,24,Color("f49e83"),2)
		draw_string(font,Vector2(clampf(screen.x-35,15,size.x-250),screen.y+28),"SOS • %s • %d м" % [other.nickname,int(actor.position.distance_to(other.position))],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ffc9ad"))
