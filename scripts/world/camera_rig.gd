class_name CameraRig
extends Node3D
## The camera, and every mouse action on the world.
##
## With no resident controlled it is the overview camera: WASD or the arrow keys move,
## Q and E turn, drag to rotate, right-drag (or Shift-drag) to pan, scroll to zoom, click the
## ground to glide there. Click a resident to take them over; the camera then blends into their
## eyes (first person) or 3 m behind and above them (third person: scroll out or press T).
## Clicking a tile walks them there; dragging turns them. The focus wraps at the seams.

signal hovered_tile(index: int, point: Vector3)
signal view_changed(third_person: bool)

@export var yaw := 0.35
@export var pitch := 0.72
@export var dist := 16.0

const PITCH_MIN := 0.35
const PITCH_MAX := 1.35
const DIST_MIN := 5.0
const DIST_MAX := 80.0
const CLICK_SLOP := 6.0            # pixels of drag before a press stops counting as a click
const PICK_MASK := 4               # the "picking" physics layer residents' Hit areas are on
const WORLD_MASK := 1              # the "world" layer: building floors, stairs, walls, furniture

var focus := Vector3.ZERO          # where the overview camera looks now (eases toward goal)
var goal := Vector3.ZERO           # where it is heading; always on the map, wrapped
var third_person := false          # the view used while controlling a resident

var _down := false
var _pan := false
var _moved := 0.0
var _fp_blend := 0.0               # 0 overview .. 1 through the resident's eyes
var _tp_blend := 0.0               # 0 first person .. 1 third person
var _fp_pitch := -0.08             # looking up or down in first person
var _fp_resident: Resident = null  # whose view we are in (kept while blending back out)
var _cam_smooth := Vector3.ZERO
var _look_smooth := Vector3.ZERO
var _primed := false

@onready var camera: Camera3D = $Camera3D
@onready var player: PlayerController = get_node("../Player")
@onready var sun: DirectionalLight3D = get_node_or_null("../Sun")
@onready var env: Environment = (get_node("../WorldEnvironment") as WorldEnvironment).environment


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x / vp.y < 0.9:
		dist = 22.0
	player.control_changed.connect(_on_control_changed)
	_update_camera(0.0)


## How far the view has blended into third person (0 first person .. 1 third person).
func third_person_amount() -> float:
	return _tp_blend if _fp_resident else 0.0


func set_view(third: bool) -> void:
	if third_person == third:
		return
	third_person = third
	player.touch()
	view_changed.emit(third)


func _on_control_changed(r: Resident) -> void:
	if r:
		if _fp_resident and _fp_resident != r:
			_fp_resident.body.visible = true
			_fp_resident.tag.visible = true
		_fp_resident = r
		_fp_pitch = -0.08
	else:
		# carry on from where they were standing
		goal = Vector3(Hex.wrap_x(_fp_resident.position.x), 0.0, Hex.wrap_z(_fp_resident.position.z)) if _fp_resident else goal


func _unhandled_input(event: InputEvent) -> void:
	var ctrl := player.controlled
	if event.is_action_pressed("toggle_view") and ctrl:
		set_view(not third_person)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if not mb.pressed:
					return
				var out := mb.button_index == MOUSE_BUTTON_WHEEL_DOWN
				if ctrl:
					set_view(out)
				else:
					var k := 1.0 + 0.1 * maxf(mb.factor, 1.0)
					dist = clampf(dist * k if out else dist / k, DIST_MIN, DIST_MAX)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if mb.pressed:
					_down = true
					_moved = 0.0
					_pan = mb.button_index != MOUSE_BUTTON_LEFT or mb.shift_pressed
				else:
					var was_click := _down and _moved <= CLICK_SLOP and mb.button_index == MOUSE_BUTTON_LEFT
					_down = false
					if was_click:
						_click(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _down:
			_moved += absf(mm.relative.x) + absf(mm.relative.y)
			if _moved > CLICK_SLOP:
				_drag(mm.relative, ctrl)
		else:
			var p = ground_point(mm.position)
			if p != null:
				hovered_tile.emit(Hex.tile_at(p.x, p.z), p)
	elif event is InputEventMagnifyGesture and not ctrl:
		dist = clampf(dist / (event as InputEventMagnifyGesture).factor, DIST_MIN, DIST_MAX)
	elif event is InputEventPanGesture and not ctrl:
		dist = clampf(dist * (1.0 + (event as InputEventPanGesture).delta.y * 0.05), DIST_MIN, DIST_MAX)


func _drag(rel: Vector2, ctrl: Resident) -> void:
	if ctrl:
		player.look(rel.x)
		_fp_pitch = clampf(_fp_pitch - rel.y * 0.005, -1.1, 0.9)
	elif _pan:
		var k := dist * 0.0018
		var sy := sin(yaw)
		var cy := cos(yaw)
		goal.x = Hex.wrap_x(goal.x - (cy * rel.x + sy * rel.y) * k)
		goal.z = Hex.wrap_z(goal.z - (-sy * rel.x + cy * rel.y) * k)
	else:
		yaw -= rel.x * 0.008
		pitch = clampf(pitch + rel.y * 0.006, PITCH_MIN, PITCH_MAX)


# a click: a resident takes them over; otherwise walk there (controlling) or glide there
func _click(screen: Vector2) -> void:
	var r := pick_resident(screen)
	if r and r != player.controlled:
		player.possess(r)
		return
	if player.controlled:
		# a floor inside a building (an upper floor, a stair): walk to exactly that spot
		var f = floor_point(screen)
		if f != null:
			player.walk_to(f)
			return
	var p = ground_point(screen)
	if p == null:
		return
	if player.controlled:
		var t := Hex.tile_at(p.x, p.z)
		if t >= 0 and not Game.tiles.has_flag(t, TileGrid.F_BLOCK):
			# the tile centre, in the copy of the world nearest the click
			player.walk_to(Vector3(Hex.near_copy_x(Hex.tile_x(t), p.x), p.y, Hex.near_copy_z(Hex.tile_z(t), p.z)))
	else:
		goal = Vector3(Hex.wrap_x(p.x), 0.0, Hex.wrap_z(p.z))


## The resident under a screen point, if any (not the one being controlled).
func pick_resident(screen: Vector2) -> Resident:
	var q := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(screen),
		camera.project_ray_origin(screen) + camera.project_ray_normal(screen) * 400.0, PICK_MASK)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	if player.controlled:
		q.exclude = [player.controlled.get_node("Hit").get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return (hit.collider as Node).get_parent() as Resident


## Where a screen point meets a building's floor, stair or upper floor, or null if it meets
## the open ground (or a wall) first. Storeys faded out to look in at the resident are skipped.
func floor_point(screen: Vector2):
	var from := camera.project_ray_origin(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen) * 400.0, WORLD_MASK)
	var skip: Array[RID] = []
	for b in get_tree().get_nodes_in_group("buildings"):
		skip.append_array((b as Building).peeled_bodies())
	# from above ground, the goblins' lair (under the grass) can't be clicked on
	var lair := get_tree().get_first_node_in_group("goblin_lair") as GoblinLair
	if lair and not lair.under:
		skip.append(lair.rock_body())
	q.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
		return null
	var g = ground_point(screen)
	if g != null and from.distance_to(g) < from.distance_to(hit.position) - 0.01:
		return null
	return hit.position


## Where a screen point meets the ground (y = 0; down in the goblins' lair, its floor), or null
## if it points at the sky.
func ground_point(screen: Vector2):
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if dir.y >= -0.0001:
		return null
	var lair := get_tree().get_first_node_in_group("goblin_lair") as GoblinLair
	var level := GoblinLair.FLOOR_Y if lair and lair.under else 0.0
	if from.y <= level:
		return null
	return from + dir * ((level - from.y) / dir.y)


func _process(delta: float) -> void:
	delta = Game.real_delta(delta)        # the camera moves in real time at any game speed
	var ctrl := player.controlled
	if not ctrl and not Game.sheet_open:
		var f := Input.get_action_strength("cam_forward") - Input.get_action_strength("cam_back")
		var sd := Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left")
		var turn := Input.get_action_strength("cam_turn_right") - Input.get_action_strength("cam_turn_left")
		if turn != 0.0:
			yaw -= turn * delta * 1.8
		if f != 0.0 or sd != 0.0:
			var v := (4.0 + dist * 0.6) * delta / Vector2(f, sd).length()
			var sy := sin(yaw)
			var cy := cos(yaw)
			goal.x = Hex.wrap_x(goal.x + (-sy * f + cy * sd) * v)
			goal.z = Hex.wrap_z(goal.z + (-cy * f - sy * sd) * v)
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var ctrl := player.controlled
	var target := ctrl.position + Vector3.UP * 0.6 if ctrl else goal
	# the target crossed a seam: jump the whole rig by one world width (the world looks identical)
	var jump := Vector3(roundf((target.x - focus.x) / Hex.WRAP) * Hex.WRAP, 0.0,
		roundf((target.z - focus.z) / Hex.WRAP_Z) * Hex.WRAP_Z)
	if jump != Vector3.ZERO:
		focus += jump
		_cam_smooth += jump
		_look_smooth += jump
	focus = focus.lerp(target, minf(1.0, delta * (3.0 if ctrl else 6.0)))

	_fp_blend = clampf(_fp_blend + (1.0 if ctrl else -1.0) * delta * 2.2, 0.0, 1.0)
	var ease := _fp_blend * _fp_blend * (3.0 - 2.0 * _fp_blend)
	var orbit := focus + Vector3(dist * cos(pitch) * sin(yaw), dist * sin(pitch), dist * cos(pitch) * cos(yaw))
	var cam_pos := orbit
	var look_at := focus
	var fov := 42.0
	_tp_blend = clampf(_tp_blend + (1.0 if third_person else -1.0) * delta * 3.0, 0.0, 1.0)
	if _fp_resident and ease > 0.0:
		var t := _tp_blend * _tp_blend * (3.0 - 2.0 * _tp_blend)
		var g := _fp_resident.position
		# the resident may have just been moved across the seam: use their copy nearest the focus
		g.x = Hex.near_copy_x(g.x, focus.x)
		g.z = Hex.near_copy_z(g.z, focus.z)
		var h := _fp_resident.heading
		var sh := sin(h)
		var ch := cos(h)
		var cp := cos(_fp_pitch)
		# eye: 0.18 m in front of the face at 1.25 m; third person: 3.5 m behind and 3 m above that
		var back := 0.18 + (-3.5 - 0.18) * t
		var up := 1.25 + 3.0 * t
		var fp_pos := g + Vector3(sh * back, up, ch * back)
		# first person looks where the resident looks; third person aims 3.3 m ahead of them
		var fp_look := g + Vector3(sh * (0.18 + cp * 5.0), 1.25 + sin(_fp_pitch) * 5.0, ch * (0.18 + cp * 5.0))
		var tp_look := g + Vector3(sh * 3.3, 0.6, ch * 3.3)
		cam_pos = orbit.lerp(fp_pos, ease)
		look_at = focus.lerp(fp_look.lerp(tp_look, t), ease)
		fov = 42.0 + 16.0 * t * ease    # a wider lens in third person keeps feet and horizon on screen
		_fp_resident.body.visible = not (ease > 0.8 and _tp_blend < 0.25)
		_fp_resident.tag.visible = not (ctrl == _fp_resident and ease > 0.5)
	if not ctrl and _fp_blend == 0.0 and _fp_resident:
		_fp_resident.body.visible = true
		_fp_resident.tag.visible = true
		_fp_resident = null
	camera.fov = fov

	# a light spring on the camera soaks up any remaining jolts from the walk
	if not _primed:
		_cam_smooth = cam_pos
		_look_smooth = look_at
		_primed = true
	var spring := 1.0 - exp(-delta * 14.0) if delta > 0.0 else 1.0
	_cam_smooth = _cam_smooth.lerp(cam_pos, spring)
	_look_smooth = _look_smooth.lerp(look_at, spring)
	camera.position = _cam_smooth
	if not _cam_smooth.is_equal_approx(_look_smooth):
		camera.look_at(_look_smooth, Vector3.UP)

	# fade into black around the view (closer in first person), as the HTML game does
	var fog_d := dist + (10.0 - dist) * ease
	env.fog_depth_begin = fog_d * 1.1
	env.fog_depth_end = fog_d * 2.6 + 20.0
	if sun:   # keep shadows sharp up close and present when zoomed out
		sun.directional_shadow_max_distance = maxf(40.0, fog_d * 2.2)
