extends Control
## Lightweight vector menu artwork; no GPU-heavy background scene.
var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c171e"))
	for x: int in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.22, 0.45, 0.47, 0.06))
	for y: int in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.22, 0.45, 0.47, 0.06))
	var origin := Vector2(size.x * 0.24, size.y * 0.64)
	for i: int in range(1, 6):
		draw_arc(origin, 58.0 * i + fmod(time * 8.0, 58.0), PI * 1.05, PI * 1.95, 80, Color(0.37, 0.7, 0.67, 0.11), 1.0, true)
	var top := origin - Vector2(0, 195)
	draw_line(top, origin + Vector2(-65, 90), Color("52736d"), 2.0, true)
	draw_line(top, origin + Vector2(65, 90), Color("52736d"), 2.0, true)
	draw_line(top, origin + Vector2(0, 90), Color("52736d"), 2.0, true)
	for i: int in range(5):
		var yy: float = -130.0 + i * 48.0
		var w: float = (yy + 195.0) / 285.0 * 65.0
		draw_line(origin + Vector2(-w, yy), origin + Vector2(w, yy + 35), Color("314f4c"), 1.0, true)
		draw_line(origin + Vector2(w, yy), origin + Vector2(-w, yy + 35), Color("314f4c"), 1.0, true)
	draw_circle(top, 4.0, Color("d29d60") * (0.7 + 0.3 * sin(time * 2.0)))
	var points := PackedVector2Array()
	for x: int in range(0, int(size.x), 3):
		var wave: float = sin(x * 0.06 + time) * sin(x * 0.013 - time * 0.5) * 8.0
		points.append(Vector2(x, size.y - 32 + wave))
	if points.size() > 1:
		draw_polyline(points, Color(0.37, 0.7, 0.67, 0.24), 1.0, true)
