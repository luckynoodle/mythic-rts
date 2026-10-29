class_name SimpleAI
extends Node
## A small scripted opponent driven by the faction's "ai" block in its JSON:
## keeps workers busy, follows a build order, trains an army and attacks in waves.

var team := 1
var think_interval := 1.0
## Seconds of peace before the first attack wave (gives new players time to learn).
var first_attack_time := 240.0
var wave_size := 4
var max_wave_size := 24

var _timer := 0.0
var _rng := RandomNumberGenerator.new()
var _faction: Dictionary = {}
var _ai: Dictionary = {}
var _army_index := 0
var _saving := false


func _ready() -> void:
	_rng.randomize()
	_faction = GameData.get_faction(Game.faction_of(team))
	_ai = _faction.get("ai", {})
	_timer = _rng.randf() * think_interval


func _physics_process(delta: float) -> void:
	if not Game.running:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = think_interval
	_think()


func _think() -> void:
	var my_buildings := Game.buildings_of(team)
	if my_buildings.is_empty():
		return
	var my_units := Game.units_of(team)
	var hq := _find_hq(my_buildings)
	var builders := my_units.filter(func(u): return u.is_builder())
	var army := my_units.filter(func(u): return u.can_fight())
	_manage_economy(builders, hq)
	_follow_build_order(builders, hq)
	_train_army(my_buildings)
	_manage_army(army, hq)


func _find_hq(my_buildings: Array) -> Building:
	var fallback: Building = null
	for b in my_buildings:
		if b.def_id == _faction.get("hq", "") and b.is_complete:
			return b
		if fallback == null:
			fallback = b
	return fallback


# ---------------------------------------------------------------- economy

func _manage_economy(builders: Array, hq: Building) -> void:
	var target_workers := int(_ai.get("target_workers", 8))
	var builder_id := str(_faction.get("builder", ""))
	if builders.size() < target_workers and hq and hq.is_complete and hq.train_queue.is_empty() and hq.trains.has(builder_id):
		hq.enqueue(builder_id)

	var counts := {}
	for r in GameData.RESOURCE_TYPES:
		counts[r] = 0
	for u in builders:
		if u.job_type != "" and (u.state == Unit.State.GATHER or u.state == Unit.State.RETURN):
			counts[u.job_type] += 1
	var origin: Vector2 = hq.global_position if hq else Game.MAP_SIZE * 0.5
	var priority := _resource_priority(counts)
	for u in builders:
		# Move one worker per think off a stockpiled resource onto a needed one.
		if u.state == Unit.State.GATHER and u.carry_amount == 0 and priority.size() > 0 \
				and Game.get_resource(team, u.job_type) >= int(_ai.get("stockpile_cap", 400)) \
				and Game.get_resource(team, priority[0]) < int(_ai.get("stockpile_cap", 400)):
			var n := Game.nearest_resource(priority[0], origin, 1400.0)
			if n:
				counts[u.job_type] -= 1
				u.command_gather(n)
				counts[n.resource_type] += 1
				priority = _resource_priority(counts)
				break
	for u in builders:
		if u.state != Unit.State.IDLE:
			continue
		var node: ResourceNode = null
		for r in _resource_priority(counts):
			node = Game.nearest_resource(r, origin, 1400.0)
			if node:
				break
		if node == null:
			node = _any_resource(u.global_position)
		if node:
			u.command_gather(node)
			counts[node.resource_type] += 1


## Resource types ordered by how far below the desired worker ratio they are.
func _resource_priority(counts: Dictionary) -> Array:
	var ratio: Dictionary = _ai.get("gather_ratio", {"gold": 0.5, "wood": 0.35, "stone": 0.15})
	var stockpile_cap := int(_ai.get("stockpile_cap", 400))
	var needed: Array = []
	var stocked: Array = []
	for r in ratio.keys():
		# Don't keep mining something we already have plenty of.
		if Game.get_resource(team, r) >= stockpile_cap:
			stocked.append(r)
		else:
			needed.append(r)
	needed.sort_custom(func(a, b):
		return float(counts.get(a, 0)) / maxf(0.01, float(ratio[a])) < float(counts.get(b, 0)) / maxf(0.01, float(ratio[b])))
	return needed + stocked


func _any_resource(pos: Vector2) -> ResourceNode:
	for r in GameData.RESOURCE_TYPES:
		var n := Game.nearest_resource(r, pos)
		if n:
			return n
	return null


# ---------------------------------------------------------------- construction

func _follow_build_order(builders: Array, hq: Building) -> void:
	_saving = false
	if hq == null:
		return
	var next_bid := ""
	var tally := {}
	for bid in _ai.get("build_order", []):
		tally[bid] = tally.get(bid, 0) + 1
		if Game.count_buildings(team, bid) < tally[bid]:
			next_bid = bid
			break
	var supply_bid := str(_faction.get("supply_building", ""))
	var headroom := Game.supply_cap(team) - Game.supply_used(team)
	if supply_bid != "" and headroom <= 2 and not _has_unfinished(supply_bid):
		next_bid = supply_bid
	if next_bid == "" or _unfinished_count() >= 2:
		return
	var reason := Game.build_blocker(team, next_bid)
	if reason != "":
		_saving = reason.begins_with("Not enough")
		return
	var builder = _pick_builder(builders, hq.global_position)
	if builder == null:
		return
	var bdef := GameData.get_building_def(Game.faction_of(team), next_bid)
	var s: Array = bdef.get("size", [64, 64])
	var spot = _find_build_spot(hq.global_position, Vector2(float(s[0]), float(s[1])))
	if spot == null:
		return
	Game.spend(team, bdef.get("cost", {}))
	var site := Game.spawn_building(team, next_bid, spot, false)
	builder.command_build(site)


func _has_unfinished(bid: String) -> bool:
	for b in Game.buildings_of(team):
		if b.def_id == bid and not b.is_complete:
			return true
	return false


func _unfinished_count() -> int:
	return Game.buildings_of(team).filter(func(b): return not b.is_complete).size()


func _pick_builder(builders: Array, near: Vector2):
	var best = null
	var best_d := INF
	for u in builders:
		if u.state == Unit.State.BUILD:
			continue
		var d: float = u.global_position.distance_to(near)
		if d < best_d:
			best_d = d
			best = u
	return best


func _find_build_spot(center: Vector2, size: Vector2):
	for i in 50:
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(170.0, 480.0)
		var p := (center + Vector2(cos(angle), sin(angle)) * dist).snapped(Vector2(16, 16))
		# Leave walking lanes between buildings.
		if Game.is_area_free(Rect2(p - size * 0.5, size).grow(28)):
			return p
	return null


# ---------------------------------------------------------------- army

func _train_army(my_buildings: Array) -> void:
	var army_list: Array = _ai.get("army", [])
	if army_list.is_empty():
		return
	if _saving and _rng.randf() < 0.6:
		return  # let resources pile up for the next building
	for b in my_buildings:
		if not b.is_complete or b.train_queue.size() >= 2:
			continue
		for k in army_list.size():
			var uid: String = army_list[(_army_index + k) % army_list.size()]
			if b.trains.has(uid) and b.can_train(uid) == "":
				b.enqueue(uid)
				_army_index = (_army_index + k + 1) % army_list.size()
				break


func _manage_army(army: Array, hq: Building) -> void:
	var idle := army.filter(func(u): return u.state == Unit.State.IDLE)
	# Defend the base first.
	if hq:
		var threat = Game.nearest_enemy(team, hq.global_position, 650.0)
		if threat != null:
			for u in idle:
				u.command_attack(threat)
			return
	if Game.elapsed < first_attack_time or idle.size() < wave_size:
		return
	var target_pos = _enemy_target(hq.global_position if hq else Game.MAP_SIZE * 0.5)
	if target_pos == null:
		return
	for u in idle:
		u.command_move(target_pos + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-60, 60)), true)
	wave_size = mini(wave_size + 2, max_wave_size)


func _enemy_target(from: Vector2):
	var best = null
	var best_d := INF
	for b in Game.buildings:
		if Entity.alive(b) and b.team != team and b.team >= 0:
			var d: float = b.global_position.distance_to(from)
			if d < best_d:
				best_d = d
				best = b.global_position
	return best
