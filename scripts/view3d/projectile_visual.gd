class_name ProjectileVisual
extends EntityVisual
## 3D view of a Projectile: flies in an arc from shooter to target.

var kind := "arrow"
var _start := Vector2.ZERO
var _total := 1.0
var _arc := 1.0
var _spin := 0.0


func setup(p: Projectile, p_view) -> void:
	entity = p
	view = p_view
	kind = p.visual if p.visual != "" else ("boulder" if p.splash > 0.0 else "arrow")
	set_model(ModelLibrary.projectile_model(kind))
	_start = p.global_position
	_total = maxf(1.0, _start.distance_to(p.target_pos))
	_arc = clampf(ViewSpace.m(_total) * 0.18, 0.4, 6.0)
	_place(p.global_position, 0.0)


func sync(delta: float) -> void:
	var p: Projectile = entity
	var remaining := p.global_position.distance_to(p.target_pos)
	var k := clampf(1.0 - remaining / _total, 0.0, 1.0)
	var before := position
	_place(p.global_position, k)
	var dir := position - before
	if dir.length_squared() > 0.000001:
		look_at(position + dir, Vector3.UP, true)  # models face +Z
	if kind == "axe":
		_spin += delta * 18.0
		model.rotation.x = _spin
	elif kind == "boulder":
		model.rotation.x += delta * 6.0


func _place(world_pos: Vector2, k: float) -> void:
	position = ViewSpace.to_3d(world_pos, 1.4 + sin(k * PI) * _arc)


func process_death(_delta: float) -> bool:
	return true
