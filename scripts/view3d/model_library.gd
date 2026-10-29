class_name ModelLibrary
extends RefCounted
## Finds the 3D model for each unit, building, resource and projectile.
##
## Lookup order (first match wins):
##   1. the "model" path in the faction JSON, e.g. "res://art/humans/footman.glb"
##   2. the conventional path  res://art/<faction>/<id>.glb  (or .gltf / .tscn / .scn)
##   3. a code-built placeholder (PlaceholderModels)
##
## So upgrading a unit's look is just: drop footman.glb into res://art/humans/.
## See docs/ART_GUIDE.md for the conventions a model must follow.

const EXTENSIONS := ["glb", "gltf", "tscn", "scn"]

## Animation name candidates per state (matched case-insensitively, by "contains").
const ANIM_NAMES := {
	"idle": ["idle", "stand"],
	"walk": ["walk", "run", "move"],
	"attack": ["attack", "slash", "shoot", "punch", "throw", "sword"],
	"work": ["work", "gather", "chop", "mine", "build", "interact", "hammer"],
	"die": ["die", "death", "dead"],
}

static var _scenes := {}
static var _team_mats := {}


static func unit_model(faction_id: String, unit_id: String, def: Dictionary) -> Node3D:
	var scene := _find_scene(def, "res://art/%s/%s" % [faction_id, unit_id])
	if scene:
		return _prepare(scene.instantiate(), def)
	return PlaceholderModels.unit(faction_id, unit_id, def)


static func building_model(faction_id: String, building_id: String, def: Dictionary) -> Node3D:
	var scene := _find_scene(def, "res://art/%s/%s" % [faction_id, building_id])
	if scene:
		return _prepare(scene.instantiate(), def)
	return PlaceholderModels.building(faction_id, building_id, def)


static func resource_model(resource_type: String, variant: int) -> Node3D:
	# Variants: res://art/resources/wood_2.glb, ... falling back to wood.glb.
	var scene := _find_scene({}, "res://art/resources/%s_%d" % [resource_type, variant % 4])
	if scene == null:
		scene = _find_scene({}, "res://art/resources/" + resource_type)
	if scene:
		var n: Node3D = scene.instantiate()
		n.rotation.y = float(variant % 360) * 0.017
		return n
	return PlaceholderModels.resource(resource_type, variant)


static func projectile_model(kind: String) -> Node3D:
	var scene := _find_scene({}, "res://art/projectiles/" + kind)
	if scene:
		return scene.instantiate()
	return PlaceholderModels.projectile(kind)


static func _find_scene(def: Dictionary, base_path: String) -> PackedScene:
	var explicit := str(def.get("model", ""))
	var candidates: Array = [explicit] if explicit != "" else []
	for ext in EXTENSIONS:
		candidates.append("%s.%s" % [base_path, ext])
	for path in candidates:
		if _scenes.has(path):
			if _scenes[path] != null:
				return _scenes[path]
			continue
		var scene: PackedScene = null
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is PackedScene:
				scene = res
		_scenes[path] = scene
		if scene:
			return scene
	return null


## Applies optional per-entry tweaks from the JSON: "model_scale" and "model_rotation_y".
static func _prepare(model: Node3D, def: Dictionary) -> Node3D:
	if def.has("model_scale"):
		var s := float(def["model_scale"])
		model.scale = Vector3(s, s, s)
	if def.has("model_rotation_y"):
		model.rotation_degrees.y = float(def["model_rotation_y"])
	return model


# ---------------------------------------------------------------- conventions

## Recolours every material whose name contains "team" with the team colour.
## Works for placeholders and for imported glTF models alike.
static func apply_team_color(root: Node, color: Color) -> void:
	for mi in meshes(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(i)
			if mat == null:
				mat = mesh.surface_get_material(i)
			if mat == null or not mat.resource_name.to_lower().contains("team"):
				continue
			var key := "%d|%s" % [mat.get_instance_id(), color.to_html()]
			if not _team_mats.has(key):
				var dup: Material = mat.duplicate()
				dup.resource_name = mat.resource_name
				if dup is BaseMaterial3D:
					dup.albedo_color = color
				elif dup is ShaderMaterial:
					dup.set_shader_parameter("team_color", color)
				_team_mats[key] = dup
			mi.set_surface_override_material(i, _team_mats[key])


static func meshes(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(meshes(c))
	return out


static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var p := find_animation_player(c)
		if p:
			return p
	return null


## Maps our states (idle/walk/attack/work/die) to the model's own animation names.
static func map_animations(player: AnimationPlayer) -> Dictionary:
	var out := {}
	if player == null:
		return out
	var names := player.get_animation_list()
	for state in ANIM_NAMES:
		for wanted in ANIM_NAMES[state]:
			for n in names:
				var lower := String(n).to_lower()
				if lower == wanted or lower.ends_with("/" + wanted):
					out[state] = n
			if out.has(state):
				break
		if not out.has(state):
			for wanted in ANIM_NAMES[state]:
				for n in names:
					if String(n).to_lower().contains(wanted):
						out[state] = n
						break
				if out.has(state):
					break
	return out


## Finds an attachment point (Node3D or BoneAttachment3D) by name, e.g. "carry".
static func find_anchor(root: Node, anchor_name: String) -> Node3D:
	var n := root.find_child(anchor_name, true, false)
	return n as Node3D
