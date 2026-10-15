extends Node3D
## The world scene's root: aims the sun and brings in the buildings from res://data/buildings
## and the residents from res://data/npcs.

const SUN_DIR := Vector3(0.45, 0.8, 0.3)     # toward the sun until the DayNight node takes over
const RESIDENT := preload("res://scenes/actors/resident.tscn")


func _ready() -> void:
	$Sun.look_at_from_position(SUN_DIR, Vector3.ZERO)
	var bdefs := Registry.all("buildings")
	bdefs.sort_custom(func(a: BuildingDef, b: BuildingDef) -> bool: return a.id < b.id)
	for d in bdefs:
		var b: Building = d.scene.instantiate()
		b.setup(d)
		$Buildings.add_child(b)
	Game.tiles.flush()
	var defs := Registry.all("npcs")
	defs.sort_custom(func(a: NpcDef, b: NpcDef) -> bool: return a.id < b.id)
	for d in defs:
		var r: Resident = RESIDENT.instantiate()
		r.setup(d)
		r.add_to_group("residents")
		$Residents.add_child(r)
