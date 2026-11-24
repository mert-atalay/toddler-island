extends RefCounted
## The island's places beyond the farmyard, each built round a landmark you can see from the next:
## the cottage and garden (the start, chimney), the windmill hill, the orchard (big apple trees and
## beehives), the wood (a tall oak), the pond (a jetty and a rowing boat) and the beach (a lighthouse).
## The free model packs had no cottage, jetty, boat, beehive or lighthouse, so those are built from
## simple shapes in the same low-poly style.

const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const N := "res://assets/nature/quaternius/"
const P := "res://assets/props/quaternius/"
const B := "res://assets/buildings/quaternius-farm/"

static var _mats := {}
static var glows: Array = []  # window and lamp materials that light up at dusk


static func glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.45)
	m.emission_energy_multiplier = 0.0
	glows.append(m)
	return m


static func mat(c: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var key := "%s %.2f %.2f" % [c.to_html(), rough, emit]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if emit > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emit
		_mats[key] = m
	return _mats[key]


## A box (or cylinder when `round` > 0) under `parent`, in its local space.
static func block(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO, round := 0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	if round > 0:
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 0.5
		cm.bottom_radius = size.z * 0.5
		cm.height = size.y
		cm.radial_segments = round
		cm.rings = 1
		inst.mesh = cm
	else:
		var bm := BoxMesh.new()
		bm.size = size
		inst.mesh = bm
	inst.material_override = m
	inst.position = pos
	inst.rotation_degrees = rot
	inst.set_meta("block", true)
	parent.add_child(inst)
	return inst


static func solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = pos
	body.add_child(shape)
	parent.add_child(body)


static func root_at(corner: Node3D, at: Vector2, yaw_deg := 0.0) -> Node3D:
	var r := Node3D.new()
	r.position = Vector3(at.x, Terrain.height(at.x, at.y), at.y)
	r.rotation_degrees.y = yaw_deg
	corner.add_child(r)
	return r


static func build(corner: Node3D) -> void:
	_cottage(corner)
	_hill(corner)
	_orchard(corner)
	_wood(corner)
	_pond(corner)
	_beach(corner)
	_visitor_field(corner)


# --- the cottage and garden (the start) ----------------------------------------------------

static func _cottage(corner: Node3D) -> void:
	var c := Terrain.COTTAGE
	var r := root_at(corner, c)
	var wall := mat(Color(0.95, 0.9, 0.78))
	var trim := mat(Color(0.98, 0.98, 0.96))
	var roof := mat(Color(0.72, 0.32, 0.22))
	var wood := mat(Color(0.45, 0.3, 0.18))
	var glass := glow_mat(Color(0.55, 0.75, 0.9))
	var stone := mat(Color(0.62, 0.6, 0.58))
	# walls, base and a pitched roof; the front with the door faces north, toward the path
	block(r, Vector3(7.4, 0.4, 5.4), Vector3(0, 0.2, 0), stone)
	block(r, Vector3(7.0, 3.0, 5.0), Vector3(0, 1.9, 0), wall)
	for side in [-1.0, 1.0]:
		block(r, Vector3(7.8, 0.22, 3.4), Vector3(0, 4.35, side * 1.37), roof, Vector3(side * 36.0, 0, 0))
	# gable ends
	for gx in [-3.5, 3.5]:
		var g := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(5.0, 2.0, 0.2)
		g.mesh = pm
		g.material_override = wall
		g.position = Vector3(gx, 4.4, 0)
		g.rotation_degrees.y = 90.0
		r.add_child(g)
	block(r, Vector3(0.7, 2.4, 0.7), Vector3(2.0, 5.2, 0.9), stone)     # the chimney: the cottage's landmark
	block(r, Vector3(0.85, 0.2, 0.85), Vector3(2.0, 6.45, 0.9), mat(Color(0.4, 0.38, 0.36)))
	# door, step and windows on the front
	block(r, Vector3(1.1, 2.0, 0.12), Vector3(0, 1.4, -2.52), wood)
	block(r, Vector3(1.4, 0.2, 0.9), Vector3(0, 0.3, -2.95), stone)
	block(r, Vector3(0.12, 0.12, 0.05), Vector3(0.35, 1.4, -2.6), mat(Color(0.85, 0.7, 0.2), 0.3))
	for wx in [-2.3, 2.3]:
		block(r, Vector3(1.3, 1.1, 0.1), Vector3(wx, 2.1, -2.53), trim)
		block(r, Vector3(1.05, 0.85, 0.12), Vector3(wx, 2.1, -2.55), glass)
		block(r, Vector3(1.4, 0.12, 0.35), Vector3(wx, 1.5, -2.65), mat(Color(0.6, 0.38, 0.25)))  # flower box
	for wz in [-1.0, 1.0]:
		for sx in [-3.53, 3.53]:
			block(r, Vector3(0.1, 1.0, 1.1), Vector3(sx, 2.1, wz), glass)
	solid(r, Vector3(7.4, 4.5, 5.4), Vector3(0, 2.25, 0))
	corner.blocked.append([c, 4.6])
	# flowers in the window boxes
	for wx in [-2.3, 2.3]:
		for k in 5:
			block(r, Vector3(0.12, 0.12, 0.12), Vector3(wx - 0.5 + k * 0.25, 1.65, -2.66),
				mat([Color(0.95, 0.4, 0.5), Color(1.0, 0.85, 0.3), Color(0.7, 0.5, 0.95)][k % 3]), Vector3.ZERO, 6)
	# the garden: a low fence with a gap for the path
	var x0 := c.x - 9.0
	var x1 := c.x + 9.0
	var z0 := c.y - 8.0
	var z1 := c.y + 8.0
	_low_fence(corner, Vector2(x0, z0), Vector2(c.x - 1.4, z0))
	_low_fence(corner, Vector2(c.x + 1.4, z0), Vector2(x1, z0))
	_low_fence(corner, Vector2(x1, z0), Vector2(x1, z1))
	_low_fence(corner, Vector2(x1, z1), Vector2(x0, z1))
	_low_fence(corner, Vector2(x0, z1), Vector2(x0, z0))
	# vegetable patch with carrots in rows
	var veg := root_at(corner, Vector2(c.x - 5.5, c.y - 4.6))
	block(veg, Vector3(4.2, 0.08, 2.6), Vector3(0, 0.03, 0), mat(Color(0.42, 0.29, 0.18), 1.0))
	for row in 3:
		for k in 7:
			var top := Models.spawn(veg, P + "Carrot.gltf", 0.22, 90.0)
			if top:
				top.position = Vector3(-1.6 + k * 0.53, 0.02, -0.8 + row * 0.8)
				top.rotation_degrees.x = -70.0
	corner.blocked.append([Vector2(c.x - 5.5, c.y - 4.6), 2.2])
	# washing line with bright clothes
	var line := root_at(corner, Vector2(c.x + 5.5, c.y - 5.0))
	for px in [-1.8, 1.8]:
		block(line, Vector3(0.1, 2.0, 0.1), Vector3(px, 1.0, 0), wood)
	block(line, Vector3(3.6, 0.02, 0.02), Vector3(0, 1.9, 0), mat(Color(0.9, 0.9, 0.9)))
	var cloth := [Color(0.95, 0.45, 0.45), Color(0.45, 0.65, 0.95), Color(1.0, 0.85, 0.35), Color(0.6, 0.85, 0.55)]
	for k in 4:
		block(line, Vector3(0.55, 0.7, 0.02), Vector3(-1.2 + k * 0.8, 1.52, 0), mat(cloth[k], 0.95))
	corner.blocked.append([Vector2(c.x + 5.5, c.y - 5.0), 2.0])
	# the dog's kennel and a bench by the door
	var ken := root_at(corner, Vector2(c.x + 6.0, c.y + 1.5), -90.0)
	block(ken, Vector3(1.0, 0.75, 1.1), Vector3(0, 0.38, 0), mat(Color(0.75, 0.42, 0.3)))
	for side in [-1.0, 1.0]:
		block(ken, Vector3(1.2, 0.08, 0.75), Vector3(0, 0.98, side * 0.28), roof, Vector3(side * 38.0, 0, 0))
	block(ken, Vector3(0.45, 0.5, 0.05), Vector3(0, 0.3, -0.56), mat(Color(0.18, 0.12, 0.08)))
	solid(ken, Vector3(1.1, 1.0, 1.2), Vector3(0, 0.5, 0))
	corner.blocked.append([Vector2(c.x + 6.0, c.y + 1.5), 1.0])
	corner.put(P + "Bench.gltf", 0.48, c.x + 2.9, c.y - 3.5, 0.0)
	corner.put(P + "Bucket_Wooden_1.gltf", 0.35, c.x - 2.4, c.y - 3.1, 0.0, false)


static func _low_fence(corner: Node3D, a: Vector2, b: Vector2) -> void:
	corner.fence_lines.append([a, b])
	var d := b - a
	var count := maxi(1, roundi(d.length() / 3.0))
	var yaw := atan2(-d.y, d.x)
	for i in count:
		var c := a + d * (i + 0.5) / count
		var holder := Models.spawn(corner, B + "Fence.fbx", 0.8, 0.0)
		var seg: float = (holder.get_meta("size") as Vector3).x
		holder.position = Vector3(c.x, Terrain.height(c.x, c.y) - 0.04, c.y)
		holder.rotation.y = yaw
		holder.scale.x = (d.length() / count) / seg
		solid(holder, Vector3(seg, 1.0, 0.3), Vector3(0, 0.5, 0))
	for t in range(0, int(d.length()), 1):
		corner.fence_points.append([a + d.normalized() * t, Vector2(-d.y, d.x).normalized()])


# --- the windmill hill ----------------------------------------------------------------------

static func _hill(corner: Node3D) -> void:
	var h := Terrain.HILL
	corner.put(B + "Windmill.fbx", 12.0, h.x, h.y, 25.0, true, 3.0)
	corner.put(P + "Bench.gltf", 0.48, h.x + 3.8, h.y + 4.0, 200.0)
	for r in [[h.x - 6.0, h.y + 3.0, 1.4], [h.x + 7.0, h.y - 3.0, 1.1], [h.x - 3.0, h.y - 7.0, 0.9]]:
		corner.put(N + "Rock_Medium_1.gltf", r[2], r[0], r[1], randf() * 360.0)


# --- the orchard ----------------------------------------------------------------------------

static func _orchard(corner: Node3D) -> void:
	var o := Terrain.ORCHARD
	for off in [Vector2(-6, -5), Vector2(0, -6.5), Vector2(6, -4.5), Vector2(-5, 2), Vector2(1, 1.5), Vector2(7, 3)]:
		var p: Vector2 = o + off
		corner.put(N + "CommonTree_1.gltf", randf_range(4.6, 5.6), p.x, p.y, randf() * 360.0, false, 1.5)
		corner._trunk(p.x, p.y, 0.35)
		corner._apples(p.x, p.y)
	corner.put(P + "FarmCrate_Apple.gltf", 0.45, o.x - 7.5, o.y + 0.5, 30.0)
	corner.put(P + "Barrel_Apples.gltf", 0.95, o.x + 2.5, o.y + 6.0, 0.0)
	corner.put(P + "FarmCrate_Empty.gltf", 0.4, o.x + 0.5, o.y + 6.8, -20.0)
	# two beehives at the orchard's edge
	for k in 2:
		var hive := root_at(corner, o + Vector2(10.5, -4.0 + k * 2.4), -90.0)
		block(hive, Vector3(0.7, 0.18, 0.7), Vector3(0, 0.09, 0), mat(Color(0.45, 0.3, 0.18)))
		for lvl in 3:
			block(hive, Vector3(0.6, 0.26, 0.6), Vector3(0, 0.32 + lvl * 0.27, 0), mat([Color(0.98, 0.95, 0.85), Color(1.0, 0.86, 0.45), Color(0.98, 0.95, 0.85)][lvl]))
		block(hive, Vector3(0.75, 0.08, 0.75), Vector3(0, 1.16, 0), mat(Color(0.72, 0.32, 0.22)))
		corner.blocked.append([o + Vector2(10.5, -4.0 + k * 2.4), 0.6])


# --- the wood -------------------------------------------------------------------------------

static func _wood(corner: Node3D) -> void:
	var t := Terrain.OAK
	corner.put(N + "CommonTree_3.gltf", 17.0, t.x, t.y, 30.0, false, 2.5)  # the tall oak: the wood's landmark
	corner._trunk(t.x, t.y, 0.8)
	var logs := root_at(corner, t + Vector2(3.0, -6.5), 20.0)
	for k in 5:
		var lx: float = [-0.45, 0.0, 0.45, -0.22, 0.22][k]
		var ly: float = [0.22, 0.22, 0.22, 0.6, 0.6][k]
		block(logs, Vector3(0.42, 2.2, 0.42), Vector3(lx, ly, 0), mat(Color(0.5, 0.34, 0.2)), Vector3(90, 0, 0), 8)
	solid(logs, Vector3(1.5, 0.9, 2.2), Vector3(0, 0.45, 0))
	corner.blocked.append([t + Vector2(3.0, -6.5), 1.6])


# --- the pond -------------------------------------------------------------------------------

static func _pond(corner: Node3D) -> void:
	var p := Terrain.POND
	var deck := mat(Color(0.6, 0.43, 0.27))
	var jetty := Node3D.new()
	jetty.position = Vector3(p.x + 2.5, 0.0, p.y + 7.0)
	corner.add_child(jetty)
	for k in 14:
		block(jetty, Vector3(1.6, 0.08, 0.42), Vector3(0, 0.55, 4.6 - k * 0.5), deck)
	for side in [-0.72, 0.72]:
		for k in 4:
			block(jetty, Vector3(0.14, 1.6, 0.14), Vector3(side, -0.15, 4.4 - k * 2.0), mat(Color(0.42, 0.3, 0.2)))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.1, 7.0)
	shape.shape = box
	body.position = Vector3(0, 0.55, 1.35)
	body.add_child(shape)
	jetty.add_child(body)
	corner.blocked.append([p, 9.5])


# --- the visitor field: one zoo animal comes to stay each day -----------------------------

static func _visitor_field(corner: Node3D) -> void:
	var v := Terrain.VISITOR
	var x0 := v.x - 8.0
	var x1 := v.x + 8.0
	var z0 := v.y - 6.0
	var z1 := v.y + 6.0
	_low_fence(corner, Vector2(x0, z1), Vector2(v.x - 1.5, z1))
	_low_fence(corner, Vector2(v.x + 1.5, z1), Vector2(x1, z1))
	_low_fence(corner, Vector2(x1, z1), Vector2(x1, z0))
	_low_fence(corner, Vector2(x1, z0), Vector2(x0, z0))
	_low_fence(corner, Vector2(x0, z0), Vector2(x0, z1))
	corner.put(P + "FarmCrate_Carrot.gltf", 0.45, v.x + 2.6, v.y + 4.6, 10.0)


# --- the beach and the lighthouse -------------------------------------------------------------

static func _beach(corner: Node3D) -> void:
	var l := Terrain.LIGHTHOUSE
	for rk in [[0.0, 0.0, 3.0], [2.2, 1.5, 2.0], [-2.0, 1.8, 1.8]]:
		corner.put(N + "Rock_Medium_1.gltf", rk[2], l.x + rk[0], l.y + rk[1], randf() * 360.0)
	var base := Terrain.height(l.x, l.y) + 2.2
	var tower := Node3D.new()
	tower.position = Vector3(l.x, base, l.y)
	corner.add_child(tower)
	var white := mat(Color(0.97, 0.97, 0.95))
	var red := mat(Color(0.82, 0.2, 0.18))
	for k in 4:
		var r0: float = 1.7 - k * 0.12
		block(tower, Vector3(r0 * 2.0 - 0.24, 2.4, r0 * 2.0), Vector3(0, 1.2 + k * 2.4, 0), red if k % 2 == 1 else white, Vector3.ZERO, 16)
	block(tower, Vector3(3.0, 0.2, 3.0), Vector3(0, 9.7, 0), mat(Color(0.25, 0.25, 0.28)), Vector3.ZERO, 16)
	block(tower, Vector3(1.8, 1.4, 1.8), Vector3(0, 10.5, 0), glow_mat(Color(1.0, 0.95, 0.7)), Vector3.ZERO, 12)
	var cap := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.2
	cone.height = 1.3
	cone.radial_segments = 12
	cap.mesh = cone
	cap.material_override = red
	cap.position = Vector3(0, 11.85, 0)
	tower.add_child(cap)
	solid(tower, Vector3(3.2, 10.0, 3.2), Vector3(0, 5.0, 0))
	corner.blocked.append([l, 4.0])
	# shells on the sand
	var shell := SphereMesh.new()
	shell.radius = 0.05
	shell.height = 0.05
	shell.radial_segments = 8
	shell.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = shell
	var spots: Array = []
	for i in 2000:
		var a := randf() * TAU
		var d := randf_range(60.0, 82.0)
		var x := Terrain.CENTRE.x + cos(a) * d
		var z := Terrain.CENTRE.y + sin(a) * d
		var h := Terrain.height(x, z)
		if Terrain.is_sand(x, z) > 0.6 and h > 0.05 and h < 0.6:
			spots.append(Vector3(x, h + 0.01, z))
		if spots.size() >= 120:
			break
	mm.instance_count = spots.size()
	var shell_mat := StandardMaterial3D.new()
	shell_mat.vertex_color_use_as_albedo = true
	shell.material = shell_mat
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(1.4, 0.5, 1.0)), spots[i]))
		mm.set_instance_color(i, [Color(1.0, 0.92, 0.88), Color(1.0, 0.75, 0.7), Color(0.95, 0.93, 0.85)][i % 3])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	corner.add_child(mmi)
