class_name SelectionBox
extends Control
## Draws the drag rectangle used by Box Select mode.

var box := Rect2()
var showing := false


func _draw() -> void:
	if not showing:
		return
	draw_rect(box, Color(0.45, 1.0, 0.45, 0.15))
	draw_rect(box, Color(0.45, 1.0, 0.45, 0.9), false, 2.0)
