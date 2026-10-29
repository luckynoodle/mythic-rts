class_name Unit
extends Entity
## A mobile unit. Behaviour is a small state machine driven by player or AI commands.
##
## Builders (role "builder") can gather resources and construct buildings.
## Every other role fights. All stats come from the faction JSON.

enum State { IDLE, MOVE, ATTACK, GATHER, RETURN, BUILD }

const SCAN_INTERVAL := 0.5
const RESOURCE_SEARCH_RADIUS := 700.0

var role := "melee"
var speed := 80.0
var attack: Dictionary = {}
var supply := 1
var carry_capacity := 0
var gather_time := 2.0
var build_rate := 1.0

var state: State = State.IDLE
var move_target := Vector2.ZERO
var attack_move := false
var target = null          # Entity being attacked
var resource_node = null   # ResourceNode being harvested
var build_site = null      # Building being constructed
var carry_type := ""
var carry_amount := 0
## Resource type this builder works on; lets it resume work after building or depletion.
var job_type := ""

var _job_pos := Vector2.ZERO
var _cooldown := 0.0
var _gather_timer := 0.0
var _scan_timer := 0.0
var _flash := 0.0


func setup(p_team: int, p_faction: String, p_unit_id: String) -> void:
	team = p_team
	faction_id = p_faction
	def_id = p_unit_id
	def = GameData.get_unit_def(p_faction, p_unit_id)
	display_name = str(def.get("name", p_unit_id))
	role = str(def.get("role", "melee"))
	max_hp = float(def.get("hp", 100))
	hp = max_hp
	armor = float(def.get("armor", 0))
	radius = float(def.get("radius", 10))
	sight = float(def.get("sight", 250))
	speed = float(def.get("speed", 80))
	attack = def.get("attack", {})
	supply = int(def.get("supply", 1))
	carry_capacity = int(def.get("carry_capacity", 0))
	gather_time = float(def.get("gather_time", 2.0))
	build_rate = float(def.get("build_rate", 1.0))
	team_color = Game.get_player(team).color
	_scan_timer = randf() * SCAN_INTERVAL
	add_to_group("entities")
	add_to_group("units")


func is_builder() -> bool:
	return role == "builder"


func can_fight() -> bool:
	return role != "builder" and float(attack.get("damage", 0)) > 0.0


func attack_range() -> float:
	return float(attack.get("range", 6))


# ---------------------------------------------------------------- commands

func command_move(pos: Vector2, p_attack_move := false) -> void:
	_clear_jobs()
	job_type = ""
	move_target = Game.clamp_to_map(pos)
	attack_move = p_attack_move and can_fight()
	state = State.MOVE


func command_attack(e) -> void:
	if not Entity.alive(e) or float(attack.get("damage", 0)) <= 0.0:
		return
	_clear_jobs()
	job_type = ""
	target = e
	state = State.ATTACK


func command_gather(node) -> void:
	if not ResourceNode.alive(node):
		return
	if carry_capacity <= 0:
		command_move(node.global_position)
		return
	_clear_jobs()
	if carry_type != node.resource_type:
		carry_amount = 0
		carry_type = node.resource_type
	resource_node = node
	job_type = node.resource_type
	_job_pos = node.global_position
	_gather_timer = 0.0
	state = State.GATHER
	queue_redraw()


func command_build(site) -> void:
	if not is_builder() or not Entity.alive(site):
		return
	_clear_jobs()  # keeps job_type so the builder returns to gathering afterwards
	build_site = site
	state = State.BUILD


func command_stop() -> void:
	_clear_jobs()
	job_type = ""
	state = State.IDLE


func _clear_jobs() -> void:
	target = null
	resource_node = null
	build_site = null
	attack_move = false


func status_text() -> String:
	match state:
		State.IDLE:
			return "Idle"
		State.MOVE:
			return "Attack-moving" if attack_move else "Moving"
		State.ATTACK:
			return "Attacking %s" % target.display_name if Entity.alive(target) else "Attacking"
		State.GATHER:
			return "Gathering %s" % job_type
		State.RETURN:
			return "Returning %d %s" % [carry_amount, carry_type]
		State.BUILD:
			return "Building %s" % build_site.display_name if Entity.alive(build_site) else "Building"
	return ""


# ---------------------------------------------------------------- behaviour

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_scan_timer -= delta
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			queue_redraw()
	match state:
		State.IDLE:
			_process_idle()
		State.MOVE:
			_process_move(delta)
		State.ATTACK:
			_process_attack(delta)
		State.GATHER:
			_process_gather(delta)
		State.RETURN:
			_process_return(delta)
		State.BUILD:
			_process_build(delta)
	_resolve_collisions()


func _scan_for_enemy():
	if not can_fight() or _scan_timer > 0.0:
		return null
	_scan_timer = SCAN_INTERVAL
	return Game.nearest_enemy(team, global_position, sight)


func _process_idle() -> void:
	var enemy = _scan_for_enemy()
	if enemy != null:
		target = enemy
		state = State.ATTACK


func _process_move(delta: float) -> void:
	if attack_move:
		var enemy = _scan_for_enemy()
		if enemy != null:
			target = enemy
			state = State.ATTACK
			return
	if _step_towards(move_target, delta, 4.0):
		attack_move = false
		state = State.IDLE


func _process_attack(delta: float) -> void:
	if not Entity.alive(target):
		target = null
		var next = Game.nearest_enemy(team, global_position, sight) if can_fight() else null
		if next != null:
			target = next
		elif attack_move:
			state = State.MOVE
		else:
			state = State.IDLE
		return
	if target.edge_distance_to(global_position) <= radius + attack_range():
		if _cooldown <= 0.0:
			_perform_attack()
	else:
		_step_towards(target.global_position, delta, 0.0, target)


func _perform_attack() -> void:
	_cooldown = float(attack.get("cooldown", 1.0))
	var dmg := float(attack.get("damage", 1))
	if attack.get("projectile", false):
		Game.spawn_projectile(team, global_position, target, dmg,
				float(attack.get("projectile_speed", 450)), float(attack.get("splash", 0)),
				team_color.lightened(0.45), str(attack.get("projectile_visual", "")))
	else:
		target.take_damage(dmg, self)
	_flash = 0.12
	queue_redraw()


func _process_gather(delta: float) -> void:
	if carry_amount >= carry_capacity:
		state = State.RETURN
		return
	if not ResourceNode.alive(resource_node):
		resource_node = Game.nearest_resource(job_type, _job_pos, RESOURCE_SEARCH_RADIUS)
		if resource_node == null:
			state = State.RETURN if carry_amount > 0 else State.IDLE
			return
	if resource_node.edge_distance_to(global_position) > radius + 4.0:
		_gather_timer = 0.0
		_step_towards(resource_node.global_position, delta, 0.0)
		return
	_gather_timer += delta
	if _gather_timer >= gather_time:
		_gather_timer = 0.0
		carry_type = resource_node.resource_type
		carry_amount += resource_node.harvest(carry_capacity - carry_amount)
		_flash = 0.12
		queue_redraw()
		if carry_amount >= carry_capacity or not ResourceNode.alive(resource_node):
			state = State.RETURN


func _process_return(delta: float) -> void:
	if carry_amount <= 0:
		_resume_work()
		return
	var drop := Game.nearest_drop_off(team, carry_type, global_position)
	if drop == null:
		state = State.IDLE  # Nowhere to deliver this resource; keep holding it.
		return
	if drop.edge_distance_to(global_position) <= radius + 6.0:
		Game.add_resource(team, carry_type, carry_amount)
		carry_amount = 0
		queue_redraw()
		_resume_work()
	else:
		_step_towards(drop.global_position, delta, 0.0, drop)


func _process_build(delta: float) -> void:
	if not Entity.alive(build_site) or build_site.is_complete:
		build_site = null
		_resume_work()
		return
	if build_site.edge_distance_to(global_position) <= radius + 6.0:
		build_site.add_build_progress(delta * build_rate)
	else:
		_step_towards(build_site.global_position, delta, 0.0, build_site)


func _resume_work() -> void:
	if ResourceNode.alive(resource_node):
		state = State.GATHER
		return
	if job_type != "":
		resource_node = Game.nearest_resource(job_type, _job_pos, RESOURCE_SEARCH_RADIUS)
		if resource_node == null:
			resource_node = Game.nearest_resource(job_type, global_position, RESOURCE_SEARCH_RADIUS)
		if resource_node != null:
			state = State.GATHER
			return
	state = State.IDLE


# ---------------------------------------------------------------- movement

## Moves toward `point`; returns true once within `arrive_dist` of it.
## `ignore` is a building we're walking *to* (so it isn't treated as an obstacle).
func _step_towards(point: Vector2, delta: float, arrive_dist: float, ignore = null) -> bool:
	var to := point - global_position
	var dist := to.length()
	if dist <= arrive_dist:
		return true
	var step := speed * delta
	if dist - arrive_dist <= step:
		global_position = point - to / dist * arrive_dist
		return true
	var waypoint := _steer_around_buildings(point, ignore)
	var dir := (waypoint - global_position).normalized()
	global_position += dir * step
	return false


## If a building blocks the straight line to `point`, returns the corner of that
## building to head for instead. Simple and cheap; real pathfinding is on the roadmap.
func _steer_around_buildings(point: Vector2, ignore) -> Vector2:
	var pos := global_position
	var hit_t := INF
	var blocker: Rect2
	var solid: Rect2  # the area we physically can't enter
	for b in Game.buildings:
		if b == ignore or not is_instance_valid(b) or b._dead:
			continue
		var r: Rect2 = b.get_rect().grow(radius + 2.0)
		if r.has_point(point):
			continue  # the destination is inside/next to it; push-out handles the rest
		var t := _segment_rect_entry(pos, point, r)
		if t >= 0.0 and t < hit_t:
			hit_t = t
			blocker = r
			solid = b.get_rect().grow(radius - 1.0)
	if hit_t == INF:
		return point
	var corners_rect := blocker.grow(6.0)
	var corners := [corners_rect.position, Vector2(corners_rect.end.x, corners_rect.position.y),
			corners_rect.end, Vector2(corners_rect.position.x, corners_rect.end.y)]
	var best: Vector2 = point
	var best_cost := INF
	for c in corners:
		if pos.distance_to(c) < 3.0:
			continue  # already at this corner; pick the next one
		# Skip corners we can't reach directly (the blocker is in the way).
		if _segment_rect_entry(pos, c, solid) >= 0.0:
			continue
		var cost: float = pos.distance_to(c) + c.distance_to(point)
		# Strongly prefer corners that can see the destination; this avoids
		# flip-flopping between two corners on the same side.
		if _segment_rect_entry(c, point, blocker.grow(-1.0)) >= 0.0:
			cost += 10000.0
		if cost < best_cost:
			best_cost = cost
			best = c
	return best


## Liang-Barsky: fraction along a->b where the segment enters `r`, or -1 if it doesn't.
static func _segment_rect_entry(a: Vector2, b: Vector2, r: Rect2) -> float:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var p := [-d.x, d.x, -d.y, d.y]
	var q := [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		if absf(p[i]) < 0.0001:
			if q[i] < 0.0:
				return -1.0
			continue
		var t: float = q[i] / p[i]
		if p[i] < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return -1.0
	return t0


## Soft separation from other units and a hard push out of building footprints.
## TODO: replace with NavigationServer2D pathfinding + a spatial hash (see docs/ROADMAP.md).
func _resolve_collisions() -> void:
	for other in Game.units:
		if other == self or not is_instance_valid(other) or other._dead:
			continue
		var off: Vector2 = global_position - other.global_position
		var min_d: float = radius + other.radius
		var d2 := off.length_squared()
		if d2 >= min_d * min_d:
			continue
		if d2 < 0.01:
			off = Vector2(randf() - 0.5, randf() - 0.5)
			d2 = off.length_squared()
		var d := sqrt(d2)
		global_position += off / d * (min_d - d) * 0.5
	for b in Game.buildings:
		if not is_instance_valid(b) or b._dead:
			continue
		var r: Rect2 = b.get_rect().grow(radius)
		var p := global_position
		if not r.has_point(p):
			continue
		var left := p.x - r.position.x
		var right := r.end.x - p.x
		var top := p.y - r.position.y
		var bottom := r.end.y - p.y
		var m := minf(minf(left, right), minf(top, bottom))
		if m == left:
			p.x = r.position.x
		elif m == right:
			p.x = r.end.x
		elif m == top:
			p.y = r.position.y
		else:
			p.y = r.end.y
		global_position = p
	global_position = Game.clamp_to_map(global_position)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var r := radius
	if selected:
		draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 32, Color(0.45, 1.0, 0.45), 2.0)
	var body := team_color.lightened(0.45) if _flash > 0.0 else team_color
	var outline := team_color.darkened(0.55)
	match role:
		"ranged":
			var tri := PackedVector2Array([Vector2(0, -r * 1.15), Vector2(r, r * 0.8), Vector2(-r, r * 0.8)])
			draw_colored_polygon(tri, body)
			tri.append(tri[0])
			draw_polyline(tri, outline, 2.0)
		"heavy":
			var sq := Rect2(-r, -r, r * 2.0, r * 2.0)
			draw_rect(sq, body)
			draw_rect(sq, outline, false, 2.0)
		"vehicle":
			var body_rect := Rect2(-r, -r * 0.65, r * 2.0, r * 1.3)
			draw_rect(body_rect, body)
			draw_rect(body_rect, outline, false, 2.0)
			for x in [-r * 0.6, r * 0.6]:
				draw_circle(Vector2(x, r * 0.7), r * 0.3, outline)
		"flyer":
			var dia := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
			draw_colored_polygon(dia, body)
		_:
			draw_circle(Vector2.ZERO, r, body)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, outline, 2.0)
	var font := ThemeDB.fallback_font
	var fs := int(r * 1.2)
	draw_string(font, Vector2(-r, fs * 0.35), display_name.left(1), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
	if carry_amount > 0:
		draw_circle(Vector2(r * 0.85, -r * 0.85), 4.5, GameData.RESOURCE_COLORS.get(carry_type, Color.WHITE))
	if selected or hp < max_hp:
		draw_health_bar(maxf(r * 2.4, 22.0), -r - 10.0)
