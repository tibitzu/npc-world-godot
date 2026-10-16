class_name LightBolt
extends MeshInstance3D
## A bolt of light from the wizard's staff: a glowing ball that flies to what it was aimed at and
## hurts it when it gets there (if it's still standing).

const SPEED := 14.0                # m/s

var target: Monster
var damage := 0
var by: Resident


## Throw one from a point at a monster.
static func throw(from: Vector3, at: Monster, dmg: int, thrower: Resident) -> void:
	var b := LightBolt.new()
	b.target = at
	b.damage = dmg
	b.by = thrower
	var m := StandardMaterial3D.new()
	m.albedo_color = Look.html_hex(0xe8e2ff)
	m.emission_enabled = true
	m.emission = Look.html_hex(0x9a8cff)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	s.radial_segments = 10
	s.rings = 5
	s.material = m
	b.mesh = s
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	thrower.get_parent().add_child(b)
	b.global_position = from


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var aim := target.global_position + Vector3.UP * 0.6
	var to := aim - global_position
	var step := SPEED * delta
	if to.length() <= step:
		target.hurt(damage, by if is_instance_valid(by) else null)
		queue_free()
		return
	global_position += to.normalized() * step
	scale = Vector3.ONE * (1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.03))
