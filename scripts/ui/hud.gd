extends CanvasLayer
## The on-screen text and buttons: the title, the tile under the cursor, the clock (time of day
## where you are, its phase and the day), the speed bar, the residents (click a card to take
## control or let go), the controls hint, and while controlling, the view switch, Let go, and a
## warning before the resident takes themselves back.

@onready var _title: Label = $Title
@onready var _coords: Label = $Coords
@onready var _help: Label = $Help
@onready var _roster: VBoxContainer = $Roster
@onready var _view_btn: Button = $Buttons/View
@onready var _let_go_btn: Button = $Buttons/LetGo
@onready var _idle: Label = $Idle
@onready var _player: PlayerController = get_node("../Player")
@onready var _rig: CameraRig = get_node("../CameraRig")

var _cards := {}       # Resident -> Button
var _dial: ClockDial
var _time: Label
var _phase: Label
var _day: Label
var _speed_btns := {}  # speed -> Button
var _shown_minute := -1


func _ready() -> void:
	_title.text = "npc-world · %d × %d hex tiles · %d m × %d m" % [
		Hex.COLS, Hex.ROWS, roundi(Hex.WRAP), roundi(Hex.WRAP_Z)]
	_rig.hovered_tile.connect(_on_hovered_tile)
	_player.control_changed.connect(func(_r: Resident) -> void: _refresh())
	_rig.view_changed.connect(func(_t: bool) -> void: _refresh())
	_view_btn.pressed.connect(func() -> void: _rig.set_view(not _rig.third_person))
	_let_go_btn.pressed.connect(_player.let_go)
	_build_roster.call_deferred()      # the residents are added after the HUD is ready
	_build_clock()
	_build_speed_bar()
	Game.speed_changed.connect(func(_s: int) -> void: _refresh_speed())
	_idle.offset_top = 62.0
	_idle.offset_bottom = 86.0


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.72)
	sb.border_color = Color(0.95, 0.93, 0.86, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# the clock, under the title in the top left: the dial, the time, the phase and the day
func _build_clock() -> void:
	var panel := PanelContainer.new()
	panel.name = "Clock"
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(16, 66)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_dial = ClockDial.new()
	_dial.custom_minimum_size = Vector2(54, 54)
	row.add_child(_dial)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_time = Label.new()
	_time.add_theme_font_size_override("font_size", 26)
	_time.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	col.add_child(_time)
	_phase = Label.new()
	_phase.add_theme_font_size_override("font_size", 12)
	_phase.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	col.add_child(_phase)
	_day = Label.new()
	_day.add_theme_font_size_override("font_size", 11)
	_day.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
	col.add_child(_day)


# the speed bar, top centre: 1x, 2x, 5x for the whole world ([ and ] step through them)
func _build_speed_bar() -> void:
	var panel := PanelContainer.new()
	panel.name = "SpeedBar"
	var sb := _panel_style()
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 12
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	panel.add_child(row)
	var lab := Label.new()
	lab.text = "SPEED"
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lab)
	for sp in Game.SPEEDS:
		var b := Button.new()
		b.text = "%d×" % sp
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(42, 0)
		b.pressed.connect(func() -> void:
			Game.set_speed(sp)
			_refresh_speed())
		row.add_child(b)
		_speed_btns[sp] = b
	_refresh_speed()


func _refresh_speed() -> void:
	for sp in _speed_btns:
		(_speed_btns[sp] as Button).set_pressed_no_signal(sp == Game.speed)


func _update_clock() -> void:
	var x := _player.controlled.position.x if _player.controlled else _rig.focus.x
	var h := Game.local_hours(x)
	var minute := floori(h * 60.0)
	if minute == _shown_minute:
		return
	_shown_minute = minute
	_time.text = Game.clock_text(h)
	_phase.text = Game.phase_name(h).to_upper()
	_day.text = "LOCAL TIME · DAY %d" % Game.day_number(x)
	_dial.hours = h


func _build_roster() -> void:
	for r in get_tree().get_nodes_in_group("residents"):
		var res := r as Resident
		var b := Button.new()
		b.text = "%s · %s" % [res.def.display_name, res.def.role]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", Look.html_colour(res.def.colour).lightened(0.3))
		b.pressed.connect(func() -> void:
			if _player.controlled == res:
				_player.let_go()
			else:
				_player.possess(res))
		_roster.add_child(b)
		_cards[res] = b
	_refresh()


func _refresh() -> void:
	var ctrl := _player.controlled
	for res in _cards:
		(_cards[res] as Button).set_pressed_no_signal(res == ctrl)
	_view_btn.visible = ctrl != null
	_let_go_btn.visible = ctrl != null
	_view_btn.text = "1st person" if _rig.third_person else "3rd person"
	if ctrl:
		_help.text = "You are %s. W S walk (hold Left Shift to run) · A D step aside · Q E or drag to look · click a tile or floor to walk there · F lies down in a bed or gets up · scroll or T switches view · B bedtime for the others · P routes · Esc lets go" % ctrl.def.display_name
	else:
		_help.text = "Click a resident to take control · WASD / arrows move · Q E turn · drag to rotate · right-drag to pan · scroll to zoom · click to glide · B bedtime · [ ] game speed · V tiles · P routes"


func _process(_delta: float) -> void:
	_update_clock()
	var ctrl := _player.controlled
	var left := _player.idle_left() if ctrl else 99.0
	_idle.visible = ctrl != null and left < 10.0
	if _idle.visible:
		_idle.text = "%s will carry on alone in %d s" % [ctrl.def.display_name, ceili(left)]


func _on_hovered_tile(i: int, p: Vector3) -> void:
	if i < 0:
		_coords.text = ""
		return
	_coords.text = "tile %d, %d · %s · x %.1f  z %.1f" % [
		Hex.col_of(i), Hex.row_of(i), Game.tiles.kind(i), Hex.wrap_x(p.x), Hex.wrap_z(p.z)]
