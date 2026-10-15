class_name LampPosts
extends Node3D
## The town's street lamps: iron posts with a lantern on top, flanking the tavern's door and the
## Wick's across the square. Old Fen lights them one by one on his evening round (see
## LamplighterJob); they burn through the night and gutter out at dawn.

## Where the posts stand (world x, z).
@export var spots: Array[Vector2] = [Vector2(4.0, 17.6), Vector2(4.0, 0.3), Vector2(-4.0, 0.3), Vector2(-4.0, 17.6)]

const HEAD_Y := 2.45
const OUT_FROM := 6.0              # local hour the lamps gutter out (until the evening)
const OUT_TO := 17.0

var lamps: Array[Dictionary] = []  # {pos: Vector3, lit: bool, light: OmniLight3D, glass: MeshInstance3D}

var _iron: StandardMaterial3D
var _glass_off: StandardMaterial3D
var _glass_on: StandardMaterial3D


func _ready() -> void:
	add_to_group("lamp_posts")
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Look.html_hex(0x2b2a2c)
	_iron.roughness = 0.6
	_iron.metallic = 0.3
	_glass_off = StandardMaterial3D.new()
	_glass_off.albedo_color = Color(0.45, 0.45, 0.42)
	_glass_off.roughness = 0.2
	_glass_on = StandardMaterial3D.new()
	_glass_on.albedo_color = Look.html_hex(0x80603a)
	_glass_on.emission_enabled = true
	_glass_on.emission = Look.html_hex(0xffb060)
	_glass_on.emission_energy_multiplier = 2.2
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var holes: Array = []
	for s in spots:
		var p := Vector3(s.x, 0.0, s.y)
		var post := Node3D.new()
		post.position = p
		add_child(post)
		_mesh(post, _cyl(0.05, 0.07, HEAD_Y - 0.2), _iron, Vector3(0, (HEAD_Y - 0.2) / 2, 0))
		_mesh(post, _cyl(0.14, 0.14, 0.1), _iron, Vector3(0, 0.05, 0))
		var glass := _mesh(post, _box(Vector3(0.24, 0.3, 0.24)), _glass_off, Vector3(0, HEAD_Y, 0))
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh(post, _cyl(0.0, 0.2, 0.16), _iron, Vector3(0, HEAD_Y + 0.23, 0))
		_mesh(post, _box(Vector3(0.28, 0.04, 0.28)), _iron, Vector3(0, HEAD_Y - 0.17, 0))
		var light := OmniLight3D.new()
		light.position = Vector3(0, HEAD_Y, 0)
		light.light_color = Look.html_hex(0xffc27a)
		light.light_energy = 1.4
		light.omni_range = 8.0
		light.omni_attenuation = 1.6
		light.visible = false
		post.add_child(light)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.12
		sh.height = HEAD_Y
		cs.shape = sh
		cs.position = p + Vector3.UP * HEAD_Y * 0.5
		body.add_child(cs)
		holes.append(Rect2(p.x - 0.45, p.z - 0.45, 0.9, 0.9))
		lamps.append({"pos": p, "lit": false, "light": light, "glass": glass})
	var nav := get_tree().get_first_node_in_group("world_nav") as WorldNav
	if nav:
		nav.carve_many(holes)


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _mesh(parent: Node3D, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


func set_lit(i: int, on: bool) -> void:
	var l := lamps[i]
	l.lit = on
	(l.light as OmniLight3D).visible = on
	(l.glass as MeshInstance3D).material_override = _glass_on if on else _glass_off


func any_unlit() -> bool:
	for l in lamps:
		if not l.lit:
			return true
	return false


## The unlit lamp nearest a point (index), or -1.
func nearest_unlit(p: Vector3) -> int:
	var best := -1
	var bd := INF
	for i in lamps.size():
		if not lamps[i].lit:
			var d := Hex.distance(p, lamps[i].pos)
			if d < bd:
				bd = d
				best = i
	return best


func _process(_delta: float) -> void:
	# lamps left burning gutter out once the day has come
	for i in lamps.size():
		if lamps[i].lit:
			var h := Game.local_hours(lamps[i].pos.x)
			if h >= OUT_FROM and h < OUT_TO:
				set_lit(i, false)
