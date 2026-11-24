extends RefCounted
## The Moon's surface for the landing: 200 m of grey dust with craters of every size (bowls with
## raised rims), gentle rolling ground, scattered rocks from the Space Kit, and a flat landing spot in
## the middle. Heights come from one function so the rocket, footprints and rocks all sit on it.

const Models := preload("res://lib/models.gd")
const SK := "res://assets/kits/space/"
const SIZE := 200.0
const STEP := 1.0

static var _craters: Array = []   # [Vector2 centre, radius, depth]
static var _noise: FastNoiseLite


static func _setup() -> void:
	if _noise:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 1969
	_noise.frequency = 0.02
	var rng := RandomNumberGenerator.new()
	rng.seed = 1969
	while _craters.size() < 70:
		var r := pow(rng.randf(), 2.2) * 11.0 + 1.2
		var c := Vector2(rng.randf_range(-95, 95), rng.randf_range(-95, 95))
		if c.length() < r + 9.0:
			continue  # keep the landing spot clear
		_craters.append([c, r, r * rng.randf_range(0.18, 0.28)])


## Height of the ground at (x, z), in the surface's own space (the landing spot is at 0, 0).
static func height(x: float, z: float) -> float:
	_setup()
	var p := Vector2(x, z)
	var h := 0.9 * _noise.get_noise_2d(x, z) + 0.25 * _noise.get_noise_2d(x * 4.0, z * 4.0)
	for c in _craters:
		var d := p.distance_to(c[0])
		var r: float = c[1]
		if d > r * 1.8:
			continue
		var depth: float = c[2]
		var bowl := -depth * maxf(0.0, 1.0 - (d / r) * (d / r))
		var rim := depth * 0.45 * exp(-pow((d - r) / (r * 0.28), 2.0))
		h += bowl + rim
	# the landing spot is flat
	var flat := clampf((p.length() - 6.0) / 6.0, 0.0, 1.0)
	return h * flat * flat * (3.0 - 2.0 * flat)


## Builds the surface under `parent` (a Node3D at the surface's origin). Returns the ground body.
static func build(parent: Node3D) -> StaticBody3D:
	_setup()
	var count := int(SIZE / STEP) + 1
	var half := SIZE * 0.5
	var hs := PackedFloat32Array()
	hs.resize(count * count)
	for j in count:
		for i in count:
			hs[j * count + i] = height(-half + i * STEP, -half + j * STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in count:
		for i in count:
			var x := -half + i * STEP
			var z := -half + j * STEP
			var h := hs[j * count + i]
			var hl := hs[j * count + maxi(i - 1, 0)]
			var hr := hs[j * count + mini(i + 1, count - 1)]
			var hd := hs[maxi(j - 1, 0) * count + i]
			var hu := hs[mini(j + 1, count - 1) * count + i]
			var n := Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
			var g := 0.4 + 0.08 * _noise.get_noise_2d(x * 3.0 + 50.0, z * 3.0) + h * 0.04
			st.set_color(Color(g, g, g * 0.98))
			st.set_normal(n)
			st.set_uv(Vector2(x, z) * 0.25)
			st.add_vertex(Vector3(x, h, z))
	for j in count - 1:
		for i in count - 1:
			var a := j * count + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + count)
			st.add_index(a + 1)
			st.add_index(a + count + 1)
			st.add_index(a + count)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	var tex := NoiseTexture2D.new()
	var tn := FastNoiseLite.new()
	tn.frequency = 0.08
	tex.noise = tn
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	m.albedo_texture = tex
	m.uv1_scale = Vector3(1, 1, 1)
	m.detail_enabled = false
	mi.material_override = m
	parent.add_child(mi)
	# the ground to stand on
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = count
	hm.map_depth = count
	hm.map_data = hs
	shape.shape = hm
	body.add_child(shape)
	parent.add_child(body)
	# rocks scattered about, more of the small ones
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kinds := [["rocks_smallA", 0.3], ["rocks_smallB", 0.35], ["rock", 0.7], ["rock_largeA", 1.4], ["rock_largeB", 1.8], ["meteor", 0.9]]
	for k in 70:
		var p := Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))
		if p.length() < 9.0:
			continue
		var kind: Array = kinds[mini(int(pow(rng.randf(), 1.8) * kinds.size()), kinds.size() - 1)]
		var r := Models.spawn(parent, SK + kind[0] + ".glb", float(kind[1]) * rng.randf_range(0.7, 1.4), rng.randf() * 360.0)
		if r:
			r.position = Vector3(p.x, height(p.x, p.y) - 0.08, p.y)
			for g in r.find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).material_override = _rock_mat()
	return body


static var _rm: StandardMaterial3D


static func _rock_mat() -> StandardMaterial3D:
	if _rm == null:
		_rm = StandardMaterial3D.new()
		_rm.albedo_color = Color(0.55, 0.54, 0.52)
		_rm.roughness = 1.0
	return _rm
