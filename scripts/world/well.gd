class_name Well
extends Node3D
## The well in the middle of the town square (as in the HTML game, where it stood in front of the
## tavern): a stone ring with water in it, two posts, a winding beam with a bucket and a little
## shingled roof. Residents come here to drink (see Resident's needs); so can you (F).

@export var spot := Vector2(0.0, 8.9)

const RING_R := 0.8

var _blocked: Array = []


## The area (world x, z) cut out of the walkable ground.
func blocker_rects() -> Array:
	return _blocked


func _ready() -> void:
	add_to_group("well")
	position = Vector3(spot.x, 0.0, spot.y)
	var stone := Gear.mat(0x8c8f96, 0.95)
	var wood := Gear.mat(0x6b4a33, 0.9)
	var water := Gear.mat(0x2f5b7a, 0.2, 0.2)
	_put(_cyl(RING_R - 0.02, RING_R, 0.68, 20), stone, Vector3(0, 0.34, 0))
	_put(_cyl(RING_R + 0.03, RING_R + 0.03, 0.08, 20), Gear.mat(0x6e7176, 0.95), Vector3(0, 0.7, 0))
	var w := _put(_cyl(RING_R - 0.15, RING_R - 0.15, 0.02, 20), water, Vector3(0, 0.6, 0))
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s in [-1, 1]:
		_put(_box(Vector3(0.12, 1.5, 0.12)), wood, Vector3(0.68 * s, 1.0, 0))
	_put(_cyl(0.06, 0.06, 1.5, 8), wood, Vector3(0, 1.64, 0), Vector3(0, 0, PI / 2))
	var roof := _put(_cyl(0.0, 1.1, 0.64, 4), Gear.mat(0x7a3b2e, 0.85), Vector3(0, 2.04, 0), Vector3(0, PI / 4, 0))
	roof.scale = Vector3(1, 1, 0.75)
	_put(_cyl(0.012, 0.012, 0.5, 4), Gear.mat(0x3a2a20), Vector3(0, 1.35, 0))
	_put(_cyl(0.14, 0.12, 0.2, 10), wood, Vector3(0, 1.0, 0))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = RING_R + 0.03
	sh.height = 1.6
	cs.shape = sh
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)
	var h := RING_R + 0.35
	_blocked = [Rect2(spot.x - h, spot.y - h, 2 * h, 2 * h)]
	add_to_group("nav_blockers")
	var nav := get_tree().get_first_node_in_group("world_nav") as WorldNav
	if nav:
		nav.carve_many(_blocked)
	for i in Hex.tiles_in(Rect2(spot.x - RING_R, spot.y - RING_R, 2 * RING_R, 2 * RING_R)):
		Game.tiles.set_flag(i, TileGrid.F_BLOCK)
		Game.tiles.set_kind(i, "well")


## Where to stand to drink, on the side facing `from`.
func stand_point(from: Vector3) -> Vector3:
	var d := Hex.offset(position, from)
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.BACK
	return position + d * (RING_R + 0.55)


func _put(m: Mesh, mat: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
