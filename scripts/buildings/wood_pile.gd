class_name WoodPile
extends Node3D
## A stack of split logs on sleepers beside a wall (Brann's, at Timber Hollow). It shows as many
## logs as it holds, in rows along the node's Z, each log lying across them (along X). The fire
## burns one now and then; Brann brings more.

## How many logs it holds now, and at most.
@export var count := 10:
	set(v):
		count = clampi(v, 0, capacity)
		_show()
@export var capacity := 30
## A log burns every so many game seconds (the cabin's oven), while there are any.
@export var burn_every := 30.0

const ROW := [13, 10, 7]           # logs in each layer, bottom up
const GAP := 0.2                   # between logs in a row (m)
const R := 0.095                   # a log's radius

var _logs: Array[MeshInstance3D] = []
var _burn := 0.0


func _ready() -> void:
	add_to_group("wood_piles")
	var mesh := CylinderMesh.new()
	mesh.top_radius = R
	mesh.bottom_radius = R
	mesh.height = 0.85
	mesh.radial_segments = 8
	mesh.rings = 1
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Look.html_hex(0x5e3d24)
	bark.roughness = 0.95
	mesh.material = bark
	for layer in ROW.size():
		var n: int = ROW[layer]
		for i in n:
			var m := MeshInstance3D.new()
			m.mesh = mesh
			m.position = Vector3(0.0, R + layer * R * 1.75, (i - (n - 1) * 0.5) * GAP)
			m.rotation = Vector3(0.0, 0.0, PI / 2)
			add_child(m)
			_logs.append(m)
	capacity = mini(capacity, _logs.size())
	_show()


func _process(delta: float) -> void:
	if count > 0:
		_burn += delta
		if _burn >= burn_every:
			_burn = 0.0
			count -= 1


func is_full() -> bool:
	return count >= capacity


func _show() -> void:
	for i in _logs.size():
		_logs[i].visible = i < count
