class_name TouchInput
extends Node
## Turns touch gestures into RTS selection and commands.
##
##   Tap own unit/building ........ select it
##   Double-tap own unit .......... select all of that type on screen
##   Tap ground / enemy / resource  command the selection (move / attack / gather)
##   One-finger drag .............. pan the camera (or draw a box in Box Select mode)
##   Two-finger pinch / drag ...... zoom / pan
##
## On desktop, the left mouse emulates touch, the wheel zooms and right-click commands.
##
## The camera is a 3D RTSCamera, but it works in game-world pixels, so all game
## logic here stays 2D. Taps are matched against what is drawn on screen
## (a unit's whole body, a building's whole volume), not just its footprint.

signal selection_changed

const TAP_MAX_MOVE := 16.0     # screen pixels
const TAP_MAX_TIME := 0.4      # seconds
const DOUBLE_TAP_TIME := 0.35
const TAP_SLOP := 18.0         # extra screen-pixel radius that makes small units easy to hit
const SNAP := 16.0
const FORMATION_SPACING := 30.0

var camera: RTSCamera
var hud = null
var team := 0

var selection: Array = []
var select_mode := false        # next one-finger drag draws a selection box
var attack_move_armed := false  # next ground tap issues an attack-move
var placing := ""               # building id being placed; "" when not placing
var ghost: PlacementGhost = null

var _touches := {}   # index -> {"start", "pos", "time", "over_ui"}
var _gesture := ""   # "", "pan", "box", "pinch", "pinch_done", "ghost"
var _pinch_dist := 1.0
var _pinch_zoom := 1.0
var _pinch_mid := Vector2.ZERO
var _last_tap_time := -10.0
var _last_tap_hit = null


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func screen_to_world(p: Vector2) -> Vector2:
	return camera.screen_to_world(p)


func _process(_delta: float) -> void:
	var before := selection.size()
	selection = selection.filter(func(e): return Entity.alive(e))
	if selection.size() != before:
		selection_changed.emit()


# ---------------------------------------------------------------- raw input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(camera.zoom * 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(camera.zoom / 1.1)
			MOUSE_BUTTON_RIGHT:
				if placing == "":
					command_at(screen_to_world(event.position), pick_at(event.position))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_placement()
		set_selection([])


func _active_touches() -> Array:
	var out: Array = []
	for idx in _touches:
		if not _touches[idx]["over_ui"]:
			out.append(idx)
	return out


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		var over_ui: bool = hud != null and hud.blocks(e.position)
		_touches[e.index] = {"start": e.position, "pos": e.position, "time": _now(), "over_ui": over_ui}
		if over_ui:
			return
		var active := _active_touches()
		if active.size() >= 2:
			_begin_pinch(active)
		elif active.size() == 1 and placing != "" and _ghost_hit(e.position):
			_gesture = "ghost"
		return

	if not _touches.has(e.index):
		return
	var t: Dictionary = _touches[e.index]
	_touches.erase(e.index)
	if t["over_ui"]:
		return
	var is_tap: bool = (e.position - t["start"]).length() <= TAP_MAX_MOVE and _now() - t["time"] <= TAP_MAX_TIME
	match _gesture:
		"box":
			_finish_box(t["start"], e.position)
		"ghost":
			if is_tap:
				var err := confirm_placement()
				if err != "" and hud:
					hud.show_message(err)
		"":
			if is_tap and _active_touches().is_empty():
				_handle_tap(e.position)
	if _active_touches().is_empty():
		_gesture = ""
	elif _gesture == "pinch":
		_gesture = "pinch_done"  # the remaining finger shouldn't pan or tap


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	var t: Dictionary = _touches[e.index]
	if t["over_ui"]:
		return
	t["pos"] = e.position
	var active := _active_touches()
	if _gesture == "pinch":
		if active.size() >= 2:
			_update_pinch(active)
		return
	if _gesture == "pinch_done" or active.size() != 1:
		return
	if _gesture == "":
		if (e.position - t["start"]).length() <= TAP_MAX_MOVE:
			return
		_gesture = "box" if select_mode else "pan"
	match _gesture:
		"pan":
			camera.pan_screen(e.position - e.relative, e.position)
		"box":
			if hud:
				hud.show_box(Rect2(t["start"], e.position - t["start"]).abs())
		"ghost":
			_move_ghost(screen_to_world(e.position))


# ---------------------------------------------------------------- camera

func _set_zoom(z: float) -> void:
	camera.zoom = z


## Keeps the camera over the map.
func clamp_camera() -> void:
	camera.clamp_focus()


func focus_on(world_pos: Vector2) -> void:
	camera.focus = world_pos
	clamp_camera()


func _begin_pinch(active: Array) -> void:
	_gesture = "pinch"
	if hud:
		hud.hide_box()
	var a: Vector2 = _touches[active[0]]["pos"]
	var b: Vector2 = _touches[active[1]]["pos"]
	_pinch_dist = maxf(1.0, a.distance_to(b))
	_pinch_zoom = camera.zoom
	_pinch_mid = (a + b) * 0.5


func _update_pinch(active: Array) -> void:
	var a: Vector2 = _touches[active[0]]["pos"]
	var b: Vector2 = _touches[active[1]]["pos"]
	var mid := (a + b) * 0.5
	_set_zoom(_pinch_zoom * a.distance_to(b) / _pinch_dist)
	camera.pan_screen(_pinch_mid, mid)
	_pinch_mid = mid


# ---------------------------------------------------------------- taps & commands

func _handle_tap(screen_pos: Vector2) -> void:
	var wp := screen_to_world(screen_pos)
	if placing != "":
		_move_ghost(wp)
		return
	var hit = pick_at(screen_pos)
	var now := _now()
	var is_double: bool = hit != null and hit == _last_tap_hit and now - _last_tap_time <= DOUBLE_TAP_TIME
	_last_tap_time = now
	_last_tap_hit = hit

	if hit is Entity and hit.team == team:
		# Builders tapped onto an unfinished building help construct it.
		if hit is Building and not hit.is_complete and not selected_builders().is_empty():
			command_at(wp, hit)
			return
		if is_double and hit is Unit:
			_select_same_type_on_screen(hit)
		else:
			set_selection([hit])
		return
	if attack_move_armed and not (hit is Entity):
		_attack_move_to(wp)
		return
	command_at(wp, hit)


## Issues the "smart" command for the current selection at a world position.
func command_at(wp: Vector2, hit = null) -> void:
	var units := selected_own_units()
	var building := selected_own_building()

	if hit is Entity and hit.team == team:
		if hit is Building and not hit.is_complete:
			for u in selected_builders():
				u.command_build(hit)
			_marker(hit.global_position, Color(1.0, 0.85, 0.3))
		return

	if hit is Entity and hit.team != team:
		if units.is_empty():
			set_selection([hit])  # inspect the enemy
			return
		for u in units:
			if u.can_fight():
				u.command_attack(hit)
			else:
				u.command_move(hit.global_position)
		_marker(hit.global_position, Color(1.0, 0.3, 0.3))
		return

	if hit is ResourceNode:
		if not units.is_empty():
			for u in units:
				if u.carry_capacity > 0:
					u.command_gather(hit)
				else:
					u.command_move(hit.global_position)
			_marker(hit.global_position, Color(1.0, 0.9, 0.35))
		elif building and not building.trains.is_empty():
			building.set_rally(hit.global_position, hit)
			_marker(hit.global_position, Color(1.0, 0.9, 0.35))
		return

	if not units.is_empty():
		_move_group(units, wp, false)
		_marker(wp, Color(0.45, 1.0, 0.45))
		return
	if building and not building.trains.is_empty():
		building.set_rally(wp)
		_marker(wp, Color(0.45, 1.0, 0.45))
		return
	set_selection([])


func arm_attack_move() -> void:
	attack_move_armed = true
	selection_changed.emit()


func _attack_move_to(wp: Vector2) -> void:
	attack_move_armed = false
	_move_group(selected_own_units(), wp, true)
	_marker(wp, Color(1.0, 0.45, 0.3))
	selection_changed.emit()


func _move_group(units: Array, wp: Vector2, attack_move: bool) -> void:
	var n := units.size()
	var cols := int(ceil(sqrt(float(n))))
	var rows := int(ceil(float(n) / float(cols)))
	for i in n:
		var col := i % cols
		var row := i / cols
		var offset := Vector2((col - (cols - 1) * 0.5) * FORMATION_SPACING,
				(row - (rows - 1) * 0.5) * FORMATION_SPACING)
		units[i].command_move(wp + offset, attack_move)


func _marker(pos: Vector2, color: Color) -> void:
	var m := CommandMarker.new()
	m.color = color
	m.position = pos
	Game.world.add_child(m)


# ---------------------------------------------------------------- picking

## What the player tapped: the unit, building or resource drawn under `screen_pos`.
## Units win over buildings, which win over resources; the closest on screen wins.
func pick_at(screen_pos: Vector2):
	var best = null
	var best_d := INF
	for u in Game.units:
		if not Entity.alive(u):
			continue
		var d := _distance_to_upright(screen_pos, u.global_position, u.radius, ViewSpace.unit_height(u.def))
		if d < best_d:
			best_d = d
			best = u
	if best != null:
		return best
	for b in Game.buildings:
		if not Entity.alive(b):
			continue
		var rect := _building_screen_rect(b)
		if rect.has_area() and rect.grow(TAP_SLOP * 0.5).has_point(screen_pos):
			return b
	for n in Game.resource_nodes:
		if not ResourceNode.alive(n):
			continue
		var d := _distance_to_upright(screen_pos, n.global_position, n.radius, ViewSpace.resource_height(n.resource_type))
		if d < best_d:
			best_d = d
			best = n
	return best


## Returns a "hit score" (lower is better) if screen_pos lies on an upright thing
## standing at `world_pos`, or INF if it misses.
func _distance_to_upright(screen_pos: Vector2, world_pos: Vector2, radius_px: float, height_m: float) -> float:
	if not _projects_sanely(world_pos, height_m):
		return INF
	var feet := camera.world_to_screen(world_pos)
	var top := camera.world_to_screen(world_pos, height_m)
	var side := camera.world_to_screen(world_pos + Vector2(radius_px, 0))
	var r := feet.distance_to(side) + TAP_SLOP
	var d := Geometry2D.get_closest_point_to_segment(screen_pos, feet, top).distance_to(screen_pos)
	return d if d <= r else INF


## False for things behind (or nearly behind) the camera, whose projected
## screen positions are meaningless and would otherwise steal taps.
func _projects_sanely(world_pos: Vector2, height_m: float) -> bool:
	for h in [0.0, height_m]:
		if camera.is_position_behind(ViewSpace.to_3d(world_pos, h)):
			return false
	var vis := get_viewport().get_visible_rect().grow(400.0)
	return vis.has_point(camera.world_to_screen(world_pos)) or vis.has_point(camera.world_to_screen(world_pos, height_m))


func _building_screen_rect(b: Building) -> Rect2:
	var r := b.get_rect()
	var h := ViewSpace.building_height(b.def)
	if not _projects_sanely(b.global_position, h):
		return Rect2()
	var rect := Rect2(camera.world_to_screen(r.position), Vector2.ZERO)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		for height in [0.0, h]:
			rect = rect.expand(camera.world_to_screen(corner, height))
	return rect


# ---------------------------------------------------------------- selection

func set_selection(list: Array) -> void:
	for e in selection:
		if Entity.alive(e):
			e.selected = false
	selection = list.filter(func(e): return Entity.alive(e))
	for e in selection:
		e.selected = true
	attack_move_armed = false
	selection_changed.emit()


func selected_own_units() -> Array:
	return selection.filter(func(e): return e is Unit and e.team == team and Entity.alive(e))


func selected_builders() -> Array:
	return selected_own_units().filter(func(u): return u.is_builder())


func selected_own_building() -> Building:
	if selection.size() == 1 and selection[0] is Building and selection[0].team == team:
		return selection[0]
	return null


func select_army() -> void:
	set_selection(Game.units_of(team).filter(func(u): return u.can_fight()))


## Selects the next idle builder (cycling) and centres the camera on it.
func select_idle_builder() -> void:
	var idle := Game.units_of(team).filter(func(u): return u.is_builder() and u.state == Unit.State.IDLE)
	if idle.is_empty():
		if hud:
			hud.show_message("No idle workers")
		return
	var pick = idle[0]
	if selection.size() == 1 and idle.has(selection[0]):
		pick = idle[(idle.find(selection[0]) + 1) % idle.size()]
	set_selection([pick])
	focus_on(pick.global_position)


func _select_same_type_on_screen(u: Unit) -> void:
	set_selection(Game.units_of(team).filter(
			func(o): return o.def_id == u.def_id and camera.is_on_screen(o.global_position)))


func toggle_select_mode(on: bool) -> void:
	select_mode = on
	selection_changed.emit()


func _finish_box(start_screen: Vector2, end_screen: Vector2) -> void:
	if hud:
		hud.hide_box()
	# Box select happens in screen space, which is what the player sees.
	var r := Rect2(start_screen, end_screen - start_screen).abs().grow(6.0)
	var picked := Game.units_of(team).filter(func(u):
		var h := ViewSpace.unit_height(u.def) * 0.5
		return r.has_point(camera.world_to_screen(u.global_position, h)))
	select_mode = false
	if not picked.is_empty():
		set_selection(picked)
	else:
		selection_changed.emit()


# ---------------------------------------------------------------- building placement

func start_placement(building_id: String) -> void:
	cancel_placement()
	var bdef := GameData.get_building_def(Game.faction_of(team), building_id)
	placing = building_id
	ghost = PlacementGhost.new()
	var s: Array = bdef.get("size", [64, 64])
	ghost.size = Vector2(float(s[0]), float(s[1]))
	ghost.label = str(bdef.get("name", building_id))
	Game.world.add_child(ghost)
	var vis := get_viewport().get_visible_rect()
	_move_ghost(screen_to_world(vis.position + vis.size * 0.5))
	selection_changed.emit()


func cancel_placement() -> void:
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	if placing != "":
		placing = ""
		selection_changed.emit()


func _ghost_rect() -> Rect2:
	return Rect2(ghost.position - ghost.size * 0.5, ghost.size)


func _ghost_hit(screen_pos: Vector2) -> bool:
	if ghost == null:
		return false
	return _ghost_rect().grow(TAP_SLOP * camera.world_px_per_screen_px()).has_point(screen_to_world(screen_pos))


func _move_ghost(wp: Vector2) -> void:
	if ghost == null:
		return
	ghost.position = wp.snapped(Vector2(SNAP, SNAP))
	ghost.valid = Game.is_area_free(_ghost_rect())
	ghost.queue_redraw()


## Places the building at the ghost. Returns an error message, or "" on success.
func confirm_placement() -> String:
	if placing == "" or ghost == null:
		return ""
	var builders := selected_builders()
	if builders.is_empty():
		return "Select a builder first"
	if not Game.is_area_free(_ghost_rect()):
		return "Can't build there"
	var blocker := Game.build_blocker(team, placing)
	if blocker != "":
		return blocker
	Game.spend(team, GameData.get_building_def(Game.faction_of(team), placing).get("cost", {}))
	var site := Game.spawn_building(team, placing, ghost.position, false)
	for u in builders:
		u.command_build(site)
	_marker(site.global_position, Color(1.0, 0.85, 0.3))
	cancel_placement()
	return ""
