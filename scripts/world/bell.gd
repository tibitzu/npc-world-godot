class_name AlarmBell
extends Node3D
## The alarm bell (as in the HTML game): a bronze bell in a timber frame on the square, west of
## the well. When a raid comes, the guard on watch runs to it and rings it; anyone can ring it
## with F.
##
## Ringing it raises the alarm: for as long as the raid it was rung for goes on (or a couple of
## hours, rung with no raid on) everyone who isn't a guard hurries indoors and stays there, and both guards turn out for
## raiders anywhere in town, the one off duty getting out of bed for it.

@export var spot := Vector2(-3.4, 7.9)

const ALARM_FOR := 12.0            # game seconds (a couple of hours) the alarm lasts when rung with no raid on
const SWING_FOR := 4.0             # real seconds the bell swings
const STAND := 1.0                 # where a ringer stands: this far south of the bell (m)
const RUNG := ["Goblins! Everyone indoors!", "Raiders! Get inside and bar the doors!", "To your homes! Goblins!"]

var alarm_until := -1.0
## The raid (GoblinCamp.raid_no) it was last rung for.
var rung_for := 0

var _pivot: Node3D
var _swing := -1.0                 # real seconds since it was rung (-1: still)
var _player: AudioStreamPlayer3D
var _blocked: Array = []


func _ready() -> void:
	add_to_group("alarm_bell")
	position = Vector3(spot.x, 0.0, spot.y)
	_build()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for x in [-0.7, 0.7]:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.16
		sh.height = 2.5
		cs.shape = sh
		cs.position = Vector3(x, 1.25, 0)
		body.add_child(cs)
	_blocked = [Rect2(spot.x - 0.95, spot.y - 0.45, 1.9, 0.9)]
	for i in Hex.tiles_in(_blocked[0].grow(0.2)):
		Game.tiles.set_flag(i, TileGrid.F_BLOCK)
	add_to_group("nav_blockers")
	var nav := get_tree().get_first_node_in_group("world_nav") as WorldNav
	if nav:
		nav.carve_many(_blocked)
	_player = AudioStreamPlayer3D.new()
	_player.position = Vector3(0, 2.2, 0)
	_player.unit_size = 25.0
	_player.max_distance = 220.0
	add_child(_player)


func blocker_rects() -> Array:
	return _blocked


## The bell, wherever it is (or null).
static func find(tree: SceneTree) -> AlarmBell:
	return tree.get_first_node_in_group("alarm_bell") as AlarmBell


## Is the alarm up? (Everyone indoors, the guards out.)
static func alarm(tree: SceneTree) -> bool:
	var b := find(tree)
	return b != null and b.is_alarm()


func is_alarm() -> bool:
	if Game.world_time < alarm_until:
		return true
	var camp := get_tree().get_first_node_in_group("goblin_camp") as GoblinCamp
	return camp != null and camp.raiding and rung_for == camp.raid_no and rung_for > 0


## Has it been rung for the raid going on now?
func rung_for_this_raid() -> bool:
	var camp := get_tree().get_first_node_in_group("goblin_camp") as GoblinCamp
	return camp == null or not camp.raiding or rung_for == camp.raid_no


## Where someone stands to ring it.
func stand_point() -> Vector3:
	return position + Vector3(0, 0, STAND)


## Ring it (by: whoever pulled the rope).
func ring(by: Resident) -> void:
	if _swing >= 0.0 and _swing < 2.5:
		return                                 # still swinging from the last pull
	var camp := get_tree().get_first_node_in_group("goblin_camp") as GoblinCamp
	if camp and camp.raiding:
		rung_for = camp.raid_no               # until the raid's over
	else:
		alarm_until = Game.world_time + ALARM_FOR
	_swing = 0.0
	if _player.stream == null:
		_player.stream = _bell_sound()     # made the first time it's needed
	_player.play()
	if by:
		by.face_toward(position)
		by.say(by.pick_fresh(RUNG))
		Events.town_event.emit("%s rang the alarm bell! Everyone indoors." % by.def.display_name)
	else:
		Events.town_event.emit("The alarm bell is ringing! Everyone indoors.")


func _process(delta: float) -> void:
	if _swing < 0.0:
		return
	_swing += delta
	if _swing > SWING_FOR:
		_swing = -1.0
		_pivot.rotation.x = 0.0
		return
	_pivot.rotation.x = 0.55 * sin(_swing * TAU * 0.58) * exp(-_swing * 0.55)


func _build() -> void:
	var wood := Gear.mat(0x6b4a33, 0.9)
	var dark := Gear.mat(0x3e2a1d, 0.9)
	var stone := Gear.mat(0x8a8698, 0.95)
	var slate := Gear.mat(0x3b3a48, 0.8)
	var bronze := Gear.mat(0xb08a3a, 0.35, 0.75)
	Gear._put(self, Gear._cyl(0.95, 1.05, 0.16, 16), stone, Vector3(0, 0.08, 0))
	for x in [-0.7, 0.7]:
		Gear._put(self, Gear._box(Vector3(0.16, 2.5, 0.16)), wood, Vector3(x, 1.33, 0))
		Gear._put(self, Gear._box(Vector3(0.4, 0.12, 0.4)), dark, Vector3(x, 0.22, 0))
	Gear._put(self, Gear._box(Vector3(1.75, 0.18, 0.22)), dark, Vector3(0, 2.5, 0))
	for sd in [-1, 1]:
		Gear._put(self, Gear._box(Vector3(2.0, 0.07, 0.62)), slate, Vector3(0, 2.78, sd * 0.2), Vector3(sd * 0.62, 0, 0))
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 2.4, 0)
	add_child(_pivot)
	# the bell: a flared bronze cup hanging from the beam, a clapper inside and the rope
	Gear._put(_pivot, Gear._cyl(0.2, 0.25, 0.32, 20), bronze, Vector3(0, -0.2, 0))
	Gear._put(_pivot, Gear._cyl(0.25, 0.34, 0.2, 20), bronze, Vector3(0, -0.45, 0))
	Gear._put(_pivot, Gear._dome(0.2), bronze, Vector3(0, -0.04, 0))
	Gear._put(_pivot, Gear._ball(0.07), dark, Vector3(0, -0.5, 0))
	Gear._put(_pivot, Gear._cyl(0.018, 0.018, 1.4, 6), Gear.mat(0xc9a45c, 1.0), Vector3(0.18, -1.2, 0))


# three strokes of a bronze bell (as the HTML game makes it): a stack of decaying partials
static func _bell_sound() -> AudioStreamWAV:
	const RATE := 16000
	const LEN := 5.2
	const PARTIALS := [[0.5, 0.55, 4.0], [1.0, 1.0, 3.2], [1.19, 0.45, 2.6], [1.5, 0.32, 2.2], [2.0, 0.42, 1.8], [2.74, 0.2, 1.2], [3.9, 0.12, 0.8]]
	var n := int(RATE * LEN)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for start in [0.0, 0.85, 1.7]:
		var i0 := int(start * RATE)
		for p in PARTIALS:
			var f: float = 330.0 * p[0]
			var a: float = p[1]
			var k := 6.9 / float(p[2])            # down to a thousandth by the end of its ring
			for i in range(i0, mini(n, i0 + int(float(p[2]) * RATE))):
				var t := float(i - i0) / RATE
				buf[i] += a * sin(TAU * f * t) * exp(-k * t) * minf(1.0, t / 0.006)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * 0.22, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
