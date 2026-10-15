extends Node3D
## Markers drawn on the ground: the hexagonal ring under the resident you control, the outline
## of the tile under the cursor while controlling (click it to walk there), and, with P, the
## route every resident is following (for checking the pathing).

const ORANGE := Color(1.0, 0.8659, 0.5856)        # the HTML game's 0xffb84d, as it looks there

var show_paths := false

var _ring: MeshInstance3D
var _hover: MeshInstance3D
var _paths: MeshInstance3D
var _hover_tile := -1
var _hover_point := Vector3.ZERO

@onready var player: PlayerController = get_node("../Player")
@onready var rig: CameraRig = get_node("../CameraRig")


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ORANGE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = _mesh_node(_hex_ring(0.42, 0.5), mat)
	_hover = _mesh_node(_hex_outline(Hex.S * 0.97), mat)
	var path_mat := mat.duplicate() as StandardMaterial3D
	path_mat.albedo_color = Color(0.55, 0.85, 1.0, 0.9)
	path_mat.no_depth_test = true
	_paths = MeshInstance3D.new()
	_paths.material_override = path_mat
	_paths.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_paths)
	rig.hovered_tile.connect(func(i: int, p: Vector3) -> void:
		_hover_tile = i
		_hover_point = p)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_paths"):
		show_paths = not show_paths
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var ctrl := player.controlled
	var t := Time.get_ticks_msec() / 1000.0
	_ring.visible = ctrl != null and ctrl.body.visible and not ctrl.is_lying()
	if _ring.visible:
		_ring.position = Vector3(ctrl.position.x, ctrl.position.y + 0.045, ctrl.position.z)
		_ring.rotation.y = t * 0.8
	# a tile outline only on the open ground (inside a building you click the floor itself)
	_hover.visible = ctrl != null and _hover_tile >= 0 and not Game.tiles.has_flag(_hover_tile, TileGrid.F_BLOCK)
	if _hover.visible:
		_hover.position = Vector3(Hex.near_copy_x(Hex.tile_x(_hover_tile), _hover_point.x), 0.03,
			Hex.near_copy_z(Hex.tile_z(_hover_tile), _hover_point.z))
	_draw_paths()


func _draw_paths() -> void:
	var im := ImmediateMesh.new()
	_paths.mesh = im
	if not show_paths:
		return
	var any := false
	for r in get_tree().get_nodes_in_group("residents"):
		var res := r as Resident
		if not res.has_goal():
			continue
		var path: PackedVector3Array = res.agent.get_current_navigation_path()
		var from := res.agent.get_current_navigation_path_index()
		if path.size() - from < 1:
			continue
		if not any:
			im.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var prev := res.position
		for k in range(from, path.size()):
			im.surface_add_vertex(prev + Vector3.UP * 0.06)
			im.surface_add_vertex(path[k] + Vector3.UP * 0.06)
			prev = path[k]
	if any:
		im.surface_end()


func _mesh_node(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


# a flat hexagonal ring, pointy end toward +Z like the tiles
static func _hex_ring(r0: float, r1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var a0 := k * TAU / 6.0
		var a1 := (k + 1) * TAU / 6.0
		var i0 := Vector3(sin(a0) * r0, 0, cos(a0) * r0)
		var o0 := Vector3(sin(a0) * r1, 0, cos(a0) * r1)
		var i1 := Vector3(sin(a1) * r0, 0, cos(a1) * r0)
		var o1 := Vector3(sin(a1) * r1, 0, cos(a1) * r1)
		for v in [i0, o0, o1, i0, o1, i1]:
			st.add_vertex(v)
	return st.commit()


static func _hex_outline(r: float) -> ArrayMesh:
	return _hex_ring(r - 0.035, r)
