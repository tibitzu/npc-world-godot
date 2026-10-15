class_name NeedBars
extends Control
## Four little bars along the bottom of a resident's card: fatigue, happiness, hunger and thirst
## (full is fine), in the HTML game's colours. Hover for the numbers.

const KEYS := ["fatigue", "happiness", "hunger", "thirst"]
const NAMES := ["Fatigue", "Happiness", "Hunger", "Thirst"]
const COLOURS := [Color("#b9a6f0"), Color("#f2c86b"), Color("#e59a6a"), Color("#7fc4e8")]

var resident: Resident
var _shown := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, 6)


func _process(_delta: float) -> void:
	if resident == null:
		return
	var now := []
	for k in KEYS:
		now.append(roundi(resident.needs[k]))
	if now != _shown:
		_shown = now
		tooltip_text = "  ".join(range(4).map(func(i: int) -> String: return "%s %d" % [NAMES[i], now[i]]))
		queue_redraw()


func _draw() -> void:
	if _shown.is_empty():
		return
	var gap := 5.0
	var w := (size.x - gap * 3) / 4.0
	for i in 4:
		var x := i * (w + gap)
		draw_rect(Rect2(x, 0, w, size.y), Color(1, 1, 1, 0.12))
		var v: float = _shown[i] / 100.0
		var c: Color = COLOURS[i] if v > 0.25 else COLOURS[i].lerp(Color(0.95, 0.3, 0.25), 0.6)
		draw_rect(Rect2(x, 0, w * v, size.y), c)
