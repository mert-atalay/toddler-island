extends RefCounted
## The second dressing of every place, from the free model kits: the cottage garden and porch, the
## farm's pumpkin patch and scarecrow, a picnic in the orchard, a telescope and a kite on the hill, a
## treehouse and camp in the wood, bridges over the stream, a rowing boat and lilies on the pond, a
## bucket-and-spade beach with buoys and a sailboat, signposts at the junctions, and the rocket meadow.

const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const Places := preload("res://corner/places.gd")
const Rocket := preload("res://space/rocket.gd")
const NK := "res://assets/kits/nature/"
const WK := "res://assets/kits/water/"
const SK := "res://assets/kits/space/"
const VK := "res://assets/kits/survival/"
const FK := "res://assets/kits/food/"
const PG := "res://assets/kits/playground/"
const PC := "res://assets/kits/picnic/"
const EX := "res://assets/kits/extra/"


static func build(corner: Node3D) -> void:
	_garden(corner)
	_farm(corner)
	_orchard(corner)
	_hill(corner)
	_wood(corner)
	_pond(corner)
	_bridges(corner)
	_beach(corner)
	_rocket_meadow(corner)
	_signposts(corner)


## A free spot near `p`: nudged off paths, the stream and other things, so nothing lands on a path.
static func spot(corner: Node3D, p: Vector2, margin := 0.8) -> Vector2:
	for ring in 8:
		for k in 8:
			var q := p + Vector2.from_angle(k * TAU / 8.0) * ring * 0.9 if ring > 0 else p
			if Terrain.path_distance(q.x, q.y) > 1.4 + margin * 0.5 and Terrain.stream_distance(q.x, q.y) > 1.8 \
					and Terrain.height(q.x, q.y) > 0.2 and _clear(corner, q, margin):
				return q
			if ring == 0:
				break
	return p


static func _clear(corner: Node3D, q: Vector2, margin: float) -> bool:
	for b in corner.blocked:
		if q.distance_to(b[0]) < float(b[1]) + margin * 0.5:
			return false
	return true


static func place(corner: Node3D, path: String, height: float, p: Vector2, yaw := 0.0, solid := true, margin := 0.8) -> Node3D:
	var q := spot(corner, p, margin)
	return corner.put(path, height, q.x, q.y, yaw, solid)


## A swing set of our own, so the seat really swings: an A-frame each side, a top bar, and two
## seats hanging on ropes from pivots (metas "pivot" for her seat, "pivot2" for the empty one).
static func _build_swing(corner: Node3D, at: Vector2, yaw: float) -> Node3D:
	var r := Places.root_at(corner, at, yaw)
	var wood := Places.mat(Color(0.95, 0.55, 0.3))
	var rope := Places.mat(Color(0.85, 0.78, 0.6))
	var seat := Places.mat(Color(0.3, 0.6, 0.95))
	for side in [-1.4, 1.4]:
		for lean in [-1.0, 1.0]:
			Places.block(r, Vector3(0.11, 2.6, 0.11), Vector3(side, 1.2, lean * 0.42), wood, Vector3(lean * 19.0, 0, 0))
		Places.solid(r, Vector3(0.3, 2.4, 1.0), Vector3(side, 1.2, 0))
	Places.block(r, Vector3(3.0, 0.13, 0.13), Vector3(0, 2.45, 0), wood)
	var pivots: Array = []
	for x in [-0.55, 0.55]:
		var p := Node3D.new()
		p.position = Vector3(x, 2.42, 0)
		r.add_child(p)
		for rx in [-0.24, 0.24]:
			Places.block(p, Vector3(0.025, 1.95, 0.025), Vector3(rx, -0.975, 0), rope)
		Places.block(p, Vector3(0.6, 0.06, 0.26), Vector3(0, -1.95, 0), seat)
		pivots.append(p)
	r.set_meta("pivot", pivots[0])
	r.set_meta("pivot2", pivots[1])
	var idle := (pivots[1] as Node3D).create_tween().set_loops()
	idle.tween_property(pivots[1], "rotation:x", 0.08, 1.4).set_trans(Tween.TRANS_SINE)
	idle.tween_property(pivots[1], "rotation:x", -0.08, 1.4).set_trans(Tween.TRANS_SINE)
	corner.blocked.append([at, 2.0])
	return r


## Bark and cut-wood colours for the kit logs (the kit draws them pale pink).
static func _woody(n: Node3D) -> Node3D:
	if n == null:
		return null
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var mat := m.get_active_material(k) as BaseMaterial3D
			if mat == null:
				continue
			var w := mat.duplicate() as BaseMaterial3D
			w.albedo_color = Color(0.45, 0.3, 0.18) if mat.albedo_color.v < 0.8 else Color(0.8, 0.64, 0.42)
			w.albedo_texture = null
			m.set_surface_override_material(k, w)
	return n


## The kit draws its crop leaves teal; make them a fresh leaf green (orange and yellow stay).
static func _green_leaves(n: Node3D) -> void:
	if n == null:
		return
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var mat := m.get_active_material(k) as BaseMaterial3D
			if mat == null:
				continue
			var c := mat.albedo_color
			if c.b > c.r and c.b > c.g * 0.7:
				var g := mat.duplicate() as BaseMaterial3D
				g.albedo_color = Color(0.36, 0.62, 0.22) if c.v > 0.5 else Color(0.25, 0.47, 0.16)
				m.set_surface_override_material(k, g)


## Marks a thing she can press: play.gd gives it a word and a little action.
static func toy(corner: Node3D, n: Node3D, word: String, kind := "bounce") -> Node3D:
	if n == null:
		return null
	var list: Array = corner.get_meta("toys", [])
	list.append({"node": n, "word": word, "kind": kind})
	if n.get_child_count() > 0 and n.has_meta("file"):
		n.set_meta("file_path", String(n.get_child(0).scene_file_path))
	corner.set_meta("toys", list)
	return n


static func smoke(parent: Node3D, pos: Vector3, scale := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.5 * scale
	pm.initial_velocity_max = 0.8 * scale
	pm.gravity = Vector3(0.18, 0.05, 0.05)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(1, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.15, Color(0.95, 0.95, 0.95, 0.55))
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.9, 0.9, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	p.amount = 18
	p.lifetime = 6.0
	p.preprocess = 6.0
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9) * scale
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = Rocket._soft_dot()
	q.material = m
	p.draw_pass_1 = q
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
	parent.add_child(p)
	return p


# --- the cottage garden ---------------------------------------------------------------------

static func _garden(corner: Node3D) -> void:
	var c := Terrain.COTTAGE
	# chimney smoke (the chimney sits at +2.0, 6.45, +0.9 from the cottage centre)
	smoke(corner, Vector3(c.x + 2.0, Terrain.height(c.x, c.y) + 6.7, c.y + 0.9), 1.0)
	# vegetable beds to the west of the cottage: rows of crops
	var crops := ["crop_carrot", "crop_pumpkin", "crops_cornStageD", "crop_turnip", "crops_leafsStageB", "crop_melon"]
	for row in 3:
		for k in 5:
			var x := c.x - 9.0 + k * 1.1
			var z := c.y - 1.0 + row * 1.6
			var row_node: Node3D = corner.put(NK + "crops_dirtRow.glb", 0.25, x, z, 0.0, false, 0.0)
			for mi in row_node.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = Places.mat(Color(0.42, 0.3, 0.2))
			var crop: Node3D = corner.put(NK + crops[(row * 2 + k) % crops.size()] + ".glb", [0.55, 0.5, 1.2, 0.45, 0.5, 0.45][(row * 2 + k) % crops.size()], x, z, randf() * 360.0, false, 0.0)
			_green_leaves(crop)
	corner.blocked.append([c + Vector2(-6.8, 0.6), 3.4])
	# a swing set and a sandbox behind the cottage, a slide and a spring horse to its east
	corner.set_meta("swing", toy(corner, _build_swing(corner, spot(corner, c + Vector2(-2.0, 8.5), 2.2), 0.0), "Swing", "swing"))
	toy(corner, place(corner, PG + "sandbox_round_decorated.gltf", 0.5, c + Vector2(4.5, 7.5), 0.0, false), "Sand")
	toy(corner, place(corner, PG + "slide_A.gltf", 2.0, c + Vector2(9.0, 2.0), 90.0), "Slide", "slide")
	toy(corner, place(corner, PG + "spring_horse_A.gltf", 0.9, c + Vector2(7.5, -3.0), 200.0), "Horsey", "rock")
	toy(corner, place(corner, PG + "merry_go_round.gltf", 0.8, c + Vector2(10.5, 7.0), 0.0), "Round and round", "spin")
	toy(corner, place(corner, PG + "seesaw_small.gltf", 0.7, c + Vector2(-9.0, 7.5), 90.0), "Seesaw", "seesaw")
	toy(corner, place(corner, PG + "tire_blue.gltf", 0.35, c + Vector2(7.0, 10.0), 20.0, false), "Tire")
	toy(corner, place(corner, PG + "tire_pink.gltf", 0.35, c + Vector2(8.0, 10.6), 70.0, false), "Tire")
	place(corner, PG + "picnic_table.gltf", 0.8, c + Vector2(-6.0, -6.0), 15.0)
	# a mailbox by the gate, a lantern pot and flowers along the front
	var mail := Places.root_at(corner, spot(corner, c + Vector2(1.8, -6.8), 0.3))
	Places.block(mail, Vector3(0.08, 1.0, 0.08), Vector3(0, 0.5, 0), Places.mat(Color(0.45, 0.3, 0.18)))
	Places.block(mail, Vector3(0.32, 0.28, 0.48), Vector3(0, 1.1, 0), Places.mat(Color(0.25, 0.45, 0.75)), Vector3.ZERO, 12)
	Places.block(mail, Vector3(0.04, 0.2, 0.12), Vector3(0.18, 1.25, -0.1), Places.mat(Color(0.85, 0.2, 0.18)))
	toy(corner, mail, "A letter!", "mail")
	for k in 6:
		var fx := c.x - 3.2 + k * 1.3
		if absf(fx - c.x) < 0.9 or absf(fx - (c.x + 2.9)) < 1.4:
			continue
		corner.put(NK + ["flower_redA", "flower_yellowA", "flower_purpleA"][k % 3] + ".glb", 0.45, fx, c.y - 3.6, randf() * 360.0, false, 0.0)
	corner.put(NK + "pot_large.glb", 0.6, c.x + 1.1, c.y - 3.3, 0.0, false, 0.0)
	corner.put(NK + "pot_large.glb", 0.6, c.x - 1.1, c.y - 3.3, 0.0, false, 0.0)


# --- the farm -------------------------------------------------------------------------------

static func _farm(corner: Node3D) -> void:
	# a pumpkin patch beside the farm path
	var pc := spot(corner, Vector2(-13.0, 5.8), 3.4)
	for k in 9:
		var p := pc + Vector2(-1.4 + (k % 3) * 1.4, -1.3 + (k / 3) * 1.3) + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		corner.put(FK + "pumpkin.glb", randf_range(0.35, 0.55), p.x, p.y, randf() * 360.0, false, 0.0)
	corner.blocked.append([pc, 2.6])
	var patch := Node3D.new()
	patch.position = Vector3(pc.x, Terrain.height(pc.x, pc.y), pc.y)
	corner.add_child(patch)
	toy(corner, patch, "Pumpkin", "pumpkin")
	# the scarecrow watching over it
	var sc := spot(corner, pc + Vector2(-3.2, 0.5), 0.6)
	var s := Places.root_at(corner, sc, 30.0)
	var wood := Places.mat(Color(0.5, 0.36, 0.22))
	Places.block(s, Vector3(0.12, 2.2, 0.12), Vector3(0, 1.1, 0), wood)
	Places.block(s, Vector3(1.6, 0.1, 0.1), Vector3(0, 1.55, 0), wood)
	Places.block(s, Vector3(0.62, 0.7, 0.32), Vector3(0, 1.45, 0), Places.mat(Color(0.3, 0.45, 0.7)))     # shirt
	Places.block(s, Vector3(0.4, 0.4, 0.4), Vector3(0, 2.05, 0), Places.mat(Color(0.93, 0.85, 0.6)), Vector3.ZERO, 12)  # sack head
	Places.block(s, Vector3(0.7, 0.05, 0.7), Vector3(0, 2.25, 0), Places.mat(Color(0.85, 0.7, 0.35)), Vector3.ZERO, 14)  # straw hat
	Places.block(s, Vector3(0.36, 0.25, 0.36), Vector3(0, 2.38, 0), Places.mat(Color(0.85, 0.7, 0.35)), Vector3.ZERO, 14)
	for side in [-1.0, 1.0]:
		Places.block(s, Vector3(0.06, 0.06, 0.02), Vector3(side * 0.09, 2.1, -0.2), Places.mat(Color(0.15, 0.12, 0.1)))
	corner.blocked.append([sc, 0.8])
	toy(corner, s, "Scarecrow", "wiggle")
	# sunflowers along the back fence, outside the paddock
	for k in 14:
		var x := -14.0 + k * 1.9
		corner.put(NK + "flower_yellowA.glb", randf_range(1.2, 1.6), x, -22.4 + randf_range(-0.2, 0.2), randf() * 360.0, false, 0.0)
	# a hay pile and a cart of logs by the farm path
	var hay := Places.mat(Color(0.9, 0.78, 0.42))
	var hp := Places.root_at(corner, spot(corner, Vector2(5.5, 6.5), 1.0), 20.0)
	for k in 3:
		var bale := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.55
		cyl.bottom_radius = 0.55
		cyl.height = 1.0
		bale.mesh = cyl
		bale.material_override = hay
		bale.rotation_degrees.z = 90.0
		bale.position = [Vector3(-0.6, 0.55, 0), Vector3(0.6, 0.55, 0), Vector3(0, 1.45, 0)][k]
		hp.add_child(bale)
	Places.solid(hp, Vector3(2.4, 1.2, 1.1), Vector3(0, 0.6, 0))
	toy(corner, hp, "Hay")
	corner.blocked.append([hp.position.x * Vector2.RIGHT + hp.position.z * Vector2.DOWN, 1.4])


# --- the orchard ----------------------------------------------------------------------------

static func _orchard(corner: Node3D) -> void:
	var o := Terrain.ORCHARD
	var at := spot(corner, o + Vector2(3.5, 9.0), 2.0)
	var pic := Places.root_at(corner, at, 25.0)
	var blanket := Models.spawn(pic, PC + "picnic_blanket_red.gltf", 0.04, 0.0)
	blanket.scale = Vector3.ONE
	var bs: Vector3 = blanket.get_meta("size")
	blanket.scale = Vector3.ONE * (2.2 / maxf(bs.x, 0.01)) * Vector3(1, 1, 1)
	var bits := [[PC + "picnic_basket_round.gltf", 0.45, Vector3(-0.6, 0.02, -0.3)], [PC + "teapot.gltf", 0.22, Vector3(0.3, 0.02, 0.2)],
		[PC + "plate_A.gltf", 0.03, Vector3(0.5, 0.02, -0.35)], [PC + "sandwich.gltf", 0.07, Vector3(0.5, 0.05, -0.35)],
		[PC + "apple.gltf", 0.1, Vector3(-0.2, 0.02, 0.45)], [PC + "apple.gltf", 0.1, Vector3(-0.05, 0.02, 0.55)]]
	for b in bits:
		var m := Models.spawn(pic, b[0], b[1], randf() * 360.0)
		if m:
			m.position = b[2]
	corner.blocked.append([at, 1.6])
	toy(corner, pic, "Picnic")
	# a ladder leaning on the first apple tree
	var t := o + Vector2(-6, -5)
	var lad := Places.root_at(corner, t + Vector2(0.9, 0.0), 90.0)
	var w := Places.mat(Color(0.62, 0.46, 0.3))
	var lean := Node3D.new()
	lean.rotation_degrees.x = -16.0
	lad.add_child(lean)
	for side in [-0.25, 0.25]:
		Places.block(lean, Vector3(0.07, 3.0, 0.07), Vector3(side, 1.5, 0), w)
	for k in 7:
		Places.block(lean, Vector3(0.5, 0.05, 0.05), Vector3(0, 0.35 + k * 0.4, 0), w)


# --- the windmill hill ----------------------------------------------------------------------

static func _hill(corner: Node3D) -> void:
	var h := Terrain.HILL
	toy(corner, place(corner, EX + "telescope.glb", 1.5, h + Vector2(5.5, 3.0), 210.0), "Telescope", "telescope")
	# a kite flying above the hill on a long string
	var anchor := spot(corner, h + Vector2(-4.0, 4.5), 0.4)
	var base := Vector3(anchor.x, Terrain.height(anchor.x, anchor.y), anchor.y)
	var stake := Places.root_at(corner, anchor)
	Places.block(stake, Vector3(0.06, 0.5, 0.06), Vector3(0, 0.25, 0), Places.mat(Color(0.45, 0.3, 0.18)))
	toy(corner, stake, "Kite", "kite")
	var kite := Node3D.new()
	kite.name = "Kite"
	corner.add_child(kite)
	kite.position = base + Vector3(-6.0, 11.0, -5.0)
	var diamond := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.2, 0.8, 0.03)
	diamond.mesh = pm
	diamond.material_override = Places.mat(Color(0.95, 0.3, 0.35))
	diamond.position.y = 0.4
	kite.add_child(diamond)
	var low := MeshInstance3D.new()
	var pm2 := PrismMesh.new()
	pm2.size = Vector3(1.2, 1.2, 0.03)
	low.mesh = pm2
	low.material_override = Places.mat(Color(1.0, 0.85, 0.3))
	low.rotation_degrees.z = 180.0
	low.position.y = -0.6
	kite.add_child(low)
	for k in 5:
		Places.block(kite, Vector3(0.22, 0.1, 0.02), Vector3(0.0, -1.4 - k * 0.45, 0.0), Places.mat([Color(0.3, 0.6, 0.95), Color(0.95, 0.3, 0.35)][k % 2]), Vector3(0, 0, 30.0 * (1 if k % 2 == 0 else -1)))
	var string := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	string.mesh = im
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.95, 0.95, 0.95)
	string.material_override = sm
	corner.add_child(string)
	kite.set_meta("string", string)
	kite.set_meta("anchor", base + Vector3(0, 0.5, 0))
	kite.set_meta("home", kite.position)
	var tw := kite.create_tween().set_loops()
	tw.tween_property(kite, "position", kite.position + Vector3(1.5, 1.2, 0.8), 3.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(kite, "position", kite.position + Vector3(-1.0, -0.6, -0.5), 3.8).set_trans(Tween.TRANS_SINE)
	var rot := kite.create_tween().set_loops()
	rot.tween_property(kite, "rotation:z", 0.25, 1.7).set_trans(Tween.TRANS_SINE)
	rot.tween_property(kite, "rotation:z", -0.2, 1.9).set_trans(Tween.TRANS_SINE)
	kite.set_meta("tweens", [tw, rot])
	# the string follows the kite each frame
	var draw := func() -> void:
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		var a: Vector3 = kite.get_meta("anchor")
		var b := kite.position + Vector3(0, -0.9, 0)
		for i in 13:
			var t := i / 12.0
			im.surface_add_vertex(a.lerp(b, t) + Vector3(0, -sin(t * PI) * 1.4, 0))
		im.surface_end()
	corner.get_tree().process_frame.connect(draw)


# --- the wood -------------------------------------------------------------------------------

static func _wood(corner: Node3D) -> void:
	var t := Terrain.OAK
	# a treehouse round the tall oak: a deck at 3.4 m, a little hut, railings and a ladder
	var th := Places.root_at(corner, t, 0.0)
	var plank := Places.mat(Color(0.62, 0.45, 0.28))
	var dark := Places.mat(Color(0.45, 0.31, 0.19))
	Places.block(th, Vector3(4.2, 0.18, 4.2), Vector3(0, 3.4, 0), plank)
	for px in [-1.9, 1.9]:
		for pz in [-1.9, 1.9]:
			Places.block(th, Vector3(0.22, 3.4, 0.22), Vector3(px, 1.7, pz), dark)
	for side in [-2.05, 2.05]:
		Places.block(th, Vector3(4.2, 0.08, 0.08), Vector3(0, 4.15, side), dark)
		Places.block(th, Vector3(0.08, 0.08, 4.2), Vector3(side, 4.15, 0), dark)
	Places.block(th, Vector3(2.0, 1.6, 1.6), Vector3(0.6, 4.3, 1.0), Places.mat(Color(0.85, 0.55, 0.3)))
	Places.block(th, Vector3(2.3, 0.14, 1.9), Vector3(0.6, 5.2, 1.0), Places.mat(Color(0.3, 0.55, 0.35)), Vector3(0, 0, 8))
	Places.block(th, Vector3(0.5, 0.5, 0.06), Vector3(0.6, 4.4, 0.18), Places.glow_mat(Color(1.0, 0.85, 0.5)))
	var lad := Node3D.new()
	lad.position = Vector3(-1.2, 0, -2.4)
	lad.rotation_degrees.x = 14.0
	th.add_child(lad)
	for side in [-0.28, 0.28]:
		Places.block(lad, Vector3(0.08, 3.6, 0.08), Vector3(side, 1.8, 0), dark)
	for k in 8:
		Places.block(lad, Vector3(0.56, 0.06, 0.06), Vector3(0, 0.35 + k * 0.42, 0), dark)
	# a ring of mushrooms, a camp with a tent and a fire, a hollow log
	var ring := spot(corner, t + Vector2(6.0, -6.0), 2.5)
	for k in 9:
		var a := k * TAU / 9.0
		corner.put(NK + ["mushroom_red", "mushroom_tan", "mushroom_redGroup"][k % 3] + ".glb", 0.3, ring.x + cos(a) * 1.4, ring.y + sin(a) * 1.4, randf() * 360.0, false, 0.0)
	corner.blocked.append([ring, 1.8])
	var rn := Node3D.new()
	rn.position = Vector3(ring.x, Terrain.height(ring.x, ring.y), ring.y)
	corner.add_child(rn)
	toy(corner, rn, "Mushroom", "mushroom")
	var camp := spot(corner, t + Vector2(-3.0, 8.0), 3.0)
	toy(corner, corner.put(NK + "tent_detailedOpen.glb", 1.7, camp.x - 1.8, camp.y + 1.0, 200.0), "Tent", "wiggle")
	corner.put(NK + "campfire_stones.glb", 0.22, camp.x + 0.8, camp.y - 0.6, 0.0, false)
	var fire: Node3D = toy(corner, _woody(corner.put(NK + "campfire_logs.glb", 0.4, camp.x + 0.8, camp.y - 0.6, 30.0, false)), "Campfire", "fire")
	for n in corner.get_children().slice(-2):
		if n is Node3D and n.has_meta("file") and String(n.get_meta("file")).begins_with("campfire"):
			(n as Node3D).position.y = Terrain.height(camp.x + 0.8, camp.y - 0.6) - 0.02
	smoke(corner, Vector3(camp.x + 0.8, Terrain.height(camp.x, camp.y) + 0.4, camp.y - 0.6), 0.6)
	_woody(corner.put(NK + "log.glb", 0.4, camp.x + 2.4, camp.y + 0.6, 80.0))
	toy(corner, _woody(place(corner, NK + "log_large.glb", 0.9, t + Vector2(5.0, 6.0), 30.0)), "Log")
	place(corner, NK + "stump_old.glb", 0.6, t + Vector2(-6.0, -4.0), 0.0)


# --- the pond -------------------------------------------------------------------------------

static func _pond(corner: Node3D) -> void:
	var p := Terrain.POND
	var boat := Models.spawn(corner, WK + "boat-row-small.glb", 0.75, 8.0)
	boat.position = Vector3(p.x + 4.6, 0.02, p.y + 5.0)
	boat.name = "RowBoat"
	corner.set_meta("row_boat", boat)
	var bob := boat.create_tween().set_loops()
	bob.tween_property(boat, "position:y", 0.07, 2.1).set_trans(Tween.TRANS_SINE)
	bob.tween_property(boat, "position:y", -0.01, 2.3).set_trans(Tween.TRANS_SINE)
	for k in 14:
		var a := randf() * TAU
		var r := randf_range(2.5, 6.8)
		var lily := Models.spawn(corner, NK + ("lily_large.glb" if k % 3 else "lily_small.glb"), 0.05, randf() * 360.0)
		if lily:
			lily.position = Vector3(p.x + cos(a) * r, -0.02, p.y + sin(a) * r)
			var ls: Vector3 = lily.get_meta("size")
			lily.scale = Vector3.ONE * (1.0 / maxf(ls.x, 0.01)) * randf_range(0.7, 1.1)



# --- bridges where a path crosses the stream ------------------------------------------------

static func _bridges(corner: Node3D) -> void:
	for line in Terrain.PATHS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			for j in Terrain.STREAM.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(a, b, Terrain.STREAM[j], Terrain.STREAM[j + 1])
				if hit == null:
					continue
				_footbridge(corner, hit, (b - a).normalized())


## A little wooden footbridge across the stream: planks on a gentle arch from bank to bank, posts
## and a rail each side. Its ends sit on the real ground at each bank, so it can never dip into the
## water, and you walk on the arch itself.
static func _footbridge(corner: Node3D, at: Vector2, dir: Vector2) -> void:
	var half := 6.4
	var width := 1.7
	var p0 := at - dir * half
	var p1 := at + dir * half
	var h0 := Terrain.height(p0.x, p0.y) + 0.04
	var h1 := Terrain.height(p1.x, p1.y) + 0.04
	var water := Terrain.height(at.x, at.y, false) - 0.22
	var rise := maxf(0.32, water + 0.35 - lerpf(h0, h1, 0.5))
	var deck := func(u: float) -> float: return lerpf(h0, h1, u) + rise * sin(PI * u)
	var root := Node3D.new()
	root.position = Vector3(at.x, 0, at.y)
	root.rotation.y = atan2(dir.x, dir.y)
	corner.add_child(root)
	var plank := Places.mat(Color(0.62, 0.44, 0.27))
	var dark := Places.mat(Color(0.45, 0.31, 0.19))
	var n := 16
	for k in n:
		var u := (k + 0.5) / n
		var z := lerpf(-half, half, u)
		var y: float = deck.call(u)
		var slope := (float(deck.call(minf(u + 0.02, 1.0))) - float(deck.call(maxf(u - 0.02, 0.0)))) / (0.04 * half * 2.0)
		Places.block(root, Vector3(width, 0.07, half * 2.0 / n - 0.03), Vector3(0, y - 0.035, z), plank if k % 3 else dark, Vector3(-rad_to_deg(atan(slope)), 0, 0))
	for side in [-1.0, 1.0]:
		for k in 5:
			var u := k / 4.0
			var z := lerpf(-half, half, u)
			var y: float = deck.call(u)
			Places.block(root, Vector3(0.09, 0.7, 0.09), Vector3(side * (width * 0.5 - 0.04), y + 0.3, z), dark)
		for k in 8:
			var u := (k + 0.5) / 8.0
			var z := lerpf(-half, half, u)
			var y: float = deck.call(u)
			var slope := (float(deck.call(minf(u + 0.02, 1.0))) - float(deck.call(maxf(u - 0.02, 0.0)))) / (0.04 * half * 2.0)
			Places.block(root, Vector3(0.07, 0.07, half * 2.0 / 8.0 + 0.04), Vector3(side * (width * 0.5 - 0.04), y + 0.62, z), plank, Vector3(-rad_to_deg(atan(slope)), 0, 0))
	# the walking surface follows the arch
	var faces := PackedVector3Array()
	var steps := 12
	for k in steps:
		var u0 := float(k) / steps
		var u1 := float(k + 1) / steps
		var z0 := lerpf(-half - 0.3, half + 0.3, u0)
		var z1 := lerpf(-half - 0.3, half + 0.3, u1)
		var y0: float = deck.call(clampf((z0 + half) / (half * 2.0), 0.0, 1.0)) - 0.02
		var y1: float = deck.call(clampf((z1 + half) / (half * 2.0), 0.0, 1.0)) - 0.02
		var w := width * 0.5
		faces.append_array([Vector3(-w, y0, z0), Vector3(w, y0, z0), Vector3(-w, y1, z1), Vector3(w, y0, z0), Vector3(w, y1, z1), Vector3(-w, y1, z1)])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	# rails stop her walking off the sides into the stream
	for side in [-1.0, 1.0]:
		var rail := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.1, 1.2, half * 2.0)
		rail.shape = box
		rail.position = Vector3(side * width * 0.5, lerpf(h0, h1, 0.5) + rise + 0.3, 0)
		body.add_child(rail)
	corner.blocked.append([at, 2.6])
	var list: Array = corner.get_meta("bridges", [])
	list.append([at, dir, half, width])
	corner.set_meta("bridges", list)


# --- the beach ------------------------------------------------------------------------------

static func _sand_spot(near: Vector2) -> Vector2:
	var best := near
	var best_d := 1e9
	for k in 400:
		var q := near + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		var h := Terrain.height(q.x, q.y)
		if Terrain.is_sand(q.x, q.y) > 0.7 and h > 0.35 and h < 1.2 and Terrain.path_distance(q.x, q.y) > 2.0:
			var d := q.distance_to(near)
			if d < best_d:
				best_d = d
				best = q
	return best


static func _is_sand_ok(q: Vector2) -> bool:
	var h := Terrain.height(q.x, q.y)
	return Terrain.is_sand(q.x, q.y) > 0.7 and h > 0.3 and h < 1.2


static func _beach(corner: Node3D) -> void:
	var l := Terrain.LIGHTHOUSE
	var s := _sand_spot(l + Vector2(-9.0, 4.0))
	corner.put(PG + "sandcastle_A.gltf", 0.7, s.x, s.y, 20.0)
	toy(corner, corner.put(PG + "bucket_A.gltf", 0.3, s.x + 1.1, s.y + 0.4, 0.0, false), "Bucket")
	corner.put(PG + "shovel_A.gltf", 0.12, s.x + 1.3, s.y - 0.4, 60.0, false)
	corner.set_meta("sandcastle_spot", s)
	# a beach umbrella and towel
	var u := _sand_spot(l + Vector2(-14.0, -2.0))
	var ur := Places.root_at(corner, u)
	Places.block(ur, Vector3(0.06, 2.3, 0.06), Vector3(0, 1.15, 0), Places.mat(Color(0.95, 0.95, 0.92)))
	for k in 8:
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 1.4
		cm.height = 0.5
		cm.radial_segments = 16
		seg.mesh = cm
		seg.material_override = Places.mat(Color(0.95, 0.35, 0.3) if k % 2 == 0 else Color(0.98, 0.97, 0.94))
		seg.position.y = 2.35
		seg.scale = Vector3(1, 1, 1)
		ur.add_child(seg)
		break
	Places.block(ur, Vector3(1.0, 0.02, 1.8), Vector3(0.9, 0.02, 0.6), Places.mat(Color(0.3, 0.6, 0.85)), Vector3(0, 20, 0))
	corner.blocked.append([u, 1.6])
	# buoys and a little sailboat on the lake
	for k in 4:
		var a := deg_to_rad(40.0 + k * 70.0)
		var d := Terrain.LAKE_R * 0.55
		var by := Models.spawn(corner, WK + ("buoy-flag.glb" if k % 2 else "buoy.glb"), 0.9, randf() * 360.0)
		by.position = Vector3(Terrain.LAKE.x + cos(a) * d, -0.3, Terrain.LAKE.y + sin(a) * d)
		var tw := by.create_tween().set_loops()
		tw.tween_property(by, "rotation:z", 0.12, 1.6 + k * 0.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(by, "rotation:z", -0.12, 1.6 + k * 0.2).set_trans(Tween.TRANS_SINE)
	var sail := Models.spawn(corner, WK + "boat-sail-a.glb", 3.2, 0.0)
	sail.name = "Sailboat"
	var lake := Terrain.LAKE
	var sr := Terrain.LAKE_R * 0.45
	sail.position = Vector3(lake.x + sr, -0.15, lake.y)
	var sw := sail.create_tween().set_loops()
	sw.tween_method(func(t: float) -> void:
		sail.position = Vector3(lake.x + cos(t) * sr, -0.15 + sin(t * 5.0) * 0.03, lake.y + sin(t) * sr)
		sail.rotation.y = -t, 0.0, TAU, 90.0)


# --- the rocket meadow ----------------------------------------------------------------------

static func _rocket_meadow(corner: Node3D) -> void:
	var r := Terrain.ROCKET
	var ground := Terrain.height(r.x, r.y)
	var pad := Models.spawn(corner, SK + "platform_large.glb", 0.4, 0.0)
	var ps: Vector3 = pad.get_meta("size")
	pad.scale = Vector3(9.0 / ps.x, 1.0, 9.0 / ps.z)
	pad.position = Vector3(r.x, ground - 0.15, r.y)
	var rocket := Rocket.build(corner, 12.0)
	rocket.position = Vector3(r.x, ground + 0.25, r.y)
	rocket.rotation_degrees.y = 200.0
	corner.set_meta("rocket", rocket)
	Places.solid(rocket, Vector3(2.6, 12.0, 2.6), Vector3(0, 6.0, 0))
	# a little gantry with a ladder up to the hatch
	var g := Places.root_at(corner, r + Vector2(-2.6, -0.4), 0.0)
	var steel := Places.mat(Color(0.85, 0.3, 0.25), 0.5)
	for px in [-0.5, 0.5]:
		for pz in [-0.5, 0.5]:
			Places.block(g, Vector3(0.12, 4.0, 0.12), Vector3(px, 2.0, pz), steel)
	for k in 5:
		Places.block(g, Vector3(1.1, 0.08, 1.1), Vector3(0, 0.8 + k * 0.8, 0), Places.mat(Color(0.75, 0.75, 0.78), 0.6))
	Places.block(g, Vector3(1.4, 0.08, 0.5), Vector3(0.95, 3.2, 0), Places.mat(Color(0.75, 0.75, 0.78), 0.6))
	Places.solid(g, Vector3(1.1, 4.0, 1.1), Vector3(0, 2.0, 0))
	# a windsock on a pole
	var ws := Places.root_at(corner, spot(corner, r + Vector2(6.5, 3.5), 0.4), 0.0)
	Places.block(ws, Vector3(0.08, 3.2, 0.08), Vector3(0, 1.6, 0), Places.mat(Color(0.95, 0.95, 0.92)))
	var sock := Node3D.new()
	sock.position = Vector3(0, 3.1, 0)
	ws.add_child(sock)
	for k in 4:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2 - k * 0.03
		cm.bottom_radius = 0.17 - k * 0.03
		cm.height = 0.35
		c.mesh = cm
		c.material_override = Places.mat(Color(1.0, 0.5, 0.15) if k % 2 == 0 else Color(0.98, 0.97, 0.94))
		c.rotation_degrees.z = 90.0
		c.position = Vector3(0.2 + k * 0.35, 0, 0)
		sock.add_child(c)
	var wt := sock.create_tween().set_loops()
	wt.tween_property(sock, "rotation:y", 0.4, 2.5).set_trans(Tween.TRANS_SINE)
	wt.tween_property(sock, "rotation:y", -0.2, 3.0).set_trans(Tween.TRANS_SINE)
	# the rover and a satellite dish, for the space feel
	toy(corner, place(corner, SK + "rover.glb", 1.0, r + Vector2(6.5, -3.0), 140.0, false), "Rover", "rover")
	toy(corner, place(corner, SK + "satelliteDish.glb", 2.2, r + Vector2(5.0, 5.5), 210.0), "Beep beep", "spin")
	corner.blocked.append([r, 6.0])


# --- signposts at the junctions, each with a tiny model of where it leads ---------------------

static func _signposts(corner: Node3D) -> void:
	var signs := [
		[Vector2(38.0, 34.0), FK + "apple.glb", "Home"],         # loop, by the cottage path
		[Vector2(38.0, -18.0), NK + "flower_yellowA.glb", "Windmill"],  # loop, at the hill path
		[Vector2(64.0, 8.0), NK + "mushroom_red.glb", "The wood"],    # loop, at the wood
		[Vector2(56.4, 26.4), WK + "buoy.glb", "The beach"],           # loop, at the beach path
		[Vector2(37.5, 40.0), SK + "rocket_topA.glb", "Rocket"],    # cottage path, at the rocket meadow path
		[Vector2(12.0, 8.0), FK + "egg.glb", "The farm"],             # loop, at the farm path
	]
	for s in signs:
		var j: Vector2 = s[0]
		var q := j + Vector2(1.9, 1.9)
		for k in 8:
			var c := j + Vector2.from_angle(k * TAU / 8.0 + 0.4) * 2.2
			if Terrain.path_distance(c.x, c.y) > 1.3:
				q = c
				break
		var post: Node3D = corner.put(VK + "signpost.glb", 1.5, q.x, q.y, rad_to_deg(-(j - q).angle()), false, 0.6)
		if post == null:
			continue
		toy(corner, post, s[2], "sign")
		var icon := Models.spawn(post, s[1], 0.28, 0.0)
		if icon:
			icon.position = Vector3(0, 1.55, 0)
			var spin := icon.create_tween().set_loops()
			spin.tween_property(icon, "rotation:y", TAU, 8.0).from(0.0)
