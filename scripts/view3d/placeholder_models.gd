class_name PlaceholderModels
extends RefCounted
## Code-built stand-in models in a stylised / heroic (Warcraft-like) style:
## ~5 heads tall, big shoulders, hands and weapons.
##
## They follow exactly the same conventions as real model files
## (see docs/ART_GUIDE.md): metres, origin at the feet / footprint centre,
## facing +Z, a material named "team" for team colour, and a "carry" marker.
## Drop a real model into res://art/ and it replaces these automatically.

const STEEL := Color8(196, 204, 214)
const STEEL_D := Color8(136, 144, 156)
const WOOD := Color8(124, 82, 46)
const WOOD_L := Color8(160, 112, 66)
const GOLD := Color8(236, 190, 62)
const LEATHER := Color8(110, 72, 42)
const BONE := Color8(238, 230, 210)
const STONE := Color8(184, 178, 166)
const STONE_D := Color8(140, 134, 124)
const HIDE := Color8(156, 114, 78)
const WHITE := Color(1, 1, 1)
const TEAM_D := Color(0.72, 0.72, 0.72)  # team-tinted shade

const SKIN_HUMAN := Color8(236, 192, 152)

static var _mesh_cache := {}


# ================================================================ entry points

static func unit(faction_id: String, unit_id: String, def: Dictionary) -> Node3D:
	var key := "u|%s|%s" % [faction_id, unit_id]
	var info: Dictionary = _mesh_cache.get(key, {})
	if info.is_empty():
		var m := MeshMerger.new()
		var anchors := _build_unit(m, _style(faction_id), def)
		info = {"mesh": m.commit(), "anchors": anchors}
		_mesh_cache[key] = info
	return _wrap(info["mesh"], info["anchors"])


static func building(faction_id: String, building_id: String, def: Dictionary) -> Node3D:
	var key := "b|%s|%s" % [faction_id, building_id]
	if not _mesh_cache.has(key):
		var m := MeshMerger.new()
		_build_building(m, _style(faction_id), _building_kind(faction_id, building_id, def), def)
		_mesh_cache[key] = {"mesh": m.commit(), "anchors": {}}
	return _wrap(_mesh_cache[key]["mesh"], {})


static func resource(resource_type: String, variant: int) -> Node3D:
	var key := "r|%s|%d" % [resource_type, variant]
	if not _mesh_cache.has(key):
		var m := MeshMerger.new()
		match resource_type:
			"gold":
				_gold_mine(m, variant)
			"stone":
				_stone_quarry(m, variant)
			_:
				_tree(m, variant)
		_mesh_cache[key] = {"mesh": m.commit(), "anchors": {}}
	return _wrap(_mesh_cache[key]["mesh"], {})


static func projectile(kind: String) -> Node3D:
	var key := "p|" + kind
	if not _mesh_cache.has(key):
		var m := MeshMerger.new()
		match kind:
			"boulder":
				m.sphere(0.35, Vector3.ZERO, Color8(130, 120, 110), Vector3.ONE, 8)
			"axe":
				m.box(Vector3(0.06, 0.06, 0.55), Vector3.ZERO, WOOD)
				m.box(Vector3(0.04, 0.32, 0.26), Vector3(0, 0.1, 0.2), STEEL)
			"bolt":
				m.box(Vector3(0.08, 0.08, 1.4), Vector3.ZERO, WOOD_L)
				m.cyl(0.0, 0.1, 0.25, Vector3(0, 0, 0.8), STEEL, Vector3(90, 0, 0), 6)
			_:  # arrow
				m.box(Vector3(0.04, 0.04, 0.9), Vector3.ZERO, Color8(220, 200, 160))
				m.cyl(0.0, 0.05, 0.14, Vector3(0, 0, 0.5), STEEL, Vector3(90, 0, 0), 5)
				m.box(Vector3(0.12, 0.01, 0.14), Vector3(0, 0, -0.4), WHITE)
		_mesh_cache[key] = {"mesh": m.commit(), "anchors": {}}
	return _wrap(_mesh_cache[key]["mesh"], {})


static func carry_item(resource_type: String) -> Mesh:
	var key := "c|" + resource_type
	if not _mesh_cache.has(key):
		var m := MeshMerger.new()
		match resource_type:
			"wood":
				for i in 3:
					m.cyl(0.11, 0.11, 0.9, Vector3(0, i * 0.17 - 0.05 * (i % 2), 0), WOOD_L, Vector3(0, 0, 90), 7)
			"stone":
				m.sphere(0.24, Vector3.ZERO, STONE, Vector3(1.2, 0.8, 1), 7)
			_:
				m.sphere(0.26, Vector3.ZERO, Color8(178, 140, 92), Vector3(1, 0.9, 1), 8)
				m.sphere(0.1, Vector3(0.05, 0.2, 0.05), GOLD, Vector3.ONE, 6, "glow")
				m.sphere(0.08, Vector3(-0.08, 0.2, -0.04), GOLD, Vector3.ONE, 6, "glow")
		_mesh_cache[key] = {"mesh": m.commit(), "anchors": {}}
	return _mesh_cache[key]["mesh"]


static func _wrap(mesh: Mesh, anchors: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Placeholder"
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	root.add_child(mi)
	for a in anchors:
		var n := Node3D.new()
		n.name = a
		n.position = anchors[a]
		root.add_child(n)
	return root


## Placeholder look per faction, read from the faction JSON ("placeholder": {...}).
static func _style(faction_id: String) -> Dictionary:
	var p: Dictionary = GameData.get_faction(faction_id).get("placeholder", {})
	return {
		"race": str(p.get("race", "human")),
		"skin": Color.html(str(p.get("skin", "#ecc098"))),
		"bulk": float(p.get("bulk", 1.0)),
	}


# ================================================================ units

## Builds a heroic humanoid facing +Z. Returns anchor points (metres).
## Note: facing +Z, the figure's right hand is on the -X side.
static func _hero(m: MeshMerger, H: float, o: Dictionary) -> Dictionary:
	var skin: Color = o.get("skin", SKIN_HUMAN)
	var bulk: float = o.get("bulk", 1.0)
	var y0: float = o.get("y0", 0.0)
	var head := H / 4.8
	var body := H - head
	var leg_h := body * 0.44
	var torso_h := body - leg_h
	var w := head * 1.35 * bulk
	var limb := head * 0.27 * bulk
	var legs: bool = not o.get("no_legs", false)
	if legs:
		for s in [-1, 1]:
			m.cyl(limb * 1.2, limb * 1.0, leg_h, Vector3(s * w * 0.27, y0 + leg_h * 0.55, 0), o.get("legs", Color8(70, 66, 80)), Vector3.ZERO, 8)
			m.box(Vector3(limb * 2.4, leg_h * 0.22, limb * 3.0), Vector3(s * w * 0.27, y0 + leg_h * 0.11, limb * 0.4), o.get("boots", LEATHER))
	else:
		leg_h = 0.0
	var ty := y0 + leg_h
	m.cyl(w * 0.62, w * 0.46, torso_h, Vector3(0, ty + torso_h * 0.5, 0), o.get("torso", WHITE), Vector3.ZERO, 12, o.get("torso_surface", "team"))
	m.cyl(w * 0.5, w * 0.48, torso_h * 0.16, Vector3(0, ty + torso_h * 0.12, 0), o.get("belt", LEATHER), Vector3.ZERO, 12)
	m.box(Vector3(w * 0.28, torso_h * 0.13, 0.05), Vector3(0, ty + torso_h * 0.12, w * 0.49), GOLD)
	var sh_y := ty + torso_h * 0.9
	for s in [-1, 1]:
		m.sphere(limb * 2.0, Vector3(s * w * 0.64, sh_y, 0), o.get("pads", STEEL), Vector3(1, 0.85, 1), 10, o.get("pads_surface", "base"))
		m.cyl(limb * 1.05, limb * 0.9, torso_h * 0.82, Vector3(s * w * 0.74, sh_y - torso_h * 0.42, 0.04), o.get("arms", skin), Vector3(0, 0, s * 7), 8)
		m.sphere(limb * 1.45, Vector3(s * w * 0.8, sh_y - torso_h * 0.86, 0.1), skin, Vector3.ONE, 8)
	var hy := ty + torso_h + head * 0.48
	var hr := head * 0.52
	m.sphere(hr, Vector3(0, hy, 0), skin, Vector3(1, 1.05, 1), 12)
	for s in [-1, 1]:
		m.sphere(hr * 0.12, Vector3(s * hr * 0.36, hy + hr * 0.08, hr * 0.88), Color8(28, 22, 26), Vector3.ONE, 6)
	m.sphere(hr * 0.16, Vector3(0, hy - hr * 0.12, hr * 0.95), skin.darkened(0.08), Vector3.ONE, 6)
	return {
		"hand_r": Vector3(-w * 0.8, sh_y - torso_h * 0.86, 0.1),
		"hand_l": Vector3(w * 0.8, sh_y - torso_h * 0.86, 0.1),
		"head": Vector3(0, hy, 0),
		"head_r": hr,
		"carry": Vector3(0, ty + torso_h * 0.75, -w * 0.62),
		"w": w,
		"limb": limb,
	}


static func _build_unit(m: MeshMerger, st: Dictionary, def: Dictionary) -> Dictionary:
	var H := ViewSpace.unit_height(def)
	var orc: bool = st["race"] == "orc"
	var skin: Color = st["skin"]
	var bulk: float = st["bulk"]
	var a := {}
	match str(def.get("role", "melee")):
		"builder":
			a = _hero(m, H, {"skin": skin, "bulk": bulk * 0.95, "torso": Color8(150, 110, 72), "torso_surface": "base",
					"pads": Color8(140, 100, 64), "arms": skin, "legs": Color8(96, 80, 60), "belt": WHITE})
			# team sash
			m.box(Vector3(a["w"] * 1.1, H * 0.06, a["w"] * 1.0), a["head"] + Vector3(0, -H * 0.34, 0), WHITE, Vector3(0, 0, 25), "team")
			if orc:
				_orc_face(m, a)
			else:
				m.cyl(a["head_r"] * 1.7, a["head_r"] * 1.7, 0.05, a["head"] + Vector3(0, a["head_r"] * 0.55, 0), Color8(226, 194, 110), Vector3.ZERO, 14)
				m.cyl(a["head_r"] * 0.75, a["head_r"] * 0.9, a["head_r"] * 0.5, a["head"] + Vector3(0, a["head_r"] * 0.8, 0), Color8(226, 194, 110), Vector3.ZERO, 12)
			# pickaxe in the right hand
			var h: Vector3 = a["hand_r"]
			m.box(Vector3(0.07, H * 0.42, 0.07), h + Vector3(0, H * 0.12, 0.05), WOOD)
			m.box(Vector3(0.5, 0.08, 0.08), h + Vector3(0, H * 0.32, 0.05), STEEL, Vector3(0, 0, 12))
		"ranged":
			if orc:
				a = _hero(m, H, {"skin": skin, "bulk": bulk, "torso": skin, "torso_surface": "base", "pads": WHITE,
						"pads_surface": "team", "legs": LEATHER.darkened(0.2)})
				_orc_face(m, a)
				m.cyl(a["head_r"] * 1.02, a["head_r"] * 1.02, a["head_r"] * 0.35, a["head"] + Vector3(0, a["head_r"] * 0.45, 0), WHITE, Vector3.ZERO, 12, "team")
				_axe(m, a["hand_r"], H * 0.38, false, Vector3(0, 0, 35))
				_axe(m, a["carry"] + Vector3(0.2, 0.1, -0.05), H * 0.3, false, Vector3(0, 0, -20))
			else:
				a = _hero(m, H, {"skin": skin, "bulk": bulk * 0.9, "torso": Color(0.85, 0.85, 0.85), "pads": Color8(70, 126, 66), "legs": Color8(80, 70, 56)})
				m.sphere(a["head_r"] * 1.12, a["head"] + Vector3(0, 0.03, -0.04), Color8(70, 126, 66), Vector3(1, 1.05, 1), 12, "base", true)
				m.box(Vector3(a["w"] * 1.1, H * 0.45, 0.06), a["carry"] + Vector3(0, -H * 0.12, -0.02), Color8(60, 110, 58))  # cloak
				var hl: Vector3 = a["hand_l"]
				for i in 3:  # bow
					var dy := (i - 1) * H * 0.2
					m.box(Vector3(0.07, H * 0.23, 0.07), hl + Vector3(0, dy, 0.12), WOOD_L, Vector3(0, 0, (i - 1) * -28))
				m.box(Vector3(0.015, H * 0.58, 0.015), hl + Vector3(-0.1, 0, 0.12), WHITE)
				m.cyl(0.12, 0.12, H * 0.33, a["carry"] + Vector3(-0.15, 0.1, 0), LEATHER, Vector3(15, 0, 20), 8)
		"heavy":
			if orc:  # ogre: huge, small head, massive club
				a = _hero(m, H, {"skin": skin, "bulk": bulk * 1.5, "torso": skin, "torso_surface": "base", "pads": WHITE,
						"pads_surface": "team", "legs": LEATHER})
				m.sphere(a["w"] * 0.55, a["head"] + Vector3(0, -H * 0.4, a["w"] * 0.2), skin, Vector3(1, 0.9, 0.9), 12)  # belly
				_orc_face(m, a)
				var h: Vector3 = a["hand_r"]
				m.cyl(0.1, 0.14, H * 0.55, h + Vector3(0, H * 0.18, 0.1), WOOD, Vector3(0, 0, 18), 8)
				m.sphere(0.3, h + Vector3(0.09, H * 0.45, 0.1), WOOD_L, Vector3(1, 1.3, 1), 8)
			else:  # mounted knight
				a = _mounted_knight(m, H, skin, bulk)
		"vehicle":
			a = _siege(m, H, orc)
		"flyer":
			a = _hero(m, H * 0.8, {"skin": skin, "bulk": bulk * 0.8, "y0": H * 0.2, "no_legs": true})
			for s in [-1, 1]:
				m.box(Vector3(H * 0.7, 0.04, H * 0.3), Vector3(s * H * 0.42, H * 0.75, -0.1), WHITE, Vector3(0, 0, s * 12), "team")
		_:  # melee
			if orc:
				a = _hero(m, H, {"skin": skin, "bulk": bulk, "torso": skin, "torso_surface": "base", "pads": WHITE,
						"pads_surface": "team", "legs": LEATHER.darkened(0.25)})
				_orc_face(m, a)
				m.sphere(a["head_r"] * 1.06, a["head"] + Vector3(0, 0.05, 0), Color8(64, 56, 60), Vector3.ONE, 12, "base", true)
				for s in [-1, 1]:
					m.cyl(0.0, 0.07, a["head_r"] * 0.9, a["head"] + Vector3(s * a["head_r"] * 0.8, a["head_r"] * 0.6, 0), BONE, Vector3(0, 0, -s * 35), 6)
				_axe(m, a["hand_r"], H * 0.55, true)
			else:
				a = _hero(m, H, {"skin": skin, "bulk": bulk, "pads": STEEL})
				m.sphere(a["head_r"] * 1.08, a["head"] + Vector3(0, 0.04, 0), STEEL, Vector3.ONE, 12, "base", true)
				m.box(Vector3(0.05, a["head_r"] * 0.7, 0.06), a["head"] + Vector3(0, -a["head_r"] * 0.05, a["head_r"] * 0.98), STEEL_D)
				m.cyl(0.0, 0.08, a["head_r"] * 0.9, a["head"] + Vector3(0, a["head_r"] * 1.3, 0), WHITE, Vector3.ZERO, 6, "team")
				_sword(m, a["hand_r"], H * 0.5)
				_shield(m, a["hand_l"] + Vector3(0.05, 0.08, 0.15), H * 0.2)
	return {"carry": a.get("carry", Vector3(0, H * 0.6, -0.3)), "hand_r": a.get("hand_r", Vector3.ZERO),
			"hand_l": a.get("hand_l", Vector3.ZERO), "head": a.get("head", Vector3(0, H, 0))}


static func _orc_face(m: MeshMerger, a: Dictionary) -> void:
	var hr: float = a["head_r"]
	var hp: Vector3 = a["head"]
	for s in [-1, 1]:
		m.cyl(0.0, hr * 0.13, hr * 0.5, hp + Vector3(s * hr * 0.32, -hr * 0.42, hr * 0.82), BONE, Vector3(-10, 0, 0), 6)
		m.sphere(hr * 0.22, hp + Vector3(s * hr * 0.95, hr * 0.05, -0.02), a.get("skin", Color8(112, 168, 72)), Vector3(0.6, 1, 1), 6)
	m.box(Vector3(hr * 1.1, hr * 0.14, hr * 0.2), hp + Vector3(0, hr * 0.3, hr * 0.85), Color8(40, 50, 30))  # heavy brow


static func _sword(m: MeshMerger, hand: Vector3, length: float) -> void:
	m.box(Vector3(0.09, length, 0.18), hand + Vector3(0, length * 0.55, 0.12), STEEL)
	m.box(Vector3(0.03, length * 0.95, 0.04), hand + Vector3(0, length * 0.55, 0.22), WHITE)
	m.box(Vector3(0.42, 0.08, 0.12), hand + Vector3(0, 0.08, 0.12), GOLD)
	m.sphere(0.07, hand + Vector3(0, -0.12, 0.12), GOLD, Vector3.ONE, 6)


static func _shield(m: MeshMerger, pos: Vector3, r: float) -> void:
	m.cyl(r, r, 0.08, pos, STEEL, Vector3(90, 0, 0), 16)
	m.cyl(r * 0.78, r * 0.78, 0.1, pos + Vector3(0, 0, 0.02), WHITE, Vector3(90, 0, 0), 16, "team")
	m.sphere(r * 0.2, pos + Vector3(0, 0, 0.06), GOLD, Vector3(1, 1, 0.6), 8)


static func _axe(m: MeshMerger, hand: Vector3, length: float, double: bool, rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot * (PI / 180.0))
	var up := b * Vector3.UP
	m.box(Vector3(0.08, length, 0.08), hand + up * length * 0.35 + Vector3(0, 0, 0.1), WOOD, rot)
	var head := hand + up * length * 0.78 + Vector3(0, 0, 0.1)
	m.box(Vector3(0.05, length * 0.32, length * 0.3), head + b * Vector3(0, 0, length * 0.14), STEEL, rot)
	if double:
		m.box(Vector3(0.05, length * 0.32, length * 0.3), head - b * Vector3(0, 0, length * 0.14), STEEL, rot)


static func _mounted_knight(m: MeshMerger, H: float, skin: Color, bulk: float) -> Dictionary:
	var horse := Color8(110, 78, 54)
	var bh := H * 0.42  # horse back height
	m.sphere(H * 0.22, Vector3(0, bh, 0), horse, Vector3(1.0, 0.85, 2.0), 12)
	for x in [-1, 1]:
		for z in [-1, 1]:
			m.cyl(0.08, 0.07, bh * 0.85, Vector3(x * H * 0.12, bh * 0.42, z * H * 0.3), horse.darkened(0.15), Vector3.ZERO, 6)
	m.cyl(0.11, 0.15, H * 0.35, Vector3(0, bh + H * 0.12, H * 0.42), horse, Vector3(-40, 0, 0), 8)
	m.box(Vector3(0.22, 0.24, 0.48), Vector3(0, bh + H * 0.26, H * 0.6), horse, Vector3(25, 0, 0))
	m.cyl(0.02, 0.07, H * 0.35, Vector3(0, bh, -H * 0.48), Color8(60, 40, 30), Vector3(-30, 0, 0), 6)
	m.box(Vector3(H * 0.5, H * 0.2, H * 0.62), Vector3(0, bh - 0.02, -0.02), WHITE, Vector3.ZERO, "team")  # caparison
	var a := _hero(m, H * 0.68, {"skin": skin, "bulk": bulk * 1.15, "y0": bh + H * 0.12, "no_legs": true, "pads": STEEL})
	m.sphere(a["head_r"] * 1.1, a["head"] + Vector3(0, 0.03, 0), STEEL, Vector3.ONE, 12, "base", true)
	m.box(Vector3(a["head_r"] * 1.6, a["head_r"] * 0.15, 0.05), a["head"] + Vector3(0, 0.0, a["head_r"] * 0.98), Color8(30, 30, 36))
	m.cyl(0.0, 0.1, a["head_r"] * 1.3, a["head"] + Vector3(0, a["head_r"] * 1.4, 0), WHITE, Vector3.ZERO, 6, "team")
	m.cyl(0.05, 0.06, H * 0.9, a["hand_r"] + Vector3(0, H * 0.2, 0.3), WOOD_L, Vector3(55, 0, 0), 6)  # lance
	m.cyl(0.0, 0.08, 0.3, a["hand_r"] + Vector3(0, H * 0.45, 0.65), STEEL, Vector3(55, 0, 0), 6)
	_shield(m, a["hand_l"] + Vector3(0.08, 0.05, 0.1), H * 0.16)
	a["carry"] = Vector3(0, bh + 0.2, -H * 0.35)
	return a


static func _siege(m: MeshMerger, H: float, orc: bool) -> Dictionary:
	var L := H * 1.3
	var wood := WOOD if not orc else Color8(98, 70, 44)
	m.box(Vector3(H * 0.75, 0.22, L), Vector3(0, H * 0.25, 0), wood)
	for x in [-1, 1]:
		m.box(Vector3(0.14, 0.18, L * 1.05), Vector3(x * H * 0.36, H * 0.32, 0), wood.lightened(0.1))
		for z in [-1, 1]:
			m.cyl(H * 0.2, H * 0.2, 0.14, Vector3(x * H * 0.44, H * 0.2, z * L * 0.36), wood.darkened(0.2), Vector3(0, 0, 90), 10)
			m.cyl(H * 0.06, H * 0.06, 0.18, Vector3(x * H * 0.44, H * 0.2, z * L * 0.36), STEEL_D, Vector3(0, 0, 90), 6)
	if orc:  # catapult: throwing arm + bucket with boulder
		for x in [-1, 1]:
			m.box(Vector3(0.12, H * 0.7, 0.12), Vector3(x * H * 0.25, H * 0.6, 0.0), wood, Vector3(0, 0, x * -12))
		m.box(Vector3(0.14, 0.14, L * 0.95), Vector3(0, H * 0.75, -L * 0.15), wood.lightened(0.15), Vector3(-25, 0, 0))
		m.sphere(H * 0.17, Vector3(0, H * 1.0, -L * 0.52), LEATHER, Vector3(1, 0.6, 1), 8)
		m.sphere(H * 0.14, Vector3(0, H * 1.08, -L * 0.52), Color8(130, 120, 110), Vector3.ONE, 8)
		for s in [-1, 1]:
			m.cyl(0.0, 0.08, 0.45, Vector3(s * H * 0.3, H * 0.4, L * 0.52), BONE, Vector3(70, 0, 0), 6)
		m.box(Vector3(0.6, 0.5, 0.04), Vector3(0, H * 0.95, L * 0.3), WHITE, Vector3.ZERO, "team")
	else:  # ballista: big crossbow
		m.box(Vector3(0.18, 0.18, L * 0.9), Vector3(0, H * 0.62, 0.05), wood.lightened(0.15), Vector3(-8, 0, 0))
		for s in [-1, 1]:
			m.box(Vector3(H * 0.62, 0.12, 0.12), Vector3(s * H * 0.3, H * 0.72, L * 0.38), wood.lightened(0.05), Vector3(0, s * 22, 0))
		m.box(Vector3(H * 1.15, 0.025, 0.025), Vector3(0, H * 0.72, L * 0.18), WHITE)
		m.box(Vector3(0.06, 0.06, L * 0.75), Vector3(0, H * 0.74, L * 0.1), STEEL_D)
		m.box(Vector3(0.65, 0.42, 0.04), Vector3(0, H * 0.55, -L * 0.48), WHITE, Vector3.ZERO, "team")
	return {"carry": Vector3(0, H * 0.4, -L * 0.4), "hand_r": Vector3(0, H * 0.7, L * 0.4),
			"hand_l": Vector3(0, H * 0.7, L * 0.4), "head": Vector3(0, H * 0.8, 0)}


# ================================================================ buildings

static func _building_kind(faction_id: String, bid: String, def: Dictionary) -> String:
	var f := GameData.get_faction(faction_id)
	if bid == f.get("hq", ""):
		return "hq"
	if bid == f.get("supply_building", ""):
		return "farm"
	for k in ["stable", "beast", "kennel", "roost"]:
		if bid.contains(k):
			return "stables"
	for k in ["workshop", "siege", "forge"]:
		if bid.contains(k):
			return "workshop"
	if not def.get("drop_off", []).is_empty():
		return "mill"
	if not def.get("trains", []).is_empty():
		return "barracks"
	return "generic"


static func _build_building(m: MeshMerger, st: Dictionary, kind: String, def: Dictionary) -> void:
	var s: Array = def.get("size", [64, 64])
	var W := ViewSpace.m(float(s[0]))
	var D := ViewSpace.m(float(s[1]))
	var H := ViewSpace.building_height(def)
	# Ground plate so every building sits on a dirt pad.
	m.box(Vector3(W * 1.06, 0.06, D * 1.06), Vector3(0, 0.03, 0), Color8(150, 122, 84))
	if st["race"] == "orc":
		_orc_building(m, kind, W, D, H)
	else:
		_human_building(m, kind, W, D, H)


static func _human_building(m: MeshMerger, kind: String, W: float, D: float, H: float) -> void:
	var plaster := Color8(232, 218, 188)
	var timber := Color8(104, 70, 40)
	match kind:
		"hq":  # stone keep with four towers
			var bw := W * 0.66
			var bd := D * 0.6
			var wh := H * 0.5
			m.box(Vector3(bw, wh, bd), Vector3(0, wh * 0.5, 0), STONE)
			for i in 8:  # crenellations
				var x := -bw * 0.5 + bw * (i + 0.5) / 8.0
				m.box(Vector3(bw / 14.0, 0.35, 0.3), Vector3(x, wh + 0.17, bd * 0.5 - 0.1), STONE_D)
			m.prism(Vector3(bw * 0.92, H * 0.35, bd * 0.85), Vector3(0, wh + H * 0.175, -0.1), WHITE, Vector3.ZERO, "team")
			for x in [-1, 1]:
				for z in [-1, 1]:
					var tp := Vector3(x * W * 0.4, 0, z * D * 0.36)
					m.cyl(W * 0.11, W * 0.12, H * 0.68, tp + Vector3(0, H * 0.34, 0), STONE.lightened(0.05), Vector3.ZERO, 10)
					m.cyl(0.0, W * 0.15, H * 0.3, tp + Vector3(0, H * 0.83, 0), WHITE, Vector3.ZERO, 10, "team")
					m.box(Vector3(0.25, 0.5, 0.1), tp + Vector3(0, H * 0.48, W * 0.12), Color8(255, 210, 120), Vector3.ZERO, "glow")
			m.cyl(0.9, 0.9, 0.12, Vector3(0, wh * 0.25, bd * 0.5 + 0.02), timber, Vector3(90, 0, 0), 12)  # arched door top
			m.box(Vector3(1.8, wh * 0.55, 0.12), Vector3(0, wh * 0.27, bd * 0.5 + 0.02), timber)
			for x in [-1, 1]:
				m.box(Vector3(0.5, 0.8, 0.08), Vector3(x * bw * 0.3, wh * 0.6, bd * 0.5 + 0.03), Color8(255, 210, 120), Vector3.ZERO, "glow")
				m.box(Vector3(0.7, 1.6, 0.05), Vector3(x * bw * 0.16, wh * 0.72, bd * 0.5 + 0.05), WHITE, Vector3.ZERO, "team")
			m.cyl(0.05, 0.05, 2.2, Vector3(0, wh + H * 0.35 + 1.0, -0.1), timber, Vector3.ZERO, 6)
			m.box(Vector3(1.1, 0.6, 0.04), Vector3(0.58, wh + H * 0.35 + 1.75, -0.1), WHITE, Vector3.ZERO, "team")
		"farm":
			var hw := W * 0.55
			m.box(Vector3(hw, H * 0.45, D * 0.5), Vector3(-W * 0.18, H * 0.225, -D * 0.12), plaster)
			for x in [-1, 1]:
				m.box(Vector3(0.15, H * 0.45, 0.06), Vector3(-W * 0.18 + x * hw * 0.45, H * 0.225, D * 0.13 + 0.01), timber)
			m.prism(Vector3(hw * 1.15, H * 0.4, D * 0.6), Vector3(-W * 0.18, H * 0.65, -D * 0.12), Color8(214, 178, 86))
			m.box(Vector3(0.7, 1.1, 0.06), Vector3(-W * 0.18, 0.55, D * 0.13 + 0.02), timber)
			m.box(Vector3(0.5, 0.45, 0.05), Vector3(-W * 0.32, H * 0.28, D * 0.13 + 0.02), Color8(255, 210, 120), Vector3.ZERO, "glow")
			m.box(Vector3(0.4, 1.0, 0.4), Vector3(-W * 0.05, H * 0.8, -D * 0.2), STONE_D)
			for i in 3:  # crop rows
				m.box(Vector3(W * 0.32, 0.35, 0.4), Vector3(W * 0.3, 0.2, -D * 0.25 + i * D * 0.25), Color8(150, 190, 70))
			m.box(Vector3(0.6, 0.6, 0.06), Vector3(W * 0.05, 0.9, D * 0.13 + 0.03), WHITE, Vector3.ZERO, "team")
		"barracks":
			m.box(Vector3(W * 0.9, 0.5, D * 0.75), Vector3(0, 0.25, 0), STONE_D)
			m.box(Vector3(W * 0.86, H * 0.42, D * 0.7), Vector3(0, 0.5 + H * 0.21, 0), WOOD_L)
			for i in 7:
				m.box(Vector3(0.14, H * 0.42, 0.08), Vector3(-W * 0.4 + i * W * 0.8 / 6.0, 0.5 + H * 0.21, D * 0.35 + 0.02), timber)
			m.prism(Vector3(W * 0.98, H * 0.42, D * 0.85), Vector3(0, 0.5 + H * 0.42 + H * 0.21, 0), WHITE, Vector3.ZERO, "team")
			m.box(Vector3(1.4, 1.8, 0.1), Vector3(0, 0.9 + 0.5, D * 0.35 + 0.04), timber.darkened(0.2))
			_shield(m, Vector3(-W * 0.25, 0.5 + H * 0.28, D * 0.35 + 0.1), 0.5)
			_shield(m, Vector3(W * 0.25, 0.5 + H * 0.28, D * 0.35 + 0.1), 0.5)
			for i in 4:  # weapon rack
				m.box(Vector3(0.06, 1.6, 0.06), Vector3(W * 0.46, 0.8, -D * 0.2 + i * 0.3), STEEL, Vector3(0, 0, 10))
		"mill":
			for x in [-1, 1]:
				for z in [-1, 1]:
					m.box(Vector3(0.25, H * 0.55, 0.25), Vector3(x * W * 0.38, H * 0.275, z * D * 0.3), timber)
			m.prism(Vector3(W * 0.9, H * 0.35, D * 0.8), Vector3(0, H * 0.55 + H * 0.175, 0), WHITE, Vector3.ZERO, "team")
			for i in 4:  # log pile
				m.cyl(0.32, 0.32, W * 0.5, Vector3(-W * 0.1, 0.32 + (i / 3) * 0.55, -D * 0.1 + (i % 3) * 0.66), WOOD_L, Vector3(0, 0, 90), 8)
			m.cyl(0.9, 0.9, 0.06, Vector3(W * 0.25, 1.0, D * 0.25), STEEL, Vector3(90, 0, 0), 16)  # saw blade
			for i in 3:
				m.sphere(0.45, Vector3(W * 0.3 + (i % 2) * 0.5, 0.35 + (i / 2) * 0.4, -D * 0.25), STONE, Vector3(1, 0.7, 1), 7)
		"stables":
			m.box(Vector3(W * 0.8, H * 0.45, D * 0.55), Vector3(-W * 0.05, H * 0.225, -D * 0.15), Color8(150, 74, 52))
			m.prism(Vector3(W * 0.88, H * 0.38, D * 0.65), Vector3(-W * 0.05, H * 0.45 + H * 0.19, -D * 0.15), WHITE, Vector3.ZERO, "team")
			m.box(Vector3(1.6, H * 0.35, 0.08), Vector3(-W * 0.05, H * 0.175, D * 0.13), timber)
			for i in 7:  # fence
				m.box(Vector3(0.12, 0.9, 0.12), Vector3(-W * 0.45 + i * W * 0.9 / 6.0, 0.45, D * 0.45), timber)
			m.box(Vector3(W * 0.9, 0.1, 0.08), Vector3(0, 0.7, D * 0.45), timber)
			for i in 2:
				m.cyl(0.4, 0.4, 0.7, Vector3(W * 0.3 + i * 0.85, 0.4, D * 0.22), Color8(222, 196, 104), Vector3(0, 0, 90), 10)
		"workshop":
			m.box(Vector3(W * 0.7, H * 0.5, D * 0.6), Vector3(-W * 0.1, H * 0.25, -D * 0.1), STONE)
			m.prism(Vector3(W * 0.78, H * 0.32, D * 0.7), Vector3(-W * 0.1, H * 0.5 + H * 0.16, -D * 0.1), WHITE, Vector3.ZERO, "team")
			m.box(Vector3(0.7, H * 0.9, 0.7), Vector3(-W * 0.35, H * 0.55, -D * 0.25), STONE_D)
			m.sphere(0.25, Vector3(-W * 0.35, H * 1.0, -D * 0.25), Color8(255, 150, 60), Vector3.ONE, 8, "glow")
			m.cyl(1.0, 1.0, 0.3, Vector3(W * 0.33, 1.3, D * 0.1), WOOD_L, Vector3(0, 0, 90), 12)  # cog
			for i in 8:
				var ang := TAU * i / 8.0
				m.box(Vector3(0.3, 0.35, 0.35), Vector3(W * 0.33, 1.3 + sin(ang) * 1.1, D * 0.1 + cos(ang) * 1.1), WOOD)
			m.box(Vector3(1.4, 1.1, 0.06), Vector3(-W * 0.1, H * 0.25, D * 0.2 + 0.02), timber)
		_:
			m.box(Vector3(W * 0.8, H * 0.5, D * 0.7), Vector3(0, H * 0.25, 0), plaster)
			m.prism(Vector3(W * 0.9, H * 0.4, D * 0.8), Vector3(0, H * 0.7, 0), WHITE, Vector3.ZERO, "team")


static func _orc_building(m: MeshMerger, kind: String, W: float, D: float, H: float) -> void:
	var logc := Color8(96, 66, 42)
	match kind:
		"hq":  # great hall: log walls, huge hide roof with tusks along the ridge
			m.box(Vector3(W * 0.82, H * 0.38, D * 0.7), Vector3(0, H * 0.19, 0), logc)
			for i in 9:
				m.cyl(0.28, 0.3, H * 0.42, Vector3(-W * 0.4 + i * W * 0.1, H * 0.21, D * 0.36), logc.lightened(0.08), Vector3.ZERO, 7)
			m.prism(Vector3(W * 0.98, H * 0.55, D * 0.92), Vector3(0, H * 0.38 + H * 0.275, 0), HIDE)
			for i in 5:
				m.cyl(0.0, 0.22, 1.4, Vector3(-W * 0.36 + i * W * 0.18, H * 0.96, 0), BONE, Vector3(0, 0, 10 - i * 5), 6)
			for s in [-1, 1]:  # tusk gate
				m.cyl(0.05, 0.3, H * 0.5, Vector3(s * 1.0, H * 0.22, D * 0.48), BONE, Vector3(-15, 0, s * 25), 8)
				m.box(Vector3(0.9, 2.2, 0.06), Vector3(s * W * 0.28, H * 0.35, D * 0.4), WHITE, Vector3.ZERO, "team")
			m.box(Vector3(1.4, H * 0.32, 0.1), Vector3(0, H * 0.16, D * 0.36 + 0.06), Color8(40, 28, 22))
			m.sphere(0.45, Vector3(W * 0.35, 0.3, D * 0.5), Color8(255, 130, 50), Vector3(1, 0.7, 1), 8, "glow")
		"farm":  # pig farm: hut + mud pen + pigs
			m.cyl(W * 0.22, W * 0.24, H * 0.32, Vector3(-W * 0.2, H * 0.16, -D * 0.15), logc, Vector3.ZERO, 8)
			m.cyl(0.0, W * 0.32, H * 0.5, Vector3(-W * 0.2, H * 0.32 + H * 0.25, -D * 0.15), HIDE, Vector3.ZERO, 8)
			m.box(Vector3(W * 0.5, 0.05, D * 0.55), Vector3(W * 0.2, 0.06, D * 0.1), Color8(110, 86, 60))
			for i in 6:
				var t := i / 5.0
				m.box(Vector3(0.12, 0.8, 0.12), Vector3(W * (-0.05 + 0.5 * t), 0.4, D * 0.4), logc)
			for p in [Vector3(W * 0.12, 0.4, D * 0.05), Vector3(W * 0.32, 0.4, D * 0.2), Vector3(W * 0.28, 0.4, -D * 0.08)]:
				m.sphere(0.45, p, Color8(232, 156, 150), Vector3(0.8, 0.75, 1.2), 8)
				m.sphere(0.2, p + Vector3(0, 0.05, 0.55), Color8(222, 140, 136), Vector3.ONE, 6)
			m.box(Vector3(0.7, 1.0, 0.05), Vector3(-W * 0.2, H * 0.2, -D * 0.15 + W * 0.24), WHITE, Vector3.ZERO, "team")
		"barracks":  # war camp: big tents + spikes + fire
			m.cyl(0.0, W * 0.32, H * 0.85, Vector3(-W * 0.18, H * 0.425, -D * 0.05), HIDE, Vector3.ZERO, 7)
			m.cyl(0.0, W * 0.25, H * 0.65, Vector3(W * 0.24, H * 0.325, D * 0.1), HIDE.lightened(0.1), Vector3.ZERO, 7)
			for p in [Vector3(-W * 0.18, H * 0.85, -D * 0.05), Vector3(W * 0.24, H * 0.65, D * 0.1)]:
				for s in [-1, 1]:
					m.cyl(0.0, 0.08, 1.0, p + Vector3(s * 0.2, 0.35, 0), BONE, Vector3(0, 0, -s * 25), 6)
			for i in 5:
				m.cyl(0.0, 0.12, 1.3, Vector3(-W * 0.45 + i * 0.6, 0.6, D * 0.45), logc.lightened(0.15), Vector3(25, 0, 0), 6)
			m.box(Vector3(0.9, 1.4, 0.05), Vector3(-W * 0.18, H * 0.3, -D * 0.05 + W * 0.3), WHITE, Vector3.ZERO, "team")
			m.sphere(0.5, Vector3(W * 0.05, 0.35, D * 0.4), Color8(255, 130, 50), Vector3(1, 0.8, 1), 8, "glow")
		"mill":
			for x in [-1, 1]:
				for z in [-1, 1]:
					m.cyl(0.18, 0.2, H * 0.6, Vector3(x * W * 0.38, H * 0.3, z * D * 0.3), logc, Vector3.ZERO, 6)
			m.prism(Vector3(W * 0.95, H * 0.35, D * 0.85), Vector3(0, H * 0.6 + H * 0.175, 0), HIDE)
			for i in 4:
				m.cyl(0.0, 0.15, 0.9, Vector3(-W * 0.35 + i * W * 0.23, H * 0.98, 0), BONE, Vector3.ZERO, 6)
			for i in 4:
				m.cyl(0.3, 0.3, W * 0.45, Vector3(-W * 0.1, 0.3 + (i / 3) * 0.5, -D * 0.1 + (i % 3) * 0.62), WOOD, Vector3(0, 0, 90), 8)
			for i in 3:
				m.sphere(0.45, Vector3(W * 0.3 + (i % 2) * 0.5, 0.35 + (i / 2) * 0.4, D * 0.2), STONE_D, Vector3(1, 0.7, 1), 7)
			m.box(Vector3(0.8, 1.2, 0.05), Vector3(0, H * 0.45, D * 0.3 + 0.2), WHITE, Vector3.ZERO, "team")
		"stables":  # beastiary: cage + hut
			m.cyl(W * 0.25, W * 0.28, H * 0.4, Vector3(-W * 0.2, H * 0.2, -D * 0.15), logc, Vector3.ZERO, 8)
			m.cyl(0.0, W * 0.34, H * 0.55, Vector3(-W * 0.2, H * 0.4 + H * 0.275, -D * 0.15), HIDE, Vector3.ZERO, 8)
			for i in 6:
				m.box(Vector3(0.15, 2.4, 0.15), Vector3(W * 0.08 + i * W * 0.07, 1.2, D * 0.25), logc)
			m.box(Vector3(W * 0.42, 0.18, 0.18), Vector3(W * 0.26, 2.3, D * 0.25), logc)
			m.sphere(0.6, Vector3(W * 0.25, 0.4, D * 0.38), BONE, Vector3(1.3, 0.4, 0.6), 8)  # bones
			m.box(Vector3(0.8, 1.2, 0.05), Vector3(-W * 0.2, H * 0.25, -D * 0.15 + W * 0.28), WHITE, Vector3.ZERO, "team")
		"workshop":  # siege works: open frame, wheel, scrap
			for x in [-1, 1]:
				m.box(Vector3(0.3, H * 0.8, 0.3), Vector3(x * W * 0.35, H * 0.4, -D * 0.1), logc)
			m.box(Vector3(W * 0.8, 0.35, 0.35), Vector3(0, H * 0.8, -D * 0.1), logc)
			m.box(Vector3(0.2, H * 0.6, 0.2), Vector3(0, H * 0.75, D * 0.1), logc.lightened(0.1), Vector3(35, 0, 0))
			m.cyl(1.1, 1.1, 0.25, Vector3(W * 0.3, 1.1, D * 0.25), WOOD, Vector3(0, 0, 90), 10)
			m.sphere(0.6, Vector3(-W * 0.25, 0.4, D * 0.25), STEEL_D, Vector3(1.4, 0.6, 1), 7)
			m.box(Vector3(1.0, 1.4, 0.05), Vector3(0, H * 0.6, -D * 0.1 + 0.2), WHITE, Vector3.ZERO, "team")
			m.sphere(0.4, Vector3(-W * 0.3, 0.3, -D * 0.35), Color8(255, 130, 50), Vector3(1, 0.8, 1), 8, "glow")
		_:
			m.cyl(0.0, minf(W, D) * 0.45, H, Vector3(0, H * 0.5, 0), HIDE, Vector3.ZERO, 7)
			m.box(Vector3(0.8, 1.2, 0.05), Vector3(0, H * 0.25, minf(W, D) * 0.3), WHITE, Vector3.ZERO, "team")


# ================================================================ resources

static func _tree(m: MeshMerger, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant
	var h := rng.randf_range(4.6, 6.2)
	m.cyl(0.22, 0.32, h * 0.4, Vector3(0, h * 0.2, 0), Color8(104, 70, 42), Vector3.ZERO, 7)
	if variant % 3 != 0:  # pine
		var g := Color8(40, 112, 60).lightened(rng.randf_range(0.0, 0.12))
		for i in 4:
			var r := 1.7 - i * 0.35
			m.cyl(0.0, r, h * 0.32, Vector3(0, h * 0.32 + i * h * 0.17, 0), g.lightened(i * 0.05), Vector3(0, rng.randf() * 60, 0), 8)
	else:  # broadleaf
		var g := Color8(70, 140, 62).lightened(rng.randf_range(0.0, 0.1))
		m.sphere(1.6, Vector3(0, h * 0.62, 0), g, Vector3(1, 0.95, 1), 9)
		m.sphere(1.05, Vector3(0.8, h * 0.78, 0.3), g.lightened(0.08), Vector3.ONE, 8)
		m.sphere(1.0, Vector3(-0.7, h * 0.72, -0.4), g.darkened(0.08), Vector3.ONE, 8)


static func _gold_mine(m: MeshMerger, variant: int) -> void:
	var rock := Color8(128, 114, 100)
	m.sphere(2.4, Vector3(0, 0.3, -0.4), rock, Vector3(1.25, 0.9, 1.0), 10)
	m.sphere(1.4, Vector3(-1.6, 0.4, 0.5), rock.lightened(0.06), Vector3(1, 0.8, 1), 8)
	m.sphere(1.2, Vector3(1.7, 0.3, 0.6), rock.darkened(0.06), Vector3(1, 0.8, 1), 8)
	m.box(Vector3(1.6, 1.8, 0.6), Vector3(0, 0.9, 1.65), Color8(22, 16, 18))
	for x in [-1, 1]:
		m.box(Vector3(0.22, 2.0, 0.22), Vector3(x * 0.9, 1.0, 1.95), WOOD)
	m.box(Vector3(2.2, 0.24, 0.24), Vector3(0, 2.0, 1.95), WOOD)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant + 7
	for i in 12:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 2.4, rng.randf_range(0.6, 2.2), sin(a) * 1.4)
		m.sphere(rng.randf_range(0.15, 0.3), p, GOLD, Vector3.ONE, 6, "glow")


static func _stone_quarry(m: MeshMerger, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant + 3
	for i in 5:
		var p := Vector3(rng.randf_range(-1.1, 1.1), 0.3, rng.randf_range(-0.8, 0.8))
		var r := rng.randf_range(0.6, 1.1)
		m.sphere(r, p, Color8(180, 184, 192).darkened(rng.randf_range(0, 0.15)), Vector3(1, 0.75, 1), 7)
