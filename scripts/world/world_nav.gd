class_name WorldNav
extends Node3D
## The navigation mesh for the open ground of the whole wrapping map.
##
## The map is cut into a grid of chunks, each its own NavigationRegion3D, so a change in one
## place only rebuilds the chunks it touches. Chunks on an edge also get a copy placed just past
## the opposite edge, so routes run straight across the seam; a resident who steps over it is
## moved back by one world width (see Resident._wrap).
##
## Open ground is one flat rectangle per chunk. A building carves its area out (carve()), and
## the chunks it touches are baked again with that hole; the building's own navigation mesh
## fills the hole and meets the ground mesh all round its edge.

const CHUNKS_X := 12               # 12 x 60.6 m = the map's width exactly
const CHUNKS_Z := 10               # 10 x 63 m = the map's depth exactly
const CELL := 0.1                  # navigation cell size (matches the project setting)
const BORDER := 0.4                # baked meshes are baked this far past their edges, then cut back
## Baking puts the bake area's floor here: just above a cell boundary, so a floor at a whole
## multiple of 0.1 m comes out exactly one cell (NAV_SINK) high, and its region is moved down by that.
const BAKE_Y0 := -0.499
const NAV_SINK := 0.1

var _meshes := {}                  # Vector2i chunk -> NavigationMesh
var _regions := {}                 # Vector2i chunk -> Array of NavigationRegion3D (the chunk and its copies)
var _holes: Array[Rect2] = []


func _ready() -> void:
	add_to_group("world_nav")
	for cz in CHUNKS_Z:
		for cx in CHUNKS_X:
			var key := Vector2i(cx, cz)
			var nm := _flat_mesh(cx, cz)
			_meshes[key] = nm
			_regions[key] = []
			_add_region(key, nm, Vector3.ZERO, "Chunk_%d_%d" % [cx, cz])
			# copies past the opposite edges (and corners) for the chunks along the seams
			var kxs := [0]
			var kzs := [0]
			if cx == 0: kxs.append(1)
			if cx == CHUNKS_X - 1: kxs.append(-1)
			if cz == 0: kzs.append(1)
			if cz == CHUNKS_Z - 1: kzs.append(-1)
			for kx in kxs:
				for kz in kzs:
					if kx != 0 or kz != 0:
						_add_region(key, nm, Vector3(kx * Hex.WRAP, 0.0, kz * Hex.WRAP_Z), "Copy_%d_%d_%+d%+d" % [cx, cz, kx, kz])


## The settings every navigation mesh in the game shares (the resident's size and step).
static func new_nav_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = CELL
	nm.cell_height = CELL
	nm.agent_radius = 0.25            # a resident's body, arms in
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.3          # a stair step is up to 0.3 m
	nm.agent_max_slope = 46.0
	nm.border_size = BORDER
	nm.edge_max_error = 1.0           # keeps baked edges on the bake area's sides, so chunks meet
	nm.region_min_size = 12.0         # drops scraps nobody can reach (tops of beds and walls)
	return nm


static func chunk_bounds(cx: int, cz: int) -> Rect2:
	var w := Hex.WRAP / CHUNKS_X
	var d := Hex.WRAP_Z / CHUNKS_Z
	var x0 := -Hex.WRAP * 0.5 + cx * w
	var z0 := -Hex.WRAP_Z * 0.5 + cz * d
	# the far edges come from the same formula as the next chunk's near edges, so they meet exactly
	var x1 := -Hex.WRAP * 0.5 + (cx + 1) * w
	var z1 := -Hex.WRAP_Z * 0.5 + (cz + 1) * d
	return Rect2(x0, z0, x1 - x0, z1 - z0)


## Take an area (world x, z) out of the open ground, for a building's own mesh to fill.
func carve(area: Rect2) -> void:
	_holes.append(area)
	for key in _chunks_touching(area):
		var nm := _baked_mesh(key.x, key.y)
		_meshes[key] = nm
		for region in _regions[key]:
			(region as NavigationRegion3D).navigation_mesh = nm


# every chunk an area overlaps, allowing for the wrap
func _chunks_touching(area: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cz in CHUNKS_Z:
		for cx in CHUNKS_X:
			if _hole_in(chunk_bounds(cx, cz), area).has_area():
				out.append(Vector2i(cx, cz))
	return out


# the hole shifted to whichever copy of the world is nearest the chunk, clipped to the chunk
static func _hole_in(chunk: Rect2, hole: Rect2) -> Rect2:
	var c := chunk.get_center()
	var hc := hole.get_center()
	var shifted := Rect2(Vector2(Hex.near_copy_x(hc.x, c.x), Hex.near_copy_z(hc.y, c.y)) - hole.size * 0.5, hole.size)
	return chunk.intersection(shifted)


# one rectangle, a cell high like the baked ones
func _flat_mesh(cx: int, cz: int) -> NavigationMesh:
	var r := chunk_bounds(cx, cz)
	var nm := NavigationMesh.new()
	nm.cell_size = CELL
	nm.cell_height = CELL
	nm.agent_radius = 0.25
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.3
	nm.vertices = PackedVector3Array([
		Vector3(r.position.x, NAV_SINK, r.position.y),
		Vector3(r.end.x, NAV_SINK, r.position.y),
		Vector3(r.end.x, NAV_SINK, r.end.y),
		Vector3(r.position.x, NAV_SINK, r.end.y),
	])
	nm.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	return nm


# open ground with the holes cut out, baked (about a tenth of a second per chunk)
func _baked_mesh(cx: int, cz: int) -> NavigationMesh:
	var r := chunk_bounds(cx, cz)
	var nm := new_nav_mesh()
	nm.filter_baking_aabb = AABB(Vector3(r.position.x - BORDER, BAKE_Y0, r.position.y - BORDER),
		Vector3(r.size.x + 2.0 * BORDER, 1.0, r.size.y + 2.0 * BORDER))
	var data := NavigationMeshSourceGeometryData3D.new()
	var g := r.grow(BORDER + 1.0)
	var a := Vector3(g.position.x, 0.0, g.position.y)
	var b := Vector3(g.end.x, 0.0, g.position.y)
	var c := Vector3(g.end.x, 0.0, g.end.y)
	var d := Vector3(g.position.x, 0.0, g.end.y)
	data.add_faces(PackedVector3Array([a, b, c, a, c, d]), Transform3D.IDENTITY)
	for hole in _holes:
		var h := _hole_in(r.grow(BORDER), hole)
		if not h.has_area():
			continue
		data.add_projected_obstruction(PackedVector3Array([
			Vector3(h.position.x, 0.0, h.position.y), Vector3(h.end.x, 0.0, h.position.y),
			Vector3(h.end.x, 0.0, h.end.y), Vector3(h.position.x, 0.0, h.end.y)]), -1.0, 2.0, true)
	NavigationServer3D.bake_from_source_geometry_data(nm, data)
	return nm


func _add_region(key: Vector2i, nm: NavigationMesh, offset: Vector3, region_name: String) -> void:
	var region := NavigationRegion3D.new()
	region.name = region_name
	region.navigation_mesh = nm
	region.position = offset + Vector3.DOWN * NAV_SINK   # flat or baked, every chunk is a cell high (see BAKE_Y0)
	add_child(region)
	_regions[key].append(region)
