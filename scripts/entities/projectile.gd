class_name Projectile
extends Node2D
## Arrows, axes, bolts and boulders. Homes on its target and deals damage on arrival.

var team := -1
var target = null
var target_pos := Vector2.ZERO
var damage := 10.0
var speed := 450.0
var splash := 0.0
var color := Color.WHITE


func _ready() -> void:
	z_index = 5


func _physics_process(delta: float) -> void:
	if Entity.alive(target):
		target_pos = target.global_position
	var to := target_pos - global_position
	var step := speed * delta
	if to.length() <= step:
		_impact()
		return
	global_position += to.normalized() * step
	rotation = to.angle()


func _impact() -> void:
	if splash > 0.0:
		for e in Game.enemies_in_radius(team, target_pos, splash):
			e.take_damage(damage)
	elif Entity.alive(target):
		target.take_damage(damage)
	queue_free()


func _draw() -> void:
	if splash > 0.0:
		draw_circle(Vector2.ZERO, 5, color)
	else:
		draw_line(Vector2(-7, 0), Vector2(5, 0), color, 2.0)
