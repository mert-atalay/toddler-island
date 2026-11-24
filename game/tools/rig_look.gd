extends SceneTree
## Renders the rigged animals playing one clip, at a chosen time: rig_look.gd -- out.png Walk 0.25
const Models := preload("res://lib/models.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var clip := args[1] if args.size() > 1 else "Walk"
	var at := float(args[2]) if args.size() > 2 else 0.25
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var files := ["lion", "elephant", "giraffe", "hippo", "rhino", "tiger", "bearcub"]
	var heights := [1.2, 2.6, 4.0, 1.5, 1.6, 1.1, 0.9]
	if args.size() > 5 and args[5] == "small":
		files = ["../wild/squirrel", "../wild/grayrabbit", "CrabEnemy", "../../kits/extra/crab", "Raccoon", "Fox", "owl"]
		heights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	for i in files.size():
		var h := Models.spawn(root, "res://assets/animals/new/%s.glb" % files[i], heights[i], 0.0)
		h.position = Vector3(i * 3.2 - 9.6, 0, 0)
		h.rotation_degrees.y = 90.0
		var ap := h.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			ap.play(clip)
			ap.seek(at, true)
			ap.pause()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(float(args[3]) if args.size() > 3 else 0.0, 2.0, float(args[4]) if args.size() > 4 else 15.0)
	cam.look_at(Vector3(cam.position.x, 1.1, 0))
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(l)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.8, 0.85, 0.9)
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(args[0])
	quit()
