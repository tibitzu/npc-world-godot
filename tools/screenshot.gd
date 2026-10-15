extends Node
## Renders the world and saves a screenshot, for checking changes without opening the editor:
## godot --path . res://tools/screenshot.tscn -- out.png [frames] [yaw pitch dist x z] [hex]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shot.png"
	var frames := int(args[1]) if args.size() > 1 else 30
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	var rig := world.get_node("CameraRig")
	if args.size() > 6:
		rig.yaw = float(args[2])
		rig.pitch = float(args[3])
		rig.dist = float(args[4])
		rig.goal = Vector3(float(args[5]), 0, float(args[6]))
		rig.focus = rig.goal
	if args.size() > 7 and args[7] == "hex":
		Game.tiles_shown = true
		Events.tiles_toggled.emit(true)
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
