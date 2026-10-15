extends Node
## Game-wide state every system can reach: the world seed, the tile grid and view settings.
## The clock, day counter and game speed join here in milestone 4.

var world_seed := 0
var tiles: TileGrid
var tiles_shown := false        # V: hex tiles on or off (off by default, as in the HTML game)


func _ready() -> void:
	world_seed = randi()
	tiles = TileGrid.new()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tiles"):
		tiles_shown = not tiles_shown
		Events.tiles_toggled.emit(tiles_shown)
		get_viewport().set_input_as_handled()
