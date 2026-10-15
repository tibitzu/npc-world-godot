class_name TownSquare
extends MeshInstance3D
## The town square: a square of grey cobblestones laid over the open ground. The tiles under it
## are marked as paved square (shown in the top left); they keep their moss colour, so the
## ground's soft blending doesn't spill grey past the square's edge.

## Centre of the square (world x, z in metres).
@export var centre := Vector2(0.0, 5.825)
## Length of each side (m).
@export var size := 14.85

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mesh = plane
	position = Vector3(centre.x, 0.006, centre.y)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/cobbles.gdshader")
	mat.set_shader_parameter("size", size)
	material_override = mat
	var r := Rect2(centre - Vector2(size, size) * 0.5, Vector2(size, size))
	for i in Hex.tiles_in(r):
		Game.tiles.set_flag(i, TileGrid.F_ROAD)
		Game.tiles.set_kind(i, "square")
