extends Node
## Renders a fixed set of screenshots from a live AI-vs-AI match, for reviewing art.
##
## Run (needs a real renderer, not --headless):
##   godot -- --ai-vs-ai --screenshots=/path/to/dir
## Produces base.png, enemy_base.png, battle.png and battle_close.png.

var out_dir := ""
var _shots := [
	{"name": "base", "at": 25.0, "focus": "base", "zoom": 1.0},
	{"name": "enemy_base", "at": 200.0, "focus": "enemy", "zoom": 0.85},
	{"name": "battle", "at": 150.0, "focus": "battle", "zoom": 1.0},
	{"name": "battle_close", "at": 0.0, "focus": "battle", "zoom": 1.9},
]
var _busy := false
var _battle_done := false


func _ready() -> void:
	# Software renderers are slow; skip 3D rendering while waiting for each shot.
	get_viewport().disable_3d = true


func _process(_delta: float) -> void:
	if _busy:
		return
	if _shots.is_empty():
		get_tree().quit()
		return
	var shot: Dictionary = _shots[0]
	if Game.elapsed < shot["at"]:
		return
	var main = get_parent()
	var focus = _focus_point(shot["focus"])
	if focus == null:
		if Game.elapsed > 900.0:
			_shots.pop_front()  # never happened; skip it
		return
	_busy = true
	main.view.camera.zoom = shot["zoom"]
	main.input_ctrl.focus_on(focus)
	if shot["focus"] == "battle":
		main.input_ctrl.set_selection(Game.units_of(0).filter(func(u): return u.can_fight() and u.global_position.distance_to(focus) < 500))
	elif shot["focus"] == "base":
		main.input_ctrl.set_selection([Game.units_of(0).filter(func(u): return u.is_builder())[0]])
	else:
		main.input_ctrl.set_selection([])
	get_viewport().disable_3d = false
	for i in 4:
		await RenderingServer.frame_post_draw
	var path := out_dir.path_join(shot["name"] + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path)
	_shots.pop_front()
	get_viewport().disable_3d = true
	_busy = false


func _focus_point(kind: String):
	match kind:
		"base":
			return Game.buildings_of(0)[0].global_position + Vector2(140, 60) if not Game.buildings_of(0).is_empty() else null
		"enemy":
			return Game.buildings_of(1)[0].global_position + Vector2(-60, 60) if not Game.buildings_of(1).is_empty() else null
		"battle":
			# The spot with the most units from both sides close together.
			var best = null
			var best_score := 0
			for u in Game.units_of(0):
				if not u.can_fight():
					continue
				var mine := 0
				var theirs := 0
				for o in Game.units:
					if Entity.alive(o) and o.global_position.distance_to(u.global_position) < 260:
						if o.team == 0:
							mine += 1
						else:
							theirs += 1
				var score := mini(mine, theirs) * 2 + mine + theirs
				if theirs >= 2 and mine >= 2 and score > best_score:
					best_score = score
					best = u.global_position
			return best
	return null
