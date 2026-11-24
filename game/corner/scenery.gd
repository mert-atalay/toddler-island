extends RefCounted
## Depth for the world: distant islands with pine woods out on the sea (the haze makes them read as
## far away), big rocks along the shoreline, reeds round the pond, and patches of wildflower meadow.
## Everything here is drawn in batches (one draw per kind), so it costs little.

const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const N := "res://assets/nature/quaternius/"
const NK := "res://assets/kits/nature/"


static func build(corner: Node3D) -> void:
	_reeds(corner)
	_meadows(corner)


## One batch of copies of a model: transforms are [Vector3 position, yaw, height].
static func batch(corner: Node3D, path: String, items: Array, shadows := false, range_end := 0.0, tint := Color(0, 0, 0, 0)) -> MultiMeshInstance3D:
	if items.is_empty() or not ResourceLoader.exists(path):
		return null
	# every mesh part of the model (a flower is a stem and petals), each as one batch
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var parts: Array = []
	var box := AABB()
	var first := true
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != inst and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		parts.append([mi.mesh, xf, mi])
		var bb: AABB = xf * mi.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	if parts.is_empty():
		inst.free()
		return null
	var native := maxf(box.size.y, 0.001)
	var last: MultiMeshInstance3D = null
	for part in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = items.size()
		for i in items.size():
			var it: Array = items[i]
			var sc := float(it[2]) / native
			var pxf: Transform3D = part[1]
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, float(it[1])).scaled(Vector3.ONE * sc), it[0]) * pxf
			xf.origin.y -= box.position.y * sc
			mm.set_instance_transform(i, xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var src := part[2] as MeshInstance3D
		for k in src.get_surface_override_material_count():
			var om := src.get_surface_override_material(k)
			if om:
				mmi.set_surface_override_material(k, om)
		if src.material_override:
			mmi.material_override = src.material_override
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if range_end > 0.0:
			mmi.visibility_range_end = range_end
		if tint.a > 0.0:
			var m2 := StandardMaterial3D.new()
			m2.albedo_color = tint
			m2.roughness = 0.95
			m2.cull_mode = BaseMaterial3D.CULL_DISABLED
			mmi.material_override = m2
		corner.add_child(mmi)
		last = mmi
	inst.free()
	return last


# --- far islands ------------------------------------------------------------------------------

static func _far_islands(corner: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.06
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var pines: Array = []
	var islands := [[-0.3, 330.0, 55.0, 26.0], [0.55, 420.0, 80.0, 38.0], [1.6, 300.0, 40.0, 16.0],
		[2.4, 380.0, 65.0, 30.0], [3.3, 460.0, 95.0, 44.0], [4.4, 340.0, 50.0, 20.0], [5.4, 400.0, 70.0, 34.0]]
	for isl in islands:
		var a: float = isl[0]
		var dist: float = isl[1]
		var r: float = isl[2]
		var hgt: float = isl[3]
		var c := Terrain.CENTRE + Vector2(cos(a), sin(a)) * dist
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := 16
		var segs := 40
		var pts: Array = []
		for i in rings + 1:
			var row: Array = []
			for j in segs:
				var ang := j * TAU / segs
				var rr := float(i) / rings
				var edge := r * (1.0 + 0.25 * noise.get_noise_2d(cos(ang) * 10.0 + a * 50.0, sin(ang) * 10.0))
				var x := cos(ang) * edge * rr
				var z := sin(ang) * edge * rr
				var h := hgt * pow(maxf(0.0, 1.0 - rr * rr), 1.3) * (0.8 + 0.4 * noise.get_noise_2d(x * 0.5 + a * 20.0, z * 0.5)) - 3.0 * rr * rr
				row.append(Vector3(c.x + x, h, c.y + z))
			pts.append(row)
		for i in rings:
			for j in segs:
				var j2 := (j + 1) % segs
				var quad := [pts[i][j], pts[i + 1][j], pts[i][j2], pts[i + 1][j], pts[i + 1][j2], pts[i][j2]]
				for v in quad:
					var p: Vector3 = v
					var col := Color(0.86, 0.8, 0.6) if p.y < 1.6 else Color(0.42, 0.6, 0.34).lerp(Color(0.5, 0.5, 0.46), clampf((p.y - hgt * 0.6) / (hgt * 0.4), 0.0, 1.0))
					st.set_color(col)
					st.add_vertex(p)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		corner.add_child(mi)
		# pine woods on the slopes
		for k in int(r * 0.9):
			var ang := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * 0.75
			var x := c.x + cos(ang) * r * rr
			var z := c.y + sin(ang) * r * rr
			var h := hgt * pow(maxf(0.0, 1.0 - rr * rr), 1.3) * 0.85 - 3.0 * rr * rr
			if h < 2.5:
				continue
			pines.append([Vector3(x, h - 0.5, z), rng.randf() * TAU, rng.randf_range(9.0, 16.0)])
	var by_file := {}
	for p in pines:
		var f: String = ["Pine_1", "Pine_2", "Pine_3", "Pine_4"][rng.randi() % 4]
		if not by_file.has(f):
			by_file[f] = []
		(by_file[f] as Array).append(p)
	for f in by_file:
		batch(corner, N + f + ".gltf", by_file[f])


# --- big rocks along the shore ----------------------------------------------------------------

static func _shore_rocks(corner: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var kinds := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
	var groups := {}
	var placed: Array = []
	for i in 900:
		if placed.size() >= 46:
			break
		var a := rng.randf() * TAU
		var x0 := Terrain.CENTRE.x + cos(a) * 80.0
		var z0 := Terrain.CENTRE.y + sin(a) * 80.0
		var r := Terrain.shore_radius(x0, z0) - rng.randf_range(4.0, 11.0)
		var x := Terrain.CENTRE.x + cos(a) * r
		var z := Terrain.CENTRE.y + sin(a) * r
		var p := Vector2(x, z)
		var h := Terrain.height(x, z)
		if h < -0.6 or Terrain.path_distance(x, z) < 3.5:
			continue
		if p.distance_to(Terrain.LIGHTHOUSE) < 9.0 or p.distance_to(Terrain.ROCKET) < 10.0:
			continue
		var clear := true
		for b in corner.blocked:
			if p.distance_to(b[0]) < float(b[1]) + 1.5:
				clear = false
				break
		for q in placed:
			if p.distance_to(q) < 4.0:
				clear = false
				break
		if not clear:
			continue
		placed.append(p)
		var f: String = kinds[rng.randi() % kinds.size()]
		if not groups.has(f):
			groups[f] = []
		(groups[f] as Array).append([Vector3(x, h - 0.3, z), rng.randf() * TAU, rng.randf_range(1.0, 2.8)])
		# a couple of small ones beside it
		for k in 2:
			var q2 := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.5, 2.5)
			var g2: String = "RockPath_Round_Small_1" if k == 0 else "RockPath_Round_Small_2"
			if not groups.has(g2):
				groups[g2] = []
			(groups[g2] as Array).append([Vector3(q2.x, Terrain.height(q2.x, q2.y) - 0.05, q2.y), rng.randf() * TAU, rng.randf_range(0.2, 0.4)])
		corner.blocked.append([p, 1.6])
	for f in groups:
		batch(corner, N + f + ".gltf", groups[f], f.begins_with("Rock_"), 160.0)


# --- reeds round the pond ---------------------------------------------------------------------

static func _reeds(corner: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var tall: Array = []
	var short: Array = []
	var p := Terrain.POND
	for i in 400:
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.6, 10.6)
		var x := p.x + cos(a) * r
		var z := p.y + sin(a) * r
		# not on the jetty, the path to it, or the stream mouth
		if absf(x - (p.x + 2.5)) < 2.2 and z > p.y + 3.0:
			continue
		if Terrain.path_distance(x, z) < 1.6 or Terrain.stream_distance(x, z) < 2.0:
			continue
		var h := Terrain.height(x, z)
		if h < -0.35 or h > 0.6:
			continue
		var item := [Vector3(x, h - 0.05, z), rng.randf() * TAU, rng.randf_range(0.7, 1.1)]
		if rng.randf() < 0.55:
			tall.append(item)
		else:
			short.append(item)
	batch(corner, N + "Grass_Wispy_Tall.gltf", tall, false, 90.0)
	batch(corner, N + "Grass_Common_Tall.gltf", short, false, 70.0)


# --- wildflower meadows -----------------------------------------------------------------------

static func _meadows(corner: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var patches := [Terrain.HILL + Vector2(-12, 14), Terrain.HILL + Vector2(14, 9), Vector2(-28, 16),
		Terrain.VISITOR + Vector2(14, 10), Vector2(18, 38), Terrain.ORCHARD + Vector2(10, 12)]
	var groups := {"Flower_3_Group": [], "Flower_4_Group": [], "Flower_3_Single": []}
	for c in patches:
		for i in 70:
			var q: Vector2 = c + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0)) * (0.4 + rng.randf() * 0.6)
			var h := Terrain.height(q.x, q.y)
			if h < 0.3 or Terrain.path_distance(q.x, q.y) < 1.6 or Terrain.is_sand(q.x, q.y) > 0.3:
				continue
			var ok := true
			for b in corner.blocked:
				if q.distance_to(b[0]) < float(b[1]):
					ok = false
					break
			if not ok:
				continue
			var f: String = groups.keys()[rng.randi() % 3]
			(groups[f] as Array).append([Vector3(q.x, h - 0.02, q.y), rng.randf() * TAU, rng.randf_range(0.35, 0.6)])
	for f in groups:
		batch(corner, N + f + ".gltf", groups[f], false, 60.0)
