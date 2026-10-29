class_name PlacementGhost
extends Node2D
## Translucent footprint shown while the player chooses where to put a building.

var size := Vector2(64, 64)
var label := ""
var valid := true


func _ready() -> void:
	z_index = 50


func _draw() -> void:
	var col := Color(0.35, 1.0, 0.45) if valid else Color(1.0, 0.35, 0.3)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(col.r, col.g, col.b, 0.3))
	draw_rect(rect, col, false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, 6), label,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color.WHITE)
