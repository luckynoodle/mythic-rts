class_name WorldView
extends Node3D
## The 3D presentation of the match.
##
## The simulation (Game, Unit, Building...) is 2D and authoritative. Every frame
## this view mirrors it: it creates a 3D visual for each new entity, updates
## existing ones, and plays a death animation for anything that disappeared.
## Nothing in the simulation depends on this node, so it can be replaced or
## improved without touching game logic.

const GROUND_COLOR_A := Color8(58, 104, 40)
const GROUND_COLOR_B := Color8(92, 138, 56)

var camera: RTSCamera
var input_ctrl = null    # TouchInput (for the placement ghost and selection)
var sun: DirectionalLight3D

var _visuals := {}       # instance id -> EntityVisual
var _dying: Array = []
var _markers := {}       # instance id -> MeshInstance3D
var _ghost: Node3D
var _ghost_id := ""
var _ghost_plate: MeshInstance3D
var _rally: Node3D
var _ring_mats := {}


func _ready() -> void:
	name = "WorldView"
	_environment()
	_terrain()
	_border_forest()
	_decor()
	camera = RTSCamera.new()
	add_child(camera)
	camera.make_current()
	_rally = _make_flag()
	_rally.visible = false
	add_child(_rally)


func _process(delta: float) -> void:
	_sync_entities(delta)
	_sync_markers()
	_sync_ghost()
	_sync_rally()


# ---------------------------------------------------------------- syncing

func _sync_entities(delta: float) -> void:
	var seen := {}
	for u in Game.units:
		if Entity.alive(u):
			_touch(u, seen, delta, UnitVisual)
	for b in Game.buildings:
		if Entity.alive(b):
			_touch(b, seen, delta, BuildingVisual)
	for n in Game.resource_nodes:
		if ResourceNode.alive(n):
			_touch(n, seen, delta, ResourceVisual)
	for p in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			_touch(p, seen, delta, ProjectileVisual)
	for id in _visuals.keys():
		if not seen.has(id):
			var v: EntityVisual = _visuals[id]
			_visuals.erase(id)
			v.start_dying()
			_dying.append(v)
	for i in range(_dying.size() - 1, -1, -1):
		var v: EntityVisual = _dying[i]
		if v.process_death(delta):
			v.queue_free()
			_dying.remove_at(i)


func _touch(e: Node, seen: Dictionary, delta: float, visual_class) -> void:
	var id := e.get_instance_id()
	seen[id] = true
	var v: EntityVisual = _visuals.get(id)
	if v == null:
		v = visual_class.new()
		add_child(v)
		v.setup(e, self)
		_visuals[id] = v
	v.sync(delta)


func visual_for(e: Node) -> EntityVisual:
	return _visuals.get(e.get_instance_id())


func _sync_markers() -> void:
	var seen := {}
	for m in get_tree().get_nodes_in_group("markers"):
		var id: int = m.get_instance_id()
		seen[id] = true
		var mi: MeshInstance3D = _markers.get(id)
		if mi == null:
			mi = MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.75
			t.outer_radius = 0.95
			mi.mesh = t
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = m.color
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_markers[id] = mi
		var k: float = clampf(m._age / CommandMarker.LIFETIME, 0.0, 1.0)
		mi.position = ViewSpace.to_3d(m.global_position, 0.08)
		var s := 0.5 + k * 1.2
		mi.scale = Vector3(s, 0.2, s)
		var mat: StandardMaterial3D = mi.material_override
		mat.albedo_color = Color(mat.albedo_color, 1.0 - k)
	for id in _markers.keys():
		if not seen.has(id):
			_markers[id].queue_free()
			_markers.erase(id)


func _sync_ghost() -> void:
	var ghost = input_ctrl.ghost if input_ctrl else null
	if ghost == null or not is_instance_valid(ghost):
		if _ghost:
			_ghost.queue_free()
			_ghost = null
			_ghost_id = ""
		return
	if _ghost_id != input_ctrl.placing:
		if _ghost:
			_ghost.queue_free()
		_ghost_id = input_ctrl.placing
		var fid := Game.faction_of(input_ctrl.team)
		var bdef := GameData.get_building_def(fid, _ghost_id)
		_ghost = Node3D.new()
		var model := ModelLibrary.building_model(fid, _ghost_id, bdef)
		ModelLibrary.apply_team_color(model, Game.get_player(input_ctrl.team).color)
		for mi in ModelLibrary.meshes(model):
			mi.transparency = 0.45
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.add_child(model)
		var plate := BoxMesh.new()
		plate.size = Vector3(ghost.size.x, 2.0, ghost.size.y) / ViewSpace.PX_PER_M
		plate.size.y = 0.08
		_ghost_plate = MeshInstance3D.new()
		_ghost_plate.mesh = plate
		_ghost_plate.position.y = 0.06
		_ghost.add_child(_ghost_plate)
		add_child(_ghost)
	_ghost.position = ViewSpace.to_3d(ghost.position)
	var col := Color(0.35, 1.0, 0.45, 0.55) if ghost.valid else Color(1.0, 0.3, 0.25, 0.6)
	_ghost_plate.material_override = _unshaded(col, true)


func _sync_rally() -> void:
	var b = input_ctrl.selected_own_building() if input_ctrl else null
	_rally.visible = b != null and b.is_complete and not b.trains.is_empty()
	if _rally.visible:
		_rally.position = ViewSpace.to_3d(b.rally_point)


# ---------------------------------------------------------------- helpers used by visuals

func make_ring(radius: float, friendly: bool) -> Node3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius
	t.outer_radius = radius + 0.12
	t.rings = 24
	mi.mesh = t
	mi.scale = Vector3(1, 0.25, 1)
	mi.position.y = 0.06
	mi.material_override = _unshaded(Color8(110, 255, 130) if friendly else Color8(255, 90, 80))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


## Rectangular selection frame for buildings.
func make_frame(size: Vector2, friendly: bool) -> Node3D:
	var root := Node3D.new()
	var mat := _unshaded(Color8(110, 255, 130) if friendly else Color8(255, 90, 80))
	for side in [[Vector3(size.x, 0.05, 0.14), Vector3(0, 0.06, size.y * 0.5)],
			[Vector3(size.x, 0.05, 0.14), Vector3(0, 0.06, -size.y * 0.5)],
			[Vector3(0.14, 0.05, size.y), Vector3(size.x * 0.5, 0.06, 0)],
			[Vector3(0.14, 0.05, size.y), Vector3(-size.x * 0.5, 0.06, 0)]]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = side[0]
		mi.mesh = b
		mi.position = side[1]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	root.visible = false
	return root


func make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := SphereMesh.new()
	q.radius = 0.5
	q.height = 1.0
	q.radial_segments = 6
	q.rings = 3
	p.mesh = q
	p.material_override = _lit(Color8(60, 58, 60, 255))
	p.amount = 14
	p.lifetime = 2.6
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0.4, 0.3, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	return p


func make_dust(size: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := SphereMesh.new()
	q.radius = 0.35
	q.height = 0.7
	q.radial_segments = 6
	q.rings = 3
	p.mesh = q
	p.material_override = _lit(Color8(196, 172, 132))
	p.amount = 18
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.5, 0.2, size.y * 0.5)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, -0.4, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	return p


func _unshaded(c: Color, transparent := false) -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), transparent]
	if not _ring_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		if transparent:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mats[key] = m
	return _ring_mats[key]


func _lit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _make_flag() -> Node3D:
	var m := MeshMerger.new()
	m.cyl(0.05, 0.05, 2.2, Vector3(0, 1.1, 0), PlaceholderModels.WOOD, Vector3.ZERO, 6)
	m.box(Vector3(0.9, 0.55, 0.04), Vector3(0.47, 1.9, 0), Color8(110, 255, 130))
	var mi := MeshInstance3D.new()
	mi.mesh = m.commit()
	var root := Node3D.new()
	root.add_child(mi)
	return root


# ---------------------------------------------------------------- world dressing

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(150, 190, 220)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(186, 204, 236)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.light_energy = 1.25
	sun.light_color = Color8(255, 242, 220)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)


func _terrain() -> void:
	var size := Game.MAP_SIZE / ViewSpace.PX_PER_M
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var grad := Gradient.new()
	grad.set_color(0, GROUND_COLOR_A)
	grad.set_color(1, GROUND_COLOR_B)
	grad.add_point(0.55, Color8(74, 122, 48))
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(6, 4.5, 1)
	mat.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = size
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = mat
	ground.position = Vector3(size.x * 0.5, 0, size.y * 0.5)
	add_child(ground)
	# Darker forest floor beyond the playable area.
	var outer := PlaneMesh.new()
	outer.size = size + Vector2(240, 240)
	var outer_mi := MeshInstance3D.new()
	outer_mi.mesh = outer
	outer_mi.position = ground.position + Vector3(0, -0.05, 0)
	outer_mi.material_override = _lit(Color8(36, 66, 32))
	add_child(outer_mi)


## Non-interactive trees outside the map edge, so the camera never shows a void.
func _border_forest() -> void:
	var size := Game.MAP_SIZE / ViewSpace.PX_PER_M
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var by_variant := {}
	for i in 900:
		var p := Vector3(rng.randf_range(-40, size.x + 40), 0, rng.randf_range(-40, size.y + 40))
		var inside := p.x > 2 and p.x < size.x - 2 and p.z > 2 and p.z < size.y - 2
		if inside:
			continue
		var v := rng.randi_range(0, 5)
		if not by_variant.has(v):
			by_variant[v] = []
		var s := rng.randf_range(0.9, 1.35)
		by_variant[v].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
	for v in by_variant:
		var model := PlaceholderModels.resource("wood", v)
		var mesh: Mesh = (model.get_node("Mesh") as MeshInstance3D).mesh
		model.free()
		_multimesh(mesh, by_variant[v])


func _decor() -> void:
	var size := Game.MAP_SIZE / ViewSpace.PX_PER_M
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tuft := MeshMerger.new()
	for i in 3:
		tuft.cyl(0.0, 0.06, 0.38, Vector3((i - 1) * 0.08, 0.17, 0), Color8(70, 130, 52), Vector3(0, 0, (i - 1) * 18), 4)
	var flowers := [Color8(246, 96, 110), Color8(255, 226, 96), Color8(250, 250, 250), Color8(150, 130, 250)]
	var rock := MeshMerger.new()
	rock.sphere(0.22, Vector3(0, 0.05, 0), Color8(160, 162, 168), Vector3(1, 0.6, 1), 6)
	var lists := {"tuft": [], "rock": []}
	for i in 2200:
		lists["tuft"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf() * size.x, 0, rng.randf() * size.y)))
	for i in 160:
		var s := rng.randf_range(0.6, 1.8)
		lists["rock"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(rng.randf() * size.x, 0, rng.randf() * size.y)))
	_multimesh(tuft.commit(), lists["tuft"])
	_multimesh(rock.commit(), lists["rock"])
	for c in flowers:
		var f := MeshMerger.new()
		f.sphere(0.09, Vector3(0, 0.12, 0), c, Vector3.ONE, 5)
		f.sphere(0.07, Vector3(0.15, 0.1, 0.08), c, Vector3.ONE, 5)
		var xs: Array = []
		for i in 120:
			var center := Vector3(rng.randf() * size.x, 0, rng.randf() * size.y)
			for j in 3:
				xs.append(Transform3D(Basis(), center + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))))
		_multimesh(f.commit(), xs)


func _multimesh(mesh: Mesh, transforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
