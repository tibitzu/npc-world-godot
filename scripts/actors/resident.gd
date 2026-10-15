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
##
## Needs (as in the HTML game): fatigue, happiness, hunger and thirst, each 0..100 (100 is
## fine). Awake they tire (faster at work) and sleep restores them; hunger and thirst run down
## through the day, and when one gets low they go for a drink at the well or a meal by an oven
## (their own, or the tavern's), dropping their work if it gets very low. Happiness slips
## slowly and comes back with company, food and drink. Worn out, they'll nap.
##
## Health and fighting (as in the HTML game): each has health (def.hp_max) and fights with the
## tool of their trade (Gear.WEAPONS). Raiding goblins go for anyone out of doors. The guards turn
## out for any raider within 30 m, even from bed; anyone else hits back when attacked, and runs
## for home when badly hurt. Health comes back slowly out of danger and quickly in bed. At none
## they die: they lie where they fell and can't be played until a new game.
##
## Work: a resident with a job (def.job, see scripts/brains) does it in their working hours; the
## job walks them about, sets their pose (chopping, carrying, reaching up with a pole) and what they
## carry (their pack, and set_held for a tool). Off duty they stroll as before, and now and then drop into the general store
## while it's open.

signal arrived
## They said something (shown over their head); the HUD's chatter log listens.
signal spoke(text: String)
## Their pack changed (the HUD's pack panel listens).
signal packed

const PLAYED_SPEED := 2.3          # m/s when a player walks them
const RUN_FACTOR := 1.5            # Left Shift
const ARRIVE_DIST := 0.08          # close enough to a destination (m)
const LIE_TIME := 0.7              # seconds to lie down or get up
const SAY_MIN := 2.8               # real seconds a line stays over their head, at least...
const SAY_PER_CHAR := 0.07         # ...or 1.2 s plus this per letter, for longer ones
const MUSE_CHANCE := 0.45          # chance of saying a line at the end of a stroll
const PACK_CAP := {"logs": 3, "parcels": 2}
const NEED_LOW := 35.0             # off for a drink or a meal below this
const NEED_URGENT := 15.0          # ...dropping their work below this
## How fast needs run down (points per game second): a day is 120 s; a night's sleep restores 100.
const DRAIN := {"fatigue": 100.0 / 480.0, "hunger": 100.0 / 360.0, "thirst": 100.0 / 240.0, "happiness": 100.0 / 960.0}
const ASLEEP_DRAIN := 0.35         # hunger and thirst run down slower in bed
const REST := 100.0 / 40.0
const THIRSTY := ["Thirsty work. To the well!", "My throat's dry as dust.", "Water. Now."]
const HUNGRY := ["My stomach's growling.", "Time for a bite.", "Something smells good. Probably my imagination."]
const DRANK := ["Ah, that's better.", "Cold and clear.", "Lovely drop of water."]
const ATE := ["Mm, still warm.", "That hit the spot.", "Fed and happy."]
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
var _visiting := false             # strolling into the town square (or dropping into the shop)
## Their day job (or null), and how fast they walk while it has them (0: their usual speed).
var job: Job = null
var work_speed := 0.0
var _job_active := false           # the job is directing them this frame
## What they're doing with their arms: "" (walking), "carry", "chop" or "light".
var pose := ""
var _held := ""                    # the tool in their right hand
var _tool_shown := false           # their everyday tool (def.tool) is in their hand
## What they're carrying: logs on their back, parcels in their arms.
var pack := {"logs": 0, "parcels": 0}
var _action_left := 0.0            # game seconds of the current action (felling, lighting) left
var _action_done := Callable()
var _action_at := Vector3.ZERO
var _face_pos := Vector3.INF       # a spot to turn and face while standing (set each frame by a job)
var _bed_line_said := false         # tonight's goodnight has been said
## Their needs, 0..100 each (see above).
var needs := {"fatigue": 100.0, "happiness": 100.0, "hunger": 100.0, "thirst": 100.0}
var _errand := ""                  # "drink" or "eat" while off to see to a need
var _errand_spot := Vector3.ZERO
var _errand_face := Vector3.ZERO
var _errand_tries := 0
var _napping := false
var _last_said := ""
## Health, and whether they've died.
var hp := 100.0
var dead := false
var _hurt_at := -99.0              # Game.world_time they were last hurt
var _attacker: Node3D = null
var _cool := 0.0                   # until they can strike again
var _strike := 0.0                 # seconds into a blow (0: not striking)
var _fighting := false
var _fleeing := false
const GUARD_RANGE := 30.0          # how far the guards turn out for a raider
const TO_ARMS := ["To arms! Goblins!", "Raiders! Stay indoors!", "Here they come. Stay behind me."]
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
	Gear.dress(body, def)
	tag.text = def.display_name.to_upper()
	tag.modulate = Look.html_colour(def.colour).lightened(0.35)
	_animate(0.0)
	job = Job.make(self)
	hp = def.hp_max
	for k in needs:
		needs[k] = randf_range(55.0, 100.0)    # so they don't all get thirsty at once
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
	_last_said = text
	next_speak = Game.world_time + 6.0 + randf() * 6.0
	spoke.emit(text)


## Say a line after a pause (game seconds).
func say_later(text: String, delay: float) -> void:
	if not text.is_empty():
		_queued.append([delay, text])


## Is anything on their mind? Played, mid-sentence, waiting to speak, busy with bed, or at work.
func is_busy() -> bool:
	return dead or _fighting or _fleeing or controlled or _say_left > 0.0 or not _queued.is_empty() or bed != null or _lying or _lie > 0.0 or _job_active or _errand != ""


## Turn to face a spot while standing still (a job calls this each frame it wants it).
func face_toward(p: Vector3) -> void:
	_face_pos = p


## Put something in their pack, if there's room ("logs" or "parcels"). False if it's full.
func pack_add(kind: String, n := 1) -> bool:
	if pack.get(kind, 0) + n > PACK_CAP.get(kind, 0):
		return false
	pack[kind] = pack.get(kind, 0) + n
	_refresh_props()
	packed.emit()
	return true


## Take something out of their pack. False if there isn't that much.
func pack_take(kind: String, n := 1) -> bool:
	if pack.get(kind, 0) < n:
		return false
	pack[kind] -= n
	_refresh_props()
	packed.emit()
	return true


func pack_room(kind: String) -> int:
	return PACK_CAP.get(kind, 0) - pack.get(kind, 0)


## A tool in their right hand: "axe", "pole" or "" for none.
func set_held(tool: String) -> void:
	if tool != _held:
		_held = tool
		_refresh_props()


## Something that takes a moment (felling a tree, lighting a lamp): they stand facing `at` in a
## pose, holding a tool, for secs game seconds, then done is called. Walking off cancels it.
func start_action(action_pose: String, tool: String, secs: float, at: Vector3, done: Callable) -> void:
	_action_left = secs
	_action_done = done
	_action_at = at
	_goal = null
	pose = action_pose
	set_held(tool)
	var to := Hex.offset(position, at)
	if to.length() > 0.05:
		heading = atan2(to.x, to.z)


func is_acting() -> bool:
	return _action_left > 0.0


func _end_action(finished: bool) -> void:
	_action_left = 0.0
	pose = ""
	set_held("")
	var done := _action_done
	_action_done = Callable()
	if finished and done.is_valid():
		done.call()


# their everyday tool shows in their hand unless they're holding something for work, carrying
# parcels, or lying down
func _wants_tool() -> bool:
	return def.tool != "" and _held == "" and pack.get("parcels", 0) == 0 and _lie == 0.0


# logs on the back and parcels in the arms (from the pack), and the tool in the right hand
func _refresh_props() -> void:
	for holder in [body, _arm_r]:
		var old := (holder as Node3D).get_node_or_null("Carry")
		if old:
			old.free()
	var logs: int = pack.get("logs", 0)
	var parcels: int = pack.get("parcels", 0)
	if logs > 0 or parcels > 0:
		var c := Node3D.new()
		c.name = "Carry"
		body.add_child(c)
		for i in logs:
			_prop(c, _cyl_mesh(0.05, 0.38, 0x5e3d24), Vector3(0.0, 0.42 + i * 0.095, -0.2), Vector3(0, 0, PI / 2))
		for i in parcels:
			_prop(c, _box_mesh(Vector3(0.22, 0.12, 0.17), 0xb08a5a), Vector3(0.0, 0.5 + i * 0.125, 0.21), Vector3(0, i * 0.3, 0))
		if parcels > 0:
			_prop(c, _box_mesh(Vector3(0.23, 0.01, 0.03), 0xd8c9a3), Vector3(0.0, 0.5 + (parcels - 1) * 0.125 + 0.065, 0.21), Vector3.ZERO)
	_tool_shown = _wants_tool()
	if _tool_shown:
		var t := Node3D.new()
		t.name = "Carry"
		_arm_r.add_child(t)
		Gear.tool_in(t, def.tool)
	elif _held != "":
		var h := Node3D.new()
		h.name = "Carry"
		_arm_r.add_child(h)
		match _held:
			"axe":
				_prop(h, _cyl_mesh(0.016, 0.55, 0x8a6242), Vector3(0.0, -0.3, 0.16), Vector3(PI / 2, 0, 0))
				_prop(h, _box_mesh(Vector3(0.025, 0.13, 0.15), 0x8a929c), Vector3(0.0, -0.33, 0.4), Vector3.ZERO)
			"pole":
				# held at the hand, upright while walking; turned to point where the arm reaches when lighting
				h.position = Vector3(0.0, -0.3, 0.0)
				_prop(h, _cyl_mesh(0.012, 1.7, 0x5a3b28), Vector3(0.0, 0.45, 0.04), Vector3.ZERO)
				_prop(h, _box_mesh(Vector3(0.04, 0.08, 0.04), 0xc9a25c), Vector3(0.0, 1.32, 0.04), Vector3.ZERO)


func _prop(parent: Node3D, m: Mesh, at: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)


static func _prop_mat(hex: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Look.html_hex(hex)
	m.roughness = 0.9
	return m


static func _box_mesh(size: Vector3, hex: int) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	b.material = _prop_mat(hex)
	return b


static func _cyl_mesh(r: float, h: float, hex: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	c.material = _prop_mat(hex)
	return c


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
	if dead:
		return "Dead"
	if _fighting:
		return "Fighting"
	if _fleeing:
		return "Running for home"
	if controlled:
		return "Played by you"
	if _lying or _lie > 0.0:
		return "Asleep" if sleep_time() else "In bed"
	if bed:
		return "Heading home" if Hex.distance(position, bed.stand_point()) > 12.0 else "Going to bed"
	if _errand != "":
		return "Getting a drink" if _errand == "drink" else "Having a meal"
	if _job_active and job:
		return job.label()
	if moving:
		return "Walking"
	return "Idle"


## Hand the resident back to their own routine. If they're in bed they stay there.
func release() -> void:
	if job and job.working:
		job.finish()
	controlled = false
	drive = Vector2.ZERO
	running = false
	if not _lying:
		_goal = null
		_leave_bed_plan()
	_timer = 2.2


func take_over() -> void:
	if job and job.working:
		job.finish()
	_job_active = false
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
	if dead:
		if _say_left > 0.0:
			_say_left -= Game.real_delta(delta)
			_say.visible = _say_left > 0.0
		return
	_drain_needs(delta)
	_cool = maxf(0.0, _cool - delta)
	# a guard asleep with raiders about gets up
	if not controlled and _is_guard() and (_lying or _lie > 0.0) and _lying and _nearest_raider(GUARD_RANGE) != null:
		get_up()
		say(pick_fresh(TO_ARMS))
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
	if _action_left > 0.0:
		if (controlled and drive != Vector2.ZERO) or _goal != null:
			_end_action(false)              # walked off: never mind
		else:
			_action_left -= delta
			if _action_left <= 0.0:
				_end_action(true)
	_job_active = false
	if not controlled and _combat_step(delta):
		if job and job.working:
			job.finish()
	elif not controlled:
		# an errand under way is finished first; a very urgent need takes them off work
		var urgent: bool = needs.thirst < NEED_URGENT or needs.hunger < NEED_URGENT
		if (urgent or _errand != "") and job and job.working:
			job.finish()
		if not urgent and _errand == "":
			_job_active = _job_step(delta)
		if not _job_active and not _need_step(delta):
			_autonomy(delta)
	var want := Vector2.ZERO
	var speed := PLAYED_SPEED * (RUN_FACTOR if running else 1.0) if controlled else (work_speed if work_speed > 0.0 else def.speed)
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
	if (_face != null or _face_pos != Vector3.INF) and not moving and not controlled:
		# stopped to talk (or to work at something): turn to face it
		var to := Hex.offset(position, _face.position if _face != null else _face_pos)
		if to.length() > 0.05:
			heading = lerp_angle(heading, atan2(to.x, to.z), minf(1.0, delta * 6.0))
		if _face != null and _timer <= 0.0:
			_face = null
	_face_pos = Vector3.INF
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
			if ShopJob.player_minding() and Hex.distance(position, ShopJob.customer_spot()) < 1.2:
				face_toward(ShopJob.till_spot())
				_face = ShopJob.player_keeper
				say(_pick(PackedStringArray(ShopJob.SHOPPING)))
		if bed == null and randf() < MUSE_CHANCE and Game.world_time > next_speak and not is_busy():
			say(pick_fresh(Array(def.lines)))
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


# the day job, when it's working hours and not bedtime; true while it's directing them
func _job_step(delta: float) -> bool:
	if job == null or dead:
		return false
	if bed != null or _lying or _lie > 0.0 or sleep_time() or _bedtime_soon():
		if job.working:
			job.finish()
		return false
	return job.tick(delta)


# ---------- health and fighting ----------

func _is_guard() -> bool:
	return def.job == "patrol"


## Their weapon: the tool of their trade (or fists).
func weapon() -> Dictionary:
	return Gear.WEAPONS.get(def.tool, Gear.WEAPONS[""])


## Struck (by a goblin): lose health; at none, they die.
func hurt(dmg: int, by: Node3D) -> void:
	if dead:
		return
	hp = maxf(0.0, hp - dmg)
	_hurt_at = Game.world_time
	_attacker = by
	FloatText.pop(get_parent(), global_position + Vector3.UP * 2.1, str(dmg), Color(1, 0.4, 0.35))
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	hp = 0.0
	Events.town_event.emit("%s was slain by a goblin." % def.display_name)
	if controlled:
		var p := get_tree().get_first_node_in_group("player") as PlayerController
		if p:
			p.let_go()
	if job and job.working:
		job.finish()
	_goal = null
	_errand = ""
	_fighting = false
	_fleeing = false
	_end_action(false)
	if _lying or _lie > 0.0:
		_lying = false
		_lie = 0.0
	_release_bed()
	_vel = Vector2.ZERO
	velocity = Vector3.ZERO
	moving = false
	_collision.disabled = true
	# fallen on their back where they stood
	body.quaternion = Quaternion(Vector3.UP, heading) * Quaternion(Vector3.RIGHT, -PI / 2)
	position.y += 0.2
	tag.text = def.display_name.to_upper() + " (DEAD)"
	tag.modulate = Color(0.6, 0.6, 0.6)
	_say.visible = false


## A blow at whatever goblin is in front of them and within reach (Space, while playing them).
func strike() -> void:
	if dead or _cool > 0.0 or _lying or _lie > 0.0:
		return
	var w := weapon()
	_cool = w.cd
	_strike = 0.001
	var fwd := Vector3(sin(heading), 0, cos(heading))
	var best: Monster = null
	var bd: float = w.reach + 0.3
	for m in get_tree().get_nodes_in_group("monsters"):
		var mo := m as Monster
		if mo.dead:
			continue
		var to := Hex.offset(position, mo.position)
		var d := to.length()
		if d < bd and (d < 0.6 or fwd.dot(to / d) > 0.2):
			bd = d
			best = mo
	if best:
		best.hurt(randi_range(w.dmg.x, w.dmg.y), self)


func _nearest_raider(within: float) -> Monster:
	var best: Monster = null
	var bd := within
	for m in get_tree().get_nodes_in_group("monsters"):
		var mo := m as Monster
		if not mo.is_raiding() or absf(mo.position.y - position.y) > 1.0:
			continue
		var d := Hex.distance(position, mo.position)
		if d < bd:
			bd = d
			best = mo
	return best


# fighting (or running away), for a resident nobody is playing; true while it has them
func _combat_step(_delta: float) -> bool:
	var foe: Monster = null
	if _is_guard():
		foe = _nearest_raider(GUARD_RANGE)
	else:
		# hit back at whoever's hitting them (or squares up to them)
		var near := _nearest_raider(4.0)
		if near and near.target == self:
			foe = near
		elif _attacker is Monster and not (_attacker as Monster).dead and Game.world_time - _hurt_at < 4.0 \
				and Hex.distance(position, _attacker.position) < 6.0:
			foe = _attacker
	if _fleeing:
		if foe == null or bed != null or _goal == null:
			_fleeing = false
		else:
			return true
	if foe == null:
		if _fighting:
			_fighting = false
			_goal = null
			_timer = 1.0
		return false
	if not _is_guard() and hp < def.hp_max * 0.35:
		# badly hurt: run for home
		var b := _nearest_free_bed()
		if b:
			_fighting = false
			_fleeing = true
			_set_goal(_snap(b.stand_point()))
			say("Help! Help!")
			return true
	if not _fighting:
		_fighting = true
		if _is_guard():
			say(pick_fresh(TO_ARMS))
	var w := weapon()
	var d := Hex.distance(position, foe.position)
	if d > w.reach * 0.85:
		if _goal == null or Hex.distance(_goal, foe.position) > 0.8:
			_set_goal(foe.position)
	else:
		_goal = null
		var to := Hex.offset(position, foe.position)
		heading = lerp_angle(heading, atan2(to.x, to.z), 0.3)
		if _cool <= 0.0:
			_cool = w.cd
			_strike = 0.001
			foe.hurt(randi_range(w.dmg.x, w.dmg.y), self)
	return true


## Cheer up (talking, eating, drinking).
func cheer(points: float) -> void:
	needs.happiness = minf(100.0, needs.happiness + points)


func _drain_needs(delta: float) -> void:
	# health comes back slowly out of danger, and quickly in bed
	if hp < def.hp_max:
		var rate := 3.0 if (_lying and _lie >= 1.0) else (0.4 if Game.world_time - _hurt_at > 12.0 else 0.0)
		hp = minf(def.hp_max, hp + rate * delta)
	if _lying and _lie >= 1.0:
		needs.fatigue = minf(100.0, needs.fatigue + REST * delta)
	else:
		needs.fatigue = maxf(0.0, needs.fatigue - DRAIN.fatigue * delta * (1.5 if _job_active else 1.0))
	var asleep := _lying and _lie >= 1.0
	for k in ["hunger", "thirst"]:
		needs[k] = maxf(0.0, needs[k] - DRAIN[k] * delta * (ASLEEP_DRAIN if asleep else 1.0))
	# a good night's sleep lifts the spirits a little
	needs.happiness = clampf(needs.happiness + (0.25 if asleep else -DRAIN.happiness) * delta, 0.0, 100.0)


# off for a drink or a meal when one runs low; true while seeing to it
func _need_step(_delta: float) -> bool:
	if bed != null or _lying or _lie > 0.0:
		_errand = ""
		return false
	if _action_left > 0.0:
		return true                              # drinking or eating
	if _errand == "":
		if _bedtime_soon():
			return false
		if needs.thirst < NEED_LOW:
			# the well, or a cup of water at home if that's nearer
			var well := get_tree().get_first_node_in_group("well") as Well
			var home := _nearest_oven(false)
			if well == null and home == null:
				return false
			_errand = "drink"
			if well and (home == null or Hex.distance(position, well.position) < Hex.distance(position, home.global_position)):
				_errand_spot = well.stand_point(position)
				_errand_face = well.position
			else:
				_errand_spot = oven_front(home)
				_errand_face = home.global_position
			say(_pick(PackedStringArray(THIRSTY)))
		elif needs.hunger < NEED_LOW:
			var oven := _nearest_oven()
			if oven == null:
				return false
			_errand = "eat"
			_errand_spot = oven_front(oven)
			_errand_face = oven.global_position
			say(_pick(PackedStringArray(HUNGRY)))
		else:
			return false
		_errand_tries = 0
		_set_goal(_snap(_errand_spot))
		return true
	if Hex.distance(position, _errand_spot) < 0.7 and absf(position.y - _errand_spot.y) < 0.6:
		var kind := _errand
		start_action("", "", 2.5 if kind == "drink" else 4.0, _errand_face, func() -> void:
			if kind == "drink":
				needs.thirst = 100.0
				cheer(4.0)
				say(_pick(PackedStringArray(DRANK)))
			else:
				needs.hunger = 100.0
				cheer(6.0)
				say(_pick(PackedStringArray(ATE)))
			_errand = "")
		return true
	if _goal == null:
		_errand_tries += 1
		if _errand_tries > 3:
			# can't get there: give up for now (and don't try again straight away)
			needs[("thirst" if _errand == "drink" else "hunger")] += 20.0
			_errand = ""
			return false
		_set_goal(_snap(_errand_spot))
	return true


func _snap(p: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return p
	return NavigationServer3D.map_get_closest_point(map, p)


## Where to stand to eat by an oven: in front of its mouth.
static func oven_front(oven: Node3D) -> Vector3:
	var f := oven.global_transform.basis.z
	f.y = 0.0
	return oven.global_position + f.normalized() * 1.15


## The ovens in a building (the oven itself, not its collider).
static func ovens_in(b: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in b.find_children("Oven", "Node3D", true, false):
		if not (n is CollisionShape3D):
			out.append(n)
	return out


# their own home's oven or (if tavern) the tavern's, whichever is nearer
func _nearest_oven(tavern := true) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for b in get_tree().get_nodes_in_group("buildings"):
		var bld := b as Building
		var mine := false
		for bd_ in bld.beds:
			if bd_.owner_id == def.id:
				mine = true
		if not mine and not (tavern and bld.name == "Tavern"):
			continue
		for o in ovens_in(bld):
			var d := Hex.distance(position, o.global_position)
			if d < bd:
				bd = d
				best = o
	return best


# Set off home in time to be in bed by bedtime: true from when the walk to their bed would take
# all the time left (or once they're on their way, or already in bed early).
func _bedtime_soon() -> bool:
	var until := fposmod(def.sleep_hour - Game.local_hours(position.x), 24.0)
	if until > 12.0:
		return false
	if bed != null:
		return true
	var b := _nearest_free_bed()
	if b == null:
		return false
	var secs := Hex.distance(position, b.stand_point()) * 1.2 / maxf(def.speed, 0.1)
	return until <= secs / (Game.DAY_SECONDS / 24.0) + 0.25


# bedtime and morning, for a resident nobody is playing
func _routine(delta: float) -> void:
	if _fighting or _fleeing or (_is_guard() and _nearest_raider(GUARD_RANGE) != null):
		return                                   # no going to bed with goblins about
	# worn out: a nap, whatever the time, until they're rested
	if needs.fatigue < 12.0 and not _napping:
		_napping = true
	elif _napping and needs.fatigue >= 99.0:
		_napping = false
	var night := sleep_time() or _bedtime_soon() or _napping
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


## One of the lines, not the one they said last if there's a choice.
func pick_fresh(lines: Array) -> String:
	if lines.is_empty():
		return ""
	var options := lines.filter(func(l: String) -> bool: return l != _last_said)
	if options.is_empty():
		options = lines
	return options[randi() % options.size()]


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
	if ShopJob.is_open() and def.job != "shop" and randf() < 0.12:
		# drop into the general store while it's open
		var c := ShopJob.customer_spot() + Vector3(randf_range(-0.4, 0.4), 0.0, 0.0)
		_set_goal(Vector3(Hex.near_copy_x(c.x, position.x), c.y, Hex.near_copy_z(c.z, position.z)))
		_visiting = true
		return
	var square := get_tree().get_first_node_in_group("town_square") as TownSquare
	# glum residents go looking for company more often
	if square and randf() < def.town_visits * (1.0 + (1.0 - needs.happiness / 100.0)):
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
	if _wants_tool() != _tool_shown:
		_refresh_props()
	_walk_w += ((1.0 if moving else 0.0) - _walk_w) * minf(1.0, delta * 8.0)
	if _lie == 0.0:
		body.rotation = Vector3(0.0, heading, 0.0)
	var a := _walk_w * sin(_phase) * 0.6
	_arm_l.rotation.x = a
	_arm_r.rotation.x = -a
	_leg_l.rotation.x = -a * 0.8
	_leg_r.rotation.x = a * 0.8
	var p := pose if pose != "" else ("carry" if pack.get("parcels", 0) > 0 else "")
	match p:
		"carry":
			_arm_l.rotation.x = -1.05
			_arm_r.rotation.x = -1.05
		"chop":
			var k := absf(sin(Game.world_time * 4.5))
			_arm_r.rotation.x = -0.3 - 2.4 * k
			_arm_l.rotation.x = -0.2 - 2.0 * k
		"light":
			_arm_r.rotation.x = -2.3
			_arm_l.rotation.x = 0.0
	if _held == "pole":
		var held := _arm_r.get_node_or_null("Carry") as Node3D
		if held:
			held.rotation.x = PI if pose == "light" else -_arm_r.rotation.x
	if _strike > 0.0:
		# a quick blow with the weapon arm (a punch, bare-handed)
		_strike += delta
		var k := clampf(_strike / 0.35, 0.0, 1.0)
		_arm_r.rotation.x = (-1.6 if def.tool == "" else -2.4) * sin(k * PI)
		if k >= 1.0:
			_strike = 0.0
	_mouth.scale.y = 1.0 + 3.0 * absf(sin(Time.get_ticks_msec() * 0.018)) if _talk_left > 0.0 else 1.0
