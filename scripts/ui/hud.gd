extends CanvasLayer
## The on-screen text and buttons: the title, the tile under the cursor, the residents
## (click a card to take control or let go), the controls hint, and while controlling,
## the view switch, Let go, and a warning before the resident takes themselves back.

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


func _ready() -> void:
	_title.text = "npc-world · %d × %d hex tiles · %d m × %d m" % [
		Hex.COLS, Hex.ROWS, roundi(Hex.WRAP), roundi(Hex.WRAP_Z)]
	_rig.hovered_tile.connect(_on_hovered_tile)
	_player.control_changed.connect(func(_r: Resident) -> void: _refresh())
	_rig.view_changed.connect(func(_t: bool) -> void: _refresh())
	_view_btn.pressed.connect(func() -> void: _rig.set_view(not _rig.third_person))
	_let_go_btn.pressed.connect(_player.let_go)
	_build_roster.call_deferred()      # the residents are added after the HUD is ready


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
		_help.text = "You are %s. W S walk (hold Left Shift to run) · A D step aside · Q E or drag to look · click a tile to walk there · scroll or T switches view · P shows routes · Esc lets go" % ctrl.def.display_name
	else:
		_help.text = "Click a resident to take control · WASD / arrows move · Q E turn · drag to rotate · right-drag to pan · scroll to zoom · click to glide · V tiles · P routes"


func _process(_delta: float) -> void:
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
