class_name PlayerState
extends RefCounted
## Per-player data: which faction they play, their colour and their stockpile.

var team: int
var faction_id: String
var is_ai: bool
var color: Color
var resources: Dictionary = {}


func _init(p_team: int, p_faction_id: String, p_is_ai: bool) -> void:
	team = p_team
	faction_id = p_faction_id
	is_ai = p_is_ai
	var faction := GameData.get_faction(faction_id)
	color = Color.html(str(faction.get("color", "#ffffff")))
	for r in GameData.RESOURCE_TYPES:
		resources[r] = 0
	var start: Dictionary = faction.get("starting_resources", {})
	for r in start:
		resources[r] = int(start[r])
