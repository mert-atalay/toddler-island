extends SceneTree
## Renders the new animal candidates side by side, each scaled to the same height.
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var files := ["lion", "lion2", "elephant", "elephant2", "giraffe", "hippo", "rhino", "tiger", "bearcub", "penguin", "turtle", "Fox", "Wolf", "Alpaca", "Raccoon", "Panda", "CrabEnemy", "Frog", "Monkroose"]
	for i in files.size():
		var s: PackedScene = load("res://assets/animals/new/%s.glb" % files[i])
		var n := s.instantiate() as Node3D
		root.add_child(n)
		var ab := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var b := mi.global_transform * mi.get_aabb()
			ab = b if first else ab.merge(b)
			first = false
		var k := 1.0 / maxf(ab.size.y, 0.01)
		n.scale = Vector3.ONE * k
		var col := i % 7
		var row := i / 7
		n.position = Vector3(col * 1.6 - 4.8 - ab.get_center().x * k, -ab.position.y * k - row * 1.7, -ab.get_center().z * k)
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for a in ap.get_animation_list():
				if a.ends_with("Walk"):
					ap.play(a)
					break
		print(files[i], " size ", ab.size, " anim ", ap != null)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, -0.9, 9.0)
	cam.look_at(Vector3(0, -1.2, 0))
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
	for k in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
