extends Node
## Game-wide state every system can reach: the world seed, the tile grid, view settings, and
## the clock.
##
## The clock, as in the HTML game: one day lasts DAY_SECONDS of game time, and the sun crosses
## the flat map from east to west, so the time of day depends on where you are. When it is noon
## at the town square (x = 0) it is midnight half the map away. A new game starts at noon at the
## square on Day 1.
##
## Game speed (1x, 2x, 5x) runs everything faster, residents included, by scaling Godot's time;
## the camera and the player's turning keys use real time, so they feel the same at any speed.

signal speed_changed(speed: int)

const DAY_SECONDS := 120.0      # one full day, in game seconds at 1x (as in the HTML game)
const SPEEDS: Array[int] = [1, 2, 5]
const BASE_TICKS := 60          # physics steps per game second

var world_seed := 0
var tiles: TileGrid
var tiles_shown := false        # V: hex tiles on or off (off by default, as in the HTML game)
## Game seconds since the game began (runs faster at higher speeds).
var world_time := 0.0
## True while the player is typing something to say (keys then type, they don't move anyone).
var typing := false
var speed := 1


func _ready() -> void:
	world_seed = randi()
	tiles = TileGrid.new()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	world_time += delta          # delta is already scaled by the game speed


## Change the game speed (1, 2 or 5).
func set_speed(s: int) -> void:
	if not s in SPEEDS or s == speed:
		return
	speed = s
	Engine.time_scale = s
	# more physics steps per real second, so each step is still 1/60 of a game second
	Engine.physics_ticks_per_second = BASE_TICKS * s
	speed_changed.emit(s)


## Seconds of real time for a frame's delta (for things that shouldn't speed up: the camera).
static func real_delta(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.001)


# ---- the sun and the clock ----

## How far round the sun has gone (radians): 0 = noon at the town square.
func sun_lambda() -> float:
	return fposmod(world_time / DAY_SECONDS * TAU, TAU)


## How high the sun stands over an east-west position: 1 overhead, 0 on the horizon, below 0 at
## night. It repeats every map width, so it joins seamlessly at the seam.
func flat_sun(x: float) -> float:
	return cos(TAU * x / Hex.WRAP + sun_lambda())


## Local time (hours, 0 to 24) at an east-west position.
func local_hours(x: float) -> float:
	var th := fposmod(TAU * x / Hex.WRAP + sun_lambda(), TAU)
	return fposmod(12.0 + th / TAU * 24.0, 24.0)


## Which day it is at an east-west position: Day 1 when the game began, turning over at local midnight.
func day_number(x: float) -> int:
	var h := local_hours(x)
	var elapsed := world_time / DAY_SECONDS * 24.0          # hours since the game began
	var start := fposmod(h - elapsed, 24.0)                  # the local hour when the game began
	return 1 + floori((start + elapsed) / 24.0)


## Set the clock so that it is a given hour at the town square (for tests and screenshots).
func set_hour_at_square(h: float) -> void:
	world_time = fposmod(h - 12.0, 24.0) / 24.0 * DAY_SECONDS


static func phase_name(h: float) -> String:
	if h < 5.0: return "Night"
	if h < 7.0: return "Dawn"
	if h < 11.0: return "Morning"
	if h < 13.0: return "Midday"
	if h < 17.0: return "Afternoon"
	if h < 19.0: return "Dusk"
	if h < 21.0: return "Evening"
	return "Night"


static func clock_text(h: float) -> String:
	var m := floori(h * 60.0)
	return "%02d:%02d" % [m / 60 % 24, m % 60]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		# F11: fullscreen, or back to a maximised window
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_tiles"):
		tiles_shown = not tiles_shown
		Events.tiles_toggled.emit(tiles_shown)
		get_viewport().set_input_as_handled()
		return
	# [ and ]: slower and faster
	for dir in [-1, 1]:
		if event.is_action_pressed("speed_down" if dir < 0 else "speed_up"):
			var i := clampi(SPEEDS.find(speed) + dir, 0, SPEEDS.size() - 1)
			set_speed(SPEEDS[i])
			get_viewport().set_input_as_handled()
			return
