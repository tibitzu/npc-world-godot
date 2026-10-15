class_name WoodcutterJob
extends Job
## Brann's working day (as in the HTML game): pick one of the trees nearest his woodpile, walk
## up to it, chop (his axe over his head) until it falls ("Timber!"), gather the logs it leaves,
## up to three on his back (his pack), carry them home and stack them on the pile. When the pile
## is full he takes the rest of the day off.

const CHOP_TIME := 3.0
const REACH := 0.8                     # how near a trunk he stands to chop (m)
const PILE_STAND := Vector2(4.85, 0.4) # cabin-local x, z: beside the woodpile
const STACKED := ["That'll keep the fire going.", "Another one for the pile.", "Stacked and squared."]

var _cabin: Building
var _pile: WoodPile
var _forest: Forest
var _state := "idle"
var _tree := -1
var _stand := Vector3.ZERO
var _log: Node3D = null
var _since := 0.0                      # game seconds in this state


func label() -> String:
	return "Carrying logs" if r.pack.logs > 0 else "Felling trees"


func start() -> void:
	_cabin = building("Cabin")
	_pile = _cabin.find_child("WoodPile", true, false) as WoodPile if _cabin else null
	_forest = r.get_tree().get_first_node_in_group("forest") as Forest
	_to("idle")
	wait(2.0)


func _to(s: String) -> void:
	_state = s
	_since = 0.0


func _pile_stand() -> Vector3:
	return _cabin.global_transform * Vector3(PILE_STAND.x, 0.0, PILE_STAND.y)


func step(delta: float) -> bool:
	if _pile == null or _forest == null:
		return false
	_since += delta
	match _state:
		"idle":
			if waiting(delta):
				return true
			if r.pack.logs > 0:
				_to("haul")
			elif _pile.is_full():
				return false                       # nothing to do: the rest of the day is his own
			else:
				var near := _forest.standing_near(_pile_stand(), 30.0)
				if near.is_empty():
					return false
				_tree = near[randi() % mini(4, near.size())]
				var tp: Vector3 = _forest.trees[_tree].pos
				var dir := Hex.offset(tp, r.position)
				dir.y = 0.0
				dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
				_stand = tp + dir * (REACH + 0.2)
				_to("to_tree")
		"to_tree":
			var tp: Vector3 = _forest.trees[_tree].pos
			if not _forest.is_standing(_tree) or _since > 40.0:
				_to("idle")
			elif Hex.distance(r.position, tp) < REACH + 0.45 and not r.has_goal():
				r.stop()
				_to("chop")
				r.set_held("axe")
			elif not go(_stand):
				_to("idle")
				wait(1.0)
		"chop":
			r.face_toward(_forest.trees[_tree].pos)
			r.pose = "chop"
			if _since >= CHOP_TIME:
				r.pose = ""
				r.set_held("")
				_forest.fell(_tree, r.position)
				r.say("Timber!")
				_to("wait_fall")
		"wait_fall":
			if _since > 1.8:
				_to("collect")
		"collect":
			var tp: Vector3 = _forest.trees[_tree].pos
			if r.pack_room("logs") <= 0 or _since > 40.0:
				_to("haul")
				return true
			if _log == null or not is_instance_valid(_log):
				_log = _forest.log_near(tp, 4.5)
				if _log == null:
					_to("haul" if r.pack.logs > 0 else "idle")
					return true
			if Hex.distance(r.position, _log.position) < 0.75:
				_forest.take_log(_log)
				_log = null
				r.pack_add("logs")
				r.stop()
			elif not go(_log.position):
				_log = null
				_to("haul" if r.pack.logs > 0 else "idle")
		"haul":
			var ps := _pile_stand()
			if arrived(ps, 0.5):
				r.stop()
				_to("stack")
			elif not go(ps) or _since > 60.0:
				_to("stack")                       # can't get any nearer: stack from here
		"stack":
			r.face_toward(_cabin.global_transform * Vector3(3.9, 0.0, PILE_STAND.y))
			if _since >= 0.75:
				_since = 0.0
				if r.pack.logs > 0 and not _pile.is_full():
					r.pack_take("logs")
					_pile.count += 1
				else:
					say(STACKED)
					_to("idle")
					wait(randf_range(4.0, 9.0))
	return true
