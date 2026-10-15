class_name Building
extends Node3D
## A building you can walk into. Every building scene has this script on its root and is laid
## out the same way, so new buildings follow the tavern's pattern:
##
##   Ground   the ground storey's meshes (walls, furniture, the stair)
##   Upper    everything above the first floor, with its own Solid body (optional)
##   Roof     the roof, faded out while you look in at a resident inside (third person)
##   Solid    a StaticBody3D whose shapes are the walls, furniture and stair
##   Door     a Door node; it opens for anyone who comes near
##   Nav      a NavigationRegion3D, baked from the Solid shapes when the building is placed
##   Beds     (under Upper or Ground) Bed nodes residents can lie on
##
## The navigation mesh is baked here at start-up from the colliders, so it always matches the
## scene: change the furniture or the stair in the editor and the routes follow, with no
## waypoints to place by hand. It also covers an apron of ground round the outside; the world's
## own navigation mesh is carved away under that area, and the two meet along its edge.

## Outer size of the walls (x, z), in metres.
@export var footprint := Vector2(5.0, 3.6)
@export var wall_thickness := 0.15
## Height of the first upper floor; residents below it are on the ground storey.
@export var upper_floor := 2.5
## How far round the outside the building's own navigation mesh reaches.
@export var apron := 1.0
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


## The area of the map this building's navigation mesh covers (world x, z): the footprint plus
## the apron, as an axis-aligned rectangle.
func nav_rect() -> Rect2:
	var h := footprint * 0.5 + Vector2(apron, apron)
	return _world_rect(h)


## Is a world point inside the walls (any storey)?
func is_inside(p: Vector3) -> bool:
	var l := to_local(Vector3(Hex.near_copy_x(p.x, global_position.x), p.y, Hex.near_copy_z(p.z, global_position.z)))
	return absf(l.x) < footprint.x * 0.5 - wall_thickness and absf(l.z) < footprint.y * 0.5 - wall_thickness


## Height above the building's floor of a world point (for telling which storey it is on).
func local_height(p: Vector3) -> float:
	return p.y - global_position.y


## The collision bodies the camera should look through while a storey is faded out.
func peeled_bodies() -> Array[RID]:
	var out: Array[RID] = []
	if _peel_upper and upper and upper.has_node("Solid"):
		out.append((upper.get_node("Solid") as CollisionObject3D).get_rid())
	return out


func _world_rect(half: Vector2) -> Rect2:
	var r := Rect2(Vector2(global_position.x, global_position.z), Vector2.ZERO)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := global_transform * Vector3(sx * half.x, 0.0, sz * half.y)
			r = r.expand(Vector2(p.x, p.z))
	return r


# the tiles under the walls (and a little round them) are the building's: wandering residents
# don't pick them as destinations; those inside the walls are marked as inside
func _mark_tiles() -> void:
	var r := _world_rect(footprint * 0.5 + Vector2(0.3, 0.3))
	for i in Hex.tiles_in(r):
		Game.tiles.set_flag(i, TileGrid.F_BLOCK)
		Game.tiles.set_kind(i, tile_kind)
		if is_inside(Hex.tile_pos(i)):
			Game.tiles.set_flag(i, TileGrid.F_INSIDE)


func _bake_nav() -> void:
	var nm := WorldNav.new_nav_mesh()
	var h := footprint * 0.5 + Vector2(apron, apron)
	var b := WorldNav.BORDER
	nm.filter_baking_aabb = AABB(Vector3(-h.x - b, WorldNav.BAKE_Y0, -h.y - b), Vector3(2.0 * (h.x + b), 12.0, 2.0 * (h.y + b)))
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1          # the "world" layer: walls, furniture, floors, stairs (not the door)
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, data, self)
	# the open ground the building stands on, reaching past the bake area so its edges stay exact
	var g := Vector2(h.x + b + 1.0, h.y + b + 1.0)
	var c := [Vector3(-g.x, 0, -g.y), Vector3(g.x, 0, -g.y), Vector3(g.x, 0, g.y), Vector3(-g.x, 0, g.y)]
	data.add_faces(PackedVector3Array([c[0], c[1], c[2], c[0], c[2], c[3]]), global_transform)
	NavigationServer3D.bake_from_source_geometry_data(nm, data)
	nav.navigation_mesh = nm
	nav.position.y = -WorldNav.NAV_SINK


func _process(_delta: float) -> void:
	# look in at a resident inside: fade the roof, and the upper storey if they're below it
	# (it keeps casting its shadow, so the room stays as dark as it was)
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	var ctrl := player.controlled if player else null
	var looking_in := ctrl != null and rig != null and rig.third_person_amount() > 0.3 and is_inside(ctrl.position)
	_set_peel(looking_in, looking_in and local_height(ctrl.position) < upper_floor - 0.5)


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
