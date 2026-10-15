class_name WorldNav
extends Node3D
## The navigation mesh for the open ground of the whole wrapping map.
##
## The map is cut into a grid of chunks, each its own NavigationRegion3D, so later changes
## (a new building cutting a hole) only rebuild the chunks they touch. Chunks on an edge
## also get a copy placed just past the opposite edge, so routes run straight across the
## seam; a resident who steps over it is moved back by one world width (see Resident._wrap).
##
## For now the ground is open everywhere, so each chunk is one flat rectangle. Buildings
## bring their own navigation regions with them, joined to these at their doorways.

const CHUNKS_X := 12               # 12 x 60.6 m = the map's width exactly
const CHUNKS_Z := 10               # 10 x 63 m = the map's depth exactly
const CELL := 0.1                  # navigation cell size (matches the project setting)

var _meshes := {}                  # Vector2i chunk -> NavigationMesh


func _ready() -> void:
	for cz in CHUNKS_Z:
		for cx in CHUNKS_X:
			var nm := _chunk_mesh(cx, cz)
			_meshes[Vector2i(cx, cz)] = nm
			_add_region(nm, Vector3.ZERO, "Chunk_%d_%d" % [cx, cz])
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
						_add_region(nm, Vector3(kx * Hex.WRAP, 0.0, kz * Hex.WRAP_Z), "Copy_%d_%d_%+d%+d" % [cx, cz, kx, kz])


static func chunk_bounds(cx: int, cz: int) -> Rect2:
	var w := Hex.WRAP / CHUNKS_X
	var d := Hex.WRAP_Z / CHUNKS_Z
	var x0 := -Hex.WRAP * 0.5 + cx * w
	var z0 := -Hex.WRAP_Z * 0.5 + cz * d
	# the far edges come from the same formula as the next chunk's near edges, so they meet exactly
	var x1 := -Hex.WRAP * 0.5 + (cx + 1) * w
	var z1 := -Hex.WRAP_Z * 0.5 + (cz + 1) * d
	return Rect2(x0, z0, x1 - x0, z1 - z0)


func _chunk_mesh(cx: int, cz: int) -> NavigationMesh:
	var r := chunk_bounds(cx, cz)
	var nm := NavigationMesh.new()
	nm.cell_size = CELL
	nm.cell_height = CELL
	nm.agent_radius = 0.2
	nm.agent_height = 1.0
	nm.agent_max_climb = 0.25
	nm.vertices = PackedVector3Array([
		Vector3(r.position.x, 0.0, r.position.y),
		Vector3(r.end.x, 0.0, r.position.y),
		Vector3(r.end.x, 0.0, r.end.y),
		Vector3(r.position.x, 0.0, r.end.y),
	])
	nm.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	return nm


func _add_region(nm: NavigationMesh, offset: Vector3, region_name: String) -> void:
	var region := NavigationRegion3D.new()
	region.name = region_name
	region.navigation_mesh = nm
	region.position = offset
	add_child(region)
