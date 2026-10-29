class_name CommandMarker
extends Node2D
## A short expanding ring that confirms where a command was issued.

const LIFETIME := 0.45

var color := Color.WHITE
var _age := 0.0


func _ready() -> void:
	z_index = 40
	add_to_group("markers")


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	draw_arc(Vector2.ZERO, 6.0 + 18.0 * t, 0.0, TAU, 24, Color(color.r, color.g, color.b, 1.0 - t), 3.0)
