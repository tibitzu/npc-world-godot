extends CanvasLayer
## The on-screen text: the title, the tile under the cursor and the controls.

@onready var _title: Label = $Title
@onready var _coords: Label = $Coords
@onready var _help: Label = $Help


func _ready() -> void:
	_title.text = "npc-world · %d × %d hex tiles · %d m × %d m" % [
		Hex.COLS, Hex.ROWS, roundi(Hex.WRAP), roundi(Hex.WRAP_Z)]
	_help.text = "WASD / arrows move · Q E turn · drag to rotate · right-drag to pan · scroll to zoom · click to glide · V tiles"
	var rig := get_node_or_null("../CameraRig")
	if rig:
		rig.hovered_tile.connect(_on_hovered_tile)


func _on_hovered_tile(i: int, p: Vector3) -> void:
	if i < 0:
		_coords.text = ""
		return
	_coords.text = "tile %d, %d · %s · x %.1f  z %.1f" % [
		Hex.col_of(i), Hex.row_of(i), Game.tiles.kind(i), Hex.wrap_x(p.x), Hex.wrap_z(p.z)]
