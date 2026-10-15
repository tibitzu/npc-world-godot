@tool
class_name RingPiece
extends MeshInstance3D
## A piece of a ring, for round buildings: everything between two radii (r0, r1) and two angles
## (a0, a1), from height y0 up to y1. A curved wall is a ring piece; so is a floor with a stairwell
## cut out of it, a step of a spiral stair, or a round rug. Angles are in radians, measured from
## the node's +Z toward +X (a point at angle a and radius r is (sin a * r, y, cos a * r)).
##
## The mesh is built when the scene loads (in the editor too). With solid on, it also gets a
## collider on the "world" layer, one convex piece per segment, which the navigation bake reads.

@export var r0 := 0.0:
	set(v): r0 = v; _rebuild()
@export var r1 := 1.0:
	set(v): r1 = v; _rebuild()
@export var a0 := 0.0:
	set(v): a0 = v; _rebuild()
@export var a1 := TAU:
	set(v): a1 = v; _rebuild()
@export var y0 := 0.0:
	set(v): y0 = v; _rebuild()
@export var y1 := 0.1:
	set(v): y1 = v; _rebuild()
## Segments for a whole turn; a piece uses its share (at least one).
@export var segments := 48:
	set(v): segments = v; _rebuild()
@export var material: Material:
	set(v): material = v; _rebuild()
@export var solid := false

var _built := false


func _ready() -> void:
	_built = true
	_rebuild()
	if solid and not Engine.is_editor_hint():
		_add_collider()


func _n() -> int:
	return maxi(1, ceili(absf(a1 - a0) / TAU * segments))


static func _p(a: float, r: float, y: float) -> Vector3:
	return Vector3(sin(a) * r, y, cos(a) * r)


func _rebuild() -> void:
	if not _built:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _n()
	var whole := absf(a1 - a0) >= TAU - 0.0001
	for i in n:
		var aa := lerpf(a0, a1, float(i) / n)
		var ab := lerpf(a0, a1, float(i + 1) / n)
		# top and bottom
		_quad(st, _p(aa, r0, y1), _p(aa, r1, y1), _p(ab, r1, y1), _p(ab, r0, y1), Vector3.UP)
		_quad(st, _p(aa, r1, y0), _p(aa, r0, y0), _p(ab, r0, y0), _p(ab, r1, y0), Vector3.DOWN)
		# the outer face (smooth), and the inner one if there's a hole in the middle
		_side(st, aa, ab, r1, 1.0)
		if r0 > 0.001:
			_side(st, ab, aa, r0, -1.0)
	if not whole:
		# end caps
		var na := Vector3(-cos(a0), 0, sin(a0)) * signf(a1 - a0)
		_quad(st, _p(a0, r0, y0), _p(a0, r0, y1), _p(a0, r1, y1), _p(a0, r1, y0), na)
		var nb := Vector3(cos(a1), 0, -sin(a1)) * signf(a1 - a0)
		_quad(st, _p(a1, r1, y0), _p(a1, r1, y1), _p(a1, r0, y1), _p(a1, r0, y0), nb)
	var m := st.commit()
	if material:
		m.surface_set_material(0, material)
	mesh = m


# a quad, wound so its front faces along n
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var face := (b - a).cross(c - a)
	var pts := PackedVector3Array([a, b, c, a, c, d]) if face.dot(n) < 0.0 else PackedVector3Array([a, c, b, a, d, c])
	for p in pts:
		st.set_normal(n)
		st.set_uv(Vector2(p.x + p.z, p.y))
		st.add_vertex(p)


# a curved face at radius r from angle aa to ab, its normals pointing out (dir 1) or in (dir -1)
func _side(st: SurfaceTool, aa: float, ab: float, r: float, dir: float) -> void:
	var na := Vector3(sin(aa), 0, cos(aa)) * dir
	var nb := Vector3(sin(ab), 0, cos(ab)) * dir
	var pts: Array[Vector3] = [_p(aa, r, y0), _p(ab, r, y0), _p(ab, r, y1), _p(aa, r, y1)]
	var nrm: Array[Vector3] = [na, nb, nb, na]
	var face := (pts[1] - pts[0]).cross(pts[2] - pts[0])
	var order := [0, 1, 2, 0, 2, 3] if face.dot((na + nb) * 0.5) < 0.0 else [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_normal(nrm[k])
		st.set_uv(Vector2(r * (aa if k == 0 or k == 3 else ab), pts[k].y))
		st.add_vertex(pts[k])


func _add_collider() -> void:
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var n := _n()
	for i in n:
		var aa := lerpf(a0, a1, float(i) / n)
		var ab := lerpf(a0, a1, float(i + 1) / n)
		var pts := PackedVector3Array()
		for y: float in [y0, y1]:
			pts.append(_p(aa, r1, y))
			pts.append(_p(ab, r1, y))
			if r0 > 0.001:
				pts.append(_p(aa, r0, y))
				pts.append(_p(ab, r0, y))
			else:
				pts.append(Vector3(0, y, 0))
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
