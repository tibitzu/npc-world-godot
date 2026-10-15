extends Node3D
## Makes a fire or a candle flicker: its flame meshes stretch and sway, and its light (if it has
## one) wavers, as in the HTML game.

## A candle flame: faster and smaller.
@export var small := false

var _flames: Array[MeshInstance3D] = []
var _base: Array[Vector3] = []
var _light: OmniLight3D
var _energy := 1.0
var _seed := 0.0


func _ready() -> void:
	_seed = randf() * 10.0
	for c in get_children():
		if c is MeshInstance3D and c.name.begins_with("Flame"):
			_flames.append(c)
			_base.append(c.position)
		elif c is OmniLight3D:
			_light = c
			_energy = _light.light_energy


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in _flames.size():
		var f := _flames[i]
		var u := _seed + i * 1.7
		var s := 0.75 + 0.35 * absf(sin(now * (9.0 if small else 11.0) + u)) + 0.1 * sin(now * 23.0 + u * 2.0)
		f.scale = Vector3(1.0 + 0.08 * sin(now * 13.0 + u), s, 1.0)
		var h := (f.mesh as CylinderMesh).height
		# keep the flame's foot on the logs while it stretches
		f.position = Vector3(_base[i].x, _base[i].y - h * 0.5 + h * s * 0.5, _base[i].z)
	if _light:
		_light.light_energy = _energy * (1.0 + 0.24 * sin(now * 12.0) * sin(now * 7.3 + 1.0) + 0.1 * sin(now * 29.0))
