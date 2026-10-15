extends MeshInstance3D
## The ground plane. It stays centred under the camera, and its shader folds every
## point back onto the map, so the world wraps with no seam and no copies to manage.

@export var size := 700.0


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("tiles", Game.tiles.texture)
	material_override = mat
	Events.tiles_toggled.connect(func(on: bool) -> void: mat.set_shader_parameter("show_hex", on))


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		# whole metres, so the plane's own edges never creep
		position = Vector3(roundf(cam.global_position.x), 0.0, roundf(cam.global_position.z))
