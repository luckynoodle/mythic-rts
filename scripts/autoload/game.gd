extends Node
## Global match state ("Game" autoload).
##
## Holds the players, owns spawning, the economy helpers and the spatial
## queries that units, buildings, the AI and the input code all share.

signal message_posted(text: String)
signal match_ended(winning_team: int)

const MAP_SIZE := Vector2(3200, 2400)
const ATTACK_ALERT_COOLDOWN := 12.0

var players: Array[PlayerState] = []
var world: Node2D = null
var local_team := 0
var running := false
var elapsed := 0.0

## Per-frame snapshots of the scene groups (refreshed before anything else runs).
var units: Array = []
var buildings: Array = []
var resource_nodes: Array = []

var _victory_timer := 0.0
var _last_alert := -100.0


func reset() -> void:
	players.clear()
	world = null
	running = false
	elapsed = 0.0
	units = []
	buildings = []
	resource_nodes = []
	_last_alert = -100.0


func _physics_process(delta: float) -> void:
	if world == null:
		return
	refresh_snapshots()
	if not running:
		return
	elapsed += delta
	_victory_timer -= delta
	if _victory_timer <= 0.0:
		_victory_timer = 1.0
		_check_victory()


func refresh_snapshots() -> void:
	var tree := get_tree()
	units = tree.get_nodes_in_group("units")
	buildings = tree.get_nodes_in_group("buildings")
	resource_nodes = tree.get_nodes_in_group("resource_nodes")


# ---------------------------------------------------------------- players

func add_player(team: int, faction_id: String, is_ai: bool) -> PlayerState:
	var p := PlayerState.new(team, faction_id, is_ai)
	players.append(p)
	return p


func get_player(team: int) -> PlayerState:
	for p in players:
		if p.team == team:
			return p
	return null


func faction_of(team: int) -> String:
	var p := get_player(team)
	return p.faction_id if p else ""


func map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, MAP_SIZE)


func clamp_to_map(p: Vector2) -> Vector2:
	return p.clamp(Vector2(8, 8), MAP_SIZE - Vector2(8, 8))


# ---------------------------------------------------------------- spawning

func spawn_unit(team: int, unit_id: String, pos: Vector2) -> Unit:
	var u := Unit.new()
	u.setup(team, faction_of(team), unit_id)
	u.position = clamp_to_map(pos)
	world.add_child(u)
	return u


func spawn_building(team: int, building_id: String, pos: Vector2, complete: bool) -> Building:
	var b := Building.new()
	b.position = pos
	b.setup(team, faction_of(team), building_id, complete)
	world.add_child(b)
	return b


func spawn_resource(resource_type: String, pos: Vector2, amount: int) -> ResourceNode:
	var n := ResourceNode.new()
	n.setup(resource_type, amount)
	n.position = pos
	world.add_child(n)
	return n


func spawn_projectile(team: int, from: Vector2, target, damage: float, speed: float, splash: float, color: Color, visual := "") -> void:
	var p := Projectile.new()
	p.visual = visual
	p.team = team
	p.target = target
	p.target_pos = target.global_position
	p.damage = damage
	p.speed = speed
	p.splash = splash
	p.color = color
	p.position = from
	world.add_child(p)


# ---------------------------------------------------------------- economy

func get_resource(team: int, resource_type: String) -> int:
	return int(get_player(team).resources.get(resource_type, 0))


func add_resource(team: int, resource_type: String, amount: int) -> void:
	var p := get_player(team)
	p.resources[resource_type] = int(p.resources.get(resource_type, 0)) + amount


func can_afford(team: int, cost: Dictionary) -> bool:
	for r in cost:
		if get_resource(team, r) < int(cost[r]):
			return false
	return true


func missing_resource_names(team: int, cost: Dictionary) -> String:
	var missing: PackedStringArray = []
	for r in cost:
		if get_resource(team, r) < int(cost[r]):
			missing.append(r)
	return ", ".join(missing)


func spend(team: int, cost: Dictionary) -> void:
	for r in cost:
		add_resource(team, r, -int(cost[r]))


func refund(team: int, cost: Dictionary) -> void:
	for r in cost:
		add_resource(team, r, int(cost[r]))


func has_completed_building(team: int, building_id: String) -> bool:
	for b in buildings:
		if Entity.alive(b) and b.team == team and b.def_id == building_id and b.is_complete:
			return true
	return false


func count_buildings(team: int, building_id: String) -> int:
	var n := 0
	for b in buildings:
		if Entity.alive(b) and b.team == team and b.def_id == building_id:
			n += 1
	return n


## Returns display names of required buildings the team hasn't finished yet.
func missing_requirements(team: int, requires: Array) -> Array:
	var missing: Array = []
	for bid in requires:
		if not has_completed_building(team, bid):
			missing.append(str(GameData.get_building_def(faction_of(team), bid).get("name", bid)))
	return missing


## Why the team can't start this building right now ("" means it can).
func build_blocker(team: int, building_id: String) -> String:
	var bdef := GameData.get_building_def(faction_of(team), building_id)
	var missing := missing_requirements(team, bdef.get("requires", []))
	if not missing.is_empty():
		return "Requires " + ", ".join(PackedStringArray(missing))
	var cost: Dictionary = bdef.get("cost", {})
	if not can_afford(team, cost):
		return "Not enough " + missing_resource_names(team, cost)
	return ""


func supply_cap(team: int) -> int:
	var cap := 0
	for b in buildings:
		if Entity.alive(b) and b.team == team and b.is_complete:
			cap += b.supply_provided
	return cap


func supply_used(team: int) -> int:
	var used := 0
	for u in units:
		if Entity.alive(u) and u.team == team:
			used += u.supply
	var fid := faction_of(team)
	for b in buildings:
		if Entity.alive(b) and b.team == team:
			for uid in b.train_queue:
				used += int(GameData.get_unit_def(fid, uid).get("supply", 1))
	return used


# ---------------------------------------------------------------- queries

func units_of(team: int) -> Array:
	return units.filter(func(u): return Entity.alive(u) and u.team == team)


func buildings_of(team: int) -> Array:
	return buildings.filter(func(b): return Entity.alive(b) and b.team == team)


func nearest_drop_off(team: int, resource_type: String, pos: Vector2) -> Building:
	var best: Building = null
	var best_d := INF
	for b in buildings:
		if not Entity.alive(b) or b.team != team or not b.is_complete:
			continue
		if not b.drop_off.has(resource_type):
			continue
		var d: float = b.edge_distance_to(pos)
		if d < best_d:
			best_d = d
			best = b
	return best


func nearest_resource(resource_type: String, pos: Vector2, max_dist: float = INF) -> ResourceNode:
	var best: ResourceNode = null
	var best_d := max_dist
	for n in resource_nodes:
		if not ResourceNode.alive(n) or n.resource_type != resource_type:
			continue
		var d: float = n.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = n
	return best


## Nearest hostile entity within max_dist. Units are preferred over buildings.
func nearest_enemy(team: int, pos: Vector2, max_dist: float):
	var best = null
	var best_d := max_dist
	for u in units:
		if Entity.alive(u) and u.team != team and u.team >= 0:
			var d: float = u.edge_distance_to(pos)
			if d < best_d:
				best_d = d
				best = u
	if best != null:
		return best
	best_d = max_dist
	for b in buildings:
		if Entity.alive(b) and b.team != team and b.team >= 0:
			var d: float = b.edge_distance_to(pos)
			if d < best_d:
				best_d = d
				best = b
	return best


func enemies_in_radius(team: int, pos: Vector2, r: float) -> Array:
	var out: Array = []
	for list in [units, buildings]:
		for e in list:
			if Entity.alive(e) and e.team != team and e.team >= 0 and e.edge_distance_to(pos) <= r:
				out.append(e)
	return out


## The thing under a world-space point (units first, then buildings, then resources).
func entity_at(pos: Vector2, slop: float = 0.0):
	var best = null
	var best_d := INF
	for u in units:
		if Entity.alive(u) and u.contains_point(pos, slop):
			var d: float = u.global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = u
	if best != null:
		return best
	for b in buildings:
		if Entity.alive(b) and b.contains_point(pos, slop * 0.5):
			return b
	for n in resource_nodes:
		if ResourceNode.alive(n) and n.contains_point(pos, slop):
			return n
	return null


## True if a building footprint fits here (inside the map, no overlaps).
func is_area_free(rect: Rect2) -> bool:
	if not map_rect().grow(-16).encloses(rect):
		return false
	for b in buildings:
		if Entity.alive(b) and b.get_rect().grow(8).intersects(rect):
			return false
	for n in resource_nodes:
		if ResourceNode.alive(n) and n.get_rect().intersects(rect):
			return false
	return true


# ---------------------------------------------------------------- events

func notify(team: int, text: String) -> void:
	if team == local_team:
		message_posted.emit(text)


func on_entity_damaged(e) -> void:
	if e.team != local_team or elapsed - _last_alert < ATTACK_ALERT_COOLDOWN:
		return
	_last_alert = elapsed
	message_posted.emit("Your base is under attack!" if e is Building else "Your units are under attack!")


func _check_victory() -> void:
	var alive_teams: Array = []
	for p in players:
		if not buildings_of(p.team).is_empty():
			alive_teams.append(p.team)
	if alive_teams.size() <= 1:
		running = false
		match_ended.emit(alive_teams[0] if alive_teams.size() == 1 else -1)
