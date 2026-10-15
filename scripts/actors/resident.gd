class_name Resident
extends CharacterBody3D
## A resident of the town. On their own they stroll around their home spot; when a player
## takes them over they are driven by the keyboard or walk to a clicked tile.
##
## All walking to a destination goes through the NavigationAgent3D, so routes follow the
## navigation mesh exactly. The body faces +Z (heading 0 = facing south, as in the HTML game).

signal arrived

const PLAYED_SPEED := 2.3          # m/s when a player walks them
const RUN_FACTOR := 1.5            # Left Shift
const ARRIVE_DIST := 0.08          # close enough to a destination (m)

var def: NpcDef
var heading := 0.0                 # radians; forward is (sin h, cos h)
var controlled := false
## Set by the player each frame: x = forward/back, y = right/left, each -1..1.
var drive := Vector2.ZERO
var running := false
var moving := false

var _goal = null                   # Vector3 destination on the map (wrapped), or null
var _vel := Vector2.ZERO           # current ground velocity (x, z)
var _timer := 1.0                  # pause before the next stroll
var _phase := 0.0                  # stride cycle
var _walk_w := 0.0                 # how much of the stride shows (eases in and out)
var _stuck := 0.0

@onready var agent: NavigationAgent3D = $Agent
@onready var body: Node3D = $Body
@onready var tag: Label3D = $Tag
@onready var _arm_l: Node3D = $Body/ArmL
@onready var _arm_r: Node3D = $Body/ArmR
@onready var _leg_l: Node3D = $Body/LegL
@onready var _leg_r: Node3D = $Body/LegR


## Call before adding to the tree.
func setup(d: NpcDef) -> void:
	def = d
	name = d.id
	position = Vector3(d.start.x, 0.0, d.start.y)
	heading = randf() * TAU
	_timer = 0.5 + randf() * 2.0


func _ready() -> void:
	# each resident gets their own cloth colour (authored as in the HTML game)
	var cloth := ($Body/Torso as MeshInstance3D).mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	cloth.albedo_color = Look.html_colour(def.colour)
	for p in [$Body/Torso, $Body/ArmL/Mesh, $Body/ArmR/Mesh]:
		(p as MeshInstance3D).material_override = cloth
	tag.text = def.display_name.to_upper()
	tag.modulate = Look.html_colour(def.colour).lightened(0.35)
	_animate(0.0)


## Walk to a point on the map along the navigation mesh.
func walk_to(p: Vector3) -> void:
	_goal = Vector3(Hex.wrap_x(p.x), 0.0, Hex.wrap_z(p.z))
	_stuck = 0.0
	_retarget()


func stop() -> void:
	_goal = null


func has_goal() -> bool:
	return _goal != null


func goal():
	return _goal


## Hand the resident back to their own routine.
func release() -> void:
	controlled = false
	drive = Vector2.ZERO
	running = false
	_goal = null
	_timer = 2.2


func take_over() -> void:
	controlled = true
	_goal = null


# aim the agent at whichever copy of the goal is nearest, so routes cross the seam when that is shorter
func _retarget() -> void:
	agent.target_position = Vector3(
		Hex.near_copy_x(_goal.x, position.x), 0.0, Hex.near_copy_z(_goal.z, position.z))


func _physics_process(delta: float) -> void:
	if not controlled:
		_autonomy(delta)
	var want := Vector2.ZERO
	var speed := PLAYED_SPEED * (RUN_FACTOR if running else 1.0) if controlled else def.speed
	var key_move := false
	if controlled and drive != Vector2.ZERO:
		_goal = null
		key_move = true
		var f := drive.x
		var s := drive.y
		want = Vector2(sin(heading) * f - cos(heading) * s, cos(heading) * f + sin(heading) * s).normalized()
	elif _goal != null and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
		var to_goal := Hex.offset(position, _goal)
		var d := to_goal.length()
		if d < ARRIVE_DIST:
			_arrive()
		else:
			if agent.is_navigation_finished():
				_retarget()
			var step := agent.get_next_path_position() - position
			step.y = 0.0
			if step.length() > 0.001:
				want = Vector2(step.x, step.z).normalized()
			if d < 0.3:
				speed *= maxf(0.35, d / 0.3)
			# no progress for a while (destination unreachable): give up there
			_stuck = _stuck + delta if _vel.length() < 0.05 else 0.0
			if _stuck > 1.0:
				_arrive()

	# velocity eases toward the wanted speed, so starts, stops and turns are gradual
	_vel += (want * speed - _vel) * minf(1.0, delta * 7.0)
	velocity = Vector3(_vel.x, 0.0, _vel.y)
	move_and_slide()
	position.y = 0.0
	_wrap()

	var sp := _vel.length()
	moving = sp > 0.08
	if moving:
		# face the way we're going only when heading somewhere; a player's backwards or sideways
		# glide while slowing down must never spin them round
		if not key_move and (_goal != null or not controlled):
			heading = lerp_angle(heading, atan2(_vel.x, _vel.y), minf(1.0, delta * (5.0 if controlled else 8.0)))
		_phase += delta * sp * 7.0
	else:
		_phase *= 0.85
	_animate(delta)


# crossed a seam: come back in on the other side, and re-aim at the goal from there
func _wrap() -> void:
	var wx := Hex.wrap_x(position.x)
	var wz := Hex.wrap_z(position.z)
	if wx != position.x or wz != position.z:
		position = Vector3(wx, 0.0, wz)
		if _goal != null:
			_retarget()


func _arrive() -> void:
	_goal = null
	_stuck = 0.0
	if not controlled:
		_timer = 1.5 + randf() * 3.5
	arrived.emit()


# a stroll to a tile within wander_range, staying within home_radius of the start
func _autonomy(delta: float) -> void:
	if _goal != null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var home := Vector3(def.start.x, 0.0, def.start.y)
	if Hex.distance(position, home) > def.home_radius:
		# left far from home (a player walked them off): head back
		var back := Vector3(Hex.near_copy_x(home.x, position.x), 0.0, Hex.near_copy_z(home.z, position.z))
		var t0 := Hex.tile_at(back.x + randf_range(-2.0, 2.0), back.z + randf_range(-2.0, 2.0))
		walk_to(Hex.tile_pos(t0))
		return
	for attempt in 12:
		var a := randf() * TAU
		var r := sqrt(randf()) * def.wander_range
		var p := position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if Hex.distance(p, home) > def.home_radius:
			continue
		var t := Hex.tile_at(p.x, p.z)
		if t >= 0 and not Game.tiles.has_flag(t, TileGrid.F_BLOCK):
			walk_to(Hex.tile_pos(t))
			return
	_timer = 1.0


func _animate(delta: float) -> void:
	_walk_w += ((1.0 if moving else 0.0) - _walk_w) * minf(1.0, delta * 8.0)
	body.rotation.y = heading
	var a := _walk_w * sin(_phase) * 0.6
	_arm_l.rotation.x = a
	_arm_r.rotation.x = -a
	_leg_l.rotation.x = -a * 0.8
	_leg_r.rotation.x = a * 0.8
