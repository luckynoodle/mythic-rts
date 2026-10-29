class_name ResourceVisual
extends EntityVisual
## 3D view of a ResourceNode (tree, gold mine, stone quarry).
## Trees shake when chopped and fall over when used up.

var resource_type := ""
var _shake := 0.0
var _last_amount := -1


func setup(n: ResourceNode, p_view) -> void:
	entity = n
	view = p_view
	resource_type = n.resource_type
	var variant := absi(int(n.global_position.x * 7.0 + n.global_position.y * 13.0))
	set_model(ModelLibrary.resource_model(resource_type, variant))
	position = ViewSpace.to_3d(n.global_position)
	rotation.y = float(variant % 628) * 0.01
	_last_amount = n.amount


func sync(delta: float) -> void:
	var n: ResourceNode = entity
	if n.amount < _last_amount:
		_shake = 0.3
	_last_amount = n.amount
	if _shake > 0.0:
		_shake -= delta
		model.rotation.z = sin(_shake * 60.0) * 0.04 * (_shake / 0.3)
	else:
		model.rotation.z = 0.0


func process_death(delta: float) -> bool:
	_death_t += delta
	if resource_type == "wood":
		model.rotation.z = lerpf(model.rotation.z, PI * 0.5, minf(1.0, delta * 3.0))
		if _death_t > 1.5:
			model.position.y -= delta * 1.5
		return _death_t > 3.5
	model.position.y -= delta * 1.5
	return _death_t > 2.0
