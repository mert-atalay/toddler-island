extends SceneTree
## Renders the wildlife candidates side by side to a picture.
const Models := preload("res://lib/models.gd")
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var files := ["cottontail", "rabbit3", "grayrabbit", "rabbit", "squirrel", "mallard", "duck2", "duckling", "seagull"]
	for i in files.size():
		var h := Models.spawn(root, "res://assets/animals/wild/%s.glb" % files[i], 0.5, 60.0)
		h.scale = Vector3.ONE * 2.0
		h.position = Vector3(i * 1.5 - 6.0, 0, 0)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.6, 8.5)
	cam.look_at(Vector3(0, 0.45, 0))
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
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
