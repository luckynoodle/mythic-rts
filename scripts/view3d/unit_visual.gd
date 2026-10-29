class_name UnitVisual
extends EntityVisual
## 3D view of a Unit: follows it, turns to face where it walks or what it works on,
## and plays animations. Models with an AnimationPlayer use their own clips
## (idle / walk / attack / work / die); models without one get simple
## procedural motion (bob, lunge, chop) so placeholders feel alive.

const ATTACK_TIME := 0.35

var height := 2.0
var role := ""
var anim: AnimationPlayer
var anims := {}

var _carry_anchor: Node3D
var _carry_mi: MeshInstance3D
var _carry_type := ""
var _yaw := 0.0
var _t := 0.0
var _attack_t := 0.0
var _last_cooldown := 0.0
var _current_anim := ""


func setup(u: Unit, p_view) -> void:
	entity = u
	view = p_view
	role = u.role
	height = ViewSpace.unit_height(u.def)
	set_model(ModelLibrary.unit_model(u.faction_id, u.def_id, u.def))
	ModelLibrary.apply_team_color(model, u.team_color)
	anim = ModelLibrary.find_animation_player(model)
	anims = ModelLibrary.map_animations(anim)
	for loop_state in ["idle", "walk", "work"]:
		if anims.has(loop_state):
			anim.get_animation(anims[loop_state]).loop_mode = Animation.LOOP_LINEAR
	_carry_anchor = ModelLibrary.find_anchor(model, "carry")
	var r := ViewSpace.m(u.radius)
	ring = view.make_ring(r * 1.45, u.team == Game.local_team)
	add_child(ring)
	bar = HealthBar3D.new(clampf(r * 2.6, 0.9, 2.0))
	bar.position.y = height + 0.5
	add_child(bar)
	position = ViewSpace.to_3d(u.global_position)
	# Start facing the middle of the map.
	var to_mid := ViewSpace.to_3d(Game.MAP_SIZE * 0.5) - position
	_yaw = atan2(to_mid.x, to_mid.z)
	rotation.y = _yaw
	_t = randf() * 10.0


func sync(delta: float) -> void:
	var u: Unit = entity
	var p := ViewSpace.to_3d(u.global_position)
	var vel := (p - position) / maxf(delta, 0.0001)
	position = p
	var moving := Vector2(vel.x, vel.z).length() > 0.4
	_t += delta

	# Facing: where we walk, otherwise what we're working on or fighting.
	var look := Vector3.ZERO
	if moving:
		look = vel
	else:
		var focus = null
		match u.state:
			Unit.State.ATTACK:
				focus = u.target if Entity.alive(u.target) else null
			Unit.State.GATHER:
				focus = u.resource_node if ResourceNode.alive(u.resource_node) else null
			Unit.State.BUILD:
				focus = u.build_site if Entity.alive(u.build_site) else null
		if focus != null:
			look = ViewSpace.to_3d(focus.global_position) - p
	if Vector2(look.x, look.z).length_squared() > 0.0001:
		_yaw = lerp_angle(_yaw, atan2(look.x, look.z), minf(1.0, delta * 10.0))
	rotation.y = _yaw

	# An attack happened when the cooldown jumps back up.
	if u._cooldown > _last_cooldown + 0.01:
		_attack_t = 0.0001
		if anims.has("attack"):
			anim.stop()
			_current_anim = ""
	_last_cooldown = u._cooldown
	var working: bool = not moving and (
			(u.state == Unit.State.GATHER and u._gather_timer > 0.0)
			or (u.state == Unit.State.BUILD and Entity.alive(u.build_site)
				and u.build_site.edge_distance_to(u.global_position) <= u.radius + 6.0))

	if anim and not anims.is_empty():
		_drive_animation_player(delta, moving, working)
	else:
		_procedural(delta, moving, working)
	_update_carry(u.carry_amount > 0, u.carry_type)
	update_common(delta)


func _drive_animation_player(delta: float, moving: bool, working: bool) -> void:
	var want := "idle"
	if _attack_t > 0.0 and anims.has("attack"):
		_attack_t += delta
		want = "attack"
		if _attack_t > anim.get_animation(anims["attack"]).length:
			_attack_t = 0.0
			want = "idle"
	elif moving:
		want = "walk"
	elif working:
		want = "work" if anims.has("work") else ("attack" if anims.has("attack") else "idle")
	if not anims.has(want):
		want = "idle"
	if anims.has(want) and want != _current_anim:
		anim.play(anims[want], 0.15)
		_current_anim = want


func _procedural(delta: float, moving: bool, working: bool) -> void:
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var vehicle := role == "vehicle"
	if _attack_t > 0.0:
		_attack_t += delta
		var k := _attack_t / ATTACK_TIME
		if k >= 1.0:
			_attack_t = 0.0
		else:
			var s := sin(k * PI)
			if vehicle:
				pos.z = -s * 0.3  # recoil
			else:
				pos.z = s * 0.35
				rot.x = s * 0.35
	elif moving:
		if vehicle:
			pos.y = absf(sin(_t * 14.0)) * 0.04
		else:
			pos.y = absf(sin(_t * 9.0)) * height * 0.05
			rot.z = sin(_t * 9.0) * 0.06
			rot.x = 0.08
	elif working:
		var s := maxf(0.0, sin(_t * 7.0))
		rot.x = s * 0.4
		pos.z = s * 0.12
	else:
		pos.y = sin(_t * 2.0) * 0.015
	model.position = pos
	model.rotation = rot


func _update_carry(carrying: bool, resource_type: String) -> void:
	if not carrying:
		if _carry_mi:
			_carry_mi.visible = false
		return
	if _carry_mi == null:
		_carry_mi = MeshInstance3D.new()
		if _carry_anchor:
			_carry_anchor.add_child(_carry_mi)
		else:
			_carry_mi.position = Vector3(0, height * 0.6, -0.4)
			model.add_child(_carry_mi)
	if resource_type != _carry_type:
		_carry_type = resource_type
		_carry_mi.mesh = PlaceholderModels.carry_item(resource_type)
	_carry_mi.visible = true


func start_dying() -> void:
	super.start_dying()
	if _carry_mi:
		_carry_mi.visible = false
	if anim and anims.has("die"):
		anim.play(anims["die"], 0.1)


func process_death(delta: float) -> bool:
	if anim and anims.has("die"):
		_death_t += delta
		var length := anim.get_animation(anims["die"]).length
		if _death_t > length + 0.8:
			position.y -= delta * 1.0
		return _death_t > length + 2.5
	return super.process_death(delta)
