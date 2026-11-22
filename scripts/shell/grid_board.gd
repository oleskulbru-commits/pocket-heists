extends Node2D

const WALL := Color("#182126")
const FLOOR := Color("#27343A")
const SEAM := Color("#435159")


func _draw() -> void:
	for y in 9:
		for x in 7:
			var on_border := x == 0 or y == 0 or x == 6 or y == 8
			draw_rect(Rect2(x, y, 1, 1), WALL if on_border else FLOOR)
	var pixel := 1.0 / maxf(scale.x, 1.0)
	for x in 8:
		draw_line(Vector2(x, 0), Vector2(x, 9), SEAM, pixel, false)
	for y in 10:
		draw_line(Vector2(0, y), Vector2(7, y), SEAM, pixel, false)
