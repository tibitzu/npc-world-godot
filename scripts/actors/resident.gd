class_name Resident
extends CharacterBody3D
## A resident of the town. On their own they stroll around their home spot; when a player
## takes them over they are driven by the keyboard or walk to a clicked tile.
##
## All walking to a destination goes through the NavigationAgent3D, so routes follow the
## navigation mesh exactly, including up stairs and onto upper floors; their feet follow the
## floor or step underneath them. The body faces +Z (heading 0 = facing south,
## as in the HTML game).
##
## A resident can be sent to a bed (go_to_bed): they walk to its foot and lie down, and stay
## there until they get up (get_up), are played, or are sent somewhere else.
##
## Daily routine: while nobody is playing them, at their sleep hour (local time) they say one of
## their bedtime lines and go to bed: their own if they have one, otherwise the nearest free guest bed, and at their wake hour they get up, say a
## morning line and carry on with their day.
##
## Talk: now and then, on reaching the end of a stroll, they say one of their lines. Meeting another
## resident (see Conversations) they stop, face each other, greet and reply.

signal arrived
## They said something (shown over their head); the HUD's chatter log listens.
signal spoke(text: String)

const PLAYED_SPEED := 2.3          # m/s when a player walks them
const RUN_FACTOR := 1.5            # Left Shift
const ARRIVE_DIST := 0.08          # close enough to a destination (m)
const LIE_TIME := 0.7              # seconds to lie down or get up
const SAY_MIN := 2.8               # real seconds a line stays over their head, at least...
const SAY_PER_CHAR := 0.07         # ...or 1.2 s plus this per letter, for longer ones
const MUSE_CHANCE := 0.45          # chance of saying a line at the end of a stroll
const ROUTINE_CHECK := 2.0         # how often (game seconds) a resident looks for a bed if none was free
const STEP_UP := 0.35              # the highest step they walk up without noticing (m)
const FLOOR_MASK := 1              # the "world" layer: floors, stairs, walls, furniture

var def: NpcDef
var heading := 0.0                 # radians; forward is (sin h, cos h)
var controlled := false
## Set by the player each frame: x = forward/back, y = right/left, each -1..1.
var drive := Vector2.ZERO
var running := false
var moving := false
## The bed they are lying in or walking to.
var bed: Bed = null

var _goal = null                   # Vector3 destination on the map (wrapped), or null
var _vel := Vector2.ZERO           # current ground velocity (x, z)
var _timer := 1.0                  # pause before the next stroll
var _phase := 0.0                  # stride cycle
var _walk_w := 0.0                 # how much of the stride shows (eases in and out)
var _stuck := 0.0
var _lying := false                # in bed, or getting in
var _lie := 0.0                    # 0 standing .. 1 lying down
var _stand_at := Vector3.ZERO      # where they got in (and will get out)
var _say_left := 0.0               # real seconds the current line has left
var _routine_wait := 0.0           # until the next look for a free bed
var _path := PackedVector3Array()  # the route being followed (from the agent)
var _talk_left := 0.0              # real seconds of mouth movement left
var _queued: Array = []            # [game seconds until, text] lines waiting to be said
var _face: Node3D = null           # someone they've stopped to talk to, and turn to face
var _visiting := false             # strolling into the town square
var _bed_line_said := false         # tonight's goodnight has been said
## Game time (Game.world_time) before which they won't pipe up on their own again.
var next_speak := 0.0
var _wp := 0                       # which point of it they're heading for

@onready var agent: NavigationAgent3D = $Agent
@onready var body: Node3D = $Body
@onready var tag: Label3D = $Tag
@onready var _say: Label3D = $Say
@onready var _collision: CollisionShape3D = $Collision
@onready var _mouth: Node3D = $Body/Mouth
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
	agent.path_changed.connect(func() -> void:
		_path = agent.get_current_navigation_path()
		_wp = 0)


## Walk to a point on the map along the navigation mesh. Its height picks the floor
## (0 for the ground; an upper floor's height to go up the stairs).
func walk_to(p: Vector3) -> void:
	if _lying or _lie > 0.0:
		get_up()
	_leave_bed_plan()
	_set_goal(p)


func stop() -> void:
	_goal = null


func has_goal() -> bool:
	return _goal != null


func goal():
	return _goal


func is_lying() -> bool:
	return _lie > 0.0


## Walk to a bed and lie down in it. False if someone else has it.
func go_to_bed(b: Bed) -> bool:
	if b == null or not b.is_free_for(self) or (_lie > 0.0 and bed != b):
		return false
	_leave_bed_plan()
	bed = b
	b.occupant = self
	if _lie > 0.0:
		return true
	_set_goal(b.stand_point())
	return true


## Lie down in the bed at hand (within reach of its foot), or get up if lying.
func toggle_bed(b: Bed) -> void:
	if _lying:
		get_up()
	elif b and b.is_free_for(self):
		bed = b
		b.occupant = self
		_goal = null
		_lie_down()


## Get out of bed (if in one); they stand at its foot and the bed is free once they're up.
func get_up() -> void:
	if _lying:
		_lying = false
		_timer = 1.5 + randf() * 2.0


## Show a line over their head for a few seconds (longer lines stay longer).
func say(text: String) -> void:
	if text.is_empty():
		return
	_say.text = text
	_say.visible = true
	_say_left = maxf(SAY_MIN, 1.2 + text.length() * SAY_PER_CHAR)
	_talk_left = minf(_say_left - 0.6, 0.5 + text.length() * 0.045)
	next_speak = Game.world_time + 6.0 + randf() * 6.0
	spoke.emit(text)


## Say a line after a pause (game seconds).
func say_later(text: String, delay: float) -> void:
	if not text.is_empty():
		_queued.append([delay, text])


## Is anything on their mind? Played, mid-sentence, waiting to speak, or busy with bed.
func is_busy() -> bool:
	return controlled or _say_left > 0.0 or not _queued.is_empty() or bed != null or _lying or _lie > 0.0


## Stop for a few (game) seconds and turn to face someone.
func stop_to_talk(other: Node3D, secs: float) -> void:
	if controlled or bed != null:
		return
	_goal = null
	_timer = secs
	_face = other


## Is it their sleeping time, by the local time where they are?
func sleep_time() -> bool:
	var h := Game.local_hours(position.x)
	var s := def.sleep_hour
	var w := def.wake_hour
	return (h >= s and h < w) if s < w else (h >= s or h < w)


## What they're doing, for the roster.
func status() -> String:
	if controlled:
		return "Played by you"
	if _lying or _lie > 0.0:
		return "Asleep" if sleep_time() else "In bed"
	if bed:
		return "Going to bed"
	if moving:
		return "Walking"
	return "Idle"


## Hand the resident back to their own routine. If they're in bed they stay there.
func release() -> void:
	controlled = false
	drive = Vector2.ZERO
	running = false
	if not _lying:
		_goal = null
		_leave_bed_plan()
	_timer = 2.2


func take_over() -> void:
	controlled = true
	if not _lying:
		_goal = null
		_leave_bed_plan()


func _set_goal(p: Vector3) -> void:
	_face = null
	_visiting = false
	_goal = Vector3(Hex.wrap_x(p.x), p.y, Hex.wrap_z(p.z))
	_stuck = 0.0
	_retarget()


# aim the agent at whichever copy of the goal is nearest, so routes cross the seam when that is shorter
func _retarget() -> void:
	agent.target_position = Vector3(
		Hex.near_copy_x(_goal.x, position.x), _goal.y, Hex.near_copy_z(_goal.z, position.z))


func _physics_process(delta: float) -> void:
	if _say_left > 0.0:
		_say_left -= Game.real_delta(delta)
		_say.visible = _say_left > 0.0 and tag.visible
	_talk_left = maxf(0.0, _talk_left - Game.real_delta(delta))
	if not _queued.is_empty():
		_queued[0][0] -= delta
		if _queued[0][0] <= 0.0:
			say(_queued.pop_front()[1])
	if not controlled:
		_routine(delta)
	if _lying or _lie > 0.0:
		if controlled and drive != Vector2.ZERO:
			get_up()                           # a player who walks gets out of bed first
		_bed_pose(delta)
		_animate(delta)
		return
	if not controlled:
		_autonomy(delta)
	var want := Vector2.ZERO
	var speed := PLAYED_SPEED * (RUN_FACTOR if running else 1.0) if controlled else def.speed
	var key_move := false
	if controlled and drive != Vector2.ZERO:
		_goal = null
		_leave_bed_plan()
		key_move = true
		var f := drive.x
		var s := drive.y
		want = Vector2(sin(heading) * f - cos(heading) * s, cos(heading) * f + sin(heading) * s).normalized()
	elif _goal != null and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
		var to_goal := Hex.offset(position, _goal)
		var d := to_goal.length()
		if d < ARRIVE_DIST and absf(_goal.y - position.y) < 0.5:
			_arrive()
		else:
			if agent.is_navigation_finished():
				_retarget()
			var step := _steer_point() - position
			step.y = 0.0
			if step.length() > 0.001:
				want = Vector2(step.x, step.z).normalized()
			if d < 0.3:
				speed *= maxf(0.35, d / 0.3)
			# no progress for a while (destination unreachable): give up there
			_stuck = _stuck + delta if _vel.length() < 0.05 else 0.0
			if _stuck > 1.0:
				_leave_bed_plan()
				_arrive()

	# velocity eases toward the wanted speed, so starts, stops and turns are gradual
	_vel += (want * speed - _vel) * minf(1.0, delta * 7.0)
	velocity = Vector3(_vel.x, 0.0, _vel.y)
	move_and_slide()
	_follow_floor(delta)
	_wrap()

	var sp := _vel.length()
	moving = sp > 0.08
	if _face != null and not moving and not controlled:
		# stopped to talk: turn to face them
		var to := Hex.offset(position, _face.position)
		heading = lerp_angle(heading, atan2(to.x, to.z), minf(1.0, delta * 6.0))
		if _timer <= 0.0:
			_face = null
	if moving:
		# face the way we're going only when heading somewhere; a player's backwards or sideways
		# glide while slowing down must never spin them round
		if not key_move and (_goal != null or not controlled):
			heading = lerp_angle(heading, atan2(_vel.x, _vel.y), minf(1.0, delta * (5.0 if controlled else 8.0)))
		_phase += delta * sp * 4.7          # longer legs: a slower stride for the same speed
	else:
		_phase *= 0.85
	_animate(delta)


# The next point of the route to head for. Points count as reached by horizontal distance
# (a point on a stair can be a step's height above or below the feet), or once they're behind
# us along the way to the point after.
func _steer_point() -> Vector3:
	agent.get_next_path_position()     # keeps the agent's own route up to date
	if _path.is_empty():
		return agent.get_next_path_position()
	while _wp < _path.size() - 1:
		var here := _path[_wp]
		var flat := Vector2(position.x - here.x, position.z - here.z)
		var ahead := Vector2(_path[_wp + 1].x - here.x, _path[_wp + 1].z - here.z)
		if flat.length() < 0.15 or (flat.length() < 0.45 and flat.dot(ahead) > 0.0):
			_wp += 1
		else:
			break
	return _path[_wp]


# stand on whatever is underfoot: a building's floor, a stair step or an upper floor (anything
# on the "world" layer no more than a step above the feet), or else the open ground at y = 0
func _follow_floor(delta: float) -> void:
	var from := position + Vector3.UP * STEP_UP
	var q := PhysicsRayQueryParameters3D.create(from, position + Vector3.DOWN * 0.6, FLOOR_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var floor_y := (hit.position as Vector3).y if not hit.is_empty() else 0.0
	# ease onto each step rather than popping up it
	position.y = move_toward(position.y, floor_y, delta * 3.0) if absf(floor_y - position.y) < STEP_UP + 0.05 else floor_y


# crossed a seam: come back in on the other side, and re-aim at the goal from there
func _wrap() -> void:
	var wx := Hex.wrap_x(position.x)
	var wz := Hex.wrap_z(position.z)
	if wx != position.x or wz != position.z:
		position = Vector3(wx, position.y, wz)
		if _goal != null:
			_retarget()


func _arrive() -> void:
	_goal = null
	_stuck = 0.0
	if bed and bed.occupant == self and Hex.distance(position, bed.stand_point()) < 0.4:
		_lie_down()
	elif not controlled:
		_timer = 1.5 + randf() * 3.5
		if _visiting:
			_timer = 6.0 + randf() * 8.0        # a while in the square before heading home
			_visiting = false
		if bed == null and randf() < MUSE_CHANCE and Game.world_time > next_speak and not is_busy():
			say(_pick(def.lines))
	arrived.emit()


func _lie_down() -> void:
	_lying = true
	_stand_at = position
	_vel = Vector2.ZERO
	moving = false


# they were heading for a bed but are going somewhere else now
func _leave_bed_plan() -> void:
	if bed and not _lying and _lie == 0.0:
		_release_bed()


func _release_bed() -> void:
	if bed and bed.occupant == self:
		bed.occupant = null
	bed = null


# ease between standing at the foot of the bed and lying on it, face up, head on the pillow
func _bed_pose(delta: float) -> void:
	if bed == null:
		_lying = false
		_lie = 0.0
		return
	_lie = clampf(_lie + (1.0 if _lying else -1.0) * delta / LIE_TIME, 0.0, 1.0)
	var t := _lie * _lie * (3.0 - 2.0 * _lie)
	var hd := bed.head_dir()
	var stand_h := atan2(hd.x, hd.z)
	# feet near the foot of the mattress, head on the pillow; lifted by the body's half-depth
	var lie_pos := bed.global_position - hd * (bed.length * 0.5 - 0.4) + Vector3.UP * 0.22
	position = _stand_at.lerp(lie_pos, t)
	var standing := Quaternion(Vector3.UP, stand_h)
	var lying := Basis(hd.cross(Vector3.UP), hd, Vector3.UP).get_rotation_quaternion()
	body.quaternion = standing.slerp(lying, t)
	_collision.disabled = _lie > 0.0
	if _lie == 0.0:
		# up again, at the foot of the bed facing it
		heading = stand_h
		position = _stand_at
		_release_bed()


# bedtime and morning, for a resident nobody is playing
func _routine(delta: float) -> void:
	var night := sleep_time()
	if night:
		if bed != null:
			return                              # in bed, or on the way
		_routine_wait -= delta
		if _routine_wait > 0.0:
			return
		_routine_wait = ROUTINE_CHECK
		var b := _nearest_free_bed()
		if b and go_to_bed(b) and not _bed_line_said:
			_bed_line_said = true
			say(_pick(def.bed_lines))
	else:
		_bed_line_said = false
	if not night and bed != null:
		if _lying:
			get_up()
			say(_pick(def.wake_lines))
		elif _lie == 0.0:
			_goal = null                        # morning came while still on the way: never mind
			_release_bed()
			_timer = 1.0


# their own bed if they have one, otherwise the nearest free guest bed
func _nearest_free_bed() -> Bed:
	for b in get_tree().get_nodes_in_group("beds"):
		if (b as Bed).owner_id == def.id and (b as Bed).is_free_for(self):
			return b
	var best: Bed = null
	var bd := INF
	for b in get_tree().get_nodes_in_group("beds"):
		var bed_node := b as Bed
		if bed_node.owner_id != "" or not bed_node.is_free_for(self):
			continue
		var d := Hex.distance(position, bed_node.stand_point())
		if d < bd:
			bd = d
			best = bed_node
	return best


static func _pick(lines: PackedStringArray) -> String:
	return lines[randi() % lines.size()] if lines.size() > 0 else ""


# a stroll to a tile within wander_range, staying within home_radius of the start
func _autonomy(delta: float) -> void:
	if _goal != null or bed != null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var home := Vector3(def.start.x, 0.0, def.start.y)
	if Hex.distance(position, home) > def.home_radius:
		# left far from home (a player walked them off): head back
		var back := Vector3(Hex.near_copy_x(home.x, position.x), 0.0, Hex.near_copy_z(home.z, position.z))
		var t0 := Hex.tile_at(back.x + randf_range(-2.0, 2.0), back.z + randf_range(-2.0, 2.0))
		_set_goal(Hex.tile_pos(t0))
		return
	var square := get_tree().get_first_node_in_group("town_square") as TownSquare
	if square and randf() < def.town_visits:
		var spot := square.random_spot()
		_set_goal(Vector3(Hex.near_copy_x(spot.x, position.x), 0.0, Hex.near_copy_z(spot.z, position.z)))
		_visiting = true
		return
	for attempt in 12:
		var a := randf() * TAU
		var r := sqrt(randf()) * def.wander_range
		var p := position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if Hex.distance(p, home) > def.home_radius:
			continue
		var t := Hex.tile_at(p.x, p.z)
		if t >= 0 and not Game.tiles.has_flag(t, TileGrid.F_BLOCK):
			_set_goal(Hex.tile_pos(t))
			return
	_timer = 1.0


func _animate(delta: float) -> void:
	_walk_w += ((1.0 if moving else 0.0) - _walk_w) * minf(1.0, delta * 8.0)
	if _lie == 0.0:
		body.rotation = Vector3(0.0, heading, 0.0)
	var a := _walk_w * sin(_phase) * 0.6
	_arm_l.rotation.x = a
	_arm_r.rotation.x = -a
	_leg_l.rotation.x = -a * 0.8
	_leg_r.rotation.x = a * 0.8
	_mouth.scale.y = 1.0 + 3.0 * absf(sin(Time.get_ticks_msec() * 0.018)) if _talk_left > 0.0 else 1.0
