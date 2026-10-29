class_name BuildingVisual
extends EntityVisual
## 3D view of a Building: rises out of the ground while under construction,
## smokes when badly damaged, shows health / training bars and collapses on death.

var height := 4.0
var size_m := Vector2(4, 4)
var train_bar: HealthBar3D
var _smoke: CPUParticles3D
var _dust: CPUParticles3D
var _was_complete := true


func setup(b: Building, p_view) -> void:
	entity = b
	view = p_view
	flash_strength = 0.18
	height = ViewSpace.building_height(b.def)
	size_m = b.size / ViewSpace.PX_PER_M
	set_model(ModelLibrary.building_model(b.faction_id, b.def_id, b.def))
	ModelLibrary.apply_team_color(model, b.team_color)
	ring = view.make_frame(size_m + Vector2(0.8, 0.8), b.team == Game.local_team)
	add_child(ring)
	bar = HealthBar3D.new(clampf(size_m.x * 0.6, 1.5, 4.0), 0.18)
	bar.position.y = height + 1.2
	add_child(bar)
	train_bar = HealthBar3D.new(clampf(size_m.x * 0.6, 1.5, 4.0), 0.12)
	train_bar.position.y = height + 0.8
	add_child(train_bar)
	position = ViewSpace.to_3d(b.global_position)
	_was_complete = b.is_complete
	if not b.is_complete:
		_dust = view.make_dust(size_m)
		add_child(_dust)


func sync(delta: float) -> void:
	var b: Building = entity
	if not b.is_complete:
		var frac := b.build_progress / b.build_time
		model.position.y = -height * (1.0 - frac) * 0.9
		bar.visible = true
		bar.set_value(frac, Color8(240, 200, 80))
	else:
		model.position.y = lerpf(model.position.y, 0.0, minf(1.0, delta * 8.0))
		if not _was_complete:
			_was_complete = true
			if _dust:
				_dust.emitting = false
	if b.is_complete:
		update_common(delta)
	elif ring:
		ring.visible = b.selected
	train_bar.visible = b.is_complete and not b.train_queue.is_empty()
	if train_bar.visible:
		train_bar.set_value(b.current_train_fraction(), Color8(110, 190, 255))
	var badly_hurt := b.is_complete and b.hp / b.max_hp < 0.4
	if badly_hurt and _smoke == null:
		_smoke = view.make_smoke()
		_smoke.position.y = height * 0.8
		add_child(_smoke)
	if _smoke:
		_smoke.emitting = badly_hurt


func start_dying() -> void:
	super.start_dying()
	train_bar.visible = false
	if _smoke:
		_smoke.emitting = false
	_dust = view.make_dust(size_m)
	add_child(_dust)


func process_death(delta: float) -> bool:
	_death_t += delta
	model.position.y -= delta * height * 0.45
	model.rotation.z = sin(_death_t * 18.0) * 0.02
	if _death_t > 1.5 and _dust:
		_dust.emitting = false
	return _death_t > 3.0
