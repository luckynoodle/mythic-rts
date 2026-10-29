class_name Entity
extends Node2D
## Base class for anything that belongs to a team, has hit points and can be selected.

signal died(entity: Entity)

var team: int = -1
var faction_id: String = ""
var def_id: String = ""
var def: Dictionary = {}
var display_name: String = ""
var max_hp: float = 100.0
var hp: float = 100.0
var armor: float = 0.0
var radius: float = 12.0
var sight: float = 250.0
var team_color: Color = Color.WHITE
var selected: bool = false: set = set_selected

var _dead := false


## Safe liveness check for references that may point at freed nodes.
static func alive(e) -> bool:
	return e != null and is_instance_valid(e) and e is Entity and not e._dead


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func take_damage(amount: float, _attacker = null) -> void:
	if _dead:
		return
	hp -= maxf(1.0, amount - armor)
	queue_redraw()
	Game.on_entity_damaged(self)
	if hp <= 0.0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	queue_free()


func contains_point(p: Vector2, slop: float = 0.0) -> bool:
	return global_position.distance_to(p) <= radius + slop


## Distance from p to this entity's outer edge (0 if p is inside).
func edge_distance_to(p: Vector2) -> float:
	return maxf(0.0, global_position.distance_to(p) - radius)


func draw_health_bar(width: float, y: float) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var bar := Rect2(-width * 0.5, y, width, 5)
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.7))
	var col := Color(0.35, 0.9, 0.35)
	if frac <= 0.25:
		col = Color(0.92, 0.27, 0.22)
	elif frac <= 0.5:
		col = Color(0.95, 0.8, 0.2)
	draw_rect(Rect2(bar.position, Vector2(width * frac, bar.size.y)), col)
