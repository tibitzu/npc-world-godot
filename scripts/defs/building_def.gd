class_name BuildingDef
extends Resource
## One building placed on the map: which scene it is and where it stands.
## Add a building by adding a .tres of this type to res://data/buildings.

@export var id := ""
@export var display_name := ""
@export var scene: PackedScene
## Centre of the footprint (world x, z in metres).
@export var position := Vector2.ZERO
## Turn about the vertical (degrees); 0 has the door facing south (+Z).
@export var rotation := 0.0
