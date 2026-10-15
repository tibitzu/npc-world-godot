class_name Bed
extends Node3D
## A bed a resident can lie on. Place this node at the middle of the mattress, on top of it,
## with its -Z pointing toward the head of the bed; the bed's meshes go underneath it.
## Residents walk to the foot of the bed (stand_point) and lie down from there.

@export var bed_name := "Bed"
## Length of the mattress (m).
@export var length := 1.35
## Height of the top of the mattress above the floor (m).
@export var mattress_height := 0.4

## The resident lying in it or on the way to it, if any.
var occupant: Resident = null


func _ready() -> void:
	add_to_group("beds")


func is_free_for(r: Resident) -> bool:
	return occupant == null or occupant == r or not is_instance_valid(occupant)


## Where a resident stands to get in or out: on the floor, a little past the foot.
func stand_point() -> Vector3:
	var p := global_transform * Vector3(0.0, 0.0, length * 0.5 + 0.32)
	p.y = global_position.y - mattress_height
	return p


## Direction from the foot of the bed to its head (level).
func head_dir() -> Vector3:
	var d := -global_basis.z
	d.y = 0.0
	return d.normalized()
