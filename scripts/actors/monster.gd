class_name Monster
extends CharacterBody3D
## A goblin from the camp in the hills (as in the HTML game's goblin bands): small, green, quick,
## with a club. At the camp they loaf about the fire. On a raid night they march on the town, go
## for anyone they find outdoors (a closed door keeps them out), and head home at dawn; badly
## hurt, one runs for it. Dead, it lies where it fell for a while, and the camp sends out a new
## one the next day.
##
## Down in the lair under the camp (see GoblinLair) more of them walk the tunnels between the
## rooms, and go for anyone who comes down there; they don't run, and don't follow anyone up the
## stair. Their chief, bigger, crowned and harder-hitting, paces the great hall; killing him ends
## the raids for good.
##
## Like the residents they have the six abilities (Abilities.GOBLIN, GOBLIN_CHIEF), which work the
## same way: Strength on their blows, Agility on how quick they are and their chance to dodge,
## Constitution on their health and Wisdom on how far off they spot someone.

signal died

const HP_MAX := 30.0
const DMG := Vector2i(3, 6)
const CHIEF_HP := 90.0
const CHIEF_DMG := Vector2i(5, 9)
const REACH := 1.4
const FLOOR_MASK := 1
const STEP_UP := 0.35
const LAIR_TOP := -1.5             # anyone higher than this has gone up the stair and out
const COOLDOWN := 1.4
const SPEED := 1.6
const RUN := 2.1                   # marching on the town, running home
const SIGHT := 12.0                # how far they spot someone to go for (m)
const LINES := {
	"raid": ["Easy pickings in that town!", "Grab what you can carry!", "Torches up, lads!"],
	"spot": ["Oi! You!", "Get 'im!", "Fresh meat!"],
	"hurt": ["Ow!", "Grr!", "That smarts!"],
	"flee": ["Run for it!", "Not worth it!", "Back to camp!"],
	"die": ["Urk.", "Aaagh...", "Tell me mum..."],
	"lair": ["Intruder!", "Who let you down 'ere?", "Get out of our warren!"],
	"chief": ["You dare come to MY hall?", "I'll wear your hat, townie!", "Kneel!"],
	"chief_die": ["No... my warren...", "Aargh! The band... is finished..."],
}

## Set before it's added: a lair goblin, or the chief (who lives in the lair).
var in_lair := false
var chief := false
## Lair goblins: spots to walk between (they pick another when they get to one).
var beat: Array[Vector3] = []
var hp_max := HP_MAX
var abil: Dictionary = Abilities.GOBLIN

var hp := -1.0
var dead := false
var mode := "camp"                 # camp, march, hunt, retreat, dead
var camp: Vector3                  # home
var target: Resident = null
var _goal = null
var _cool := 0.0
var _timer := 0.0
var _strike := 0.0                 # seconds into a swing
var _say_left := 0.0
var _next_say := 0.0
var _dead_for := 0.0
var _phase := 0.0
var _vel := Vector2.ZERO

var body: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _say: Label3D
var _bar: Node3D
var _bar_fill: MeshInstance3D
var agent: NavigationAgent3D
var _hud: Node3D                   # name, health bar and speech (drawn through walls)
var _lair: GoblinLair


func _ready() -> void:
	add_to_group("monsters")
	if chief:
		hp_max = CHIEF_HP
		abil = Abilities.GOBLIN_CHIEF
	hp_max += Abilities.HP_PER_CON * Abilities.mod(abil.con)
	if hp < 0.0:
		hp = hp_max
	if in_lair:
		mode = "lair"
	collision_layer = 2
	collision_mask = 9
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.22
	cap.height = 0.9
	cs.shape = cap
	cs.position = Vector3(0, 0.45, 0)
	add_child(cs)
	agent = NavigationAgent3D.new()
	agent.radius = 0.25
	agent.height = 1.2
	agent.path_desired_distance = 0.4
	agent.target_desired_distance = 0.3
	add_child(agent)
	_build_body()


func _build_body() -> void:
	body = Node3D.new()
	body.scale = Vector3.ONE * (1.15 * 1.35 if chief else 1.15)
	add_child(body)
	var skin := Gear.mat(0x6f9a3a, 0.9)
	var rag := Gear.mat(0x7a2e2a if chief else 0x5a4632, 1.0)
	var dark := Gear.mat(0x1c1c22)
	Gear._put(body, Gear._cyl(0.13, 0.16, 0.4, 10), rag, Vector3(0, 0.44, 0))
	Gear._put(body, Gear._ball(0.15), skin, Vector3(0, 0.78, 0))
	for s in [-1, 1]:
		Gear._put(body, Gear._cyl(0.0, 0.05, 0.16, 6), skin, Vector3(0.16 * s, 0.82, 0), Vector3(0, 0, -s * 1.2))
		Gear._put(body, Gear._ball(0.025), Gear.mat(0xffd84d, 0.4), Vector3(0.055 * s, 0.8, 0.13))
	Gear._put(body, Gear._box(Vector3(0.08, 0.012, 0.01)), dark, Vector3(0, 0.72, 0.145))
	_arm_l = _limb(body, Vector3(-0.17, 0.6, 0), 0.26, skin)
	_arm_r = _limb(body, Vector3(0.17, 0.6, 0), 0.26, skin)
	_leg_l = _limb(body, Vector3(-0.07, 0.25, 0), 0.25, dark)
	_leg_r = _limb(body, Vector3(0.07, 0.25, 0), 0.25, dark)
	# a club in the right hand
	var club := Node3D.new()
	club.position = Vector3(0, -0.26, 0.04)
	club.rotation.x = 0.6
	_arm_r.add_child(club)
	if chief:
		# a cleaver, a buckler on the other arm and a spiked gold crown
		var steel := Gear.mat(0xc3cbd4, 0.3, 0.7)
		var gold := Gear.mat(0xd8b25a, 0.35, 0.6)
		Gear._put(club, Gear._cyl(0.02, 0.02, 0.2, 6), Gear.mat(0x3a2a20), Vector3(0, 0.05, 0))
		Gear._put(club, Gear._box(Vector3(0.02, 0.26, 0.13)), steel, Vector3(0, 0.27, 0.04))
		Gear._put(_arm_l, Gear._cyl(0.12, 0.12, 0.03, 12), Gear.mat(0x6b4a2e), Vector3(-0.04, -0.17, 0.02), Vector3(0, 0, PI / 2))
		Gear._put(body, Gear._cyl(0.13, 0.15, 0.08, 5), gold, Vector3(0, 0.9, 0))
		for i in 5:
			var a := TAU * i / 5.0
			Gear._put(body, Gear._cyl(0.0, 0.03, 0.09, 4), gold, Vector3(sin(a) * 0.12, 0.98, cos(a) * 0.12))
	else:
		Gear._put(club, Gear._cyl(0.045, 0.022, 0.4, 7), Gear.mat(0x7a5233), Vector3(0, 0.17, 0))
	for c in body.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# name and health bar
	_hud = Node3D.new()
	add_child(_hud)
	var tag := Label3D.new()
	tag.text = "GOBLIN CHIEF" if chief else "GOBLIN"
	tag.font_size = 28
	tag.pixel_size = 0.0006
	tag.fixed_size = true
	tag.modulate = Color(0.75, 0.95, 0.5)
	tag.outline_size = 6
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 1.85 if chief else 1.45, 0)
	_hud.add_child(tag)
	_bar = Node3D.new()
	_bar.position = Vector3(0, 1.72 if chief else 1.32, 0)
	_hud.add_child(_bar)
	var bg := _bar_quad(Color(0, 0, 0, 0.6), 0.62)
	bg.position.z = -0.001
	_bar_fill = _bar_quad(Color(0.85, 0.2, 0.15), 0.6)
	_bar.visible = false
	_say = Label3D.new()
	_say.font_size = 28
	_say.pixel_size = 0.0006
	_say.fixed_size = true
	_say.offset = Vector2(0, 30)
	_say.outline_size = 8
	_say.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_say.no_depth_test = true
	_say.position = Vector3(0, 2.15 if chief else 1.75, 0)
	_say.visible = false
	_hud.add_child(_say)


func _bar_quad(c: Color, w: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(w, 0.07)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(mi)
	return mi


func _limb(parent: Node3D, at: Vector3, length: float, m: Material) -> Node3D:
	var p := Node3D.new()
	p.position = at
	parent.add_child(p)
	Gear._put(p, Gear._cyl(0.04, 0.035, length, 6), m, Vector3(0, -length / 2, 0))
	return p


func say(kind: String, chance := 1.0) -> void:
	var lines: Array = LINES.get(kind, [])
	if lines.is_empty() or randf() > chance or Game.world_time < _next_say:
		return
	_say.text = lines[randi() % lines.size()]
	_say.visible = true
	_say_left = 2.8
	_next_say = Game.world_time + 5.0


## Is this one out raiding (or hunting someone in town)?
func is_raiding() -> bool:
	return not dead and (mode == "march" or mode == "hunt")


## Out to hurt someone: raiding, or after an intruder in the lair.
func is_hostile() -> bool:
	return not dead and (mode == "march" or mode == "hunt" or mode == "chase")


## Struck by a resident.
func hurt(dmg: int, by: Resident) -> void:
	if dead:
		return
	if randf() < Abilities.dodge(abil.agi):
		FloatText.pop(get_parent(), global_position + Vector3.UP * 1.5, "dodged", Color(0.75, 0.85, 1.0))
		if by and is_instance_valid(by) and not by.dead and target == null:
			target = by
			if in_lair and mode == "lair":
				mode = "chase"
		return
	hp = maxf(0.0, hp - dmg)
	FloatText.pop(get_parent(), global_position + Vector3.UP * 1.5, str(dmg), Color(1, 0.85, 0.4))
	_bar.visible = true
	_bar_fill.scale.x = hp / hp_max
	_bar_fill.position.x = -(1.0 - hp / hp_max) * 0.3
	if hp <= 0.0:
		_die(by)
		return
	say("hurt", 0.4)
	if by and is_instance_valid(by) and not by.dead:
		target = by                                  # turn on whoever did it
		if in_lair and mode == "lair":
			mode = "chase"
	if not in_lair and hp < hp_max * 0.3 and mode != "retreat":
		mode = "retreat"
		target = null
		say("flee")
		_set_goal(camp)


func _die(by: Resident) -> void:
	dead = true
	mode = "dead"
	target = null
	_goal = null
	_next_say = 0.0
	say("chief_die" if chief else "die", 1.0 if chief else 0.7)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
	if chief:
		Events.town_event.emit("%s slew the goblin chief!" % by.def.display_name if by else "The goblin chief is dead!")
		var camp := get_tree().get_first_node_in_group("goblin_camp") as GoblinCamp
		if camp:
			camp.chief_slain()
	else:
		Events.town_event.emit("%s defeated a goblin." % by.def.display_name if by else "A goblin fell.")
	died.emit()


func march_on(town: Vector3) -> void:
	mode = "march"
	target = null
	_set_goal(town)


func go_home() -> void:
	if dead:
		return
	mode = "retreat"
	target = null
	_set_goal(camp)


func _set_goal(p: Vector3) -> void:
	_goal = p
	agent.target_position = p


func _process(_delta: float) -> void:
	# down in the lair, their labels only show while you're down there too
	if in_lair:
		if _lair == null:
			_lair = get_tree().get_first_node_in_group("goblin_lair") as GoblinLair
		_hud.visible = _lair != null and _lair.under


func _physics_process(delta: float) -> void:
	if _say_left > 0.0:
		_say_left -= Game.real_delta(delta)
		_say.visible = _say_left > 0.0
	if dead:
		_dead_for += delta
		body.rotation.x = move_toward(body.rotation.x, -PI / 2, delta * 4.0)
		body.position.y = move_toward(body.position.y, 0.15, delta)
		if _dead_for > (120.0 if in_lair else 25.0):
			queue_free()
		return
	_cool = maxf(0.0, _cool - delta)
	var speed := SPEED
	match mode:
		"camp":
			_timer -= delta
			if _goal == null and _timer <= 0.0:
				var a := randf() * TAU
				_set_goal(camp + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 5.0))
				_timer = randf_range(3.0, 8.0)
		"march":
			speed = RUN
			_look_for_someone()
			if target:
				mode = "hunt"
				say("spot", 0.7)
			elif _goal == null:
				mode = "hunt"
		"hunt":
			_look_for_someone()
			if target:
				var d := Hex.distance(position, target.position)
				if d <= REACH:
					_goal = null
					if _cool <= 0.0:
						_swing()
				elif _goal == null or (agent.target_position - target.position).length() > 0.8:
					_set_goal(target.position)
			elif _goal == null:
				# nobody about: prowl the town
				var sq := get_tree().get_first_node_in_group("town_square") as TownSquare
				_set_goal(sq.random_spot() if sq else camp)
		"lair":
			_lair_watch(delta)
		"chase":
			_lair_chase()
		"retreat":
			speed = RUN
			if _goal == null or Hex.distance(position, camp) < 2.0:
				mode = "camp"
				_goal = null
				_timer = 2.0
				if hp < hp_max:
					hp = hp_max                       # patched up at the fire
					_bar.visible = false
	_move(delta, speed)
	_animate(delta)


# whoever's nearest and out in the open (indoors they're safe), and not dead
func _look_for_someone() -> void:
	if target and (target.dead or not _in_open(target) or absf(target.position.y - position.y) > 1.0 \
			or Hex.distance(position, target.position) > sight() * 1.5):
		target = null
	if target:
		return
	var best: Resident = null
	var bd := sight()
	for o in get_tree().get_nodes_in_group("residents"):
		var r := o as Resident
		if r.dead or not _in_open(r) or absf(r.position.y - position.y) > 1.0:
			continue
		var d := Hex.distance(position, r.position) * _shadowed(r)
		if d < bd:
			bd = d
			best = r
	target = best


static func _in_open(r: Resident) -> bool:
	if r.position.y > 0.5 or r.is_lying():
		return false
	for b in r.get_tree().get_nodes_in_group("buildings"):
		if (b as Building).is_inside(r.position):
			return false
	return true


func _swing() -> void:
	_cool = COOLDOWN * Abilities.quickness(abil.agi)
	_strike = 0.001
	var to := Hex.offset(position, target.position)
	rotation.y = atan2(to.x, to.z)
	var dmg := damage()
	target.hurt(randi_range(dmg.x, dmg.y), self)


## Damage a blow does: their club's (the chief's cleaver's), with their Strength modifier.
func damage() -> Vector2i:
	var base := CHIEF_DMG if chief else DMG
	var m := Abilities.mod(abil.str)
	return Vector2i(maxi(1, base.x + m), maxi(1, base.y + m))


## How far off they spot someone: SIGHT, a metre further (or nearer) per point of Wisdom.
func sight() -> float:
	return SIGHT + Abilities.mod(abil.wis)


func _move(delta: float, speed: float) -> void:
	var want := Vector2.ZERO
	if _goal != null:
		if Hex.distance(position, _goal) < 0.3:
			_goal = null
		elif NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
			var n := agent.get_next_path_position() - position
			n.y = 0.0
			if n.length() > 0.01:
				want = Vector2(n.x, n.z).normalized()
			if agent.is_navigation_finished():
				_goal = null
	_vel += (want * speed - _vel) * minf(1.0, delta * 7.0)
	velocity = Vector3(_vel.x, 0.0, _vel.y)
	move_and_slide()
	_follow_floor(delta)
	if _vel.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(_vel.x, _vel.y), minf(1.0, delta * 8.0))
	elif target and mode == "hunt":
		var to := Hex.offset(position, target.position)
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))


func _animate(delta: float) -> void:
	var sp := _vel.length()
	_phase += delta * sp * 6.0
	var a := sin(_phase) * 0.7 * clampf(sp, 0.0, 1.0)
	_leg_l.rotation.x = -a
	_leg_r.rotation.x = a
	_arm_l.rotation.x = a * 0.8
	_arm_r.rotation.x = -a * 0.8
	if _strike > 0.0:
		_strike += delta
		var k := clampf(_strike / 0.35, 0.0, 1.0)
		_arm_r.rotation.x = -2.4 * sin(k * PI)
		if k >= 1.0:
			_strike = 0.0


# ---- in the lair ----

# walking the tunnels between spots on their beat (the chief: back and forth before his altar),
# watching for anyone down here
func _lair_watch(delta: float) -> void:
	var seen := _intruder(sight() * (0.75 if chief else 0.65))
	if seen:
		target = seen
		mode = "chase"
		say("chief" if chief else "lair", 0.8)
		return
	_timer -= delta
	if _goal == null and _timer <= 0.0 and not beat.is_empty():
		_set_goal(beat[randi() % beat.size()])
		_timer = 4.0 if chief else randf_range(2.0, 6.0)


# after an intruder: up to them and swinging, while they stay down here and not too far off
func _lair_chase() -> void:
	if target == null or target.dead or target.position.y > LAIR_TOP or Hex.distance(position, target.position) > sight() * 1.6:
		target = _intruder(sight() * 0.65)
		if target == null:
			mode = "lair"
			_goal = null
			_timer = 1.5
			return
	var d := Hex.distance(position, target.position)
	if d <= REACH + (0.2 if chief else 0.0):
		_goal = null
		if _cool <= 0.0:
			_swing()
			_cool = COOLDOWN * Abilities.quickness(abil.agi) * (1.15 if chief else 1.0)
	elif _goal == null or (agent.target_position - target.position).length() > 0.8:
		_set_goal(target.position)


# the nearest living resident down here within a distance, with nothing solid in between
func _intruder(within: float) -> Resident:
	var best: Resident = null
	var bd := within
	for o in get_tree().get_nodes_in_group("residents"):
		var r := o as Resident
		if r.dead or r.position.y > LAIR_TOP or absf(r.position.y - position.y) > 1.0:
			continue
		var d := Hex.distance(position, r.position) * _shadowed(r)
		if d < bd and _can_see(r.position):
			bd = d
			best = r
	return best


# someone in the cloak of shadows is seen only from half as far
static func _shadowed(r: Resident) -> float:
	return 2.0 if r.equip.back == "cloak" else 1.0


func _can_see(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.9, p + Vector3.UP * 0.9, FLOOR_MASK)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# stand on the floor underfoot (the lair's, a stair step) or else the open ground
func _follow_floor(delta: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(position + Vector3.UP * STEP_UP, position + Vector3.DOWN * 0.6, FLOOR_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var floor_y := (hit.position as Vector3).y if not hit.is_empty() else 0.0
	position.y = move_toward(position.y, floor_y, delta * 3.0) if absf(floor_y - position.y) < STEP_UP + 0.05 else floor_y
