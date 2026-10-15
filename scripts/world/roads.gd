class_name Roads
extends MeshInstance3D
## The town's cobbled roads. Each road is a smooth curve through a few points (world x, z), drawn
## as a strip of cobblestones laid along it with a kerb down both edges (the same shader as the
## square, in road mode). The tiles underneath are marked as road (shown in the top left).
##
## Roads start inside the town square, which is drawn just above them, so they run out from under
## its edge; a road that branches off another starts inside it and is drawn just below it.

const WIDTH := 2.6                 # metres, kerb to kerb
const STEP := 0.4                  # metres between points along a curve

## Each road's points, from the square outward.
@export var paths: Array[PackedVector2Array] = [
	# west: past the general store to Rosehip Cottage and on
	PackedVector2Array([Vector2(-8.0, 9.0), Vector2(-14.0, 9.2), Vector2(-21.0, 8.4), Vector2(-28.0, 6.6), Vector2(-36.0, 6.0), Vector2(-44.0, 7.6), Vector2(-50.0, 10.5)]),
	# east: past the post office to the barracks and on
	PackedVector2Array([Vector2(8.0, 9.0), Vector2(14.0, 9.4), Vector2(21.0, 10.4), Vector2(28.0, 11.8), Vector2(36.0, 11.4), Vector2(44.0, 9.0), Vector2(50.0, 6.0)]),
	# north: from the square past the tavern's east side, by Timber Hollow and into the woods
	PackedVector2Array([Vector2(6.5, 1.5), Vector2(9.2, -3.5), Vector2(10.9, -10.0), Vector2(10.4, -17.0), Vector2(7.0, -23.0), Vector2(2.0, -28.5), Vector2(-3.0, -33.0)]),
]


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in paths.size():
		_add_road(st, _curve(paths[k]), 0.004 + k * 0.0004)
	st.generate_normals()
	st.generate_tangents()
	mesh = st.commit()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/cobbles.gdshader")
	mat.set_shader_parameter("road", true)
	mat.set_shader_parameter("road_width", WIDTH)
	material_override = mat


# a Catmull-Rom curve through the points, sampled about every STEP metres
static func _curve(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		var n := maxi(2, ceili(p1.distance_to(p2) / STEP))
		for j in n:
			var t := float(j) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _add_road(st: SurfaceTool, c: PackedVector2Array, y: float) -> void:
	var dist := 0.0
	var half := WIDTH * 0.5
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_d := 0.0
	for i in c.size():
		var a := c[maxi(i - 1, 0)]
		var b := c[mini(i + 1, c.size() - 1)]
		var tangent := (b - a).normalized()
		var side := Vector2(-tangent.y, tangent.x) * half
		if i > 0:
			dist += c[i].distance_to(c[i - 1])
		var l := Vector3(c[i].x + side.x, y, c[i].y + side.y)
		var r := Vector3(c[i].x - side.x, y, c[i].y - side.y)
		if i > 0:
			for v in [[prev_l, 0.0, prev_d], [prev_r, 1.0, prev_d], [r, 1.0, dist], [prev_l, 0.0, prev_d], [r, 1.0, dist], [l, 0.0, dist]]:
				st.set_uv(Vector2(v[1], v[2]))
				st.add_vertex(v[0])
			_mark(c[i - 1], c[i], half)
		prev_l = l
		prev_r = r
		prev_d = dist


# the tiles whose centres lie on this stretch of road
func _mark(a: Vector2, b: Vector2, half: float) -> void:
	var r := Rect2(a, Vector2.ZERO).expand(b).grow(half)
	for i in Hex.tiles_in(r):
		var p := Vector2(Hex.tile_x(i), Hex.tile_z(i))
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_to(a + ab * t) <= half and Game.tiles.kind(i) == "moss":
			Game.tiles.set_flag(i, TileGrid.F_ROAD)
			Game.tiles.set_kind(i, "road")
