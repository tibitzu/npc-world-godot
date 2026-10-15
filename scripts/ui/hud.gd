extends CanvasLayer
## The on-screen text and buttons: the title, the tile under the cursor, the clock (time of day
## where you are, its phase and the day), the speed bar, the residents (click a card to take
## control or let go), the controls hint, and while controlling, the view switch, Let go, and a
## warning before the resident takes themselves back. Bottom left, the town chatter: what residents
## near where you're looking have just said. While controlling, Enter opens a box to say something.

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
var _tip: PanelContainer
var _tip_xz: Label
var _tip_tile: Label
var _chatter: VBoxContainer
var _chat_lines: Array = []    # [Label, real time it was said]
var _say_box: LineEdit
var _hint: Label
var _hint_wait := 0.0
var _pack: PanelContainer
var _pack_title: Label
var _pack_slots := {}          # "logs"/"parcels" -> Array of ColorRect
var _pack_of: Resident = null

const CHATTER_LINES := 6
const CHATTER_FADE := 45.0     # real seconds a line stays in the chatter log


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
	_build_cursor_tip()
	_build_chatter()
	_build_say_box()
	_build_hint()
	_build_pack()
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


# a small tooltip by the mouse cursor: the world x and z (metres) of the ground under it, and its tile
func _build_cursor_tip() -> void:
	_tip = PanelContainer.new()
	_tip.name = "CursorTip"
	var sb := _panel_style()
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_tip.add_theme_stylebox_override("panel", sb)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(col)
	_tip_xz = Label.new()
	_tip_xz.add_theme_font_size_override("font_size", 15)
	_tip_xz.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	col.add_child(_tip_xz)
	_tip_tile = Label.new()
	_tip_tile.add_theme_font_size_override("font_size", 11)
	_tip_tile.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
	col.add_child(_tip_tile)


func _update_cursor_tip() -> void:
	var vp := get_viewport()
	var m := vp.get_mouse_position()
	var p = _rig.ground_point(m)
	if p == null or not vp.get_visible_rect().has_point(m):
		_tip.visible = false
		return
	var x := Hex.wrap_x(p.x)
	var z := Hex.wrap_z(p.z)
	var i := Hex.tile_at(x, z)
	_tip_xz.text = "x %.1f   z %.1f" % [x, z]
	_tip_tile.text = "tile %d, %d · %s" % [Hex.col_of(i), Hex.row_of(i), Game.tiles.kind(i)]
	_tip.visible = true
	_tip.reset_size()
	# beside the cursor, kept on screen
	var pos := m + Vector2(18, 18)
	var r := vp.get_visible_rect().size
	if pos.x + _tip.size.x > r.x:
		pos.x = m.x - 12 - _tip.size.x
	if pos.y + _tip.size.y > r.y:
		pos.y = m.y - 12 - _tip.size.y
	_tip.position = pos


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
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		res.spoke.connect(func(text: String) -> void: _on_spoke(res, text))
	_refresh()


func _refresh() -> void:
	var ctrl := _player.controlled
	for res in _cards:
		(_cards[res] as Button).set_pressed_no_signal(res == ctrl)
	_view_btn.visible = ctrl != null
	_let_go_btn.visible = ctrl != null
	_view_btn.text = "1st person" if _rig.third_person else "3rd person"
	if ctrl == null and _say_box and _say_box.visible:
		_close_say_box()
	if ctrl:
		_help.text = "You are %s. F does what's at hand · Enter to talk · W S walk (hold Left Shift to run) · A D step aside · Q E or drag to look · click a tile or floor to walk there · scroll or T switches view · P routes · Esc lets go" % ctrl.def.display_name
	else:
		_help.text = "Click a resident to take control · WASD / arrows move · Q E turn · drag to rotate · right-drag to pan · scroll to zoom · click to glide · [ ] game speed · V tiles · P routes"


func _process(_delta: float) -> void:
	_update_clock()
	_update_cursor_tip()
	_update_chatter()
	_update_hint(_delta)
	for res in _cards:
		var r := res as Resident
		var t := "%s · %s\n%s · sleeps %s–%s" % [r.def.display_name, r.def.role, r.status(),
			Game.clock_text(r.def.sleep_hour), Game.clock_text(r.def.wake_hour)]
		if (_cards[res] as Button).text != t:
			(_cards[res] as Button).text = t
	var ctrl := _player.controlled
	var left := _player.idle_left() if ctrl else 99.0
	_idle.visible = ctrl != null and left < 10.0
	if _idle.visible:
		_idle.text = "%s will carry on alone in %d s" % [ctrl.def.display_name, ceili(left)]


# ---------- the town chatter (bottom left) ----------

func _build_chatter() -> void:
	_chatter = VBoxContainer.new()
	_chatter.anchor_top = 1.0
	_chatter.anchor_bottom = 1.0
	_chatter.offset_left = 16.0
	_chatter.offset_right = 470.0
	_chatter.offset_top = -250.0
	_chatter.offset_bottom = -44.0
	_chatter.alignment = BoxContainer.ALIGNMENT_END
	_chatter.add_theme_constant_override("separation", 2)
	_chatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chatter)
	var title := Label.new()
	title.text = "TOWN CHATTER"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68, 0.8))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.visible = false
	_chatter.add_child(title)


# a resident said something: log it if it was within earshot of where you are (or are looking)
func _on_spoke(res: Resident, text: String) -> void:
	var ctrl := _player.controlled
	var near: bool
	if ctrl:
		near = res == ctrl or Hex.distance(res.position, ctrl.position) < 20.0
	else:
		near = Hex.distance(res.position, _rig.focus) < 20.0 + _rig.dist * 0.6
	if not near:
		return
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", 13)
	l.add_theme_color_override("default_color", Color(0.93, 0.91, 0.86, 0.95))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	var who := res.def.display_name + (" [color=#aaa49a](you)[/color]" if res == ctrl else "")
	var colour := Look.html_colour(res.def.colour).lightened(0.3).to_html(false)
	l.text = "[color=#%s]%s[/color]: %s" % [colour, who, text.replace("[", "[lb]")]
	_chatter.add_child(l)
	_chat_lines.append([l, Time.get_ticks_msec() / 1000.0])
	while _chat_lines.size() > CHATTER_LINES:
		(_chat_lines.pop_front()[0] as Node).queue_free()
	_chatter.get_child(0).visible = true


func _update_chatter() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not _chat_lines.is_empty() and now - _chat_lines[0][1] > CHATTER_FADE:
		(_chat_lines.pop_front()[0] as Node).queue_free()
	for e in _chat_lines:
		var age: float = now - e[1]
		(e[0] as Control).modulate.a = clampf((CHATTER_FADE - age) / 8.0, 0.0, 1.0)
	_chatter.get_child(0).visible = not _chat_lines.is_empty()


# ---------- saying something as the resident you're playing ----------

func _build_say_box() -> void:
	_say_box = LineEdit.new()
	_say_box.anchor_left = 0.5
	_say_box.anchor_right = 0.5
	_say_box.anchor_top = 1.0
	_say_box.anchor_bottom = 1.0
	_say_box.offset_left = -260.0
	_say_box.offset_right = 260.0
	_say_box.offset_top = -92.0
	_say_box.offset_bottom = -58.0
	_say_box.max_length = 120
	_say_box.visible = false
	var sb := _panel_style()
	_say_box.add_theme_stylebox_override("normal", sb)
	_say_box.add_theme_stylebox_override("focus", sb)
	add_child(_say_box)
	_say_box.text_submitted.connect(func(text: String) -> void:
		var t := text.strip_edges()
		var ctrl := _player.controlled
		if ctrl and not t.is_empty():
			ctrl.say(t)
			var conv := get_tree().get_first_node_in_group("conversations") as Conversations
			if conv:
				conv.player_spoke(ctrl, t)
			_player.touch()
		_close_say_box())
	_say_box.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
			_close_say_box()
			_say_box.accept_event())


func _open_say_box() -> void:
	var ctrl := _player.controlled
	_say_box.placeholder_text = "Say something as %s, then Enter (Esc to cancel)" % ctrl.def.display_name
	_say_box.text = ""
	_say_box.visible = true
	_say_box.grab_focus()
	Game.typing = true
	_player.touch()


func _close_say_box() -> void:
	_say_box.release_focus()
	_say_box.visible = false
	Game.typing = false


# ---------- what F does here, and what you're carrying ----------

func _build_hint() -> void:
	_hint = Label.new()
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -260.0
	_hint.offset_right = 260.0
	_hint.offset_top = -128.0
	_hint.offset_bottom = -100.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(1, 0.87, 0.6))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_font_size_override("font_size", 15)
	add_child(_hint)


func _update_hint(delta: float) -> void:
	_hint_wait -= Game.real_delta(delta)
	if _hint_wait > 0.0:
		return
	_hint_wait = 0.15
	var h := _player.action_hint() if not Game.typing else ""
	_hint.text = ("F · " + h) if h != "" and not h.ends_with("…") else h
	_hint.visible = h != ""
	var ctrl := _player.controlled
	if ctrl != _pack_of:
		if _pack_of and is_instance_valid(_pack_of) and _pack_of.packed.is_connected(_refresh_pack):
			_pack_of.packed.disconnect(_refresh_pack)
		_pack_of = ctrl
		if ctrl:
			ctrl.packed.connect(_refresh_pack)
		_refresh_pack()


func _build_pack() -> void:
	_pack = PanelContainer.new()
	_pack.add_theme_stylebox_override("panel", _panel_style())
	_pack.anchor_left = 1.0
	_pack.anchor_right = 1.0
	_pack.anchor_top = 1.0
	_pack.anchor_bottom = 1.0
	_pack.offset_left = -236.0
	_pack.offset_right = -16.0
	_pack.offset_top = -176.0
	_pack.offset_bottom = -94.0
	_pack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pack)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_pack.add_child(v)
	_pack_title = Label.new()
	_pack_title.add_theme_font_size_override("font_size", 13)
	_pack_title.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	v.add_child(_pack_title)
	for kind in ["logs", "parcels"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		v.add_child(row)
		var l := Label.new()
		l.text = kind.capitalize()
		l.custom_minimum_size = Vector2(64, 0)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
		row.add_child(l)
		var slots: Array = []
		for i in Resident.PACK_CAP[kind]:
			var c := ColorRect.new()
			c.custom_minimum_size = Vector2(26, 14)
			row.add_child(c)
			slots.append(c)
		_pack_slots[kind] = slots
	_pack.visible = false


func _refresh_pack() -> void:
	var r := _pack_of
	_pack.visible = r != null and is_instance_valid(r)
	if not _pack.visible:
		return
	_pack_title.text = "%s's pack" % r.def.display_name
	var full := {"logs": Look.html_hex(0x8a5a35), "parcels": Look.html_hex(0xc9a36a)}
	for kind in _pack_slots:
		var n: int = r.pack.get(kind, 0)
		var slots: Array = _pack_slots[kind]
		for i in slots.size():
			(slots[i] as ColorRect).color = full[kind] if i < n else Color(1, 1, 1, 0.1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat") and _player.controlled and not _say_box.visible:
		_open_say_box()
		get_viewport().set_input_as_handled()


func _on_hovered_tile(i: int, p: Vector3) -> void:
	if i < 0:
		_coords.text = ""
		return
	_coords.text = "tile %d, %d · %s · x %.1f  z %.1f" % [
		Hex.col_of(i), Hex.row_of(i), Game.tiles.kind(i), Hex.wrap_x(p.x), Hex.wrap_z(p.z)]
