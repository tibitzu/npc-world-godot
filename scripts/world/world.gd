extends Node3D
## The world scene's root. For now it only aims the sun; the town, residents and
## everything else are added here as the milestones go on.

const SUN_DIR := Vector3(0.45, 0.8, 0.3)     # toward the sun, as in the HTML game's daytime


func _ready() -> void:
	$Sun.look_at_from_position(SUN_DIR, Vector3.ZERO)
