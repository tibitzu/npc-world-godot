class_name Building
extends Node3D
## A building you can walk into. Every building scene has this script on its root and is laid
## out the same way, so new buildings follow the tavern's pattern:
##
##   Ground   the ground storey's meshes (walls, furniture, the stair)
##   Upper    everything above the first floor, with its own Solid body (optional)
##   Roof     the roof, faded out while you look in at a resident inside (third person), or
##            while the camera itself is inside the walls
##   Solid    a StaticBody3D whose shapes are the walls, furniture and stair
##   Door     a Door node; it opens for anyone who comes near
##   Nav      a NavigationRegion3D, baked from the Solid shapes when the building is placed
##   Beds     (under Upper or Ground) Bed nodes residents can lie on
##
## A building can have rooms built on beside its main block (the tavern's kitchen): list their
## outer walls in extra_parts, and put their meshes and shapes in Ground, Solid and Roof like the
## rest. Only the main block has an upper storey.
##
## The navigation mesh is baked here at start-up from the colliders, so it always matches the
## scene: change the furniture or the stair in the editor and the routes follow, with no
## waypoints to place by hand. It also covers an apron of ground round the outside; the world's
## own navigation mesh is carved away under that area, and the two meet along its edge.

## Outer size of the main block's walls (x, z), in metres, centred on the building's origin.
@export var footprint := Vector2(5.0, 3.6)
## Rooms built on beside the main block: each one's outer walls as a rectangle (local x, z).
@export var extra_parts: Array[Rect2] = []
@export var wall_thickness := 0.15
## Height of the first upper floor; residents below it are on the ground storey.
@export var upper_floor := 2.5
## Height of the top of the walls (the eaves).
@export var wall_height := 4.35
## How far round the outside the building's own navigation mesh reaches.
@export var apron := 1.0
## Or, instead, exactly the area (local x, z) its navigation mesh covers: for a building with a
## garden or a yard (fences, a letterbox) that should be walked round, not through.
@export var nav_area := Rect2()
## What the tiles under the building are called (shown in the top left).
@export var tile_kind := "building"

var def: BuildingDef
var beds: Array[Bed] = []

var _peel_roof := false
var _peel_upper := false

@onready var nav: NavigationRegion3D = $Nav
@onready var roof: Node3D = get_node_or_null("Roof")
@onready var upper: Node3D = get_node_or_null("Upper")


## Call before adding to the tree.
func setup(d: BuildingDef) -> void:
	def = d
	name = d.id.to_pascal_case()
	position = Vector3(d.position.x, 0.0, d.position.y)
	rotation.y = deg_to_rad(d.rotation)


func _ready() -> void:
	add_to_group("buildings")
	for b in find_children("*", "Bed", true, false):
		beds.append(b as Bed)
	_mark_tiles()
	_bake_nav()
	var world_nav := get_tree().get_first_node_in_group("world_nav") as WorldNav
	if world_nav:
		world_nav.carve(nav_rect())


## The area of the map this building's navigation mesh covers (world x, z): every part plus
## the apron, as an axis-aligned rectangle.
func nav_rect() -> Rect2:
	return _world_rect(_nav_local())


# the area (local x, z) this building's navigation mesh covers
func _nav_local() -> Rect2:
	return nav_area if nav_area.has_area() else _bounds().grow(apron)


## Is a world point inside the walls (any part, any storey)?
func is_inside(p: Vector3) -> bool:
	var l := _local(p)
	for r in parts():
		if r.grow(-wall_thickness).has_point(Vector2(l.x, l.z)):
			return true
	return false


## The outer walls of the main block and of every room built on (local x, z).
func parts() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-footprint * 0.5, footprint)]
	out.append_array(extra_parts)
	return out


## Height above the building's floor of a world point (for telling which storey it is on).
func local_height(p: Vector3) -> float:
	return p.y - global_position.y


## The collision bodies the camera should look through while a storey is faded out.
func peeled_bodies() -> Array[RID]:
	var out: Array[RID] = []
	if _peel_upper and upper and upper.has_node("Solid"):
		out.append((upper.get_node("Solid") as CollisionObject3D).get_rid())
	return out


# a world point in the building's own frame (using the copy of the world nearest the building)
func _local(p: Vector3) -> Vector3:
	return to_local(Vector3(Hex.near_copy_x(p.x, global_position.x), p.y, Hex.near_copy_z(p.z, global_position.z)))


# every part together (local x, z)
func _bounds() -> Rect2:
	var r := Rect2(-footprint * 0.5, footprint)
	for p in extra_parts:
		r = r.merge(p)
	return r


# a local rectangle as a world-space axis-aligned rectangle (x, z)
func _world_rect(local: Rect2) -> Rect2:
	var r := Rect2()
	var first := true
	for x in [local.position.x, local.end.x]:
		for z in [local.position.y, local.end.y]:
			var p := global_transform * Vector3(x, 0.0, z)
			if first:
				r = Rect2(Vector2(p.x, p.z), Vector2.ZERO)
				first = false
			else:
				r = r.expand(Vector2(p.x, p.z))
	return r


# the tiles under the walls (and a little round them) are the building's: wandering residents
# don't pick them as destinations; those inside the walls are marked as inside
func _mark_tiles() -> void:
	for part in parts():
		for i in Hex.tiles_in(_world_rect(part.grow(0.3))):
			Game.tiles.set_flag(i, TileGrid.F_BLOCK)
			Game.tiles.set_kind(i, tile_kind)
			if is_inside(Hex.tile_pos(i)):
				Game.tiles.set_flag(i, TileGrid.F_INSIDE)


func _bake_nav() -> void:
	var nm := WorldNav.new_nav_mesh()
	var area := _nav_local().grow(WorldNav.BORDER)
	nm.filter_baking_aabb = AABB(Vector3(area.position.x, WorldNav.BAKE_Y0, area.position.y), Vector3(area.size.x, 12.0, area.size.y))
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1          # the "world" layer: walls, furniture, floors, stairs (not the door)
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, data, self)
	# the open ground the building stands on, reaching past the bake area so its edges stay exact
	var g := area.grow(1.0)
	var c := [Vector3(g.position.x, 0, g.position.y), Vector3(g.end.x, 0, g.position.y),
		Vector3(g.end.x, 0, g.end.y), Vector3(g.position.x, 0, g.end.y)]
	data.add_faces(PackedVector3Array([c[0], c[1], c[2], c[0], c[2], c[3]]), global_transform)
	NavigationServer3D.bake_from_source_geometry_data(nm, data)
	nav.navigation_mesh = nm
	nav.position.y = -WorldNav.NAV_SINK


func _process(_delta: float) -> void:
	# Look in at a resident inside: fade the roof, and the upper storey if they're below it.
	# The same goes whenever the camera is inside the walls (the third-person camera is still
	# indoors, at upper-floor height, as you walk out through the door). Faded parts keep
	# casting their shadows, so the room stays as dark as it was. In first person nothing fades:
	# the upper floor is the ceiling.
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	if rig == null:
		return
	var ctrl := player.controlled if player else null
	var from_above := ctrl == null or rig.third_person_amount() > 0.3
	var res_in := ctrl != null and from_above and is_inside(ctrl.position)
	var res_main := res_in and _in_part(ctrl.position, 0, -wall_thickness)
	var res_up := res_main and local_height(ctrl.position) >= upper_floor - 0.5
	var cam := rig.camera.global_position
	var cam_low := from_above and local_height(cam) < wall_height + 0.3
	var cam_in := cam_low and _within_walls(cam, 0.3)
	var cam_main := cam_low and _in_part(cam, 0, 0.3)
	# the upper storey only fades for someone in (or a camera over) the main block, not a side room
	_set_peel(res_in or cam_in, (res_main or cam_main) and not res_up)


# a point inside the outer faces of any part's walls (plus a margin), at any height
func _within_walls(p: Vector3, margin: float) -> bool:
	for k in parts().size():
		if _in_part(p, k, margin):
			return true
	return false


func _in_part(p: Vector3, k: int, margin: float) -> bool:
	var l := _local(p)
	return parts()[k].grow(margin).has_point(Vector2(l.x, l.z))


func _set_peel(roof_off: bool, upper_off: bool) -> void:
	if roof_off != _peel_roof and roof:
		_peel_roof = roof_off
		_shadow_only(roof, roof_off)
	if upper_off != _peel_upper and upper:
		_peel_upper = upper_off
		_shadow_only(upper, upper_off)


static func _shadow_only(n: Node, on: bool) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := c as GeometryInstance3D
		if not gi.has_meta("shadow_setting"):
			gi.set_meta("shadow_setting", gi.cast_shadow)
		if gi.get_meta("shadow_setting") == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			gi.visible = not on        # things that cast no shadow (glowing windows, flames) just go
		else:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else gi.get_meta("shadow_setting")
	for l in n.find_children("*", "Light3D", true, false):
		(l as Light3D).visible = not on
