class_name Door
extends Node3D
## A hinged door: this node is the hinge, and the leaf runs along its +X. It swings open
## (toward its -Z) when a resident comes within reach, and closes once nobody is near. Turn the
## node to hang the door in any wall.
##
## Its collider is on the "doors" layer, which residents bump into but the navigation bake
## ignores, so routes go straight through the doorway and the door gets out of the way.

@export var width := 0.9
## How far it swings open (radians).
@export var open_angle := 1.65
## How close (m) someone must be to the middle of the doorway for it to open.
@export var reach := 1.1

var is_open := false

var _closed_y := 0.0               # the door's turn when shut (it may be set in any direction)

@onready var _shape: CollisionShape3D = $Body/Shape


func _ready() -> void:
	_closed_y = rotation.y


func _physics_process(delta: float) -> void:
	var mid := global_transform * Vector3(width * 0.5, 0.0, 0.0)
	is_open = false
	for r in get_tree().get_nodes_in_group("residents"):
		var p := (r as Node3D).global_position
		if absf(p.y - mid.y) < 1.0 and Hex.distance(p, mid) < reach:
			is_open = true
			break
	var goal := _closed_y + (open_angle if is_open else 0.0)
	rotation.y += (goal - rotation.y) * minf(1.0, delta * 6.0)
	# once it's swinging open it stops blocking; it blocks again when shut
	_shape.disabled = rotation.y - _closed_y > 0.25
