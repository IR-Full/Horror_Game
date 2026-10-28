extends Control
const LAYOUT := preload("res://scripts/world/sector_layout.gd")

func _process(_delta: float) -> void:
	queue_redraw()

func point(p: Vector2) -> Vector2:
	return Vector2(310+p.x*3.7, 408+p.y*3.7)

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for region: Rect2 in LAYOUT.FLOORS:
		var rect := Rect2(point(region.position),region.size*3.7)
		draw_rect(rect, Color("213a3d"))
		draw_rect(rect, Color("6c8b80"), false, 1.2)
	for data: Array in [[Vector2(-11,-3),"A • ЖИЛОЙ"], [Vector2(-60,-32),"B • КОТЕЛЬНАЯ"], [Vector2(29,-32),"C • ЛАБОРАТОРИИ"], [Vector2(-18,-84),"D • СВЯЗЬ"]]:
		draw_string(font,point(data[0]),data[1],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e6c18a"))
	if not is_instance_valid(GameManager.world): return
	for player: Node3D in GameManager.world.players.get_children():
		var at: Vector2 = point(Vector2(player.position.x, player.position.z))
		var tint: Color = Color("e9c783") if player.is_local() else Color("8ac6ac")
		if player.health <= 0: tint = Color("d86f55")
		draw_circle(at, 4, tint)
		draw_string(font, at+Vector2(7,-5), player.nickname, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
	draw_string(font, Vector2(8,475), "Золотой — вы • зелёный — напарник • красный — раненый", HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a9bdb0"))
