class_name Conversations
extends Node
## Residents meeting and talking (as in the HTML game). When two residents nobody is playing come
## within sight of each other on the same floor, neither busy (talking, or on the way to bed), one
## walks over while the other waits; then they face each other, one greets the other by name and the
## other replies. The same two won't stop again for a while.
##
## A player speaking (Enter, then type) is heard by the residents nearby: they stop, turn and reply,
## one after another; a question gets one of their answers instead.

const SIGHT := 7.0                 # how near two have to be to notice each other (m)
const MEET_DIST := 1.9             # how close they come to talk (m)
const APPROACH_TIME := 12.0        # game seconds to walk over before giving up
const PAUSE := 3.5                 # game seconds they stand and talk
const REPLY_AFTER := 1.6           # game seconds before the reply
const COOLDOWN := Vector2(25.0, 40.0)   # game seconds before the same two stop again
const EARSHOT := 4.5               # how far a player's words carry (m)

var _cooldown := {}                # "a|b" -> Game.world_time when they may meet again
var _approach: Array = []          # [speaker, listener, give-up time]


func _ready() -> void:
	add_to_group("conversations")


func _physics_process(_delta: float) -> void:
	# walking over to someone: greet them on arrival
	for k in range(_approach.size() - 1, -1, -1):
		var sp := _approach[k][0] as Resident
		var li := _approach[k][1] as Resident
		if sp.controlled or li.controlled or sp.bed != null or li.bed != null or Game.world_time > _approach[k][2]:
			_approach.remove_at(k)
			continue
		if Hex.distance(sp.position, li.position) <= MEET_DIST:
			if sp.is_busy() or li.is_busy():
				continue                        # one of them is still talking: wait
			_approach.remove_at(k)
			_meet(sp, li)
		elif not sp.has_goal():
			sp.walk_to(_beside(li, sp))
	var rs := get_tree().get_nodes_in_group("residents")
	for i in rs.size():
		var a := rs[i] as Resident
		if a.is_busy() or _engaged(a):
			continue
		for j in range(i + 1, rs.size()):
			var b := rs[j] as Resident
			if b.is_busy() or _engaged(b) or absf(a.position.y - b.position.y) > 1.0 or Hex.distance(a.position, b.position) > SIGHT:
				continue
			var key := a.def.id + "|" + b.def.id
			if _cooldown.get(key, 0.0) > Game.world_time:
				continue
			_cooldown[key] = Game.world_time + randf_range(COOLDOWN.x, COOLDOWN.y)
			var sp := a if randf() < 0.5 else b
			var li := b if sp == a else a
			if Hex.distance(a.position, b.position) <= MEET_DIST:
				_meet(sp, li)
			else:
				# one walks over; the other stops and waits for them
				li.stop_to_talk(sp, APPROACH_TIME)
				sp.walk_to(_beside(li, sp))
				_approach.append([sp, li, Game.world_time + APPROACH_TIME])
			break


func _engaged(r: Resident) -> bool:
	for e in _approach:
		if e[0] == r or e[1] == r:
			return true
	return false


# a spot a little short of someone, on the way from the one walking over
func _beside(li: Resident, sp: Resident) -> Vector3:
	var off := Hex.offset(li.position, sp.position)
	off.y = 0.0
	var d := off.length()
	var dir := off / d if d > 0.01 else Vector3(1, 0, 0)
	var p := li.position + dir * (MEET_DIST - 0.5)
	return Vector3(Hex.near_copy_x(p.x, sp.position.x), li.position.y, Hex.near_copy_z(p.z, sp.position.z))


func _meet(speaker: Resident, listener: Resident) -> void:
	speaker.stop_to_talk(listener, PAUSE)
	listener.stop_to_talk(speaker, PAUSE)
	speaker.say(fill(Resident._pick(speaker.def.greet_lines), listener))
	listener.say_later(Resident._pick(listener.def.reply_lines), REPLY_AFTER)
	speaker.cheer(10.0)
	listener.cheer(10.0)


## A player made their resident say something: everyone nearby who's free turns and answers.
func player_spoke(r: Resident, text: String) -> void:
	var k := 0
	var question := text.contains("?")
	for o in get_tree().get_nodes_in_group("residents"):
		var other := o as Resident
		if other == r or other.controlled or other.is_lying() or other.bed != null:
			continue
		if absf(other.position.y - r.position.y) > 1.0 or Hex.distance(other.position, r.position) > EARSHOT:
			continue
		other.stop_to_talk(r, 3.0 + k * 0.9)
		other.say_later(Resident._pick(other.def.answer_lines if question else other.def.reply_lines), 1.0 + k * 0.9)
		other.cheer(8.0)
		r.cheer(4.0)
		k += 1


## A greeting with the names and the time of day filled in.
static func fill(line: String, other: Resident) -> String:
	var h := Game.local_hours(other.position.x)
	var tod := "morning" if h >= 5.0 and h < 12.0 else ("afternoon" if h >= 12.0 and h < 17.0 else "evening")
	return line.replace("{n}", other.def.display_name).replace("{tod}", tod).replace("{Tod}", tod.capitalize())
