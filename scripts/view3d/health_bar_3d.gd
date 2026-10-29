class_name HealthBar3D
extends Node3D
## A small camera-facing bar (health, construction or training progress).

static var _mats := {}

var width := 1.0
var _fill_mesh: QuadMesh
var _value := -1.0
var _color := Color.BLACK
var _fill: MeshInstance3D


func _init(p_width := 1.0, height := 0.13) -> void:
	width = p_width
	var bg := QuadMesh.new()
	bg.size = Vector2(width + 0.08, height + 0.07)
	var bg_mi := MeshInstance3D.new()
	bg_mi.mesh = bg
	bg_mi.material_override = _mat(Color8(18, 16, 22), 0)
	bg_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bg_mi)
	_fill_mesh = QuadMesh.new()
	_fill_mesh.size = Vector2(width, height)
	_fill = MeshInstance3D.new()
	_fill.mesh = _fill_mesh
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill)


func set_value(frac: float, color: Color) -> void:
	frac = clampf(frac, 0.0, 1.0)
	if is_equal_approx(frac, _value) and color == _color:
		return
	_value = frac
	_color = color
	_fill_mesh.size.x = maxf(0.001, width * frac)
	_fill_mesh.center_offset = Vector3(-width * (1.0 - frac) * 0.5, 0, 0)
	_fill.material_override = _mat(color, 1)


static func health_color(frac: float) -> Color:
	if frac > 0.5:
		return Color8(110, 220, 80)
	if frac > 0.25:
		return Color8(240, 200, 60)
	return Color8(230, 80, 64)


static func _mat(color: Color, priority: int) -> StandardMaterial3D:
	var key := "%s|%d" % [color.to_html(), priority]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = true
		m.render_priority = priority
		_mats[key] = m
	return _mats[key]
