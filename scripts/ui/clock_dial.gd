class_name ClockDial
extends Control
## The 24-hour dial from the HTML game: day on the top half (06:00 to 18:00 through noon at the
## top), night below, a tick every hour (longer every six), and a hand ending in a sun by day or
## a crescent moon by night.

var hours := 12.0:
	set(v):
		hours = v
		queue_redraw()

const DAY := Color("#4b6a8c")
const NIGHT := Color("#121a2e")
const INK := Color("#f3ecdc")
const SUN := Color("#ffcf5c")
const MOON := Color("#d9e2f2")


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	# halves: angles in Godot run clockwise from +x; the top half is PI..TAU
	draw_circle(c, r, NIGHT)
	var top := PackedVector2Array([c])
	for i in 33:
		var a := PI + PI * i / 32.0
		top.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(top, DAY)
	draw_arc(c, r, 0.0, TAU, 48, Color(INK, 0.35), 1.5, true)
	for k in 24:
		var a := (k - 12) / 24.0 * TAU
		var len := 6.0 if k % 6 == 0 else 3.0
		var dir := Vector2(sin(a), -cos(a))
		draw_line(c + dir * (r - 1.0), c + dir * (r - 1.0 - len), Color(INK, 0.75), 1.0, true)
	var a := (hours - 12.0) / 24.0 * TAU
	var dir := Vector2(sin(a), -cos(a))
	var is_day := hours >= 6.0 and hours < 18.0
	draw_line(c, c + dir * (r - 10.0), INK, 2.0, true)
	var tip := c + dir * (r - 8.0)
	draw_circle(tip, 5.0, SUN if is_day else MOON)
	if not is_day:
		draw_circle(tip + Vector2(2.2, -1.5), 4.3, NIGHT)     # a crescent moon
	draw_circle(c, 2.2, INK)
