class_name PostJob
extends Job
## Bolt's rounds: collect the post from the pillar box outside Bolt Post (two parcels, in his
## arms: his pack), carry it to two of the town's letterboxes, post it, and run back for more.

const DELIVERED := ["Post!", "Delivered. Next!", "One for {house}.", "Signed, sealed, delivered.", "Mail's in."]
const FAR := 60.0                      # letterboxes further than this from the post office come up less often

var _office: Building
var _pillar: Node3D
var _boxes: Array[Dictionary] = []     # {node: Node3D, house: String}
var _round: Array[Dictionary] = []
var _state := "to_office"


func label() -> String:
	return "Delivering the post"


func start() -> void:
	_office = building("PostOffice")
	_pillar = _office.find_child("PillarBox", true, false) as Node3D if _office else null
	_boxes.clear()
	for b in r.get_tree().get_nodes_in_group("buildings"):
		var bld := b as Building
		if bld == _office:
			continue
		for n in bld.find_children("Letterbox*", "Node3D", true, false):
			_boxes.append({"node": n, "house": bld.def.display_name if bld.def else String(bld.name)})
	_round.clear()
	if r.pack.parcels > 0:
		_pick_round(r.pack.parcels)          # still has post from before: deliver it first
		_state = "deliver"
	else:
		_state = "to_office"


# where to stand to use a box: in front of its slot (the box's +Z)
func _front(n: Node3D, d := 0.75) -> Vector3:
	var f := n.global_transform.basis.z
	f.y = 0.0
	return n.global_position + f.normalized() * d


func _pillar_front() -> Vector3:
	# the pillar box stands by the square in front of the post office: stand on the square side
	var f := _office.global_transform.basis.z
	return _pillar.global_position + f.normalized() * 0.7


func step(delta: float) -> bool:
	if _pillar == null or _boxes.is_empty():
		return false
	match _state:
		"to_office":
			var p := _pillar_front()
			if arrived(p, 0.45):
				r.stop()
				_state = "collect"
				wait(1.5)
			elif not go(p):
				_state = "collect"
				wait(1.5)
		"collect":
			r.face_toward(_pillar.global_position)
			if not waiting(delta):
				r.pack_add("parcels", r.pack_room("parcels"))
				_pick_round(r.pack.parcels)
				_state = "deliver"
		"deliver":
			if _round.is_empty() or r.pack.parcels <= 0:
				_round.clear()
				_state = "to_office"
				return true
			var box: Dictionary = _round[0]
			var p := _front(box.node)
			if arrived(p, 0.45):
				r.stop()
				_state = "posting"
				wait(1.2)
			elif not go(p):
				_round.pop_front()               # can't get to that one today
		"posting":
			var box: Dictionary = _round[0]
			r.face_toward(box.node.global_position)
			if not waiting(delta):
				_round.pop_front()
				r.pack_take("parcels")
				say(DELIVERED.map(func(s: String) -> String: return s.replace("{house}", box.house)), 0.5)
				_state = "deliver"
	return true


# different letterboxes, one per parcel, the far-flung ones less often
func _pick_round(n: int) -> void:
	_round.clear()
	var pool := _boxes.duplicate()
	while _round.size() < n and not pool.is_empty():
		var weights: Array[float] = []
		var total := 0.0
		for b in pool:
			var w := 1.0 if Hex.distance((b.node as Node3D).global_position, _pillar.global_position) < FAR else 0.25
			weights.append(w)
			total += w
		var x := randf() * total
		for i in pool.size():
			x -= weights[i]
			if x <= 0.0 or i == pool.size() - 1:
				_round.append(pool[i])
				pool.remove_at(i)
				break
