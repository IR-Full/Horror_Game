extends Control
## Compact item pictograms, drawn locally; no per-frame 3D inventory viewports.
var player: Node3D
var signature: String = ""

func _process(_delta: float) -> void:
	player = GameManager.local_player()
	if not player:
		return
	var current: String = str(player.inventory) + str(player.selected_slot)
	if current != signature:
		signature = current
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	var font: Font = ThemeDB.fallback_font
	for i: int in range(player.capacity()):
		var x: float = i * 78.0
		var selected: bool = i == player.selected_slot
		draw_style_box(_style(selected), Rect2(x, 0, 70, 66))
		draw_string(font, Vector2(x + 6, 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("718d86"))
		if i < player.inventory.size():
			var kind: String = player.inventory[i]
			_icon(kind, Vector2(x + 35, 36))
			if selected:
				var text: String = GameManager.world.items.NAMES.get(kind, kind)
				draw_string(font, Vector2(-80, -12), text, HORIZONTAL_ALIGNMENT_CENTER, 465, 16, Color("e6c18a"))

func _style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(.025, .045, .05, .94)
	box.border_color = Color("dfb87a") if selected else Color("39514c")
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(5)
	return box

func _icon(kind: String, c: Vector2) -> void:
	var cream := Color("c6bb96")
	var metal := Color("8bada4")
	match kind:
		"air_filter":
			draw_rect(Rect2(c-Vector2(13,18),Vector2(26,36)),cream)
			for i: int in range(5): draw_line(c+Vector2(-9+i*4,-14),c+Vector2(-9+i*4,14),metal,2)
			draw_rect(Rect2(c-Vector2(15,18),Vector2(30,5)),Color("263634"))
			draw_rect(Rect2(c+Vector2(-15,13),Vector2(30,5)),Color("263634"))
		"key", "service_key", "car_key", "yard_key":
			draw_arc(c + Vector2(-9, -5), 7, 0, TAU, 18, cream, 3, true)
			draw_line(c + Vector2(-2, -5), c + Vector2(16, 9), cream, 4, true)
			draw_line(c + Vector2(9, 4), c + Vector2(5, 10), cream, 3, true)
		"fuel":
			draw_rect(Rect2(c - Vector2(14, 15), Vector2(28, 33)), Color("835039"))
			draw_rect(Rect2(c + Vector2(-9, -22), Vector2(18, 7)), cream, false, 3)
			draw_line(c + Vector2(-8, -7), c + Vector2(8, 10), cream, 2)
			draw_line(c + Vector2(8, -7), c + Vector2(-8, 10), cream, 2)
		"cassette":
			draw_rect(Rect2(c - Vector2(22, 13), Vector2(44, 26)), metal)
			for side: float in [-1, 1]:
				draw_circle(c + Vector2(side * 11, 0), 6, Color("263634"))
		"medkit":
			draw_rect(Rect2(c - Vector2(21, 15), Vector2(42, 30)), metal)
			draw_rect(Rect2(c - Vector2(3, 10), Vector2(6, 20)), Color("8b2924"))
			draw_rect(Rect2(c - Vector2(10, 3), Vector2(20, 6)), Color("8b2924"))
		"wheel", "drive_belt":
			draw_arc(c,18,0,TAU,30,Color("71847e"),9 if kind == "wheel" else 3,true)
			if kind == "wheel":
				draw_circle(c,9,metal)
				for i: int in range(5): draw_line(c,c+Vector2(8,0).rotated(i*TAU/5),cream,2)
		"spark_plugs":
			for i: int in range(4):
				draw_line(c+Vector2(-15+i*10,-14),c+Vector2(-15+i*10,14),cream,5)
				draw_line(c+Vector2(-15+i*10,6),c+Vector2(-15+i*10,17),metal,3)
		"sedative", "thermos":
			draw_rect(Rect2(c-Vector2(11,17),Vector2(22,34)),cream if kind == "sedative" else metal)
			draw_rect(Rect2(c+Vector2(-9,-22),Vector2(18,6)),Color("394d49"))
			if kind == "sedative": draw_rect(Rect2(c-Vector2(7,3),Vector2(14,6)),Color("934633"))
		"battery", "fuse", "car_battery":
			draw_rect(Rect2(c - Vector2(11, 17), Vector2(22, 34)), metal if kind == "fuse" else Color("967a3d"))
			draw_rect(Rect2(c + Vector2(-7, -21), Vector2(14, 5)), cream)
			draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), cream, 3)
