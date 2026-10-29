extends Node2D
## Builds a skirmish match: the map, both bases, the 3D view, the HUD, input and the AI.
##
## The simulation lives in a hidden 2D "World" node; WorldView renders it in 3D.
##
## Command-line options (after `--`), used for automated testing:
##   --ai-vs-ai               the AI plays both sides
##   --quit-after-seconds=N   quit after N seconds of game time and print a summary
##   --run-input-tests        run tests/input_test.gd (simulated touch input) and quit
##   --run-model-tests        run tests/model_test.gd (3D model pipeline) and quit
##   --screenshots=DIR        save review screenshots to DIR (tests/screenshots.gd), then quit

const PLAYER_TEAM := 0
const AI_TEAM := 1

@export var player_faction := "humans"
@export var ai_faction := "orcs"
@export var map_seed := 1337

var view: WorldView
var hud: HUD
var input_ctrl: TouchInput

var _ai_vs_ai := false
var _run_input_tests := false
var _screenshot_dir := ""
var _run_model_tests := false
var _quit_after := -1.0
var _report_timer := 0.0


func _ready() -> void:
	_parse_args()
	Game.reset()
	Game.local_team = PLAYER_TEAM

	var world := Node2D.new()
	world.name = "World"
	world.visible = false  # simulation only; WorldView draws everything in 3D
	add_child(world)
	Game.world = world

	Game.add_player(PLAYER_TEAM, player_faction, _ai_vs_ai)
	Game.add_player(AI_TEAM, ai_faction, true)
	var bases := _build_map()

	Game.refresh_snapshots()
	view = WorldView.new()
	add_child(view)
	view.camera.zoom = 1.25
	view.camera.focus = bases[PLAYER_TEAM] + Vector2(160, 40)

	input_ctrl = TouchInput.new()
	input_ctrl.camera = view.camera
	view.input_ctrl = input_ctrl
	input_ctrl.team = PLAYER_TEAM
	hud = HUD.new()
	hud.team = PLAYER_TEAM
	hud.input_ctrl = input_ctrl
	input_ctrl.hud = hud
	add_child(input_ctrl)
	add_child(hud)

	_add_ai(AI_TEAM)
	if _ai_vs_ai:
		_add_ai(PLAYER_TEAM)

	Game.refresh_snapshots()
	Game.running = true
	Game.match_ended.connect(_on_match_ended)

	if _run_input_tests:
		var tests: Node = load("res://tests/input_test.gd").new()
		tests.name = "InputTests"
		add_child(tests)
	if _run_model_tests:
		var mt: Node = load("res://tests/model_test.gd").new()
		mt.name = "ModelTests"
		add_child(mt)
	if _screenshot_dir != "":
		var shots: Node = load("res://tests/screenshots.gd").new()
		shots.out_dir = _screenshot_dir
		add_child(shots)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--ai-vs-ai":
			_ai_vs_ai = true
		elif arg == "--run-input-tests":
			_run_input_tests = true
		elif arg == "--run-model-tests":
			_run_model_tests = true
		elif arg.begins_with("--screenshots="):
			_screenshot_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--quit-after-seconds="):
			_quit_after = float(arg.get_slice("=", 1))


func _add_ai(team: int) -> void:
	var ai := SimpleAI.new()
	ai.name = "AI_%d" % team
	ai.team = team
	if _ai_vs_ai:
		ai.first_attack_time = 120.0
	add_child(ai)


func _physics_process(delta: float) -> void:
	if _quit_after < 0.0:
		return
	_report_timer -= delta
	if _report_timer <= 0.0:
		_report_timer = 30.0
		_print_status()
	if Game.elapsed >= _quit_after:
		_print_status()
		print("MATCH_SUMMARY time=%.0f running=%s" % [Game.elapsed, Game.running])
		get_tree().quit()


func _print_status() -> void:
	for p in Game.players:
		var units := Game.units_of(p.team)
		var builders := units.filter(func(u): return u.is_builder()).size()
		print("[t=%4.0fs] %-7s gold=%4d wood=%4d stone=%4d workers=%2d army=%2d buildings=%2d supply=%d/%d" % [
			Game.elapsed, p.faction_id, p.resources["gold"], p.resources["wood"], p.resources["stone"],
			builders, units.size() - builders, Game.buildings_of(p.team).size(),
			Game.supply_used(p.team), Game.supply_cap(p.team)])
		if OS.get_cmdline_user_args().has("--debug-workers"):
			var jobs := {}
			for u in units:
				if u.is_builder():
					var k := "%s/%s" % [u.job_type, Unit.State.keys()[u.state]]
					jobs[k] = jobs.get(k, 0) + 1
			print("    jobs: ", jobs)


func _on_match_ended(winning_team: int) -> void:
	var winner := Game.get_player(winning_team)
	print("MATCH_OVER winner=%s time=%.0f" % [winner.faction_id if winner else "none", Game.elapsed])
	if _quit_after >= 0.0:
		_print_status()
		print("MATCH_SUMMARY time=%.0f running=false" % Game.elapsed)
		get_tree().quit()


# ---------------------------------------------------------------- map

## Places both bases and the resources. Returns {team: hq_position}.
func _build_map() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var size := Game.MAP_SIZE
	var bases := {
		PLAYER_TEAM: Vector2(420, size.y * 0.5),
		AI_TEAM: Vector2(size.x - 420, size.y * 0.5),
	}
	_setup_base(PLAYER_TEAM, bases[PLAYER_TEAM], -1.0, rng)
	_setup_base(AI_TEAM, bases[AI_TEAM], 1.0, rng)

	# Contested resources in the middle of the map.
	var c := size * 0.5
	Game.spawn_resource("gold", c + Vector2(0, -560), 6000)
	Game.spawn_resource("gold", c + Vector2(0, 560), 6000)
	Game.spawn_resource("stone", c + Vector2(-320, 0), 2500)
	Game.spawn_resource("stone", c + Vector2(320, 0), 2500)
	_tree_cluster(c, 14, 200.0, rng)
	for x in [size.x * 0.3, size.x * 0.7]:
		_tree_cluster(Vector2(x, 260), 12, 220.0, rng)
		_tree_cluster(Vector2(x, size.y - 260), 12, 220.0, rng)
	return bases


## side = -1 for a base on the left edge, +1 for the right edge.
func _setup_base(team: int, pos: Vector2, side: float, rng: RandomNumberGenerator) -> void:
	var f := GameData.get_faction(Game.faction_of(team))
	Game.spawn_building(team, str(f.get("hq", "")), pos, true)
	Game.refresh_snapshots()
	var units: Array = f.get("starting_units", [])
	for i in units.size():
		var offset := Vector2((float(i) - units.size() * 0.5) * 30.0 * -side, 100.0)
		Game.spawn_unit(team, units[i], pos + offset)
	Game.spawn_resource("gold", pos + Vector2(40.0 * -side, -280), 4000)
	Game.spawn_resource("stone", pos + Vector2(220.0 * side, -60), 1500)
	_tree_cluster(pos + Vector2(150.0 * side, 330), 12, 130.0, rng)
	_tree_cluster(pos + Vector2(-260.0 * side, 320), 8, 110.0, rng)


func _tree_cluster(center: Vector2, count: int, spread: float, rng: RandomNumberGenerator) -> void:
	var placed: Array = []
	var tries := 0
	while placed.size() < count and tries < count * 20:
		tries += 1
		var p := center + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.6, spread * 0.6))
		if not Game.map_rect().grow(-40).has_point(p):
			continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < 30.0:
				ok = false
				break
		if ok:
			placed.append(p)
			Game.spawn_resource("wood", p, 300)

