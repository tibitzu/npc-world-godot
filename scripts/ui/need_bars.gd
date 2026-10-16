class_name NeedBars
extends Control
## Little bars along the bottom of a resident's card: health, then fatigue, happiness, hunger and
## thirst (full is fine), in the HTML game's colours. Hover for the numbers.

const KEYS := ["health", "fatigue", "happiness", "hunger", "thirst"]
const NAMES := ["Health", "Fatigue", "Happiness", "Hunger", "Thirst"]
const COLOURS := [Color("#e05a4f"), Color("#b9a6f0"), Color("#f2c86b"), Color("#e59a6a"), Color("#7fc4e8")]

var resident: Resident
var _shown := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, 6)


func _process(_delta: float) -> void:
	if resident == null:
		return
	var now := [roundi(resident.hp / resident.hp_max() * 100.0)]
	for k in KEYS.slice(1):
		now.append(roundi(resident.needs[k]))
	if now != _shown:
		_shown = now
		tooltip_text = "Health %d/%d  " % [roundi(resident.hp), roundi(resident.hp_max())] + "  ".join(range(1, 5).map(func(i: int) -> String: return "%s %d" % [NAMES[i], now[i]]))
		queue_redraw()


func _draw() -> void:
	if _shown.is_empty():
		return
	var gap := 5.0
	var w := (size.x - gap * 4) / 5.0
	for i in 5:
		var x := i * (w + gap)
		draw_rect(Rect2(x, 0, w, size.y), Color(1, 1, 1, 0.12))
		var v: float = _shown[i] / 100.0
		var c: Color = COLOURS[i] if v > 0.25 else COLOURS[i].lerp(Color(0.95, 0.3, 0.25), 0.6)
		draw_rect(Rect2(x, 0, w * v, size.y), c)
