class_name Forest
extends Node3D
## A stand of pines behind Timber Hollow, Brann's woods (as in the HTML game, where he fells trees,
## gathers the logs and stacks them at home). A felled tree topples away from the axe and leaves a
## stump and three logs on the ground; a while later a new tree has grown in its place.
##
## The trees are laid out from a fixed seed, so they're the same every game. Each trunk is solid
## and is cut out of the walkable ground, so everyone walks round them.

## Centre and radius of the woods (world x, z, metres), and how many trees to try for.
@export var centre := Vector2(-74.0, -80.5)
@export var radius := 12.0
@export var trees_wanted := 46
## Keep clear of a circle round the cabin (centre, radius) so its yard stays open.
@export var keep_clear := Vector3(-68.2, -68.2, 8.5)
@export var spacing := 2.3
## The seed the trees are laid out from.
@export var layout_seed := 7_2024
## Brann's woods, where trees are felled (another stand, like the old woods round the wizard's
## tower, is only scenery: nobody fells those).
@export var for_felling := true
## Game seconds before a felled tree has grown back (a day and a half).
@export var regrow_after := 180.0

const TRUNK_R := 0.2
const LOG_LEN := 0.8

var trees: Array[Dictionary] = []   # {pos: Vector3, node: Node3D, stump: Node3D, felled_at: float (-1 standing), scale}
var logs: Array[Node3D] = []        # logs lying on the ground

var _bark: StandardMaterial3D
var _needles: StandardMaterial3D
var _needles_dark: StandardMaterial3D
var _cut: StandardMaterial3D
var _log_mesh: CylinderMesh
var _falling: Array[Dictionary] = []  # {tree, axis, t}
var _blocked: Array = []


func _ready() -> void:
	if for_felling:
		add_to_group("forest")
	_bark = _mat(0x5e3d24)
	_needles = _mat(0x2f5a2c)
	_needles_dark = _mat(0x24472a)
	_cut = _mat(0xc49a6c)
	_log_mesh = CylinderMesh.new()
	_log_mesh.top_radius = 0.1
	_log_mesh.bottom_radius = 0.1
	_log_mesh.height = LOG_LEN
	_log_mesh.radial_segments = 8
	_log_mesh.rings = 1
	_log_mesh.material = _bark
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var spots: Array[Vector3] = []
	for attempt in trees_wanted * 30:
		if spots.size() >= trees_wanted:
			break
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := Vector3(centre.x + cos(a) * d, 0.0, centre.y + sin(a) * d)
		if Vector2(p.x - keep_clear.x, p.z - keep_clear.y).length() < keep_clear.z:
			continue
		var ok := true
		for q in spots:
			if p.distance_to(q) < spacing:
				ok = false
				break
		if ok:
			spots.append(p)
	var holes: Array = []
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for p in spots:
		var sc := rng.randf_range(0.85, 1.3)
		var t := {"pos": p, "scale": sc, "felled_at": -1.0}
		t.node = _tree_node(sc, rng.randf() * TAU)
		t.node.position = p
		add_child(t.node)
		t.stump = _stump_node()
		t.stump.position = p
		t.stump.visible = false
		add_child(t.stump)
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = TRUNK_R + 0.05
		shape.height = 2.0
		cs.shape = shape
		cs.position = p + Vector3.UP
		body.add_child(cs)
		holes.append(Rect2(p.x - TRUNK_R - 0.35, p.z - TRUNK_R - 0.35, 2 * (TRUNK_R + 0.35), 2 * (TRUNK_R + 0.35)))
		trees.append(t)
		for i in Hex.tiles_in(Rect2(p.x - 0.4, p.z - 0.4, 0.8, 0.8)):
			Game.tiles.set_flag(i, TileGrid.F_BLOCK)
			Game.tiles.set_kind(i, "woods")
	_blocked = holes
	add_to_group("nav_blockers")
	var nav := get_tree().get_first_node_in_group("world_nav") as WorldNav
	if nav:
		nav.carve_many(holes)


## The areas (world x, z) cut out of the walkable ground; buildings leave them out of their own
## navigation meshes too, where they overlap.
func blocker_rects() -> Array:
	return _blocked


func _mat(hex: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Look.html_hex(hex)
	m.roughness = 0.95
	return m


func _tree_node(sc: float, turn: float) -> Node3D:
	var n := Node3D.new()
	n.scale = Vector3.ONE * sc
	n.rotation.y = turn
	var trunk := CylinderMesh.new()
	trunk.top_radius = TRUNK_R * 0.7
	trunk.bottom_radius = TRUNK_R
	trunk.height = 1.9
	trunk.radial_segments = 8
	trunk.rings = 1
	trunk.material = _bark
	_add_mesh(n, trunk, Vector3(0, 0.95, 0))
	for k in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.25 - k * 0.3
		cone.height = 1.7 - k * 0.25
		cone.radial_segments = 9
		cone.rings = 1
		cone.material = _needles if k % 2 == 0 else _needles_dark
		_add_mesh(n, cone, Vector3(0, 1.9 + k * 0.85, 0))
	return n


func _stump_node() -> Node3D:
	var n := Node3D.new()
	var s := CylinderMesh.new()
	s.top_radius = TRUNK_R + 0.02
	s.bottom_radius = TRUNK_R + 0.05
	s.height = 0.35
	s.radial_segments = 8
	s.rings = 1
	s.material = _bark
	_add_mesh(n, s, Vector3(0, 0.175, 0))
	var top := CylinderMesh.new()
	top.top_radius = TRUNK_R
	top.bottom_radius = TRUNK_R
	top.height = 0.01
	top.radial_segments = 8
	top.rings = 1
	top.material = _cut
	_add_mesh(n, top, Vector3(0, 0.355, 0))
	return n


func _add_mesh(parent: Node3D, m: Mesh, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	parent.add_child(mi)
	return mi


func is_standing(i: int) -> bool:
	return trees[i].felled_at < 0.0


## The standing trees nearest a point, nearest first (indices), within a distance.
func standing_near(p: Vector3, within: float) -> Array[int]:
	var found: Array = []
	for i in trees.size():
		if is_standing(i):
			var d := Hex.distance(p, trees[i].pos)
			if d < within:
				found.append([d, i])
	found.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var out: Array[int] = []
	for f in found:
		out.append(f[1])
	return out


## Fell a tree: it topples away from `from` and leaves a stump and three logs where it lands.
func fell(i: int, from: Vector3) -> void:
	if not is_standing(i):
		return
	var t := trees[i]
	t.felled_at = Game.world_time
	var away := Hex.offset(from, t.pos)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	t.stump.visible = true
	_falling.append({"tree": i, "axis": away.cross(Vector3.DOWN).normalized(), "away": away, "t": 0.0})


func _process(delta: float) -> void:
	for k in range(_falling.size() - 1, -1, -1):
		var f := _falling[k]
		var t := trees[f.tree]
		f.t += delta
		var a := minf(1.0, f.t / 1.1)
		var n: Node3D = t.node
		n.basis = Basis(f.axis, a * a * PI / 2).scaled(Vector3.ONE * t.scale) * Basis(Vector3.UP, 0.0)
		if f.t > 1.6:
			n.visible = false
			n.basis = Basis.IDENTITY.scaled(Vector3.ONE * t.scale)
			for j in 3:
				_drop_log(t.pos + f.away * (0.9 + j * 0.85) * t.scale + f.axis * randf_range(-0.25, 0.25), f.away)
			_falling.remove_at(k)
	# trees grow back where they were felled
	for t in trees:
		if t.felled_at >= 0.0 and Game.world_time - t.felled_at > regrow_after:
			t.felled_at = -1.0
			t.node.visible = true
			t.stump.visible = false


func _drop_log(p: Vector3, along: Vector3) -> void:
	var l := MeshInstance3D.new()
	l.mesh = _log_mesh
	add_child(l)
	l.position = Vector3(p.x, 0.1, p.z)
	# lying across the way the tree fell, a little askew
	var dir := along.cross(Vector3.UP).rotated(Vector3.UP, randf_range(-0.4, 0.4))
	l.basis = Basis(Vector3.UP, atan2(dir.x, dir.z)) * Basis(Vector3.RIGHT, PI / 2)
	logs.append(l)


## The loose log nearest a point, within a distance (or null).
func log_near(p: Vector3, within: float) -> Node3D:
	var best: Node3D = null
	var bd := within
	for l in logs:
		var d := Hex.distance(p, l.position)
		if d < bd:
			bd = d
			best = l
	return best


func take_log(l: Node3D) -> void:
	logs.erase(l)
	l.queue_free()
