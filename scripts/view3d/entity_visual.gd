class_name EntityVisual
extends Node3D
## Base class for the 3D stand-in of a simulation object.
## Owns the model instance, selection ring, health bar, hit flash and death.

static var _flash_mats := {}

var entity = null
var view = null            # WorldView
var model: Node3D
var ring: Node3D
var bar: HealthBar3D
var dying := false
## How strongly the model flashes white when hit (buildings use a softer flash).
var flash_strength := 0.45

var _meshes: Array = []
var _flash := 0.0
var _flash_cooldown := 0.0
var _last_hp := -1.0
var _death_t := 0.0


func set_model(m: Node3D) -> void:
	model = m
	add_child(m)
	_meshes = ModelLibrary.meshes(m)


## Called every frame by WorldView with the live entity.
func sync(_delta: float) -> void:
	pass


func update_common(delta: float, show_bar_always := false) -> void:
	var e = entity
	if _last_hp >= 0.0 and e.hp < _last_hp - 0.01:
		_start_flash()
	_last_hp = e.hp
	_flash_cooldown -= delta
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_overlay(null)
	if ring:
		ring.visible = e.selected
	if bar:
		var frac: float = e.hp / e.max_hp
		bar.visible = show_bar_always or e.selected or frac < 0.999
		if bar.visible:
			bar.set_value(frac, HealthBar3D.health_color(frac))


func _start_flash() -> void:
	if _flash_cooldown > 0.0:
		return  # constant hits shouldn't turn the model white
	_flash_cooldown = 0.3
	if not _flash_mats.has(flash_strength):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, flash_strength)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mats[flash_strength] = m
	_flash = 0.08
	_set_overlay(_flash_mats[flash_strength])


func _set_overlay(m: Material) -> void:
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = m


func start_dying() -> void:
	dying = true
	_death_t = 0.0
	_set_overlay(null)
	if ring:
		ring.visible = false
	if bar:
		bar.visible = false


## Advances the death animation; returns true when the visual can be freed.
## Default: topple over, then sink into the ground.
func process_death(delta: float) -> bool:
	_death_t += delta
	if model:
		var k := clampf(_death_t / 0.4, 0.0, 1.0)
		model.rotation.x = lerpf(model.rotation.x, -PI * 0.5, k)
		if _death_t > 1.2:
			model.position.y -= delta * 1.2
	return _death_t > 3.0
