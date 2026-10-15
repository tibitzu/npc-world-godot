class_name FloatText
extends Label3D
## A number (a hit's damage) that pops up over someone's head, drifts up and fades.

var _t := 0.0


static func pop(parent: Node, at: Vector3, text: String, colour: Color) -> void:
	var f := FloatText.new()
	f.text = text
	f.modulate = colour
	f.outline_modulate = Color(0, 0, 0, 0.8)
	f.outline_size = 6
	f.font_size = 40
	f.pixel_size = 0.0007
	f.fixed_size = true
	f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.no_depth_test = true
	parent.add_child(f)
	f.global_position = at


func _process(delta: float) -> void:
	_t += Game.real_delta(delta)
	position.y += Game.real_delta(delta) * 0.9
	modulate.a = clampf(1.2 - _t, 0.0, 1.0)
	if _t > 1.2:
		queue_free()
