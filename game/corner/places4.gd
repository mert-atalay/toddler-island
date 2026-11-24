extends Node3D
## Two more places to visit:
##  - the safari plain (west, off the path past the farm): dry grass with sandy patches, flat-topped
##    acacia trees, a waterhole where the hippo wallows, a big rock the lions lie by, and a wooden
##    safari hide on stilts with a ramp up to watch from. Elephants (a mother and baby), giraffes
##    (a mother and baby), a lion and her cub, a hippo, a rhino and a tiger live here;
##  - the treehouse camp (deep in the eastern wood, past the tall oak): a giant tree with a house in
##    it, a ramp up and a slide down, a campfire with log seats, two tents, a frog pool with lily pads,
##    an owl on a branch and fireflies. A fox family, a raccoon, a bear cub and a friendly wolf live here.

const Terrain := preload("res://corner/terrain.gd")
const Places := preload("res://corner/places.gd")
const Places2 := preload("res://corner/places2.gd")
const Models := preload("res://lib/models.gd")
const NK := "res://assets/kits/nature/"
const QN := "res://assets/nature/quaternius/"
const VK := "res://assets/kits/survival/"
const W := "res://assets/animals/new/"

var corner: Node3D
var life: Node3D
var _fire_light: OmniLight3D
var _owl: Node3D
var _frogs: Array = []   # [holder, AnimationPlayer, lily index, timer]
var _lilies: Array = []  # Vector3 tops of the lily pads
var _t := 0.0
var _hoot_t := 0.0


func setup(c: Node3D) -> void:
	corner = c
	life = c.life
	var nb: int = corner.blocked.size()
	var nt: int = corner.trunks.size()
	_safari()
	_camp()
	# the route map was drawn before these places existed: mark what they put down as solid
	for i in range(nb, corner.blocked.size()):
		life.paths._solid_disc(corner.blocked[i][0], float(corner.blocked[i][1]) * 0.85)
	for i in range(nt, corner.trunks.size()):
		life.paths._solid_disc(corner.trunks[i][0], float(corner.trunks[i][1]) + 0.2)


func _y(p: Vector2) -> float:
	return corner.valley.height_at(p.x, p.y) if corner.valley else Terrain.height(p.x, p.y)


func _pool(at: Vector2, radius: float, y: float) -> void:
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 40
	disc.mesh = cm
	if corner.valley and corner.valley.water_mat:
		disc.material_override = corner.valley.water_mat
	else:
		disc.material_override = Places.mat(Color(0.3, 0.55, 0.6), 0.1)
	disc.position = Vector3(at.x, y, at.y)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)


# --- the safari plain -------------------------------------------------------------------------

func _safari() -> void:
	var c := Terrain.SAFARI
	_pool(Terrain.WATERHOLE, Terrain.WATERHOLE_R + 1.4, Terrain.WATER + 0.02)
	corner.blocked.append([Terrain.WATERHOLE, Terrain.WATERHOLE_R + 1.0])
	for k in 9:
		var a := k * TAU / 9.0 + 0.4
		var q := Terrain.WATERHOLE + Vector2(cos(a), sin(a)) * (Terrain.WATERHOLE_R + 1.6 + randf() * 0.6)
		var reed := Models.spawn(corner, QN + "Grass_Wispy_Tall.gltf", randf_range(0.8, 1.2), randf() * 360.0)
		if reed:
			reed.position = Vector3(q.x, _y(q) - 0.05, q.y)
	# flat-topped acacia trees round the edge of the plain (shade for resting)
	var trees := [Vector2(-41, 33), Vector2(-28, 30), Vector2(-45, 49), Vector2(-34, 54), Vector2(-16, 37), Vector2(-50, 40),
		Vector2(-24, 58), Vector2(-12, 45)]
	for i in trees.size():
		_acacia(trees[i], 5.5 + (i % 3) * 1.1)
	# the lions' rock: big warm boulders on the plain
	var rock_at := c + Vector2(-7.0, 2.0)
	for r in [[Vector2(0, 0), 3.4, 0.0], [Vector2(2.4, 1.2), 2.2, 70.0], [Vector2(-1.8, 1.6), 1.6, 140.0], [Vector2(1.0, -2.0), 1.3, 200.0]]:
		var q: Vector2 = rock_at + r[0]
		var s := Models.spawn(corner, "res://assets/kaykit/Rock_1_" + ["A", "B", "C", "D"][int(r[2]) / 70 % 4] + "_Color1.gltf", r[1], r[2])
		if s:
			s.scale = Vector3(1.3, 1.0, 1.15) * s.scale
			s.position = Vector3(q.x, _y(q) - 0.2, q.y)
			_tint(s, Color(0.9, 0.72, 0.52))
		corner.blocked.append([q, float(r[1]) * 0.7])
		Places.solid(corner, Vector3(float(r[1]) * 1.3, float(r[1]), float(r[1]) * 1.1), Vector3(q.x, _y(q) + float(r[1]) * 0.4, q.y))
	# termite mounds
	for q in [c + Vector2(6.0, -9.0), c + Vector2(-13.0, 10.0), c + Vector2(11.0, 12.0)]:
		var m := Places.root_at(corner, q)
		Places.block(m, Vector3(0.2, 1.8, 1.3), Vector3(0, 0.9, 0), Places.mat(Color(0.72, 0.5, 0.32)), Vector3.ZERO, 7)
		Places.block(m, Vector3(0.1, 1.0, 0.5), Vector3(0.45, 0.5, 0.1), Places.mat(Color(0.68, 0.47, 0.3)), Vector3.ZERO, 6)
		corner.blocked.append([q, 0.9])
		Places.solid(m, Vector3(1.2, 1.8, 1.2), Vector3(0, 0.9, 0))
	# a sign where the path arrives
	var sign: Node3D = corner.put(VK + "signpost-single.glb", 1.6, -30.5, 29.5, 160.0, true, 0.5)
	if sign:
		Places2._woody(sign)
	_hide(c + Vector2(9.5, -6.5))
	# the animals
	life._spawn("elephant", c + Vector2(-2.0, 8.0), 30.0)
	life._spawn("baby elephant", c + Vector2(0.5, 9.5), 60.0)
	life._spawn("giraffe", c + Vector2(-10.0, -3.0), 200.0)
	life._spawn("baby giraffe", c + Vector2(-8.5, -1.0), 220.0)
	life._spawn("lion", rock_at + Vector2(3.5, 3.0), 120.0)
	life._spawn("lion cub", rock_at + Vector2(4.5, 4.4), 150.0)
	life._spawn("hippo", Terrain.WATERHOLE + Vector2(-7.0, -1.0), 90.0)
	life._spawn("rhino", c + Vector2(-13.0, -8.0), 250.0)
	life._spawn("tiger", c + Vector2(-12.0, 12.0), 40.0)
	life.fx.drifting_butterfly(Vector3(c.x, _y(c), c.y))


func _tint(n: Node3D, col: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var base := m.get_active_material(k) as BaseMaterial3D
			if base:
				var t := base.duplicate() as BaseMaterial3D
				t.albedo_color = col
				t.albedo_texture = null
				m.set_surface_override_material(k, t)


## A flat-topped acacia: a leaning trunk that forks, under wide flat crowns.
func _acacia(at: Vector2, h: float) -> void:
	var root := Places.root_at(corner, at, randf() * 360.0)
	root.position.y = _y(at) - 0.1
	var bark := Places.mat(Color(0.42, 0.3, 0.2))
	var leaf := Places.mat(Color(0.42, 0.55, 0.2))
	var leaf2 := Places.mat(Color(0.5, 0.62, 0.24))
	Places.block(root, Vector3(0.32, h * 0.62, 0.46), Vector3(0.25, h * 0.31, 0), bark, Vector3(0, 0, -8), 7)
	Places.block(root, Vector3(0.18, h * 0.42, 0.28), Vector3(0.9, h * 0.7, 0.35), bark, Vector3(25, 0, -30), 6)
	Places.block(root, Vector3(0.18, h * 0.4, 0.28), Vector3(-0.2, h * 0.72, -0.4), bark, Vector3(-25, 0, 18), 6)
	for cr in [[Vector3(1.7, h * 0.92, 0.6), 4.6, leaf], [Vector3(-0.6, h * 0.95, -1.0), 3.6, leaf2], [Vector3(0.6, h * 1.02, 0.0), 2.6, leaf]]:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = float(cr[1]) * 0.5
		sm.height = float(cr[1]) * 0.22
		sm.radial_segments = 10
		sm.rings = 4
		m.mesh = sm
		m.material_override = cr[2]
		m.position = cr[0]
		root.add_child(m)
	corner._trunk(at.x, at.y, 0.35)


## A wooden safari hide on stilts: up a ramp to a roofed platform to watch the animals from.
func _hide(at: Vector2) -> void:
	var y0 := _y(at)
	var hide := Node3D.new()
	hide.position = Vector3(at.x, y0, at.y)
	hide.rotation.y = deg_to_rad(-35.0)
	corner.add_child(hide)
	var plank := Places.mat(Color(0.62, 0.45, 0.28))
	var dark := Places.mat(Color(0.42, 0.29, 0.18))
	var roof := Places.mat(Color(0.76, 0.62, 0.36))
	var top := 2.2
	_platform(hide, Vector2(4.2, 3.6), top, plank, dark, Vector3(0, 0, 1))
	for sx in [-1.8, 1.8]:
		for sz in [-1.5, 1.5]:
			Places.block(hide, Vector3(0.18, top + 2.3, 0.18), Vector3(sx, (top + 2.3) * 0.5, sz), dark)
	Places.block(hide, Vector3(4.8, 0.12, 2.4), Vector3(0, top + 2.45, -0.9), roof, Vector3(-18, 0, 0))
	Places.block(hide, Vector3(4.8, 0.12, 2.4), Vector3(0, top + 2.45, 0.9), roof, Vector3(18, 0, 0))
	_ramp(hide, Vector3(0, 0, 1.8), Vector3(0, 0, 1), top, 1.3, plank, dark)
	var face := hide.global_transform.basis * Vector3(0, 0, -1)
	var stand := hide.global_transform * Vector3(0, top + 0.2, -0.6)
	life.interact.register({"name": "safari hide", "reach": 2.4, "priority": 0.6, "sparkle_height": 1.2,
		"label": "Look at the animals", "icon": "res://assets/kits/extra/telescope.glb",
		"pos": func() -> Vector3: return stand,
		"act": func() -> String:
			_watch(stand, face)
			return "visit:safari hide"})
	corner.blocked.append([at, 3.0])
	var ramp_mid := hide.global_transform * Vector3(0, 0, 4.6)
	corner.blocked.append([Vector2(ramp_mid.x, ramp_mid.z), 1.6])


## A slow look across the plain from the hide.
func _watch(from: Vector3, face: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 1200.0
	corner.add_child(cam)
	cam.global_position = from + Vector3(0, 1.6, 0)
	cam.make_current()
	life.explorer.busy = 7.0
	if life.stickers:
		life.stickers._say_later("Can you see the elephant?", 0.5)
	var base := atan2(face.x, face.z)
	var tw := cam.create_tween()
	tw.tween_method(func(a: float) -> void:
		cam.look_at(from + Vector3(sin(a) * 30.0, -1.0, cos(a) * 30.0), Vector3.UP), base - 0.9, base + 0.9, 7.0).set_trans(Tween.TRANS_SINE)
	await tw.finished
	cam.queue_free()
	corner.follow.cam.make_current()


## A plank platform at `top` with a rail round it, open on the side `open` points to (local axis).
func _platform(parent: Node3D, size: Vector2, top: float, plank: Material, dark: Material, open: Vector3, open2 := Vector3.ZERO) -> void:
	Places.block(parent, Vector3(size.x, 0.18, size.y), Vector3(0, top - 0.09, 0), plank)
	for k in int(size.y / 0.5):
		Places.block(parent, Vector3(size.x, 0.02, 0.04), Vector3(0, top + 0.01, -size.y * 0.5 + 0.25 + k * 0.5), dark)
	# one solid floor the explorer walks on
	Places.solid(parent, Vector3(size.x, 0.2, size.y), Vector3(0, top - 0.1, 0))
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var sides := [[Vector3(0, 0, -1), Vector3(size.x, 0, 0)], [Vector3(0, 0, 1), Vector3(size.x, 0, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, size.y)], [Vector3(1, 0, 0), Vector3(0, 0, size.y)]]
	for sd in sides:
		var n: Vector3 = sd[0]
		var along: Vector3 = sd[1]
		var centre := Vector3(n.x * hx, top, n.z * hz)
		var open_here := n.dot(open) > 0.9 or (open2 != Vector3.ZERO and n.dot(open2) > 0.9)
		var len := along.length()
		var dir := along.normalized()
		# with an opening, rail only the two ends of this side
		var parts := [[-len * 0.5, len * 0.5]] if not open_here else [[-len * 0.5, -0.8], [0.8, len * 0.5]]
		for pr in parts:
			var a: float = pr[0]
			var b: float = pr[1]
			var mid := centre + dir * (a + b) * 0.5
			var l := b - a
			if l < 0.2:
				continue
			Places.block(parent, Vector3(maxf(absf(dir.x) * l, 0.08), 0.08, maxf(absf(dir.z) * l, 0.08)), mid + Vector3(0, 0.95, 0), plank)
			for k in int(l / 0.6) + 1:
				var p := centre + dir * (a + k * l / maxf(int(l / 0.6), 1))
				Places.block(parent, Vector3(0.08, 0.95, 0.08), p + Vector3(0, 0.48, 0), dark)
			Places.solid(parent, Vector3(maxf(absf(dir.x) * l, 0.15), 1.2, maxf(absf(dir.z) * l, 0.15)), mid + Vector3(0, 0.6, 0))


## A ramp from the ground up to a platform edge: starts at `edge` (local, at the platform's side)
## and runs outward along `out` down to the ground.
func _ramp(parent: Node3D, edge: Vector3, out: Vector3, top: float, width: float, plank: Material, dark: Material) -> void:
	var run := top / tan(deg_to_rad(22.0))
	var length := sqrt(run * run + top * top)
	var ang := atan2(top, run)
	var mid := edge + out * run * 0.5 + Vector3(0, top * 0.5 - 0.05, 0)
	var yaw := atan2(out.x, out.z)
	var holder := Node3D.new()
	holder.position = mid
	holder.rotation = Vector3(0, yaw, 0)
	parent.add_child(holder)
	var tilt := Node3D.new()
	tilt.rotation.x = ang
	holder.add_child(tilt)
	Places.block(tilt, Vector3(width, 0.12, length), Vector3.ZERO, plank)
	for k in int(length / 0.45):
		Places.block(tilt, Vector3(width, 0.03, 0.06), Vector3(0, 0.07, -length * 0.5 + 0.3 + k * 0.45), dark)
	for sx in [-1.0, 1.0]:
		Places.block(tilt, Vector3(0.07, 0.07, length), Vector3(sx * width * 0.5, 0.85, 0), plank)
		for k in int(length / 1.2) + 1:
			Places.block(tilt, Vector3(0.07, 0.85, 0.07), Vector3(sx * width * 0.5, 0.42, -length * 0.5 + k * length / maxf(int(length / 1.2), 1)), dark)
		Places.solid(tilt, Vector3(0.12, 1.2, length), Vector3(sx * (width * 0.5 + 0.06), 0.6, 0))
	Places.solid(tilt, Vector3(width, 0.14, length + 0.3), Vector3(0, -0.02, 0))


# --- the treehouse camp -----------------------------------------------------------------------

func _camp() -> void:
	var c := Terrain.CAMP
	var tree_at := c + Vector2(3.5, -3.0)
	_treehouse(tree_at)
	# the campfire with log seats round it
	var fire_at := c + Vector2(-4.0, 3.0)
	var pit: Node3D = corner.put(VK + "campfire-pit.glb", 0.7, fire_at.x, fire_at.y, 0.0, true, 1.2)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.62, 0.3)
	_fire_light.omni_range = 7.0
	_fire_light.light_energy = 1.6
	_fire_light.position = Vector3(fire_at.x, _y(fire_at) + 0.8, fire_at.y)
	add_child(_fire_light)
	_flames(Vector3(fire_at.x, _y(fire_at) + 0.25, fire_at.y))
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		var q := fire_at + Vector2(cos(a), sin(a)) * 2.1
		var lg: Node3D = corner.put(VK + "tree-log.glb", 0.45, q.x, q.y, rad_to_deg(-a) + 90.0, false, 0.4)
		if lg:
			Places2._woody(lg)
	life.interact.register({"name": "campfire", "reach": 2.6, "priority": 0.5, "sparkle_height": 0.8,
		"label": "Warm up by the fire", "icon": VK + "campfire-pit.glb",
		"pos": func() -> Vector3: return Vector3(fire_at.x, _y(fire_at) + 0.3, fire_at.y),
		"act": func() -> String:
			_warm(Vector3(fire_at.x, _y(fire_at), fire_at.y))
			return "visit:campfire"})
	# two tents
	var t1: Node3D = corner.put(NK + "tent_detailedOpen.glb", 1.9, c.x - 8.5, c.y - 2.0, 60.0, true, 1.6)
	var t2: Node3D = corner.put(NK + "tent_smallClosed.glb", 1.4, c.x - 6.0, c.y - 6.5, 20.0, true, 1.2)
	# the frog pool with lily pads
	var pool_at := c + Vector2(-2.0, 8.5)
	_pool(pool_at, 2.6, _y(pool_at) + 0.04)
	corner.blocked.append([pool_at, 2.8])
	for k in 10:
		var a := k * TAU / 10.0
		var q := pool_at + Vector2(cos(a), sin(a)) * 3.0
		var st := Models.spawn(corner, QN + "Rock_Medium_" + str(k % 3 + 1) + ".gltf", randf_range(0.3, 0.5), randf() * 360.0)
		if st:
			st.position = Vector3(q.x, _y(q) - 0.05, q.y)
	for k in 5:
		var a := k * TAU / 5.0 + 0.3
		var q := pool_at + Vector2(cos(a), sin(a)) * randf_range(0.8, 1.8)
		var lily := Models.spawn(corner, NK + ("lily_large.glb" if k % 2 == 0 else "lily_small.glb"), 0.06, randf() * 360.0)
		var top := Vector3(q.x, _y(pool_at) + 0.07, q.y)
		if lily:
			lily.scale *= 3.0
			lily.position = top - Vector3(0, 0.03, 0)
		_lilies.append(top)
	for k in 3:
		var fr := Models.spawn(corner, W + "Frog.glb", 0.22, randf() * 360.0)
		if fr:
			fr.position = _lilies[k * 2 % _lilies.size()]
			var ap := fr.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap:
				for an in ap.get_animation_list():
					if String(an).ends_with("Idle"):
						ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
						ap.play(an)
			_frogs.append([fr, ap, k * 2 % _lilies.size(), randf_range(3.0, 8.0)])
			life.interact.register({"name": "frog", "reach": 3.4, "priority": 0.4, "sparkle_height": 0.4,
				"label": "Say hello to the frog", "icon": W + "Frog.glb",
				"pos": func() -> Vector3: return fr.global_position,
				"act": func() -> String:
					_frog_hop(_frogs.find_custom(func(f: Array) -> bool: return f[0] == fr), true)
					return "frog"})
	# mushrooms, ferns and stumps round the clearing
	for k in 16:
		var a := randf() * TAU
		var q := c + Vector2(cos(a), sin(a)) * randf_range(9.0, 12.5)
		var f := Models.spawn(corner, QN + ("Fern_1.gltf" if k % 3 else "Mushroom_Common.gltf"), randf_range(0.5, 0.9) if k % 3 else 0.25, randf() * 360.0)
		if f:
			f.position = Vector3(q.x, _y(q) - 0.05, q.y)
	for q in [c + Vector2(6.0, 6.0), c + Vector2(-9.5, 5.5)]:
		var s: Node3D = corner.put(NK + "stump_round.glb", 0.5, q.x, q.y, randf() * 360.0, true, 0.5)
		if s:
			Places2._woody(s)
	var sign: Node3D = corner.put(VK + "signpost-single.glb", 1.6, 87.0, -2.5, 200.0, true, 0.5)
	if sign:
		Places2._woody(sign)
	_fireflies(Vector3(c.x, _y(c) + 1.5, c.y))
	life.fx.drifting_butterfly(Vector3(c.x, _y(c), c.y))
	# the animals
	life._spawn("fox", c + Vector2(-1.0, -6.0), 0.0)
	life._spawn("fox", c + Vector2(1.0, -7.0), 40.0)
	life._spawn("raccoon", c + Vector2(6.0, 4.0), 200.0)
	life._spawn("bear cub", c + Vector2(-6.0, 9.0), 120.0)
	life._spawn("wolf", c + Vector2(7.0, -8.0), 250.0)


## The giant tree with a house in it: a ramp winds up to the deck, a slide comes down.
func _treehouse(at: Vector2) -> void:
	var y0 := _y(at)
	var tree := Node3D.new()
	tree.position = Vector3(at.x, y0, at.y)
	tree.rotation.y = deg_to_rad(15.0)
	corner.add_child(tree)
	var bark := Places.mat(Color(0.45, 0.31, 0.2))
	var bark2 := Places.mat(Color(0.38, 0.26, 0.17))
	var plank := Places.mat(Color(0.66, 0.48, 0.3))
	var dark := Places.mat(Color(0.45, 0.31, 0.19))
	var roof := Places.mat(Color(0.75, 0.3, 0.22))
	var leaf := Places.mat(Color(0.3, 0.55, 0.22))
	var leaf2 := Places.mat(Color(0.38, 0.63, 0.25))
	# trunk, roots and branches
	Places.block(tree, Vector3(1.6, 11.0, 2.4), Vector3(0, 5.5, 0), bark, Vector3.ZERO, 10)
	for k in 5:
		var a := k * TAU / 5.0
		Places.block(tree, Vector3(0.35, 1.6, 0.7), Vector3(cos(a) * 1.15, 0.35, sin(a) * 1.15), bark2, Vector3(sin(a) * 50.0, 0, -cos(a) * 50.0), 6)
	for br in [[Vector3(1.8, 8.5, 0.3), Vector3(0, 0, -55)], [Vector3(-1.6, 9.0, -0.6), Vector3(10, 0, 50)], [Vector3(0.2, 9.4, 1.8), Vector3(55, 0, 0)]]:
		Places.block(tree, Vector3(0.4, 3.4, 0.55), br[0], bark, br[1], 6)
	# the crown: big soft clumps of leaves
	for cl in [[Vector3(0, 11.5, 0), 7.5, leaf], [Vector3(3.2, 10.2, 1.0), 5.0, leaf2], [Vector3(-3.0, 10.6, -1.2), 5.5, leaf2],
			[Vector3(0.6, 10.0, 3.2), 4.8, leaf], [Vector3(-0.8, 10.4, -3.4), 5.0, leaf], [Vector3(1.5, 13.4, -0.5), 4.6, leaf2]]:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = float(cl[1]) * 0.5
		sm.height = float(cl[1]) * 0.8
		sm.radial_segments = 12
		sm.rings = 6
		m.mesh = sm
		m.material_override = cl[2]
		m.position = cl[0]
		tree.add_child(m)
	var trunk_body := StaticBody3D.new()
	var ts := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.15
	cyl.height = 11.0
	ts.shape = cyl
	trunk_body.add_child(ts)
	trunk_body.position = Vector3(0, 5.5, 0)
	tree.add_child(trunk_body)
	corner.trunks.append([at, 1.3])
	# the deck round the trunk, a little house on its back half
	var top := 3.4
	_platform(tree, Vector2(6.0, 6.0), top, plank, dark, Vector3(0, 0, 1), Vector3(1, 0, 0))
	for sx in [-2.7, 2.7]:
		for sz in [-2.7, 2.7]:
			Places.block(tree, Vector3(0.2, top, 0.2), Vector3(sx, top * 0.5, sz), dark)
			Places.block(tree, Vector3(0.12, 1.4, 0.12), Vector3(sx * 0.6, top - 0.6, sz * 0.6), dark, Vector3(0, 0, 35.0 * signf(sx)))
	var house := Node3D.new()
	house.position = Vector3(0, top, -1.95)
	tree.add_child(house)
	for wall in [[Vector3(5.2, 2.0, 0.12), Vector3(0, 1.0, -1.0)], [Vector3(0.12, 2.0, 2.0), Vector3(-2.6, 1.0, 0)], [Vector3(0.12, 2.0, 2.0), Vector3(2.6, 1.0, 0)]]:
		Places.block(house, wall[0], wall[1], plank)
		Places.solid(house, wall[0], wall[1])
	Places.block(house, Vector3(5.6, 0.12, 1.5), Vector3(0, 2.4, -0.5), roof, Vector3(-30, 0, 0))
	Places.block(house, Vector3(5.6, 0.12, 1.5), Vector3(0, 2.4, 0.5), roof, Vector3(30, 0, 0))
	# a round window and lanterns
	Places.block(house, Vector3(0.7, 0.04, 0.7), Vector3(1.4, 1.3, -0.92), Places.mat(Color(1.0, 0.85, 0.45), 0.3, 0.8), Vector3(90, 0, 0), 12)
	for lx in [-1.5, 1.5]:
		var lan := Places.block(house, Vector3(0.22, 0.3, 0.22), Vector3(lx, 1.9, 1.15), Places.mat(Color(1.0, 0.8, 0.4), 0.3, 1.6), Vector3.ZERO, 8)
		var ll := OmniLight3D.new()
		ll.light_color = Color(1.0, 0.75, 0.4)
		ll.omni_range = 3.5
		ll.light_energy = 0.6
		lan.add_child(ll)
	# the ramp up (from the front), the slide down (from the right side)
	_ramp(tree, Vector3(0, 0, 3.0), Vector3(0, 0, 1), top, 1.4, plank, dark)
	var slide_top := Vector3(3.0, top, 0.0)
	var slide_out := Vector3(1, 0, 0)
	var slide_len := 6.4
	_slide(tree, slide_top, slide_out, top, slide_len)
	var g_top := tree.global_transform * (slide_top + Vector3(-0.4, 0.1, 0))
	var g_dir := (tree.global_transform.basis * slide_out).normalized()
	var g_bottom := tree.global_transform * (slide_top + slide_out * slide_len + Vector3(0, -top + 0.25, 0))
	life.interact.register({"name": "treehouse slide", "reach": 1.8, "priority": 0.9, "sparkle_height": 0.9,
		"label": "Slide down!", "icon": "res://assets/kits/playground/slide_A.gltf",
		"pos": func() -> Vector3: return g_top,
		"act": func() -> String:
			_slide_down(g_top, g_bottom, g_dir)
			return "slide"})
	life.interact.register({"name": "treehouse", "reach": 2.2, "priority": 0.5, "sparkle_height": 1.2,
		"label": "Peek out of the treehouse", "icon": "res://assets/kits/extra/telescope.glb",
		"pos": func() -> Vector3: return tree.global_transform * Vector3(-1.6, top + 0.2, 0.6),
		"act": func() -> String:
			_peek(tree.global_transform * Vector3(-1.6, top, 1.6), tree.global_transform.basis * Vector3(0, 0, 1))
			return "visit:treehouse"})
	# the owl on a branch
	_owl = Models.spawn(corner, W + "owl.glb", 0.55, 0.0)
	if _owl:
		_owl.position = tree.global_transform * Vector3(-2.6, 8.2, -0.9)
		life.interact.register({"name": "owl", "reach": 5.0, "priority": 0.3, "sparkle_height": 0.5,
			"label": "Hoot to the owl", "icon": W + "owl.glb",
			"pos": func() -> Vector3: return _owl.global_position,
			"act": func() -> String:
				_hoot()
				return "owl"})
	corner.blocked.append([at, 4.2])
	var rm := tree.global_transform * Vector3(0, 0, 7.5)
	corner.blocked.append([Vector2(rm.x, rm.z), 1.5])
	var sm2 := tree.global_transform * Vector3(6.5, 0, 0)
	corner.blocked.append([Vector2(sm2.x, sm2.z), 1.4])


## A bright slide from the deck down to the ground.
func _slide(parent: Node3D, top_at: Vector3, out: Vector3, top: float, length: float) -> void:
	var red := Places.mat(Color(0.95, 0.35, 0.25), 0.4)
	var yellow := Places.mat(Color(1.0, 0.8, 0.25), 0.5)
	var drop := top - 0.25
	var run := length
	var slope := sqrt(run * run + drop * drop)
	var holder := Node3D.new()
	holder.position = top_at + out * run * 0.5 + Vector3(0, -drop * 0.5 + 0.1, 0)
	holder.rotation.y = atan2(out.x, out.z)
	parent.add_child(holder)
	var tilt := Node3D.new()
	tilt.rotation.x = atan2(drop, run)
	holder.add_child(tilt)
	Places.block(tilt, Vector3(0.9, 0.08, slope), Vector3.ZERO, yellow)
	for sx in [-0.48, 0.48]:
		Places.block(tilt, Vector3(0.07, 0.32, slope), Vector3(sx, 0.14, 0), red)
	for sx in [-0.4, 0.4]:
		Places.block(parent, Vector3(0.1, top * 0.6, 0.1), top_at + out * run * 0.35 + Vector3(0, -top * 0.7, 0) + out.cross(Vector3.UP) * sx, red)


func _slide_down(top: Vector3, bottom: Vector3, dir: Vector3) -> void:
	if not life.play:
		return
	var face := atan2(dir.x, dir.z)
	life.play.say("Wheee!", 0.4)
	life.play.ride(2.2, func(k: float, _s: float) -> void:
		var e := k * k * (3.0 - 2.0 * k)
		var p := top.lerp(bottom, e)
		p.y = lerpf(top.y, bottom.y, e)
		life.play._place_her(p, face),
		func() -> void:
			life.explorer.global_position = bottom + dir * 0.8 + Vector3(0, 0.1, 0))


func _peek(from: Vector3, face: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 1200.0
	corner.add_child(cam)
	cam.global_position = from + Vector3(0, 1.5, 0)
	cam.make_current()
	life.explorer.busy = 6.0
	if life.stickers:
		life.stickers._say_later("Peekaboo!", 0.4)
	var base := atan2(face.x, face.z)
	var tw := cam.create_tween()
	tw.tween_method(func(a: float) -> void:
		cam.look_at(from + Vector3(sin(a) * 20.0, -3.4, cos(a) * 20.0), Vector3.UP), base - 1.1, base + 1.1, 6.0).set_trans(Tween.TRANS_SINE)
	await tw.finished
	cam.queue_free()
	corner.follow.cam.make_current()


func _flames(at: Vector3) -> void:
	var fl := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	g.add_point(0.4, Color(1.0, 0.5, 0.15, 0.9))
	g.set_color(g.get_point_count() - 1, Color(0.6, 0.15, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	fl.process_material = pm
	fl.amount = 40
	fl.lifetime = 0.9
	var qm := QuadMesh.new()
	qm.size = Vector2(0.35, 0.35)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	fm.albedo_texture = preload("res://space/rocket.gd")._soft_dot()
	qm.material = fm
	fl.draw_pass_1 = qm
	fl.position = at
	fl.visibility_range_end = 80.0
	add_child(fl)


func _fireflies(at: Vector3) -> void:
	var f := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10, 1.5, 10)
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
	f.process_material = pm
	f.amount = 40
	f.lifetime = 6.0
	f.preprocess = 6.0
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
	f.draw_pass_1 = qm
	f.position = at
	f.visibility_range_end = 70.0
	add_child(f)


func _warm(at: Vector3) -> void:
	life.explorer.act("emote-yes", 1.2)
	if life.stickers:
		life.stickers._say_later("Nice and warm!", 0.3)
	if life.play:
		for k in 3:
			life.play._burst(at + Vector3(randf_range(-0.3, 0.3), 0.6 + k * 0.5, randf_range(-0.3, 0.3)), Color(1.0, 0.6, 0.2), 24)
	var tw := create_tween()
	tw.tween_property(_fire_light, "light_energy", 4.0, 0.3)
	tw.tween_property(_fire_light, "light_energy", 1.6, 1.5)


func _hoot() -> void:
	_hoot_t = 2.5
	if life.stickers:
		life.stickers._say_later("Hoo hoo!", 0.2)
	var p := AudioStreamPlayer3D.new()
	p.stream = life.sound.pick("owl")
	p.bus = "Animals"
	p.max_distance = 60.0
	_owl.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	var tw := create_tween()
	tw.tween_property(_owl, "rotation:y", _owl.rotation.y + PI * 0.6, 0.5).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.8)
	tw.tween_property(_owl, "rotation:y", _owl.rotation.y, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_owl, "scale", _owl.scale * 1.15, 0.15)
	tw.tween_property(_owl, "scale", _owl.scale, 0.2)


## A frog hops to another lily pad (or straight up, croaking, when greeted).
func _frog_hop(i: int, greeted := false) -> void:
	if i < 0:
		return
	var f: Array = _frogs[i]
	var fr: Node3D = f[0]
	var ap := f[1] as AnimationPlayer
	var from: Vector3 = fr.position
	var to_i: int = f[2]
	if not greeted:
		to_i = (to_i + 1 + randi() % (_lilies.size() - 1)) % _lilies.size()
		for other in _frogs:
			if other != f and other[2] == to_i:
				return
	var to: Vector3 = _lilies[to_i]
	f[2] = to_i
	if ap:
		for an in ap.get_animation_list():
			if String(an).ends_with("Jump"):
				ap.play(an, 0.1)
				ap.queue(String(an).replace("Jump", "Idle"))
	if to != from:
		fr.rotation.y = atan2(to.x - from.x, to.z - from.z)
	if greeted:
		var p := AudioStreamPlayer3D.new()
		p.stream = life.sound.pick("frog")
		p.bus = "Animals"
		fr.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		fr.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * (0.5 if greeted else 0.35), 0), 0.0, 1.0, 0.55)


func _process(delta: float) -> void:
	_t += delta
	if _fire_light:
		_fire_light.light_energy = maxf(_fire_light.light_energy, 0.0)
		if _fire_light.light_energy < 2.0:
			_fire_light.light_energy = 1.4 + 0.25 * sin(_t * 9.0) + 0.15 * sin(_t * 23.0)
	_hoot_t -= delta
	if _owl and _hoot_t <= 0.0 and int(_t) % 9 < 6:
		_owl.rotation.y = lerp_angle(_owl.rotation.y, sin(_t * 0.35) * 0.9, 1.0 - exp(-delta * 3.0))
	for i in _frogs.size():
		_frogs[i][3] -= delta
		if _frogs[i][3] <= 0.0:
			_frogs[i][3] = randf_range(4.0, 10.0)
			_frog_hop(i)
