extends Node3D
## The island's small life: birds that loop over the trees and land on the grass, bees round the
## hives and the garden, dragonflies over the pond, frogs on the pond's edge that hop when she
## comes close, crabs scuttling sideways on the beach, fish that jump out of the pond now and then,
## and fireflies over the wood and the pond at dusk. Frogs and crabs answer her button too.

const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const EX := "res://assets/kits/extra/"

var corner: Node3D
var life: Node3D
var explorer: Node3D
var birds: Array = []      # [node, centre, radius, height, speed, phase, landed_t]
var bees: Array = []       # [node, centre, phase]
var flies: Array = []      # dragonflies: [node, phase]
var frogs: Array = []      # [node, home, cool]
var crabs: Array = []      # [node, home, phase]
var _fish_t := 6.0
var _fireflies: GPUParticles3D
var _firefly_mat: StandardMaterial3D
var _t := 0.0


func setup(c: Node3D) -> void:
	corner = c
	life = c.life
	explorer = c.explorer
	_birds()
	_bees()
	_dragonflies()
	_frogs()
	_crabs()
	_fireflies_build()


func _unlit(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _birds() -> void:
	var spots := [Terrain.OAK, Terrain.ORCHARD, Terrain.HILL + Vector2(6, 8), Terrain.COTTAGE + Vector2(-8, 4), Vector2(20, 20)]
	for k in 7:
		var b := Models.spawn(self, EX + "bird.glb", 0.28, 0.0)
		if b == null:
			return
		var centre: Vector2 = spots[k % spots.size()]
		birds.append([b, centre, randf_range(6.0, 12.0), randf_range(7.0, 12.0), randf_range(0.35, 0.6) * (1 if k % 2 else -1), randf() * TAU, 0.0])


func _bees() -> void:
	var spots := [Terrain.ORCHARD + Vector2(10.5, -3.0), Terrain.COTTAGE + Vector2(-6.8, 0.6), Terrain.COTTAGE + Vector2(0, -3.6)]
	for k in 9:
		var bee := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.035
		s.height = 0.06
		s.radial_segments = 6
		s.rings = 3
		bee.mesh = s
		bee.material_override = _unlit(Color(1.0, 0.82, 0.15))
		add_child(bee)
		var c: Vector2 = spots[k % spots.size()]
		bees.append([bee, Vector3(c.x, Terrain.height(c.x, c.y) + 0.9, c.y), randf() * TAU])


func _dragonflies() -> void:
	for k in 4:
		var d := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02, 0.02, 0.14)
		body.mesh = bm
		body.material_override = _unlit(Color(0.2, 0.55, 0.85))
		d.add_child(body)
		for side in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(0.16, 0.003, 0.04)
			w.mesh = wm
			var m := _unlit(Color(0.85, 0.95, 1.0, 0.45))
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			w.material_override = m
			w.position = Vector3(side * 0.08, 0.01, 0.01)
			d.add_child(w)
		add_child(d)
		flies.append([d, randf() * TAU])


func _frogs() -> void:
	var p := Terrain.POND
	for k in 4:
		var a := 0.6 + k * 1.4
		var home := Vector2(p.x + cos(a) * 9.6, p.y + sin(a) * 9.6)
		var f := Models.spawn(self, "res://assets/animals/new/Frog.glb", 0.17, rad_to_deg(-a) + 90.0)
		if f == null:
			return
		var fap := f.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if fap:
			for an in fap.get_animation_list():
				if String(an).ends_with("Idle"):
					fap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
					fap.play(an)
					fap.seek(randf() * 2.0, true)
		f.position = Vector3(home.x, Terrain.height(home.x, home.y), home.y)
		frogs.append([f, home, 0.0])
		life.interact.register({"name": "frog", "reach": 1.6, "priority": 0.3, "sparkle_height": 0.3, "label": "Say hi to the frog", "icon": EX + "frog.glb",
			"pos": func() -> Vector3: return f.global_position,
			"act": func() -> String:
				_hop(f, 1.0)
				life.sound.play_flat(life.sound.pop, -6.0)
				if life.stickers:
					if not life.stickers.earned.has("frog"):
						life.stickers.earn("frog")
					else:
						life.stickers._say_later("Frog!", 0.2)
				return "stroked frog"})


func _crabs() -> void:
	for k in 3:
		var home := _sand(Terrain.LIGHTHOUSE + Vector2(-6.0 - k * 5.0, 6.0 + k * 2.0))
		# the animated crab (Quaternius): walks sideways, and dances when she says hi
		var c := Models.spawn(self, "res://assets/animals/new/CrabEnemy.glb", 0.24, 0.0)
		if c == null:
			return
		c.position = Vector3(home.x, Terrain.height(home.x, home.y), home.y)
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for s in m.mesh.get_surface_count():
				var base := m.get_active_material(s) as BaseMaterial3D
				if base and base.albedo_color.get_luminance() < 0.12:
					var warm := base.duplicate() as BaseMaterial3D
					warm.albedo_color = Color(0.93, 0.42, 0.22)
					m.set_surface_override_material(s, warm)
		var ap := c.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clips := {}
		if ap:
			for an in ap.get_animation_list():
				clips[String(an).get_slice("|", String(an).get_slice_count("|") - 1)] = an
			for k2 in ["Walk", "Idle"]:
				if clips.has(k2):
					ap.get_animation(clips[k2]).loop_mode = Animation.LOOP_LINEAR
		crabs.append([c, home, randf() * TAU, 0.0, ap, clips])
		life.interact.register({"name": "crab", "reach": 1.6, "priority": 0.3, "sparkle_height": 0.3, "label": "Say hi to the crab", "icon": EX + "crab.glb",
			"pos": func() -> Vector3: return c.global_position,
			"act": func() -> String:
				for cr in crabs:
					if cr[0] == c:
						cr[3] = 3.0
						var cap := cr[4] as AnimationPlayer
						if cap and (cr[5] as Dictionary).has("Dance"):
							cap.play(cr[5]["Dance"], 0.2)
				var ex: Vector3 = life.explorer.global_position
				c.rotation.y = atan2(ex.x - c.global_position.x, ex.z - c.global_position.z)
				life.sound.play_flat(life.sound.pop, -8.0)
				if life.stickers:
					if not life.stickers.earned.has("crab"):
						life.stickers.earn("crab")
					else:
						life.stickers._say_later("Crab!", 0.2)
				return "stroked crab"})


func _sand(near: Vector2) -> Vector2:
	for k in 300:
		var q := near + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var h := Terrain.height(q.x, q.y)
		if Terrain.is_sand(q.x, q.y) > 0.7 and h > 0.2 and h < 1.0:
			return q
	return near


func _fireflies_build() -> void:
	_fireflies = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1.2, 16)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.5, 0))
	g.add_point(0.3, Color(1.0, 0.95, 0.4, 1))
	g.add_point(0.7, Color(1.0, 0.95, 0.4, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 0.5, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_fireflies.process_material = pm
	_fireflies.amount = 70
	_fireflies.lifetime = 6.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	_firefly_mat = StandardMaterial3D.new()
	_firefly_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_firefly_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_firefly_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_firefly_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_firefly_mat.vertex_color_use_as_albedo = true
	_firefly_mat.albedo_texture = preload("res://space/rocket.gd")._soft_dot()
	q.material = _firefly_mat
	_fireflies.draw_pass_1 = q
	_fireflies.visibility_aabb = AABB(Vector3(-20, -3, -20), Vector3(40, 8, 40))
	_fireflies.position = Vector3(Terrain.OAK.x - 10.0, Terrain.height(Terrain.OAK.x - 10.0, Terrain.OAK.y) + 1.2, Terrain.OAK.y + 6.0)
	_fireflies.emitting = false
	add_child(_fireflies)


func _hop(f: Node3D, strength: float) -> void:
	# the animated frog crouches and kicks while it jumps, then goes back to breathing
	var fap := f.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if fap:
		for an in fap.get_animation_list():
			if String(an).ends_with("Jump"):
				fap.play(an, 0.05)
				fap.queue(String(an).replace("Jump", "Idle"))
	var start := f.position
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 0.5 * strength
	var to := start + dir
	to.y = Terrain.height(to.x, to.z)
	var tw := f.create_tween()
	tw.tween_property(f, "position", (start + to) * 0.5 + Vector3.UP * 0.35 * strength, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "position", to, 0.18).set_ease(Tween.EASE_IN)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	var here: Vector3 = explorer.global_position
	for b in birds:
		var node: Node3D = b[0]
		if cp.distance_to(node.global_position) > 90.0 and b[6] <= 0.0:
			b[5] += b[4] * delta / b[2] * 6.0
			continue
		if b[6] > 0.0:
			# resting on the grass, pecking; flies off if she comes close
			b[6] -= delta
			node.rotation.x = sin(_t * 8.0) * 0.2 if fmod(_t, 2.0) < 0.6 else 0.0
			if here.distance_to(node.global_position) < 2.5:
				b[6] = 0.0
			continue
		b[5] += b[4] * delta / b[2] * 6.0
		var a: float = b[5]
		var c: Vector2 = b[1]
		var r: float = b[2]
		var p := Vector3(c.x + cos(a) * r, 0, c.y + sin(a) * r)
		p.y = Terrain.height(p.x, p.z) + float(b[3]) + sin(a * 3.0) * 1.2
		var nxt := Vector3(c.x + cos(a + signf(b[4]) * 0.1) * r, p.y, c.y + sin(a + signf(b[4]) * 0.1) * r)
		node.position = p
		node.look_at(nxt, Vector3.UP)
		node.rotate_object_local(Vector3.UP, PI)
		node.rotation.z = sin(_t * 18.0 + a) * 0.15
		if randf() < delta * 0.02:
			# land for a while
			var land := Vector2(p.x, p.z)
			if Terrain.height(land.x, land.y) > 0.3 and Terrain.path_distance(land.x, land.y) > 1.5:
				node.position.y = Terrain.height(land.x, land.y)
				node.rotation = Vector3(0, node.rotation.y, 0)
				b[6] = randf_range(5.0, 12.0)
	for bee in bees:
		var n: Node3D = bee[0]
		var ph: float = bee[2] + _t * 2.6
		n.position = bee[1] + Vector3(cos(ph) * 0.9 + sin(ph * 2.3) * 0.3, sin(ph * 3.1) * 0.25, sin(ph * 1.3) * 0.9)
	var pond := Terrain.POND
	for d in flies:
		var n: Node3D = d[0]
		var ph: float = d[1] + _t * 0.5
		var p := Vector3(pond.x + cos(ph) * 5.0 + sin(ph * 3.7) * 1.5, 0.6 + sin(ph * 5.0) * 0.2, pond.y + sin(ph * 1.3) * 5.0)
		# dragonflies dart and hover
		n.position = n.position.lerp(p, 1.0 - exp(-delta * (6.0 if fmod(_t + d[1], 3.0) < 0.5 else 0.6)))
		n.rotation.y = ph * 2.0
	for f in frogs:
		f[2] -= delta
		var node: Node3D = f[0]
		if f[2] <= 0.0 and here.distance_to(node.global_position) < 2.2:
			f[2] = 2.0
			_hop(node, 0.8)
		elif f[2] <= -6.0 and randf() < delta * 0.2:
			f[2] = 0.0
			_hop(node, 0.4)
		var home: Vector2 = f[1]
		if Vector2(node.position.x, node.position.z).distance_to(home) > 1.6:
			node.position = Vector3(home.x, Terrain.height(home.x, home.y), home.y)
	for c in crabs:
		var node: Node3D = c[0]
		var ap := c[4] as AnimationPlayer
		var clips: Dictionary = c[5]
		if c[3] > 0.0:
			c[3] -= delta   # dancing for her
			continue
		var ph: float = c[2] + _t * 0.7
		var home: Vector2 = c[1]
		var off := sin(ph) * 1.4
		var dir := Vector2(cos(c[2]), sin(c[2]))
		var q: Vector2 = home + dir * off
		node.position = Vector3(q.x, Terrain.height(q.x, q.y), q.y)
		# crabs walk sideways: face across the way they go
		node.rotation.y = lerp_angle(node.rotation.y, atan2(dir.y, -dir.x), 1.0 - exp(-delta * 4.0))
		if ap:
			var want: StringName = clips.get("Walk" if absf(cos(ph)) > 0.25 else "Idle", &"")
			if want != &"" and ap.current_animation != want:
				ap.play(want, 0.25)
	# a fish jumps out of the pond now and then
	_fish_t -= delta
	if _fish_t <= 0.0:
		_fish_t = randf_range(8.0, 18.0)
		if cp.distance_to(Vector3(pond.x, 0, pond.y)) < 50.0:
			_jump_fish()
	# fireflies at dusk
	var night: float = corner.look.night if corner.look else 0.0
	var dusk := clampf(night * 1.6, 0.0, 1.0)
	if life.day:
		dusk = maxf(dusk, clampf((life.day.day_fraction() - 0.8) / 0.15, 0.0, 1.0))
	_fireflies.emitting = dusk > 0.2
	_firefly_mat.albedo_color = Color(1, 1, 1, dusk)


func _jump_fish() -> void:
	var pond := Terrain.POND
	var a := randf() * TAU
	var r := randf_range(1.5, 5.5)
	var at := Vector3(pond.x + cos(a) * r, -0.1, pond.y + sin(a) * r)
	var kind: String = ["Fish1", "Fish2", "Fish3"][randi() % 3]
	var fish := Models.spawn(self, "res://assets/kits/fish/" + kind + ".fbx", 0.25, rad_to_deg(a))
	if fish == null:
		return
	fish.position = at
	var dir := Vector3(-sin(a), 0, cos(a)) * 0.9
	var tw := fish.create_tween()
	tw.tween_property(fish, "position", at + dir * 0.5 + Vector3.UP * 0.7, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(fish, "rotation:x", -0.8, 0.35)
	tw.tween_property(fish, "position", at + dir, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(fish, "rotation:x", 0.8, 0.35)
	tw.tween_callback(func() -> void:
		life.fx.ripple(Vector3(fish.position.x, 0.04, fish.position.z))
		fish.queue_free())
	life.fx.ripple(Vector3(at.x, 0.04, at.z))
