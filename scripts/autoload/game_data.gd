extends Node
## Loads every faction definition from res://data/factions/*.json at startup.
##
## Units and buildings are pure data: adding a faction means adding a JSON file
## (see docs/ADDING_A_FACTION.md) — no new code is needed for the basics.

const FACTIONS_DIR := "res://data/factions"
const RESOURCE_TYPES := ["gold", "wood", "stone"]
const RESOURCE_COLORS := {
	"gold": Color("e8c547"),
	"wood": Color("8b5a2b"),
	"stone": Color("9aa0a6"),
}
const RESOURCE_SHORT := {"gold": "g", "wood": "w", "stone": "s"}
const ROLES := ["builder", "melee", "ranged", "heavy", "vehicle", "flyer"]

var factions: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	factions.clear()
	var dir := DirAccess.open(FACTIONS_DIR)
	if dir == null:
		push_error("GameData: cannot open %s" % FACTIONS_DIR)
		return
	for file_name in dir.get_files():
		# Exported builds may list remapped names; only plain JSON is data.
		if file_name.ends_with(".json"):
			_load_faction(FACTIONS_DIR.path_join(file_name))
	for faction_id in factions:
		for err in validate_faction(factions[faction_id]):
			push_error("GameData [%s]: %s" % [faction_id, err])


func _load_faction(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: %s is not a valid JSON object" % path)
		return
	var id := str(parsed.get("id", ""))
	if id == "":
		push_error("GameData: %s has no \"id\"" % path)
		return
	factions[id] = parsed


## Returns a list of human-readable problems with a faction definition.
func validate_faction(f: Dictionary) -> Array:
	var errors: Array = []
	var units: Dictionary = f.get("units", {})
	var buildings: Dictionary = f.get("buildings", {})
	for key in ["hq", "builder", "supply_building"]:
		if not f.has(key):
			errors.append("missing \"%s\"" % key)
	if not buildings.has(f.get("hq", "")):
		errors.append("hq \"%s\" is not a building" % f.get("hq", ""))
	if not units.has(f.get("builder", "")):
		errors.append("builder \"%s\" is not a unit" % f.get("builder", ""))
	if not buildings.has(f.get("supply_building", "")):
		errors.append("supply_building \"%s\" is not a building" % f.get("supply_building", ""))
	for uid in f.get("starting_units", []):
		if not units.has(uid):
			errors.append("starting unit \"%s\" does not exist" % uid)
	for uid in units:
		var u: Dictionary = units[uid]
		if not ROLES.has(u.get("role", "")):
			errors.append("unit %s has unknown role \"%s\"" % [uid, u.get("role", "")])
		for req in u.get("requires", []):
			if not buildings.has(req):
				errors.append("unit %s requires unknown building \"%s\"" % [uid, req])
		errors.append_array(_validate_cost("unit " + uid, u.get("cost", {})))
		var trained_somewhere := false
		for bid in buildings:
			if buildings[bid].get("trains", []).has(uid):
				trained_somewhere = true
		if not trained_somewhere:
			errors.append("unit %s is not trained by any building" % uid)
	for bid in buildings:
		var b: Dictionary = buildings[bid]
		var size = b.get("size", [])
		if typeof(size) != TYPE_ARRAY or size.size() != 2:
			errors.append("building %s needs \"size\": [w, h]" % bid)
		for req in b.get("requires", []):
			if not buildings.has(req):
				errors.append("building %s requires unknown building \"%s\"" % [bid, req])
		for uid in b.get("trains", []):
			if not units.has(uid):
				errors.append("building %s trains unknown unit \"%s\"" % [bid, uid])
		for r in b.get("drop_off", []):
			if not RESOURCE_TYPES.has(r):
				errors.append("building %s accepts unknown resource \"%s\"" % [bid, r])
		errors.append_array(_validate_cost("building " + bid, b.get("cost", {})))
	var ai: Dictionary = f.get("ai", {})
	for bid in ai.get("build_order", []):
		if not buildings.has(bid):
			errors.append("ai build_order has unknown building \"%s\"" % bid)
	for uid in ai.get("army", []):
		if not units.has(uid):
			errors.append("ai army has unknown unit \"%s\"" % uid)
	return errors


func _validate_cost(owner: String, cost: Dictionary) -> Array:
	var errors: Array = []
	for r in cost:
		if not RESOURCE_TYPES.has(r):
			errors.append("%s costs unknown resource \"%s\"" % [owner, r])
	return errors


func faction_ids() -> Array:
	return factions.keys()


func get_faction(faction_id: String) -> Dictionary:
	return factions.get(faction_id, {})


func get_unit_def(faction_id: String, unit_id: String) -> Dictionary:
	return get_faction(faction_id).get("units", {}).get(unit_id, {})


func get_building_def(faction_id: String, building_id: String) -> Dictionary:
	return get_faction(faction_id).get("buildings", {}).get(building_id, {})


func building_ids(faction_id: String) -> Array:
	return get_faction(faction_id).get("buildings", {}).keys()


## Converts a JSON cost object into {resource: int}.
static func normalize_cost(cost: Dictionary) -> Dictionary:
	var out := {}
	for r in cost:
		out[r] = int(cost[r])
	return out


static func cost_to_string(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in RESOURCE_TYPES:
		if cost.has(r) and int(cost[r]) > 0:
			parts.append("%d%s" % [int(cost[r]), RESOURCE_SHORT[r]])
	return " ".join(parts)
