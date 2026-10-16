class_name GoblinCamp
extends Node3D
## A goblin camp out in the hills north-east of town: a few patched tents round a fire. Five
## goblins loaf about it. Every few nights (the first on the second night) a raiding party sets
## out at dusk, marches on the town and prowls it for anyone out of doors; at dawn the survivors
## go home. The camp makes up its numbers again each noon.
##
## The band answers to a chief down in the lair under the camp (see GoblinLair). Once he's dead
## the raids stop and the camp is no longer made up.

@export var spot := Vector2(46.0, -30.0)
@export var band := 5
@export var raiders := 4
## Where a raid comes into town (the east road's mouth on the square).
@export var town_gate := Vector3(12.0, 0.0, 10.3)

const MONSTER := preload("res://scripts/actors/monster.gd")

var goblins: Array[Monster] = []
var raiding := false
## Counts the raids (the alarm bell is rung once for each).
var raid_no := 0
## The chief is dead: no more raids.
var leaderless := false
var _next_raid_day := 2
var _refilled_day := 0
var _announced := false


func _ready() -> void:
	add_to_group("goblin_camp")
	position = Vector3(spot.x, 0.0, spot.y)
	_build()
	_refill.call_deferred()


func _build() -> void:
	var cloths := [0x6b5a3a, 0x5a4a3a, 0x7a5a3a]
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		var t := Gear._put(self, Gear._cyl(0.0, 1.3, 1.6, 4), Gear.mat(cloths[i], 1.0), Vector3(cos(a) * 4.2, 0.8, sin(a) * 4.2), Vector3(0, a, 0))
		t.scale = Vector3(1, 1, 0.8)
		Gear._put(self, Gear._box(Vector3(0.05, 1.8, 0.05)), Gear.mat(0x3a2a20), Vector3(cos(a) * 4.2, 0.9, sin(a) * 4.2))
	# the fire: a ring of stones, logs and flames
	for k in 8:
		var a := TAU * k / 8.0
		Gear._put(self, Gear._ball(0.14), Gear.mat(0x6e7176, 0.95), Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55))
	for k in 3:
		Gear._put(self, Gear._cyl(0.06, 0.06, 0.7, 6), Gear.mat(0x3b2618), Vector3(0, 0.1, 0), Vector3(PI / 2, TAU * k / 3.0, 0))
	var fire := Node3D.new()
	fire.position = Vector3(0, 0.12, 0)
	fire.set_script(load("res://scripts/buildings/flicker.gd"))
	for k in 3:
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Look.html_hex([0xff6a1f, 0xffb13d, 0xffe08a][k])
		fm.emission_enabled = true
		fm.emission = fm.albedo_color
		fm.emission_energy_multiplier = 2.4
		var f := Gear._put(fire, Gear._cyl(0.0, 0.16 - k * 0.04, 0.45 - k * 0.1, 6), fm, Vector3(0, 0.22 - k * 0.03, 0))
		f.name = "Flame%d" % k
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Look.html_hex(0xff8a3d)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = Vector3(0, 0.6, 0)
	fire.add_child(light)
	add_child(fire)                        # (after its flames, so the flicker finds them)
	# crates and a pile of loot
	Gear._put(self, Gear._box(Vector3(0.6, 0.5, 0.6)), Gear.mat(0x8a6242), Vector3(2.0, 0.25, -1.6), Vector3(0, 0.4, 0))
	Gear._put(self, Gear._box(Vector3(0.5, 0.4, 0.5)), Gear.mat(0x8a6242), Vector3(2.6, 0.2, -0.9), Vector3(0, 0.9, 0))
	var sign := Label3D.new()
	sign.text = "GOBLIN CAMP"
	sign.font_size = 56
	sign.pixel_size = 0.008
	sign.modulate = Color(0.75, 0.95, 0.5)
	sign.outline_size = 8
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 3.4, 0)
	add_child(sign)


func _refill() -> void:
	goblins = goblins.filter(func(g: Monster) -> bool: return is_instance_valid(g) and not g.dead)
	while goblins.size() < band:
		var g := MONSTER.new() as Monster
		g.camp = position
		get_parent().add_child(g)
		var a := randf() * TAU
		g.global_position = position + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.5)
		goblins.append(g)


func _process(_delta: float) -> void:
	var h := Game.local_hours(position.x)
	var day := Game.day_number(position.x)
	goblins = goblins.filter(func(g: Monster) -> bool: return is_instance_valid(g))
	var alive := goblins.filter(func(g: Monster) -> bool: return not g.dead)
	if not raiding and not leaderless and day >= _next_raid_day and h >= 19.0:
		raiding = true
		raid_no += 1
		_announced = false
		var party := alive.slice(0, raiders)
		for k in party.size():
			(party[k] as Monster).march_on(town_gate + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0)))
		if not party.is_empty():
			(party[0] as Monster).say("raid")
	elif raiding:
		var out := alive.filter(func(g: Monster) -> bool: return g.is_raiding())
		if not _announced:
			for g in out:
				if Hex.distance((g as Monster).position, town_gate) < 25.0:
					_announced = true
					Events.town_event.emit("Goblins are raiding the town!")
					break
		if out.is_empty() or (h >= 4.5 and h < 19.0):
			raiding = false
			for g in alive:
				(g as Monster).go_home()
			_next_raid_day = day + randi_range(2, 3)
			if _announced:
				Events.town_event.emit("The goblins have gone." if out.is_empty() or alive.size() > 0 else "The raid is over.")
	# made up again at noon
	if not raiding and not leaderless and h >= 12.0 and h < 13.0 and _refilled_day != day:
		_refilled_day = day
		_refill()


## The chief has been killed: any raid going on breaks off, and there won't be another.
func chief_slain() -> void:
	if leaderless:
		return
	leaderless = true
	for g in goblins:
		if is_instance_valid(g) and not (g as Monster).dead and (g as Monster).is_raiding():
			(g as Monster).go_home()
	Events.town_event.emit("With their chief dead, the goblins won't raid the town again.")


## Goblins out raiding now (for the guards to look out for).
static func raiders_in(tree: SceneTree) -> Array:
	var out := []
	for m in tree.get_nodes_in_group("monsters"):
		if (m as Monster).is_raiding():
			out.append(m)
	return out
