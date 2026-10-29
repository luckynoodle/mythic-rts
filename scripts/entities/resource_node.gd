class_name ResourceNode
extends Node2D
## A gold mine, tree or stone quarry that builders harvest.

var resource_type := "gold"
var amount := 1000
var max_amount := 1000
var radius := 24.0

var _shape_seed := 0


static func alive(n) -> bool:
	return n != null and is_instance_valid(n) and n is ResourceNode and n.amount > 0


func setup(p_type: String, p_amount: int) -> void:
	resource_type = p_type
	amount = p_amount
	max_amount = p_amount
	match resource_type:
		"gold": radius = 30.0
		"wood": radius = 16.0
		"stone": radius = 26.0
	_shape_seed = randi()
	add_to_group("resource_nodes")


## Removes up to `want` units and returns how many were actually taken.
func harvest(want: int) -> int:
	var got := mini(want, amount)
	amount -= got
	queue_redraw()
	if amount <= 0:
		queue_free()
	return got


func contains_point(p: Vector2, slop: float = 0.0) -> bool:
	return global_position.distance_to(p) <= radius + slop


func edge_distance_to(p: Vector2) -> float:
	return maxf(0.0, global_position.distance_to(p) - radius)


func get_rect() -> Rect2:
	return Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func display_name() -> String:
	match resource_type:
		"gold": return "Gold Mine"
		"wood": return "Tree"
		"stone": return "Stone Quarry"
	return resource_type.capitalize()


func _draw() -> void:
	var base: Color = GameData.RESOURCE_COLORS.get(resource_type, Color.WHITE)
	match resource_type:
		"wood":
			draw_circle(Vector2(0, 6), 5, Color(0.35, 0.22, 0.12))
			draw_circle(Vector2(0, -2), radius, Color(0.13, 0.42, 0.18))
			draw_circle(Vector2(-4, -6), radius * 0.6, Color(0.18, 0.52, 0.22))
		"gold":
			_draw_rock(Color(0.35, 0.3, 0.25), radius)
			for i in 4:
				var a := float(i) * 1.7 + float(_shape_seed % 7)
				draw_circle(Vector2(cos(a), sin(a)) * radius * 0.45, 5, base)
		"stone":
			_draw_rock(base.darkened(0.25), radius)
			_draw_rock(base, radius * 0.6)
	# Remaining-amount bar for mines and quarries.
	if resource_type != "wood":
		var w := radius * 1.6
		var frac := float(amount) / float(max_amount)
		draw_rect(Rect2(-w * 0.5, radius + 4, w, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, radius + 4, w * frac, 4), base)


func _draw_rock(col: Color, r: float) -> void:
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = _shape_seed
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * r * rng.randf_range(0.8, 1.0))
	draw_colored_polygon(pts, col)
