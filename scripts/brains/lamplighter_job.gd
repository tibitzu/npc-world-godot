class_name LamplighterJob
extends Job
## Old Fen's evening round: from late afternoon he takes his lighting pole out to the street
## lamps and lights them one by one, nearest first, then goes about his night. (They gutter out
## on their own at dawn: see LampPosts.)

const LIGHT_TIME := 1.6
const LINES := ["There. Let there be light.", "One more lit.", "Burn bright, little lamp.", "Hm. That one's always stubborn."]

var _lamps: LampPosts
var _i := -1
var _state := "walk"


func label() -> String:
	return "Lighting the lamps"


func start() -> void:
	_lamps = r.get_tree().get_first_node_in_group("lamp_posts") as LampPosts
	_i = -1
	_state = "walk"


## On duty in his working hours while any lamp still wants lighting.
func on_duty(h: float) -> bool:
	return super.on_duty(h) and _lamps_left()


func _lamps_left() -> bool:
	if _lamps == null:
		_lamps = r.get_tree().get_first_node_in_group("lamp_posts") as LampPosts
	return _lamps != null and _lamps.any_unlit()


func step(delta: float) -> bool:
	r.set_held("pole")
	if _i < 0 or _lamps.lamps[_i].lit:
		_i = _lamps.nearest_unlit(r.position)
		_state = "walk"
		if _i < 0:
			return false
	var lp: Vector3 = _lamps.lamps[_i].pos
	match _state:
		"walk":
			var dir := Hex.offset(lp, r.position)
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
			var stand := lp + dir * 0.85
			if Hex.distance(r.position, lp) < 1.2 and not r.has_goal():
				r.stop()
				_state = "light"
				wait(LIGHT_TIME)
			elif not go(stand):
				_state = "light"
				wait(LIGHT_TIME)
		"light":
			r.face_toward(lp)
			r.pose = "light"
			if not waiting(delta):
				r.pose = ""
				_lamps.set_lit(_i, true)
				say(LINES, 0.35)
				_i = -1
	return true
