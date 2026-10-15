class_name PlayerController
extends Node
## The local player: which resident they control (if any) and the keys that drive them.
## W/S walk, A/D step aside, Q/E or arrows turn, Left Shift runs, T switches view, Esc lets go,
## F lies down in the bed at hand (or gets up). After IDLE_LIMIT seconds without input the
## resident takes themselves back.
##
## B sends every resident nobody is playing to a free bed, or gets them all up again
## (until the clock and daily routines arrive in milestone 4).

signal control_changed(resident: Resident)

const IDLE_LIMIT := 30.0
const TURN_SPEED := 2.4            # rad/s with Q and E
const BED_REACH := 1.0             # how near the foot of a bed F works (m)

var controlled: Resident = null
var last_input := 0.0              # Game time of the last input while controlling


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func possess(r: Resident) -> void:
	if r == controlled or r == null:
		return
	if controlled:
		controlled.release()
	controlled = r
	r.take_over()
	last_input = now()
	control_changed.emit(r)


func let_go() -> void:
	if controlled == null:
		return
	var r := controlled
	controlled = null
	r.release()
	control_changed.emit(null)


## Walk the controlled resident to a point (a clicked tile) along the navigation mesh.
func walk_to(p: Vector3) -> void:
	if controlled:
		controlled.walk_to(p)
		touch()


## Turn the controlled resident with a mouse drag (pixels).
func look(dx: float) -> void:
	if controlled:
		controlled.heading -= dx * 0.006
		touch()


func touch() -> void:
	last_input = now()


func idle_left() -> float:
	return IDLE_LIMIT - (now() - last_input)


## The free bed whose foot is nearest the controlled resident, if within reach.
func bed_at_hand() -> Bed:
	if controlled == null:
		return null
	var best: Bed = null
	var bd := BED_REACH
	for b in get_tree().get_nodes_in_group("beds"):
		var bed := b as Bed
		var p := bed.stand_point()
		var d := Hex.distance(controlled.position, p)
		if d < bd and absf(p.y - controlled.position.y) < 0.6 and bed.is_free_for(controlled):
			best = bed
			bd = d
	return best


## B: everyone nobody is playing goes to bed; if any of them already are, they all get up.
func bedtime() -> void:
	var others: Array[Resident] = []
	for r in get_tree().get_nodes_in_group("residents"):
		if r != controlled:
			others.append(r)
	var any_abed := others.any(func(r: Resident) -> bool: return r.bed != null)
	for r in others:
		if any_abed:
			r.get_up()
		elif r.bed == null:
			var free := get_tree().get_nodes_in_group("beds").filter(func(b: Bed) -> bool: return b.occupant == null)
			free.sort_custom(func(a: Bed, b: Bed) -> bool:
				return Hex.distance(a.stand_point(), r.position) < Hex.distance(b.stand_point(), r.position))
			if not free.is_empty():
				r.go_to_bed(free[0])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("bedtime"):
		bedtime()
		get_viewport().set_input_as_handled()
		return
	if controlled == null:
		return
	if event.is_action_pressed("let_go"):
		let_go()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if controlled.is_lying() or bed_at_hand():
			controlled.toggle_bed(bed_at_hand())
			touch()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if controlled == null:
		return
	var f := Input.get_action_strength("walk_forward") - Input.get_action_strength("walk_back")
	var s := Input.get_action_strength("step_right") - Input.get_action_strength("step_left")
	var turn := Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")
	controlled.drive = Vector2(f, s)
	controlled.running = Input.is_action_pressed("run")
	if turn != 0.0:
		controlled.heading -= turn * Game.real_delta(delta) * TURN_SPEED   # turning keeps its real-time feel
	if f != 0.0 or s != 0.0 or turn != 0.0:
		touch()
	if idle_left() <= 0.0:
		let_go()
