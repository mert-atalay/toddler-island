extends Node3D

const Models := preload("res://lib/models.gd")
## The island's richer look: painted ground, the grass field, sea and pond water with foam, the stream,
## drifting clouds whose shadows cross the land, morning mist over the pond, and the real night sky
## with the Moon. Keeps the shared shader values (wind, cloud shadows, where she stands) up to date.

const Terrain := preload("res://corner/terrain.gd")
const GROUND := preload("res://look/ground.gdshader")
const GRASS := preload("res://look/grass.gdshader")
const WATER := preload("res://look/water.gdshader")
const STREAM := preload("res://look/stream.gdshader")
const NIGHT := preload("res://look/night_sky.gdshader")
const MOON := preload("res://look/moon_disc.gdshader")

var corner: Node3D
var noise_tex: NoiseTexture2D
var paint: Image
var paint_tex: ImageTexture
var clouds := Node3D.new()
var stars_mat: ShaderMaterial
var moon: MeshInstance3D
var moon_mat: ShaderMaterial
var mist: Array[MeshInstance3D] = []
var night := 0.0       # set by the day: 0 by day, 1 at night
var morning := 1.0     # set by the day: 1 early, 0 later
var _cloud_off := Vector2.ZERO


static func globals() -> void:
	pass  # declared in project.godot under [shader_globals]


func _init() -> void:
	noise_tex = NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	noise_tex.noise = fn
	noise_tex.seamless = true
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.generate_mipmaps = true


func ground_material() -> ShaderMaterial:
	paint = Terrain.paint_image()
	paint_tex = ImageTexture.create_from_image(paint)
	var m := ShaderMaterial.new()
	m.shader = GROUND
	m.set_shader_parameter("paint", paint_tex)
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("world_size", Terrain.SIZE)
	return m


func path_paint(x: float, z: float) -> float:
	var res := paint.get_width()
	var px := clampi(int((x + Terrain.SIZE * 0.5) / Terrain.SIZE * res), 0, res - 1)
	var py := clampi(int((z + Terrain.SIZE * 0.5) / Terrain.SIZE * res), 0, res - 1)
	return paint.get_pixel(px, py).r


# --- water ------------------------------------------------------------------------------------

func build_water() -> void:
	var count := int(Terrain.SIZE / Terrain.STEP) + 1
	var img := Image.create_from_data(count, count, false, Image.FORMAT_RF, Terrain.heights.to_byte_array())
	var m := ShaderMaterial.new()
	m.shader = WATER
	m.set_shader_parameter("height_tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("world_size", Terrain.SIZE)
	# fine near the island so waves and foam read, coarse far out
	for ring in [[Vector2(30, 8), 260.0, 260], [Vector2(30, 8), 3000.0, 60]]:
		var plane := PlaneMesh.new()
		plane.size = Vector2(ring[1], ring[1])
		plane.subdivide_width = ring[2]
		plane.subdivide_depth = ring[2]
		var sea := MeshInstance3D.new()
		sea.mesh = plane
		sea.material_override = m
		sea.position = Vector3(ring[0].x, Terrain.SEA - (0.0 if ring[1] < 1000.0 else 0.03), ring[0].y)
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sea)


func build_stream() -> void:
	var pts: Array[Vector2] = []
	for i in Terrain.STREAM.size() - 1:
		var a: Vector2 = Terrain.STREAM[i]
		var b: Vector2 = Terrain.STREAM[i + 1]
		var n := int(a.distance_to(b) / 0.8)
		for k in n:
			pts.append(a.lerp(b, float(k) / n))
	pts.append(Terrain.STREAM[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * 0.85
		var ya := Terrain.height(a.x, a.y, false) - 0.22
		var yb := Terrain.height(b.x, b.y, false) - 0.22
		var la := along
		along += a.distance_to(b)
		var v := [Vector3(a.x - side.x, ya, a.y - side.y), Vector3(a.x + side.x, ya, a.y + side.y),
			Vector3(b.x - side.x, yb, b.y - side.y), Vector3(b.x + side.x, yb, b.y + side.y)]
		var uv := [Vector2(la, 0), Vector2(la, 1), Vector2(along, 0), Vector2(along, 1)]
		for k in [0, 1, 2, 1, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(v[k])
	var mesh := st.commit()
	var m := ShaderMaterial.new()
	m.shader = STREAM
	m.set_shader_parameter("noise_tex", noise_tex)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_spring(m)


## Where the stream begins: water spilling out from between mossy rocks into a little pool, with a
## fine spray, so it plainly comes from somewhere.
func _spring(water: ShaderMaterial) -> void:
	var s0: Vector2 = Terrain.STREAM[0]
	var down: Vector2 = (Terrain.STREAM[1] - s0).normalized()
	var side := Vector2(-down.y, down.x)
	var up := -down
	var pool_y := Terrain.height(s0.x, s0.y, false) - 0.22
	# the pool
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.02
	disc.radial_segments = 24
	pool.mesh = disc
	pool.material_override = water
	pool.position = Vector3(s0.x, pool_y, s0.y)
	add_child(pool)
	# rocks round the head of the pool
	var rocks := [[up * 1.6, 1.8, "Rock_Medium_1"], [up * 1.1 + side * 1.6, 1.4, "Rock_Medium_2"], [up * 1.1 - side * 1.7, 1.5, "Rock_Medium_3"],
		[side * 1.9 + down * 0.3, 0.8, "Rock_Medium_2"], [-side * 1.9 + down * 0.2, 0.7, "Rock_Medium_1"], [up * 2.1 + side * 0.8, 1.4, "Rock_Medium_3"]]
	var lip := Vector3.ZERO
	for r in rocks:
		var q: Vector2 = s0 + r[0]
		var h := Models.spawn(self, "res://assets/nature/quaternius/" + String(r[2]) + ".gltf", float(r[1]), randf() * 360.0)
		if h:
			h.position = Vector3(q.x, Terrain.height(q.x, q.y) - 0.25, q.y)
			corner.blocked.append([q, float(r[1]) * 0.5])
		if r == rocks[0]:
			lip = Vector3(q.x, Terrain.height(q.x, q.y) + float(r[1]) * 0.55, q.y) - Vector3(up.x, 0, up.y) * 0.75
	# the little cascade from the rock lip down into the pool
	var fall := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom := Vector3(s0.x, pool_y, s0.y) + Vector3(up.x, 0, up.y) * 0.6
	var w := Vector3(side.x, 0, side.y) * 0.32
	var steps := 8
	for k in steps:
		var a := float(k) / steps
		var b := float(k + 1) / steps
		var pa := lip.lerp(bottom, a) + Vector3(down.x, 0, down.y) * sin(a * PI * 0.5) * 0.25
		var pb := lip.lerp(bottom, b) + Vector3(down.x, 0, down.y) * sin(b * PI * 0.5) * 0.25
		pa.y = lerpf(lip.y, bottom.y, a * a)
		pb.y = lerpf(lip.y, bottom.y, b * b)
		var quad := [[pa - w, Vector2(a * 3.0, 0)], [pa + w, Vector2(a * 3.0, 1)], [pb - w, Vector2(b * 3.0, 0)], [pa + w, Vector2(a * 3.0, 1)], [pb + w, Vector2(b * 3.0, 1)], [pb - w, Vector2(b * 3.0, 0)]]
		for v in quad:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	fall.mesh = st.commit()
	fall.material_override = water
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)
	# spray where it lands
	var spray := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, -1.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.6))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	spray.process_material = pm
	spray.amount = 30
	spray.lifetime = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.25, 0.25)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = preload("res://space/rocket.gd")._soft_dot()
	qm.material = sm
	spray.draw_pass_1 = qm
	spray.position = bottom + Vector3.UP * 0.05
	spray.visibility_range_end = 60.0
	add_child(spray)
	# ferns and bushes on the banks
	for k in 6:
		var a := k * TAU / 6.0 + 0.4
		var q := s0 + Vector2.from_angle(a) * randf_range(2.4, 3.2)
		var f := Models.spawn(self, "res://assets/nature/quaternius/" + ["Fern_1", "Grass_Wispy_Tall", "Fern_1"][k % 3] + ".gltf", randf_range(0.6, 0.9), randf() * 360.0)
		if f:
			f.position = Vector3(q.x, Terrain.height(q.x, q.y) - 0.05, q.y)


# --- sky: clouds, night sky, the Moon, mist ---------------------------------------------------

func build_sky() -> void:
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1, 1, 1)
	cloud_mat.roughness = 1.0
	cloud_mat.emission_enabled = true
	cloud_mat.emission = Color(0.75, 0.8, 0.88)
	cloud_mat.emission_energy_multiplier = 0.35
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 18:
		var c := Node3D.new()
		var puffs := rng.randi_range(5, 9)
		for k in puffs:
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var r := rng.randf_range(5.0, 11.0)
			sm.radius = r
			sm.height = r * 2.0
			sm.radial_segments = 12
			sm.rings = 6
			s.mesh = sm
			s.material_override = cloud_mat
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			s.position = Vector3(k * rng.randf_range(5.0, 8.0) - puffs * 3.0, rng.randf_range(-1.0, 3.0), rng.randf_range(-5.0, 5.0))
			s.scale = Vector3(1.0, 0.55, 0.8)
			c.add_child(s)
		var a := rng.randf() * TAU
		var d := rng.randf_range(60.0, 320.0)
		c.position = Vector3(30.0 + cos(a) * d, rng.randf_range(70.0, 110.0), 8.0 + sin(a) * d)
		clouds.add_child(c)
	add_child(clouds)
	# the real night sky on a dome that follows the camera
	stars_mat = ShaderMaterial.new()
	stars_mat.shader = NIGHT
	stars_mat.set_shader_parameter("stars", load("res://assets/space/8k_stars_milky_way.jpg"))
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 900.0
	sphere.height = 1800.0
	dome.mesh = sphere
	dome.material_override = stars_mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.name = "NightDome"
	add_child(dome)
	# the Moon, low in the east
	moon_mat = ShaderMaterial.new()
	moon_mat.shader = MOON
	moon_mat.set_shader_parameter("surface", load("res://assets/space/8k_moon.jpg"))
	moon = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(40, 40)
	moon.mesh = q
	moon.material_override = moon_mat
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)
	# morning mist over the pond
	var mist_tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.55))
	g.set_color(1, Color(1, 1, 1, 0.0))
	mist_tex.gradient = g
	mist_tex.fill = GradientTexture2D.FILL_RADIAL
	mist_tex.fill_from = Vector2(0.5, 0.5)
	mist_tex.fill_to = Vector2(1.0, 0.5)
	for i in 7:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(rng.randf_range(9, 15), rng.randf_range(5, 8))
		mi.mesh = qm
		var mm := StandardMaterial3D.new()
		mm.albedo_texture = mist_tex
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mm.albedo_color = Color(1, 1, 1, 0.0)
		mi.material_override = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf() * TAU
		mi.position = Vector3(Terrain.POND.x + cos(a) * rng.randf_range(0, 6), 1.2, Terrain.POND.y + sin(a) * rng.randf_range(0, 6))
		add_child(mi)
		mist.append(mi)


# --- the grass field --------------------------------------------------------------------------

func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for b in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.09)
		var root := Vector3(cos(a) * r, 0, sin(a) * r)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face)) * rng.randf_range(0.009, 0.015)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.02, 0.09)
		var h := rng.randf_range(0.22, 0.4)
		var mid := root + lean * 0.4 + Vector3.UP * h * 0.5
		var top := root + lean + Vector3.UP * h
		var v := [root - side, root + side, mid - side * 0.7, mid + side * 0.7, top]
		var t := [0.0, 0.0, 0.5, 0.5, 1.0]
		for k in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			st.set_uv(Vector2(0, t[k]))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[k])
	return st.commit()


func build_grass(paths: RefCounted, blocked: Array) -> int:
	var mesh := _clump_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = GRASS
	mat.set_shader_parameter("noise_tex", noise_tex)
	mesh.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var spacing := 0.47
	var total := 0
	for tz in range(-5, 6):
		for tx in range(-4, 8):
			var x0 := tx * 16.0
			var z0 := tz * 16.0
			var centre := Vector2(x0 + 8.0, z0 + 8.0)
			var sand_r := Terrain.shore_radius(centre.x, centre.y) - 17.0
			if centre.distance_to(Terrain.CENTRE) > sand_r + 14.0:
				continue
			var xf: Array[Transform3D] = []
			var cols: Array[Color] = []
			var gx := 0.0
			while gx < 16.0:
				var gz := 0.0
				while gz < 16.0:
					var x := x0 + gx + rng.randf_range(-0.18, 0.18)
					var z := z0 + gz + rng.randf_range(-0.18, 0.18)
					gz += spacing
					var p := Vector2(x, z)
					if p.distance_to(Terrain.CENTRE) > sand_r - rng.randf_range(0.0, 3.0):
						continue
					var h := Terrain.height_fast(x, z)
					if h < 0.32 or p.distance_to(Terrain.POND) < 10.4 or path_paint(x, z) > 0.3:
						continue
					if not paths.is_open(p) or Terrain.stream_distance(x, z) < 1.4:
						continue
					var s := rng.randf_range(0.75, 1.35)
					xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.25), s)), Vector3(x, h - 0.02, z)))
					cols.append(Terrain.ground_color(x, z, h))
				gx += spacing
			if xf.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = xf.size()
			for i in xf.size():
				mm.set_instance_transform(i, xf[i])
				mm.set_instance_color(i, cols[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 64.0
			mmi.visibility_range_end_margin = 4.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			add_child(mmi)
			total += xf.size()
	return total


func _process(delta: float) -> void:
	_cloud_off += Vector2(1.6, 0.6) * delta
	RenderingServer.global_shader_parameter_set("cloud_offset", -_cloud_off)
	if corner and corner.explorer:
		RenderingServer.global_shader_parameter_set("player_pos", corner.explorer.global_position)
	for c in clouds.get_children():
		c.position.x += 1.6 * delta
		c.position.z += 0.6 * delta
		if c.position.x > 380.0:
			c.position.x -= 700.0
	var cam := get_viewport().get_camera_3d()
	if cam:
		var dome := get_node_or_null("NightDome") as Node3D
		if dome:
			dome.global_position = cam.global_position
		# the Moon sits 600 m away, low in the east, facing the camera
		var dir := Vector3(0.75, 0.32, -0.58).normalized()
		moon.global_position = cam.global_position + dir * 600.0
		moon.look_at(cam.global_position, Vector3.UP)
		moon.rotate_object_local(Vector3.UP, PI)
	stars_mat.set_shader_parameter("night", night)
	moon_mat.set_shader_parameter("alpha", clampf(night * 1.4 + 0.15, 0.0, 1.0))
	for m in mist:
		(m.material_override as StandardMaterial3D).albedo_color.a = 0.22 * morning
		m.position.x += sin(Time.get_ticks_msec() / 6000.0 + m.position.z) * 0.01
