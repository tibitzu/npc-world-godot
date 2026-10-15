extends Node3D
## The overview camera used when no resident is controlled, with the HTML game's controls:
## WASD or the arrow keys move, Q and E turn, drag to rotate, right-drag (or Shift-drag) to pan,
## scroll to zoom, click the ground to glide there. It orbits a focus point that wraps at the seams.

signal hovered_tile(index: int, point: Vector3)

@export var yaw := 0.35
@export var pitch := 0.72
@export var dist := 16.0

const PITCH_MIN := 0.35
const PITCH_MAX := 1.35
const DIST_MIN := 5.0
const DIST_MAX := 80.0
const CLICK_SLOP := 6.0                     # pixels of drag before a press stops counting as a click

var focus := Vector3.ZERO                   # where the camera looks now (eases toward goal)
var goal := Vector3.ZERO                    # where it is heading; always on the map, wrapped

var _down := false
var _pan := false
var _moved := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = get_node_or_null("../Sun")
@onready var env: Environment = (get_node("../WorldEnvironment") as WorldEnvironment).environment


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x / vp.y < 0.9:
		dist = 22.0
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					dist = clampf(dist / (1.0 + 0.1 * mb.factor), DIST_MIN, DIST_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					dist = clampf(dist * (1.0 + 0.1 * mb.factor), DIST_MIN, DIST_MAX)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if mb.pressed:
					_down = true
					_moved = 0.0
					_pan = mb.button_index != MOUSE_BUTTON_LEFT or mb.shift_pressed
				else:
					var was_click := _down and _moved <= CLICK_SLOP and mb.button_index == MOUSE_BUTTON_LEFT
					_down = false
					if was_click:
						var p = ground_point(mb.position)
						if p != null:
							goal = Vector3(Hex.wrap_x(p.x), 0.0, Hex.wrap_z(p.z))
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _down:
			_moved += absf(mm.relative.x) + absf(mm.relative.y)
			if _moved > CLICK_SLOP:
				var dx := mm.relative.x
				var dy := mm.relative.y
				if _pan:
					var k := dist * 0.0018
					var sy := sin(yaw)
					var cy := cos(yaw)
					goal.x = Hex.wrap_x(goal.x - (cy * dx + sy * dy) * k)
					goal.z = Hex.wrap_z(goal.z - (-sy * dx + cy * dy) * k)
				else:
					yaw -= dx * 0.008
					pitch = clampf(pitch + dy * 0.006, PITCH_MIN, PITCH_MAX)
		else:
			var p = ground_point(mm.position)
			if p != null:
				hovered_tile.emit(Hex.tile_at(p.x, p.z), p)
	elif event is InputEventMagnifyGesture:
		dist = clampf(dist / (event as InputEventMagnifyGesture).factor, DIST_MIN, DIST_MAX)
	elif event is InputEventPanGesture:
		dist = clampf(dist * (1.0 + (event as InputEventPanGesture).delta.y * 0.05), DIST_MIN, DIST_MAX)


func _process(delta: float) -> void:
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

	# the target crossed a seam: jump the whole rig by one world width (the ground looks identical)
	focus.x += roundf((goal.x - focus.x) / Hex.WRAP) * Hex.WRAP
	focus.z += roundf((goal.z - focus.z) / Hex.WRAP_Z) * Hex.WRAP_Z
	focus = focus.lerp(goal, minf(1.0, delta * 6.0))
	_place_camera()


func _place_camera() -> void:
	camera.position = focus + Vector3(
		dist * cos(pitch) * sin(yaw),
		dist * sin(pitch),
		dist * cos(pitch) * cos(yaw))
	camera.look_at(focus, Vector3.UP)
	# fade into black around the view, as the HTML game does
	env.fog_depth_begin = dist * 1.1
	env.fog_depth_end = dist * 2.6 + 20.0
	if sun:   # keep shadows sharp up close and present when zoomed out
		sun.directional_shadow_max_distance = maxf(40.0, dist * 2.2)


## Where a screen point meets the ground (y = 0), or null if it points at the sky.
func ground_point(screen: Vector2):
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if dir.y >= -0.0001:
		return null
	return from + dir * (-from.y / dir.y)
