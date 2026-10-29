extends Node
## Automated touch-control test. Simulates real touch events through Godot's input
## pipeline against the main scene and checks the results.
##
## Run: godot --headless -- --run-input-tests
## (main.gd adds this node when it sees that flag, so autoloads are available.)

var _failures := 0
var main: Node
var input_ctrl: TouchInput
var hud: HUD


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	main = get_parent()
	input_ctrl = main.input_ctrl
	hud = main.hud
	# Freeze the AI so it doesn't interfere.
	for n in main.get_children():
		if n is SimpleAI:
			n.process_mode = Node.PROCESS_MODE_DISABLED

	await _test_tap_select()
	await _test_double_tap()
	await _test_tap_move()
	await _test_tap_gather()
	await _test_train_from_building()
	await _test_build_placement()
	await _test_hud_blocks_world_taps()
	await _test_box_select()
	await _test_pan_and_pinch()

	print("INPUT_TESTS %s (%d failure(s))" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- tests

func _test_tap_select() -> void:
	var peasant := _own_unit("peasant")
	await _look_at(peasant.global_position)
	await _tap(_to_screen(peasant.global_position))
	_check(input_ctrl.selection == [peasant], "tapping a peasant selects it")
	_check(peasant.selected, "selected peasant is flagged as selected")


func _test_double_tap() -> void:
	var peasant := _own_unit("peasant")
	await _look_at(peasant.global_position)
	await _tap(_to_screen(peasant.global_position))
	await _tap(_to_screen(peasant.global_position), true)
	var peasants := input_ctrl.selected_own_units().filter(func(u): return u.def_id == "peasant").size()
	_check(peasants >= 3, "double-tapping a peasant selects every peasant on screen (got %d)" % peasants)
	await _tap(_to_screen(peasant.global_position))
	_check(input_ctrl.selection == [peasant], "a single tap goes back to one unit")


func _test_tap_move() -> void:
	var peasant: Unit = input_ctrl.selection[0]
	var dest := _free_spot(peasant.global_position, Vector2(40, 40))
	await _tap(_to_screen(dest))
	_check(peasant.state == Unit.State.MOVE, "tapping the ground orders a move")
	await _frames(90)
	_check(peasant.global_position.distance_to(dest) < 30.0, "peasant arrives at the destination")


func _test_tap_gather() -> void:
	var peasant: Unit = input_ctrl.selection[0]
	var mine := Game.nearest_resource("gold", peasant.global_position)
	await _look_at(mine.global_position)
	await _tap(_to_screen(mine.global_position))
	_check(peasant.state == Unit.State.GATHER and peasant.job_type == "gold", "tapping a gold mine starts gathering")
	var gold_before := Game.get_resource(0, "gold")
	await _frames(60 * 14)
	_check(Game.get_resource(0, "gold") > gold_before,
			"gathered gold is delivered to the town hall (state=%s carry=%d)" % [Unit.State.keys()[peasant.state], peasant.carry_amount])


func _test_train_from_building() -> void:
	var hall := _own_building("town_hall")
	await _look_at(hall.global_position)
	await _tap(_to_screen(hall.global_position))
	_check(input_ctrl.selected_own_building() == hall, "tapping the town hall selects it")
	await _frames(2)
	var btn := _find_action("Peasant")
	_check(btn != null, "town hall shows a Peasant button")
	if btn:
		await _tap(btn.get_global_rect().get_center())
		_check(hall.train_queue.size() == 1, "tapping the Peasant button queues a peasant")
		var units_before := Game.units_of(0).size()
		await _frames(60 * 11)
		_check(Game.units_of(0).size() == units_before + 1, "the peasant finishes training")


func _test_build_placement() -> void:
	Game.add_resource(0, "wood", 500)
	var peasant := _own_unit("peasant")
	await _look_at(peasant.global_position)
	await _tap(_to_screen(peasant.global_position))
	await _frames(2)
	var btn := _find_action("Farm")
	_check(btn != null, "builders show a Farm button")
	if btn == null:
		return
	await _tap(btn.get_global_rect().get_center())
	_check(input_ctrl.placing == "farm", "Farm button enters placement mode")
	var hall_pos := _own_building("town_hall").global_position
	var spot := _free_spot(hall_pos + Vector2(250, 0), Vector2(110, 110))
	await _look_at(spot)
	await _tap(_to_screen(spot))
	_check(input_ctrl.ghost != null and input_ctrl.ghost.position.distance_to(spot) < 20.0, "tapping moves the placement ghost")
	if input_ctrl.ghost == null:
		return
	var drag_to := _free_spot(spot + Vector2(0, 120), Vector2(110, 110))
	await _drag(_to_screen(spot), _to_screen(drag_to))
	_check(input_ctrl.ghost.position.distance_to(drag_to) < 20.0, "dragging the ghost moves it")
	var sites_before := Game.buildings_of(0).size()
	await _tap(_to_screen(input_ctrl.ghost.position))
	await _frames(2)
	_check(Game.buildings_of(0).size() == sites_before + 1,
			"tapping the ghost places a construction site (hud says: '%s')" % hud._message.text)
	_check(peasant.state == Unit.State.BUILD, "selected builder goes to construct it")
	await _frames(60 * 30)
	var farm := _own_building("farm")
	_check(farm != null and farm.is_complete, "the farm finishes construction")


func _test_hud_blocks_world_taps() -> void:
	var peasant := _own_unit("peasant")
	await _look_at(peasant.global_position)
	await _tap(_to_screen(peasant.global_position))
	var top_bar_point := Vector2(hud.get_viewport().get_visible_rect().size.x * 0.3, 30)
	await _tap(top_bar_point)
	_check(input_ctrl.selection == [peasant], "tapping the HUD does not deselect or command")


func _test_box_select() -> void:
	input_ctrl.set_selection([])
	input_ctrl.toggle_select_mode(true)
	var hall := _own_building("town_hall")
	await _look_at(hall.global_position + Vector2(0, 200))
	var a := _to_screen(hall.global_position + Vector2(-300, 40))
	var b := _to_screen(hall.global_position + Vector2(300, 400))
	await _drag(a, b)
	var picked := input_ctrl.selected_own_units().size()
	_check(picked >= 2, "box select picks up several units (got %d)" % picked)
	_check(not input_ctrl.select_mode, "box select mode turns itself off")


func _test_pan_and_pinch() -> void:
	var cam := input_ctrl.camera
	await _look_at(Game.MAP_SIZE * 0.5)
	var start := cam.position
	await _drag(Vector2(640, 360), Vector2(540, 360))
	_check(cam.position.x > start.x + 50.0, "one-finger drag pans the camera")
	var zoom_before := cam.zoom.x
	await _pinch(Vector2(640, 360), 80.0, 160.0)
	_check(cam.zoom.x > zoom_before * 1.5, "pinching out zooms in (%.2f -> %.2f)" % [zoom_before, cam.zoom.x])


# ---------------------------------------------------------------- helpers

## Centres the camera on a world position so taps there land on the map, not the HUD.
func _look_at(world_pos: Vector2) -> void:
	input_ctrl.camera.position = world_pos
	input_ctrl.clamp_camera()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _to_screen(world_pos: Vector2) -> Vector2:
	return main.get_viewport().get_canvas_transform() * world_pos


## Converts a viewport position to window coordinates, which is what real touch
## events carry (the engine maps them back through the stretch transform).
func _to_window(pos: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * pos


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = _to_window(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag_event(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = _to_window(pos)
	e.relative = main.get_viewport().get_final_transform().basis_xform(rel)
	Input.parse_input_event(e)


## A single tap. Headless runs are much faster than real time, so we clear the
## double-tap memory first unless `allow_double` is set.
func _tap(pos: Vector2, allow_double := false) -> void:
	if not allow_double:
		input_ctrl._last_tap_hit = null
	_touch(0, pos, true)
	await _frames(2)
	_touch(0, pos, false)
	await _frames(2)


func _drag(from: Vector2, to: Vector2) -> void:
	_touch(0, from, true)
	await _frames(1)
	var steps := 8
	var prev := from
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		_drag_event(0, p, p - prev)
		prev = p
		await _frames(1)
	_touch(0, to, false)
	await _frames(2)


func _pinch(center: Vector2, from_half: float, to_half: float) -> void:
	_touch(0, center - Vector2(from_half, 0), true)
	_touch(1, center + Vector2(from_half, 0), true)
	await _frames(2)
	for i in range(1, 9):
		var h := lerpf(from_half, to_half, i / 8.0)
		_drag_event(0, center - Vector2(h, 0), Vector2.ZERO)
		_drag_event(1, center + Vector2(h, 0), Vector2.ZERO)
		await _frames(1)
	_touch(0, center - Vector2(to_half, 0), false)
	_touch(1, center + Vector2(to_half, 0), false)
	await _frames(2)


## Finds open ground near `near` (no units, buildings or resources in a box of `size`).
func _free_spot(near: Vector2, size: Vector2) -> Vector2:
	for ring in range(0, 12):
		for k in 12:
			var p := near + Vector2.from_angle(TAU * k / 12.0) * 40.0 * ring
			p = p.snapped(Vector2(16, 16))
			var r := Rect2(p - size * 0.5, size)
			if not Game.is_area_free(r):
				continue
			if Game.units.any(func(u): return r.grow(u.radius).has_point(u.global_position)):
				continue
			return p
	return near


func _own_unit(def_id: String) -> Unit:
	for u in Game.units_of(0):
		if u.def_id == def_id:
			return u
	return null


func _own_building(def_id: String) -> Building:
	for b in Game.buildings_of(0):
		if b.def_id == def_id:
			return b
	return null


func _find_action(title: String) -> Button:
	for c in hud._actions.get_children():
		if c is Button and not c.is_queued_for_deletion() and c.text.begins_with(title):
			return c
	return null


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   - ", what)
	else:
		_failures += 1
		print("  FAIL - ", what)
