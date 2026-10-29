class_name ViewSpace
extends RefCounted
## Conversions between the 2D simulation (pixels) and the 3D view (metres).
##
## The simulation is flat: units move on an X/Y plane measured in pixels.
## The 3D view maps that plane onto the ground (X/Z) at 16 pixels per metre.
## Nothing in the simulation knows about 3D.

const PX_PER_M := 16.0


static func to_3d(p: Vector2, height := 0.0) -> Vector3:
	return Vector3(p.x / PX_PER_M, height, p.y / PX_PER_M)


static func to_2d(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z) * PX_PER_M


static func m(px: float) -> float:
	return px / PX_PER_M


## Standing height of a unit in metres. Used for placeholder models, picking,
## health bar placement and for scaling imported models that ask for it.
static func unit_height(def: Dictionary) -> float:
	if def.has("model_height"):
		return float(def["model_height"])
	var r := float(def.get("radius", 10)) / PX_PER_M
	match str(def.get("role", "")):
		"vehicle":
			return r * 2.6
		"heavy":
			return r * 3.6
	return r * 3.3


static func building_height(def: Dictionary) -> float:
	if def.has("model_height"):
		return float(def["model_height"])
	var s: Array = def.get("size", [64, 64])
	return minf(float(s[0]), float(s[1])) / PX_PER_M * 0.75 + 1.5


static func resource_height(resource_type: String) -> float:
	match resource_type:
		"wood":
			return 5.5
		"gold":
			return 2.8
	return 1.8
