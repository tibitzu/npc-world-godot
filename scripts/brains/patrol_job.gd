class_name PatrolJob
extends Job
## A guard's watch: round the town on foot, from the barracks along the east road, round the
## square's corners and back, stopping a moment at each point to look about (and now and then
## say something). Dax goes round one way by day; Dex the other way by night.

const LOOK_TIME := 2.5
## The round (world x, z): barracks yard, the east road's mouth, the square's corners.
const ROUND: Array[Vector2] = [Vector2(29.0, 8.2), Vector2(12.0, 10.3), Vector2(9.0, 0.8),
	Vector2(-9.0, 0.8), Vector2(-9.0, 17.0), Vector2(9.0, 17.0), Vector2(12.0, 10.3)]

var _route: Array[Vector2] = []
var _i := 0
var _state := "walk"


func label() -> String:
	return "On patrol"


func start() -> void:
	_route = ROUND.duplicate()
	if r.def.id == "dex":
		_route.reverse()
	# join the round at its nearest point
	var bd := INF
	for k in _route.size():
		var d := Hex.distance(r.position, Vector3(_route[k].x, 0.0, _route[k].y))
		if d < bd:
			bd = d
			_i = k
	_state = "walk"


func step(delta: float) -> bool:
	var w := Vector3(_route[_i].x, 0.0, _route[_i].y)
	match _state:
		"walk":
			if arrived(w, 0.6):
				r.stop()
				_state = "look"
				wait(LOOK_TIME)
				say(r.def.lines, 0.25)
			elif not go(w):
				_state = "look"
				wait(0.5)
		"look":
			if not waiting(delta):
				_i = (_i + 1) % _route.size()
				_state = "walk"
	return true
