class_name Building
extends Entity
## A structure: may train units, accept resources (drop-off) and raise the supply cap.
## New buildings start as construction sites that builders finish over time.

signal construction_finished(building: Building)

const MAX_QUEUE := 5

var size := Vector2(64, 64)
var build_time := 30.0
var build_progress := 0.0
var is_complete := false
var trains: Array = []
var drop_off: Array = []
var supply_provided := 0

var train_queue: Array = []
var train_progress := 0.0
var rally_point := Vector2.ZERO
var rally_resource = null


## Call after setting `position`.
func setup(p_team: int, p_faction: String, building_id: String, complete: bool) -> void:
	team = p_team
	faction_id = p_faction
	def_id = building_id
	def = GameData.get_building_def(p_faction, building_id)
	display_name = str(def.get("name", building_id))
	var s: Array = def.get("size", [64, 64])
	size = Vector2(float(s[0]), float(s[1]))
	radius = size.length() * 0.5
	max_hp = float(def.get("hp", 500))
	armor = float(def.get("armor", 0))
	sight = maxf(size.x, size.y) + 150.0
	build_time = float(def.get("build_time", 30))
	trains = def.get("trains", [])
	drop_off = def.get("drop_off", [])
	team_color = Game.get_player(team).color
	rally_point = position + Vector2(0, size.y * 0.5 + 50.0)
	if complete:
		hp = max_hp
		_finish(false)
	else:
		hp = max_hp * 0.1
	add_to_group("entities")
	add_to_group("buildings")


func get_rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func contains_point(p: Vector2, slop: float = 0.0) -> bool:
	return get_rect().grow(slop).has_point(p)


func edge_distance_to(p: Vector2) -> float:
	var r := get_rect()
	var closest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return closest.distance_to(p)


# ---------------------------------------------------------------- construction

func add_build_progress(seconds: float) -> void:
	if is_complete or _dead:
		return
	build_progress += seconds
	hp = minf(max_hp, hp + max_hp * 0.9 * seconds / build_time)
	queue_redraw()
	if build_progress >= build_time:
		_finish(true)


func _finish(announce: bool) -> void:
	is_complete = true
	build_progress = build_time
	supply_provided = int(def.get("supply", 0))
	queue_redraw()
	if announce:
		Game.notify(team, "%s complete" % display_name)
	construction_finished.emit(self)


# ---------------------------------------------------------------- training

## Why this unit can't be queued right now ("" means it can).
func can_train(unit_id: String) -> String:
	if not is_complete:
		return "Still under construction"
	if not trains.has(unit_id):
		return "Can't train that here"
	var udef := GameData.get_unit_def(faction_id, unit_id)
	var missing := Game.missing_requirements(team, udef.get("requires", []))
	if not missing.is_empty():
		return "Requires " + ", ".join(PackedStringArray(missing))
	if train_queue.size() >= MAX_QUEUE:
		return "Queue is full"
	var cost: Dictionary = udef.get("cost", {})
	if not Game.can_afford(team, cost):
		return "Not enough " + Game.missing_resource_names(team, cost)
	if Game.supply_used(team) + int(udef.get("supply", 1)) > Game.supply_cap(team):
		var fdef := GameData.get_faction(faction_id)
		var farm := GameData.get_building_def(faction_id, str(fdef.get("supply_building", "")))
		return "Need more supply - build a %s" % farm.get("name", "supply building")
	return ""


func enqueue(unit_id: String) -> String:
	var reason := can_train(unit_id)
	if reason != "":
		return reason
	Game.spend(team, GameData.get_unit_def(faction_id, unit_id).get("cost", {}))
	train_queue.append(unit_id)
	queue_redraw()
	return ""


func cancel_last() -> void:
	if train_queue.is_empty():
		return
	var uid: String = train_queue.pop_back()
	Game.refund(team, GameData.get_unit_def(faction_id, uid).get("cost", {}))
	if train_queue.is_empty():
		train_progress = 0.0
	queue_redraw()


func current_train_fraction() -> float:
	if train_queue.is_empty():
		return 0.0
	var t := float(GameData.get_unit_def(faction_id, train_queue[0]).get("train_time", 10))
	return clampf(train_progress / t, 0.0, 1.0)


func set_rally(pos: Vector2, resource = null) -> void:
	rally_point = Game.clamp_to_map(pos)
	rally_resource = resource
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dead or not is_complete or train_queue.is_empty():
		return
	train_progress += delta
	queue_redraw()
	var t := float(GameData.get_unit_def(faction_id, train_queue[0]).get("train_time", 10))
	if train_progress >= t:
		train_progress = 0.0
		_spawn_trained(train_queue.pop_front())


func _spawn_trained(unit_id: String) -> void:
	var spawn := Vector2(global_position.x + randf_range(-size.x * 0.3, size.x * 0.3),
			get_rect().end.y + 16.0)
	var u := Game.spawn_unit(team, unit_id, spawn)
	if ResourceNode.alive(rally_resource) and u.carry_capacity > 0:
		u.command_gather(rally_resource)
	else:
		u.command_move(rally_point)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var base := team_color.darkened(0.4)
	if not is_complete:
		base = Color(base.r, base.g, base.b, 0.55)
	draw_rect(rect, base)
	if is_complete:
		draw_rect(Rect2(rect.position, Vector2(size.x, size.y * 0.28)), team_color.darkened(0.1))
	draw_rect(rect, team_color, false, 3.0)
	if selected:
		draw_rect(rect.grow(5), Color(0.45, 1.0, 0.45), false, 2.0)
		if not trains.is_empty():
			var local_rally := rally_point - global_position
			draw_line(Vector2(0, size.y * 0.5), local_rally, Color(1, 1, 1, 0.5), 2.0)
			draw_circle(local_rally, 6, Color(0.45, 1.0, 0.45))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-size.x * 0.5, 6), display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color.WHITE)
	var bar_w := size.x * 0.8
	var bar_y := size.y * 0.5 - 14.0
	if not is_complete:
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * build_progress / build_time, 6), Color(0.95, 0.8, 0.3))
	elif not train_queue.is_empty():
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * current_train_fraction(), 6), Color(0.5, 0.85, 1.0))
	if selected or hp < max_hp:
		draw_health_bar(size.x * 0.8, -size.y * 0.5 - 12.0)
