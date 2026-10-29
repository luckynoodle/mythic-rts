extends Node
## Checks the 3D model pipeline: model files replace placeholders, follow the
## conventions (team material, animation names, anchors), and every placeholder
## for every faction builds.
##
## Run: godot --headless -- --run-model-tests

const FIXTURE := "res://tests/fixtures/test_model.tscn"

var _failures := 0
var main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().physics_frame
	main = get_parent()
	for n in main.get_children():
		if n is SimpleAI:
			n.process_mode = Node.PROCESS_MODE_DISABLED

	_test_placeholders_build()
	_test_model_file_lookup()
	await _test_model_file_in_game()

	print("MODEL_TESTS %s (%d failure(s))" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_placeholders_build() -> void:
	for fid in GameData.faction_ids():
		var f := GameData.get_faction(fid)
		for uid in f["units"]:
			var m := ModelLibrary.unit_model(fid, uid, f["units"][uid])
			var meshes := ModelLibrary.meshes(m)
			var has_team := _has_team_surface(meshes)
			_check(not meshes.is_empty() and has_team, "%s/%s placeholder builds with a team-coloured part" % [fid, uid])
			_check(ModelLibrary.find_anchor(m, "carry") != null, "%s/%s placeholder has a carry anchor" % [fid, uid])
			m.free()
		for bid in f["buildings"]:
			var b := ModelLibrary.building_model(fid, bid, f["buildings"][bid])
			_check(_has_team_surface(ModelLibrary.meshes(b)), "%s/%s placeholder shows team colour" % [fid, bid])
			b.free()
	for r in GameData.RESOURCE_TYPES:
		var n := ModelLibrary.resource_model(r, 3)
		_check(not ModelLibrary.meshes(n).is_empty(), "%s resource placeholder builds" % r)
		n.free()


func _test_model_file_lookup() -> void:
	var m := ModelLibrary.unit_model("humans", "footman", {"model": FIXTURE})
	_check(m.name == "TestModel", "a \"model\" path in the JSON replaces the placeholder")
	ModelLibrary.apply_team_color(m, Color.RED)
	var body: MeshInstance3D = m.get_node("Body")
	var mat: StandardMaterial3D = body.get_surface_override_material(0)
	_check(mat != null and mat.albedo_color == Color.RED, "materials named *team* are recoloured to the team colour")
	var anims := ModelLibrary.map_animations(ModelLibrary.find_animation_player(m))
	_check(anims.get("idle") == "Idle" and anims.get("walk") == "Walk_Loop",
			"animation names are matched loosely (Idle, Walk_Loop) -> %s" % [anims])
	_check(ModelLibrary.find_anchor(m, "carry") != null, "the carry anchor is found in the model file")
	m.free()
	# Conventional path lookup (res://art/<faction>/<id>.<ext>) uses the same search.
	var found := ModelLibrary._find_scene({}, "res://tests/fixtures/test_model")
	_check(found != null, "models are found by conventional path without a JSON entry")


func _test_model_file_in_game() -> void:
	var def: Dictionary = GameData.get_unit_def("humans", "footman")
	def["model"] = FIXTURE
	var u := Game.spawn_unit(0, "footman", Game.buildings_of(0)[0].global_position + Vector2(0, 200))
	await _frames(3)
	var v = main.view.visual_for(u)
	_check(v != null and v.model.name == "TestModel", "a newly trained unit uses the model file in the 3D view")
	u.command_move(u.global_position + Vector2(300, 0))
	await _frames(10)
	_check(v.anim != null and v.anim.current_animation == "Walk_Loop", "the model's walk animation plays while moving (%s)" % [v.anim.current_animation if v.anim else "none"])
	u.command_stop()
	await _frames(5)
	_check(v.anim.current_animation == "Idle", "the idle animation plays when standing")
	def.erase("model")


func _has_team_surface(meshes: Array) -> bool:
	for mi in meshes:
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(i)
			if mat and mat.resource_name.to_lower().contains("team"):
				return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   - ", what)
	else:
		_failures += 1
		print("  FAIL - ", what)
