class_name PlayerController
extends Node
## The local player: which resident they control (if any) and the keys that drive them.
## W/S walk, A/D step aside, Q/E or arrows turn, Left Shift runs, T switches view, Esc lets go.
## After IDLE_LIMIT seconds without input the resident takes themselves back.

signal control_changed(resident: Resident)

const IDLE_LIMIT := 30.0
const TURN_SPEED := 2.4            # rad/s with Q and E

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


func _unhandled_input(event: InputEvent) -> void:
	if controlled == null:
		return
	if event.is_action_pressed("let_go"):
		let_go()
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
		controlled.heading -= turn * delta * TURN_SPEED
	if f != 0.0 or s != 0.0 or turn != 0.0:
		touch()
	if idle_left() <= 0.0:
		let_go()
