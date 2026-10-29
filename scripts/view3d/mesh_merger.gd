class_name MeshMerger
extends RefCounted
## Combines many primitive shapes into a single ArrayMesh with vertex colours,
## so a whole placeholder model renders in 2-3 draw calls instead of dozens.
##
## Surfaces:
##   "base" - ordinary coloured parts
##   "team" - parts tinted by the owner's team colour (material named "team")
##   "glow" - emissive parts (windows, fires, gold)

const SURFACE_ORDER := ["base", "team", "glow"]

static var _materials := {}

var _data := {}


func add(mesh: PrimitiveMesh, xf: Transform3D, color: Color, surface := "base") -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if not _data.has(surface):
		_data[surface] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	var d: Dictionary = _data[surface]
	var v: PackedVector3Array = d["v"]
	var n: PackedVector3Array = d["n"]
	var c: PackedColorArray = d["c"]
	var ii: PackedInt32Array = d["i"]
	var base := v.size()
	var nb := xf.basis.inverse().transposed()
	for k in verts.size():
		v.append(xf * verts[k])
		n.append((nb * norms[k]).normalized())
		c.append(color)
	if idx.is_empty():
		for k in verts.size():
			ii.append(base + k)
	else:
		for k in idx:
			ii.append(base + k)
	d["v"] = v
	d["n"] = n
	d["c"] = c
	d["i"] = ii


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in SURFACE_ORDER:
		if not _data.has(s):
			continue
		var d: Dictionary = _data[s]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = d["v"]
		arrays[Mesh.ARRAY_NORMAL] = d["n"]
		arrays[Mesh.ARRAY_COLOR] = d["c"]
		arrays[Mesh.ARRAY_INDEX] = d["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var i := mesh.get_surface_count() - 1
		mesh.surface_set_material(i, material(s))
		mesh.surface_set_name(i, s)
	return mesh


static func material(surface: String) -> StandardMaterial3D:
	if _materials.has(surface):
		return _materials[surface]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.82
	match surface:
		"team":
			m.resource_name = "team"
			m.albedo_color = Color.WHITE
		"glow":
			m.resource_name = "glow"
			m.emission_enabled = true
			m.emission = Color8(255, 190, 90)
			m.emission_energy_multiplier = 0.7
	_materials[surface] = m
	return m


# ---------------------------------------------------------------- shape helpers

static func xf(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl)
	return Transform3D(b, pos)


func box(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, surface := "base") -> void:
	var b := BoxMesh.new()
	b.size = size
	add(b, xf(pos, rot), color, surface)


func cyl(top: float, bottom: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO, seg := 10, surface := "base") -> void:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	add(c, xf(pos, rot), color, surface)


func sphere(r: float, pos: Vector3, color: Color, scl := Vector3.ONE, seg := 10, surface := "base", hemi := false) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = seg
	s.rings = maxi(3, seg / 2)
	add(s, xf(pos, Vector3.ZERO, scl), color, surface)


func prism(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, surface := "base") -> void:
	var p := PrismMesh.new()
	p.size = size
	add(p, xf(pos, rot), color, surface)
