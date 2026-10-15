extends Node
## Day and night, as in the HTML game. Every frame it looks at the time of day where you are
## (the resident you're playing, or the spot the camera is looking at) and sets:
##
## - the sun's strength and colour: full and white by day, warm and low at dawn and dusk, gone at night
## - the sky light: down to 30% at night, so the world is dim but not black
## - the sun's direction: it swings from east to west through the town square's day
##   (kept above the horizon, so shadows always fall)
## - building lamps (brighter after dark) and lit windows (glowing at dusk and night);
##   fires burn the same day and night
##
## Changes are eased, so walking or gliding a long way never makes the light jump.

const SUN_TILT_Z := 0.3            # the sun stands a little to the south, as the original fixed sun did

var _d := 1.0                      # sunlight where you are (eased): 1 overhead, < 0 at night
var _e := 0.0                      # how far east the sun leans over the square (eased)
var _rd := 1.0                     # sun height over the square (eased)
var _primed := false

var _sun_energy := 1.0
var _sun_day := Color.WHITE
var _sun_warm := Look.html_hex(0xff9a5a)
var _ambient := 1.0
var _lamps: Array[Dictionary] = []          # { light, base }
var _glows: Array[Dictionary] = []          # { mat, base }

@onready var sun: DirectionalLight3D = get_node("../Sun")
@onready var env: Environment = (get_node("../WorldEnvironment") as WorldEnvironment).environment
@onready var player: PlayerController = get_node("../Player")
@onready var rig: CameraRig = get_node("../CameraRig")


func _ready() -> void:
	_sun_energy = sun.light_energy
	_sun_day = sun.light_color
	_ambient = env.ambient_light_energy
	_collect.call_deferred()            # the buildings are added in the world's _ready


# the lamps and glowing windows of every building (a fire's light is left to its flicker)
func _collect() -> void:
	var seen := {}
	for b in get_tree().get_nodes_in_group("buildings"):
		for l in (b as Node).find_children("*", "OmniLight3D", true, false):
			var parent_script: Script = l.get_parent().get_script()
			if parent_script and parent_script.resource_path.ends_with("flicker.gd"):
				continue
			_lamps.append({"light": l, "base": (l as OmniLight3D).light_energy})
		for m in (b as Node).find_children("*", "MeshInstance3D", true, false):
			var mesh := (m as MeshInstance3D).mesh
			if mesh == null:
				continue
			var mat := mesh.surface_get_material(0) as StandardMaterial3D
			if mat and mat.emission_enabled and mat.resource_name == "glow" and not seen.has(mat):
				seen[mat] = true
				_glows.append({"mat": mat, "base": mat.emission_energy_multiplier})


static func smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


func focus_x() -> float:
	return player.controlled.position.x if player.controlled else rig.focus.x


func _process(delta: float) -> void:
	var real := Game.real_delta(delta)
	var lam := Game.sun_lambda()
	var d := Game.flat_sun(focus_x())
	var e := sin(-lam)
	var rd := Game.flat_sun(0.0)
	var k := 1.0 if not _primed else minf(1.0, real * 2.0)
	_primed = true
	_d += (d - _d) * k
	_e += (e - _e) * k
	_rd += (rd - _rd) * k

	var lit := smooth(-0.12, 0.22, _d)                 # how much sunlight reaches here
	sun.light_energy = _sun_energy * lit
	sun.visible = lit > 0.001
	sun.light_color = _sun_warm.lerp(_sun_day, smooth(0.08, 0.5, maxf(_d, 0.3)))
	env.ambient_light_energy = _ambient * lerpf(0.3, 1.0, lit)

	# one direction for the whole map, from the square's time of day
	var dir := Vector3(_e, maxf(0.3, _rd), SUN_TILT_Z).normalized()
	sun.look_at_from_position(dir, Vector3.ZERO, Vector3.UP)

	# lamps brighten as their own spot gets dark; windows glow at dusk and through the night
	for o in _lamps:
		var l: OmniLight3D = o.light
		if not is_instance_valid(l):
			continue
		var here := smooth(-0.12, 0.22, Game.flat_sun(l.global_position.x))
		l.light_energy = o.base * (1.0 + 0.8 * (1.0 - here))
	var night := 1.0 - smooth(-0.15, 0.1, _d)
	var dusk := smooth(-0.15, 0.08, _d) * (1.0 - smooth(0.12, 0.45, _d))
	var glow := maxf(night, dusk)
	for o in _glows:
		(o.mat as StandardMaterial3D).emission_energy_multiplier = o.base * (1.0 + 0.6 * glow)
