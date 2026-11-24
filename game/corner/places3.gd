extends Node3D
## Two places with height and hiding, for depth:
##  - the lookout: up the ramp onto a rocky outcrop, a wooden deck with a rail, a bench and a flag;
##    her button there swings the camera slowly round the whole valley, the waterfall and the lake;
##  - the fairy hollow: through a gap in steep grassy banks into a sheltered glade with a circle of
##    standing stones, glowing mushrooms, fireflies even by day and a hollow log to crawl through;
##    her button at the middle stone makes a wish (sparkles rise and the mushrooms glow brighter).

const Terrain := preload("res://corner/terrain.gd")
const Places := preload("res://corner/places.gd")
const Places2 := preload("res://corner/places2.gd")
const Models := preload("res://lib/models.gd")
const NK := "res://assets/kits/nature/"
const QN := "res://assets/nature/quaternius/"
const VK := "res://assets/kits/survival/"

var corner: Node3D
var life: Node3D
var _glow: Array = []   # mushroom materials that pulse
var _flies: GPUParticles3D


func setup(c: Node3D) -> void:
	corner = c
	life = c.life
	_lookout()
	_hollow()


func _y(p: Vector2) -> float:
	return corner.valley.height_at(p.x, p.y) if corner.valley else Terrain.height(p.x, p.y)


# --- the lookout ------------------------------------------------------------------------------

func _lookout() -> void:
	var c := Terrain.LOOKOUT
	var top := _y(c)
	var deck := Node3D.new()
	deck.position = Vector3(c.x, top, c.y)
	add_child(deck)
	var plank := Places.mat(Color(0.62, 0.45, 0.28))
	var dark := Places.mat(Color(0.45, 0.31, 0.19))
	Places.block(deck, Vector3(7.0, 0.2, 7.0), Vector3(0, 0.1, 0), plank)
	for k in 7:
		Places.block(deck, Vector3(7.0, 0.02, 0.04), Vector3(0, 0.21, -3.0 + k * 1.0), dark)
	# rail round the edge, open towards the ramp (south-west)
	var ramp_dir := ((Terrain.RAMP[1] as Vector2) - c).normalized()
	for k in 24:
		var a := k * TAU / 24.0
		var off := Vector2(cos(a), sin(a))
		if off.dot(ramp_dir) > 0.8:
			continue
		var q := off * 3.4
		Places.block(deck, Vector3(0.1, 0.9, 0.1), Vector3(q.x, 0.65, q.y), dark)
		var q2 := Vector2(cos(a + TAU / 48.0), sin(a + TAU / 48.0)) * 3.4
		Places.block(deck, Vector3(0.08, 0.08, 0.95), Vector3(q2.x, 1.05, q2.y), plank, Vector3(0, -rad_to_deg(a + TAU / 48.0), 0))
	Places.solid(deck, Vector3(0.3, 1.2, 0.3), Vector3(0, -50, 0))
	for k in 24:
		var a := k * TAU / 24.0
		if Vector2(cos(a), sin(a)).dot(ramp_dir) > 0.8:
			continue
		var body := StaticBody3D.new()
		var sh := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.95, 1.2, 0.2)
		sh.shape = bx
		body.add_child(sh)
		body.position = Vector3(cos(a) * 3.45, 0.6, sin(a) * 3.45)
		body.rotation.y = -a + PI / 2.0
		deck.add_child(body)
	# a bench looking out over the valley, a flag, a cairn and flowers
	var bench: Node3D = corner.put("res://assets/props/quaternius/Bench.gltf", 0.48, c.x - 1.6, c.y - 1.8, 200.0)
	if bench:
		bench.position.y = top + 0.2
	var pole := Places.root_at(corner, c + Vector2(2.4, -2.2))
	pole.position.y = top + 0.2
	Places.block(pole, Vector3(0.07, 3.2, 0.07), Vector3(0, 1.6, 0), Places.mat(Color(0.9, 0.9, 0.88)))
	var flag := Node3D.new()
	flag.position = Vector3(0, 2.9, 0)
	pole.add_child(flag)
	Places.block(flag, Vector3(0.9, 0.5, 0.03), Vector3(0.47, 0, 0), Places.mat(Color(1.0, 0.75, 0.25)))
	var tw := flag.create_tween().set_loops()
	tw.tween_property(flag, "rotation:y", 0.35, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flag, "rotation:y", -0.25, 1.9).set_trans(Tween.TRANS_SINE)
	for k in 5:
		var s := Models.spawn(corner, QN + "Rock_Medium_2.gltf", 0.5 - k * 0.07, randf() * 360.0)
		if s:
			s.position = Vector3(c.x - 2.6, top + 0.15 + k * 0.32, c.y + 2.0)
	corner.blocked.append([c, Terrain.LOOKOUT_R])
	var stand := c
	life.interact.register({"name": "lookout", "reach": 3.2, "priority": 0.6, "sparkle_height": 1.6,
		"label": "Look over the valley", "icon": "res://assets/kits/extra/telescope.glb",
		"pos": func() -> Vector3: return Vector3(stand.x, top + 0.4, stand.y),
		"act": func() -> String:
			_panorama(Vector3(stand.x, top, stand.y))
			return "visit:lookout"})


## A slow sweep of the camera round the valley from the lookout.
func _panorama(from: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 1500.0
	corner.add_child(cam)
	cam.global_position = from + Vector3(0, 3.5, 0)
	cam.make_current()
	life.explorer.busy = 9.0
	if life.stickers:
		life.stickers._say_later("Look how big our valley is!", 0.5)
	var start := atan2(Terrain.CENTRE.x - from.x, Terrain.CENTRE.y - from.z) - 1.2
	var tw := cam.create_tween()
	tw.tween_method(func(a: float) -> void:
		var target := from + Vector3(sin(a) * 60.0, -6.0, cos(a) * 60.0)
		cam.look_at(target, Vector3.UP), start, start + 2.6, 8.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	cam.queue_free()
	corner.follow.cam.make_current()


# --- the fairy hollow -------------------------------------------------------------------------

func _hollow() -> void:
	var c := Terrain.HOLLOW
	# a circle of standing stones round a low flat stone in the middle
	for k in 7:
		var a := k * TAU / 7.0 + 0.3
		var q := c + Vector2(cos(a), sin(a)) * 5.0
		var s := Models.spawn(corner, QN + "Rock_Medium_" + str(k % 3 + 1) + ".gltf", 2.2 + (k % 2) * 0.5, randf() * 360.0)
		if s:
			s.scale = Vector3(0.55, 1.0, 0.55) * s.scale
			s.position = Vector3(q.x, _y(q) - 0.15, q.y)
		corner.blocked.append([q, 0.6])
	var mid := Models.spawn(corner, QN + "Rock_Medium_1.gltf", 0.6, 0.0)
	if mid:
		mid.scale = Vector3(1.8, 1.0, 1.8) * mid.scale
		mid.position = Vector3(c.x, _y(c) - 0.1, c.y)
	# glowing mushrooms in clusters round the edge
	var shroom := StandardMaterial3D.new()
	shroom.albedo_color = Color(0.55, 0.85, 1.0)
	shroom.emission_enabled = true
	shroom.emission = Color(0.4, 0.8, 1.0)
	shroom.emission_energy_multiplier = 1.2
	var pink := shroom.duplicate() as StandardMaterial3D
	pink.albedo_color = Color(1.0, 0.65, 0.9)
	pink.emission = Color(1.0, 0.45, 0.85)
	_glow = [shroom, pink]
	for k in 14:
		var a := k * TAU / 14.0 + randf_range(-0.15, 0.15)
		var q := c + Vector2(cos(a), sin(a)) * randf_range(8.5, 10.5)
		var m := Models.spawn(corner, NK + ("mushroom_redGroup.glb" if k % 2 else "mushroom_tanGroup.glb"), randf_range(0.35, 0.6), randf() * 360.0)
		if m:
			m.position = Vector3(q.x, _y(q) - 0.02, q.y)
			for g in m.find_children("*", "MeshInstance3D", true, false):
				(g as MeshInstance3D).material_override = _glow[k % 2]
			Places2.toy(corner, m, "Glowing mushroom", "mushroom")
			if life.play:
				life.play._register_toy({"node": m, "word": "Glowing mushroom", "kind": "mushroom"})
	# a hollow log to crawl through, ferns and a butterfly
	var log := Models.spawn(corner, NK + "log_large.glb", 1.1, 80.0)
	if log:
		var lq := c + Vector2(-4.0, 6.5)
		log.position = Vector3(lq.x, _y(lq) - 0.1, lq.y)
		Places2._woody(log)
	for k in 10:
		var a := randf() * TAU
		var q := c + Vector2(cos(a), sin(a)) * randf_range(9.0, 11.5)
		var f := Models.spawn(corner, QN + "Fern_1.gltf", randf_range(0.6, 0.9), randf() * 360.0)
		if f:
			f.position = Vector3(q.x, _y(q) - 0.05, q.y)
	life.fx.drifting_butterfly(Vector3(c.x, _y(c), c.y))
	# fireflies, even by day (it is shady in here)
	_flies = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 1.5, 9)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.6, 0))
	g.add_point(0.3, Color(1.0, 0.95, 0.5, 1))
	g.add_point(0.7, Color(1.0, 0.95, 0.5, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 0.6, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_flies.process_material = pm
	_flies.amount = 50
	_flies.lifetime = 6.0
	_flies.preprocess = 6.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.1, 0.1)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	fm.albedo_texture = preload("res://space/rocket.gd")._soft_dot()
	qm.material = fm
	_flies.draw_pass_1 = qm
	_flies.position = Vector3(c.x, _y(c) + 1.4, c.y)
	_flies.visibility_range_end = 70.0
	add_child(_flies)
	corner.blocked.append([c, 1.6])
	life.interact.register({"name": "wishing stone", "reach": 2.6, "priority": 0.6, "sparkle_height": 1.0,
		"label": "Make a wish", "icon": NK + "mushroom_redGroup.glb",
		"pos": func() -> Vector3: return Vector3(c.x, _y(c) + 0.4, c.y),
		"act": func() -> String:
			_wish(Vector3(c.x, _y(c), c.y))
			return "visit:hollow wish"})


func _wish(at: Vector3) -> void:
	life.explorer.act("emote-yes", 1.2)
	life.sound.play_flat(life.sound.chime, -4.0)
	if life.stickers:
		life.stickers._say_later("Make a wish!", 0.3)
	if life.play:
		for k in 4:
			life.play._burst(at + Vector3(randf_range(-1, 1), 0.8 + k * 0.6, randf_range(-1, 1)), [Color(1.0, 0.9, 0.4), Color(0.6, 0.9, 1.0), Color(1.0, 0.6, 0.9)][k % 3], 30)
	for m in _glow:
		var mat := m as StandardMaterial3D
		var tw := create_tween()
		tw.tween_property(mat, "emission_energy_multiplier", 6.0, 0.4)
		tw.tween_property(mat, "emission_energy_multiplier", 1.2, 2.5)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for k in _glow.size():
		var mat := _glow[k] as StandardMaterial3D
		if mat.emission_energy_multiplier < 2.0:
			mat.emission_energy_multiplier = 1.0 + 0.35 * sin(t * 1.5 + k * 2.0)
