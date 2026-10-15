class_name Roadworks
extends Node3D
## Where a cobbled road is still being laid (Roads.works): the workers' things left at the end of
## the cobbles. A pallet of new stones and a sand pile with a shovel in it on one side, a
## wheelbarrow and a ROAD WORKS sign on the other, a string line pegged out along the next stretch,
## a mallet and a kneeling board by the last stones, and a few stones dropped on the sand bed.
## The pallet, sand pile and barrow are solid, and are cut out of the walkable ground.

const STONE := Color("#8a8c90")
const WOOD := Color("#9a7448")
const DARK_WOOD := Color("#5a4028")
const SAND := Color("#c9ad7c")
const STEEL := Color("#7f868c")
const BARROW := Color("#4f6b4a")
const RUBBER := Color("#2a2a2a")
const STRING := Color("#e8d27a")

var _mats := {}
var _body: StaticBody3D
var _frame: Transform3D           # local x across the road, z along it (outward), at the cobbles' end


func _ready() -> void:
	var roads := get_parent().get_node_or_null("Roads") as Roads
	if roads == null:
		return
	var nav := get_tree().get_first_node_in_group("world_nav") as WorldNav
	for w in roads.works:
		var pos: Vector2 = w.pos
		var dir: Vector2 = w.dir
		_frame = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(pos.x, 0.0, pos.y))
		_body = StaticBody3D.new()
		_body.name = "Solid"
		_body.collision_layer = 1
		_body.collision_mask = 0
		add_child(_body)
		_build(nav)


func _build(nav: WorldNav) -> void:
	# ---- one side: a pallet of new cobbles, and the sand pile with a shovel in it ----
	var px := 2.45
	var pz := 0.9
	_box("Pallet", Vector3(1.0, 0.12, 0.8), WOOD, Vector3(px, 0.06, pz))
	for layer in 3:
		for i in 4:
			for j in 3:
				if layer == 2 and (i * 3 + j) % 4 == 1:
					continue                              # some already taken off the top
				var h := fposmod(sin(float(layer * 31 + i * 7 + j) * 12.9898) * 43758.5, 1.0)
				_box("Cobble", Vector3(0.22, 0.11, 0.2), STONE.darkened(h * 0.15),
					Vector3(px - 0.36 + i * 0.24, 0.175 + layer * 0.12, pz - 0.24 + j * 0.24), (h - 0.5) * 0.1)
	_solid(Vector3(1.05, 0.6, 0.85), Vector3(px, 0.3, pz), nav)
	var sx := 2.75
	var sz := 3.5
	_mesh("SandPile", _cone(0.95, 0.9), SAND, Vector3(sx, 0.0, sz), 0.0, Vector3(1.0, 1.0, 1.25))
	var shovel := _node("Shovel", Vector3(sx - 0.3, 0.42, sz + 0.1), 0.0)
	shovel.rotation = Vector3(0.35, 0.4, 0.25)
	_box("Handle", Vector3(0.035, 1.0, 0.035), DARK_WOOD, Vector3(0, 0.45, 0), 0.0, shovel)
	_box("Grip", Vector3(0.16, 0.035, 0.035), DARK_WOOD, Vector3(0, 0.96, 0), 0.0, shovel)
	_box("Blade", Vector3(0.24, 0.3, 0.02), STEEL, Vector3(0, -0.15, 0), 0.0, shovel)
	_solid(Vector3(1.6, 0.5, 2.0), Vector3(sx, 0.25, sz), nav)
	_mesh("Bucket", _cyl(0.15, 0.12, 0.3), STEEL, Vector3(px + 0.75, 0.15, pz - 0.65))
	_mesh("Water", _cyl(0.135, 0.135, 0.01), Color("#5d6f7c"), Vector3(px + 0.75, 0.27, pz - 0.65))

	# ---- the other side: a wheelbarrow with a few stones in it ----
	var barrow := _node("Wheelbarrow", Vector3(-2.45, 0.0, 0.5), 0.35)
	_box("Tray", Vector3(0.62, 0.28, 0.8), BARROW, Vector3(0, 0.52, 0), 0.0, barrow)
	_box("TrayLip", Vector3(0.68, 0.04, 0.86), BARROW.darkened(0.2), Vector3(0, 0.67, 0), 0.0, barrow)
	for k in 4:
		_box("Cobble", Vector3(0.22, 0.11, 0.2), STONE, Vector3(-0.15 + (k % 2) * 0.3, 0.72, -0.15 + (k / 2) * 0.26), k * 0.4, barrow)
	var wheel := _mesh("Wheel", _cyl(0.2, 0.2, 0.08), RUBBER, Vector3(0, 0.2, 0.55), 0.0, Vector3.ONE, barrow)
	wheel.rotation = Vector3(0, 0, PI / 2)
	for s: int in [-1, 1]:
		var arm := _box("Handle", Vector3(0.04, 0.04, 1.3), DARK_WOOD, Vector3(s * 0.26, 0.48, -0.15), 0.0, barrow)
		arm.rotation.x = -0.22
		_box("Leg", Vector3(0.04, 0.38, 0.04), DARK_WOOD, Vector3(s * 0.22, 0.19, -0.3), 0.0, barrow)
	_solid(Vector3(0.75, 0.8, 1.45), Vector3(-2.45, 0.4, 0.4), nav, 0.35)

	# ---- on the road: the string line pegged out along the next stretch ----
	for s: int in [-1, 1]:
		var x: float = s * 1.35
		for z: float in [-0.4, 8.5]:
			_box("Peg", Vector3(0.04, 0.32, 0.04), WOOD, Vector3(x, 0.16, z))
		_box("StringLine", Vector3(0.006, 0.006, 8.9), STRING, Vector3(x, 0.26, 4.05))
	# a mallet and a kneeling board by the last stones
	_box("KneelingBoard", Vector3(0.45, 0.03, 0.32), DARK_WOOD, Vector3(0.45, 0.015, -0.9), 0.3)
	var mallet := _node("Mallet", Vector3(-0.35, 0.05, -0.55), 1.1)
	var head := _mesh("Head", _cyl(0.05, 0.05, 0.16), RUBBER, Vector3(0, 0, 0.17), 0.0, Vector3.ONE, mallet)
	head.rotation.z = PI / 2
	var shaft := _box("Shaft", Vector3(0.03, 0.03, 0.34), WOOD, Vector3(0, -0.02, 0), 0.0, mallet)
	shaft.position.y = -0.02
	# a few stones dropped on the sand bed past the end
	for k in 7:
		var h := fposmod(sin(float(k) * 78.233) * 43758.5, 1.0)
		var h2 := fposmod(sin(float(k) * 12.989 + 3.0) * 43758.5, 1.0)
		_box("LooseCobble", Vector3(0.22, 0.1, 0.2), STONE.darkened(h * 0.15),
			Vector3(-0.9 + h * 1.8, 0.05, 0.3 + h2 * 1.4), h * 3.0)


# ---------- helpers: everything is placed in the works' frame (x across, z along the road) ----------

func _mat(c: Color) -> StandardMaterial3D:
	if not _mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[c] = m
	return _mats[c]


func _node(n: String, p: Vector3, yaw: float) -> Node3D:
	var node := Node3D.new()
	node.name = n
	node.transform = _frame * Transform3D(Basis(Vector3.UP, yaw), p)
	add_child(node)
	return node


func _mesh(n: String, m: Mesh, c: Color, p: Vector3, yaw := 0.0, s := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.material_override = _mat(c)
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(s), p)
	if parent:
		mi.transform = t
		parent.add_child(mi)
	else:
		mi.transform = _frame * t
		add_child(mi)
	return mi


func _box(n: String, size: Vector3, c: Color, p: Vector3, yaw := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(n, b, c, p, yaw, Vector3.ONE, parent)


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	return c


# a rounded heap: a sphere's top half, squashed
func _cone(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.is_hemisphere = true
	s.radial_segments = 20
	s.rings = 6
	return s


# a solid box (works frame), cut out of the walkable ground with room for a resident round it
func _solid(size: Vector3, p: Vector3, nav: WorldNav, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = _frame * Transform3D(Basis(Vector3.UP, yaw), p)
	_body.add_child(cs)
	var r := Rect2()
	var first := true
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			var w: Vector3 = cs.transform * Vector3(sx * size.x, 0.0, sz * size.z)
			if first:
				r = Rect2(Vector2(w.x, w.z), Vector2.ZERO)
				first = false
			else:
				r = r.expand(Vector2(w.x, w.z))
	if nav:
		nav.carve(r.grow(0.3))
	for i in Hex.tiles_in(r.grow(0.2)):
		Game.tiles.set_flag(i, TileGrid.F_BLOCK)
