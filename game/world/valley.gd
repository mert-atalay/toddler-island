extends Node3D
## The new world: a stylized valley built with Terrain3D (sculpted, texture-painted ground), soft
## mountains, a river with a waterfall and a lake, and plants placed with care rather than at random.
## This first version is a look test: it builds the land and one composed area, and can photograph
## itself (--tour <dir>) so the look can be compared with the island.

const Shape := preload("res://world/valley_shape.gd")
const SunnyLook := preload("res://look/sunny_look.gd")
const Models := preload("res://lib/models.gd")
const WATER_SHADER := preload("res://world/valley_water.gdshader")
const KK := "res://assets/kaykit/"
const N := "res://assets/nature/quaternius/"

var terrain: Terrain3D
var _grassable := PackedByteArray()   # 1 m cells where the grass field grows
var _bottoms := {}                     # model file -> how far below its origin it reaches
var noise_tex: NoiseTexture2D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2027
	get_window().title = "Toddler Island: the valley (look test)"
	var sun := SunnyLook.apply(self, 36.0, -52.0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.45
	sun.directional_shadow_max_distance = 90.0
	sun.light_volumetric_fog_energy = 1.2
	var env: Environment = get_meta("env")
	var sky: ProceduralSkyMaterial = get_meta("sky")
	sky.sky_top_color = Color(0.26, 0.52, 0.86)
	sky.sky_horizon_color = Color(0.86, 0.88, 0.9)
	sky.ground_horizon_color = Color(0.86, 0.88, 0.9)
	env.fog_density = 0.0022
	env.fog_light_color = Color(0.8, 0.86, 0.94)
	env.fog_aerial_perspective = 0.85
	env.fog_sky_affect = 0.3
	env.fog_sun_scatter = 0.3
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.05
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.005
	env.volumetric_fog_albedo = Color(1.0, 0.97, 0.9)
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 60.0
	env.volumetric_fog_sky_affect = 0.0
	RenderingServer.global_shader_parameter_set("player_pos", Vector3(0, -100, 0))
	noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.width = 256
	noise_tex.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	noise_tex.noise = fn
	await _build_terrain()
	_build_water()
	_plants()
	_grass_field()
	_clouds()
	var args := OS.get_cmdline_user_args()
	var k := args.find("--tour")
	if k >= 0 and k + 1 < args.size():
		_tour(args[k + 1])
	else:
		_free_camera()


# --- the ground -------------------------------------------------------------------------------

## A stylized ground texture: soft colour patches from a gradient, a little fine grain, height in alpha.
func _texture(name: String, colors: Array, size := 512, freq := 0.008, grain := 0.06) -> Terrain3DTextureAsset:
	var fnl := FastNoiseLite.new()
	fnl.frequency = freq
	fnl.fractal_octaves = 3
	var fine := FastNoiseLite.new()
	fine.frequency = 0.09
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[colors.size() - 1])
	if colors.size() > 2:
		g.add_point(0.5, colors[1])
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.noise = fnl
	tex.color_ramp = g
	await tex.changed
	var img: Image = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var c := img.get_pixel(x, y)
			var f := fine.get_noise_2d(x, y) * grain
			c = Color(clampf(c.r + f, 0, 1), clampf(c.g + f, 0, 1), clampf(c.b + f * 0.6, 0, 1), c.v)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var nt := NoiseTexture2D.new()
	nt.width = size
	nt.height = size
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 2.0
	nt.noise = fnl
	await nt.changed
	var nimg: Image = nt.get_image()
	nimg.convert(Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var c := nimg.get_pixel(x, y)
			c.a = 0.9
			nimg.set_pixel(x, y, c)
	nimg.generate_mipmaps()
	var ta := Terrain3DTextureAsset.new()
	ta.name = name
	ta.albedo_texture = ImageTexture.create_from_image(img)
	ta.normal_texture = ImageTexture.create_from_image(nimg)
	return ta


func _build_terrain() -> void:
	var grass := await _texture("Grass", [Color(0.27, 0.48, 0.18), Color(0.4, 0.6, 0.24), Color(0.6, 0.66, 0.3)], 512, 0.005, 0.04)
	grass.uv_scale = 0.035
	var rock := await _texture("Rock", [Color(0.5, 0.48, 0.44), Color(0.6, 0.57, 0.52), Color(0.66, 0.62, 0.55)], 512, 0.008, 0.03)
	rock.uv_scale = 0.08
	var dirt := await _texture("Path", [Color(0.66, 0.53, 0.37), Color(0.74, 0.62, 0.45), Color(0.8, 0.7, 0.52)], 512, 0.03, 0.07)
	dirt.uv_scale = 0.12
	var bank := await _texture("Bank", [Color(0.62, 0.6, 0.52), Color(0.76, 0.72, 0.6), Color(0.84, 0.8, 0.66)], 512, 0.05, 0.1)
	bank.uv_scale = 0.14
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.free_editor_textures = false
	add_child(terrain)
	terrain.material.world_background = Terrain3DMaterial.NONE
	terrain.material.auto_shader_enabled = true
	terrain.material.set_shader_param("auto_slope", 0.55)
	terrain.material.set_shader_param("auto_base_texture", 1)
	terrain.material.set_shader_param("auto_overlay_texture", 0)
	terrain.material.set_shader_param("blend_sharpness", 0.9)
	terrain.material.set_shader_param("macro_variation1", Vector3(1.0, 0.97, 0.88))
	terrain.material.set_shader_param("macro_variation2", Vector3(0.9, 1.0, 0.9))
	terrain.assets.set_texture_asset(0, grass)
	terrain.assets.set_texture_asset(1, rock)
	terrain.assets.set_texture_asset(2, dirt)
	terrain.assets.set_texture_asset(3, bank)
	terrain.region_size = Terrain3D.SIZE_256
	var res := int(Shape.SIZE)
	_grassable.resize(res * res)
	var img := Image.create_empty(res, res, false, Image.FORMAT_RF)
	for y in res:
		for x in res:
			img.set_pixel(x, y, Color(Shape.height(x - res * 0.5, y - res * 0.5), 0, 0, 1))
	terrain.data.import_images([img, null, null], Vector3(-res * 0.5, 0, -res * 0.5), 0.0, 1.0)
	# paint the paths and the river banks (everything else follows the slope: grass, rock on steep bits)
	for y in res:
		for x in res:
			var wx := x - res * 0.5
			var wz := y - res * 0.5
			var g := Shape.ground(wx, wz)
			if g == 0 and Shape.mountain(Vector2(wx, wz)) < 0.3 and Shape.height(wx, wz) > Shape.WATER + 0.5:
				_grassable[y * res + x] = 1
			if g != 0:
				var p := Vector3(wx, 0, wz)
				terrain.data.set_control_auto(p, false)
				terrain.data.set_control_base_id(p, g)
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL)
	terrain.collision.mode = Terrain3DCollision.FULL_GAME


# --- water ------------------------------------------------------------------------------------

func _build_water() -> void:
	# which way the river flows at each point, for the ripples
	var res := 256
	var flow := Image.create_empty(res, res, false, Image.FORMAT_RGB8)
	flow.fill(Color(0.5, 0.5, 0.5))
	for i in Shape.RIVER.size() - 1:
		var a: Vector2 = Shape.RIVER[i]
		var b: Vector2 = Shape.RIVER[i + 1]
		var d := (b - a).normalized()
		var steps := int(a.distance_to(b))
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			for oy in range(-5, 6):
				for ox in range(-5, 6):
					var q := p + Vector2(ox, oy)
					var px := int((q.x / Shape.SIZE + 0.5) * res)
					var py := int((q.y / Shape.SIZE + 0.5) * res)
					if px >= 0 and py >= 0 and px < res and py < res:
						flow.set_pixel(px, py, Color(d.x * 0.5 + 0.5, d.y * 0.5 + 0.5, 0.5))
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("flow_tex", ImageTexture.create_from_image(flow))
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Shape.SIZE * 0.72, Shape.SIZE * 0.72)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	plane.mesh = pm
	plane.material_override = mat
	plane.position = Vector3(-20, Shape.WATER, -10)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	_waterfall(mat)
	_fall_rocks()


## The waterfall: a ribbon of falling water down the mountain notch, white with spray at the foot.
func _waterfall(water: ShaderMaterial) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Shape.FALL_TOP
	var b := Shape.FALL_FOOT
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x) * 3.4
	var n := 24
	for k in n:
		var u0 := float(k) / n
		var u1 := float(k + 1) / n
		var p0 := a.lerp(b, u0)
		var p1 := a.lerp(b, u1)
		var y0 := maxf(Shape.height(p0.x, p0.y) + 0.25, Shape.WATER)
		var y1 := maxf(Shape.height(p1.x, p1.y) + 0.25, Shape.WATER)
		var v := [Vector3(p0.x - side.x, y0, p0.y - side.y), Vector3(p0.x + side.x, y0, p0.y + side.y),
			Vector3(p1.x - side.x, y1, p1.y - side.y), Vector3(p1.x + side.x, y1, p1.y + side.y)]
		for i in [0, 1, 2, 1, 3, 2]:
			st.set_uv(Vector2(i % 2, u0 if i < 2 else u1))
			st.add_vertex(v[i])
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = noise_tex
	m.uv1_scale = Vector3(2.0, 6.0, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.75, 0.8)
	m.emission_energy_multiplier = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fall := MeshInstance3D.new()
	fall.mesh = st.commit()
	fall.material_override = m
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)
	var tw := create_tween().set_loops()
	tw.tween_method(func(v: float) -> void: m.uv1_offset = Vector3(0, -v, 0), 0.0, 6.0, 4.0)
	# spray at the foot
	var spray := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.5
	pm.direction = Vector3.UP
	pm.spread = 50.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.5
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0.5))
	gr.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = gr
	pm.color_ramp = gt
	spray.process_material = pm
	spray.amount = 60
	spray.lifetime = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = preload("res://space/rocket.gd")._soft_dot()
	q.material = sm
	spray.draw_pass_1 = q
	spray.position = Vector3(b.x, Shape.WATER + 0.5, b.y)
	add_child(spray)


# --- plants: composed groups, drawn in batches through the terrain's instancer ------------------

var _mesh_ids := {}


func _mesh_id(file: String) -> int:
	if _mesh_ids.has(file):
		return _mesh_ids[file]
	var ma := Terrain3DMeshAsset.new()
	ma.name = file
	ma.scene_file = load(KK + file + "_Color1.gltf") if ResourceLoader.exists(KK + file + "_Color1.gltf") else load(file)
	ma.lod0_range = 90.0 if file.begins_with("Grass") else (260.0 if file.begins_with("Bush") or file.begins_with("Rock_2") else 700.0)
	var id := terrain.assets.get_mesh_count()
	terrain.assets.set_mesh_asset(id, ma)
	_mesh_ids[file] = id
	return id


func _place(file: String, items: Array) -> void:
	if items.is_empty():
		return
	var xforms: Array[Transform3D] = []
	for it in items:
		var p: Vector2 = it[0]
		var s: float = it[1]
		var y := terrain.data.get_height(Vector3(p.x, 0, p.y))
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, y - (_bottom(file) + 0.06) * s, p.y)))
	terrain.instancer.add_transforms(_mesh_id(file), xforms)


## A natural cluster: n points round c, denser in the middle, kept to open ground.
func _cluster(c: Vector2, radius: float, n: int, margin := 0.0, spacing := 0.0) -> Array:
	var out: Array = []
	for i in n * 4:
		if out.size() >= n:
			break
		var a := rng.randf() * TAU
		var r := radius * sqrt(rng.randf()) * (0.5 + 0.5 * rng.randf())
		var p := c + Vector2(cos(a), sin(a)) * r
		if not Shape.is_open(p, margin) or Shape.height(p.x, p.y) > 30.0:
			continue
		var ok := true
		for q in out:
			if p.distance_to(q) < spacing:
				ok = false
				break
		if ok:
			out.append(p)
	return out


func _plants() -> void:
	var trees := ["Tree_1_A", "Tree_1_B", "Tree_1_C", "Tree_2_A", "Tree_2_B", "Tree_2_C", "Tree_3_A", "Tree_3_B", "Tree_4_A", "Tree_4_B"]
	var by_file := {}
	var add := func(file: String, p: Vector2, s: float) -> void:
		if not by_file.has(file):
			by_file[file] = []
		(by_file[file] as Array).append([p, s])
	# woods: big groups with clearings, thickest on the lower mountain slopes, with a forest edge of bushes
	var groves := [[Vector2(110, -40), 34.0, 46], [Vector2(-120, -40), 30.0, 34], [Vector2(-40, -120), 32.0, 36],
		[Vector2(40, -110), 26.0, 26], [Vector2(130, 40), 30.0, 30], [Vector2(-130, 70), 28.0, 26], [Vector2(-60, 110), 26.0, 22],
		[Vector2(150, -100), 30.0, 26], [Vector2(-150, 0), 26.0, 22], [Vector2(20, 140), 24.0, 18]]
	for g in groves:
		for p in _cluster(g[0], g[1], g[2], 2.0, 5.5):
			var t: String = trees[rng.randi() % trees.size()]
			add.call(t, p, rng.randf_range(2.0, 3.0))
		# bushes round the edge
		for k in int(float(g[2]) * 0.7):
			var a := rng.randf() * TAU
			var p: Vector2 = g[0] + Vector2(cos(a), sin(a)) * float(g[1]) * rng.randf_range(0.9, 1.25)
			if Shape.is_open(p, 1.0):
				add.call(["Bush_1_A", "Bush_2_A", "Bush_3_A", "Bush_4_A", "Bush_2_B", "Bush_1_C"][rng.randi() % 6], p, rng.randf_range(1.6, 2.6))
	# a few lone trees in the meadows, each with a bush or two at its foot
	for i in 260:
		var p := Vector2(rng.randf_range(-130, 140), rng.randf_range(-120, 130))
		if not Shape.is_open(p, 6.0) or Shape.mountain(p) > 0.2:
			continue
		add.call(trees[rng.randi() % trees.size()], p, rng.randf_range(2.4, 3.2))
		add.call("Bush_2_A", p + Vector2(1.6, 0.8), rng.randf_range(1.5, 2.2))
	# along the river: bushes and rocks where the bank bends
	for i in Shape.RIVER.size() - 1:
		var a: Vector2 = Shape.RIVER[i]
		var b: Vector2 = Shape.RIVER[i + 1]
		var side := (b - a).normalized().orthogonal()
		for s in 3:
			var p := a.lerp(b, rng.randf()) + side * (8.5 + rng.randf() * 3.0) * (1 if rng.randf() < 0.5 else -1)
			add.call(["Bush_3_A", "Bush_4_A", "Bush_1_B"][rng.randi() % 3], p, rng.randf_range(1.4, 2.2))
		var r := a.lerp(b, 0.5) + side * 7.0 * (1 if i % 2 == 0 else -1)
		add.call(["Rock_1_A", "Rock_3_A", "Rock_1_D", "Rock_3_C"][i % 4], r, rng.randf_range(1.6, 2.8))
		add.call("Rock_2_A", r + side * 1.4, rng.randf_range(1.0, 1.6))
	# rocks on the mountain foot
	for i in 70:
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a) / 1.08) * rng.randf_range(150, 185)
		if Shape.is_open(p, 2.0):
			add.call(["Rock_1_A", "Rock_1_E", "Rock_3_A", "Rock_3_F", "Rock_1_H"][rng.randi() % 5], p, rng.randf_range(3.0, 7.0))
	# grass tufts everywhere on open ground, thicker in patches and along the forest edges
	var patch := FastNoiseLite.new()
	patch.frequency = 0.03
	patch.seed = 3
	for i in 26000:
		var p := Vector2(rng.randf_range(-170, 170), rng.randf_range(-170, 170))
		if not Shape.is_open(p, -1.0) or Shape.mountain(p) > 0.35:
			continue
		if patch.get_noise_2d(p.x, p.y) < -0.1 and rng.randf() < 0.6:
			continue
		add.call(["Grass_1_A", "Grass_1_B", "Grass_1_C", "Grass_1_D", "Grass_2_A"][rng.randi() % 5], p, rng.randf_range(0.8, 1.3))
	# trees climbing the lower mountain slopes, thinning out higher up
	for i in 2600:
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a) / 1.08) * rng.randf_range(140, 205)
		var m := Shape.mountain(p)
		if m < 0.04 or m > 0.6 or rng.randf() < m * 1.4:
			continue
		var h0 := Shape.height(p.x, p.y)
		if absf(Shape.height(p.x + 2.0, p.y) - h0) > 4.5 or absf(Shape.height(p.x, p.y + 2.0) - h0) > 4.5:
			continue
		if Shape._line_dist(p, [Shape.FALL_TOP, Shape.FALL_FOOT]) < 12.0:
			continue
		add.call(trees[rng.randi() % trees.size()], p, rng.randf_range(2.2, 3.4))
	# little rock groups and bush clumps dotted about the meadows
	for i in 140:
		var p := Vector2(rng.randf_range(-140, 140), rng.randf_range(-140, 140))
		if not Shape.is_open(p, 1.0) or Shape.mountain(p) > 0.2:
			continue
		if rng.randf() < 0.5:
			add.call(["Rock_1_A", "Rock_1_B", "Rock_3_B", "Rock_2_B"][rng.randi() % 4], p, rng.randf_range(0.8, 1.8))
			add.call("Rock_2_A", p + Vector2(0.9, 0.5), rng.randf_range(0.6, 1.0))
		else:
			for k in 3:
				add.call(["Bush_1_A", "Bush_2_A", "Bush_4_A"][k], p + Vector2.from_angle(k * 2.1) * 1.0, rng.randf_range(1.4, 2.2))
	for file in by_file:
		_place(file, by_file[file])
	# wildflower patches (the Quaternius flowers, drawn as plain models for now)
	var flowers := ["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single"]
	for c in [Vector2(20, 20), Vector2(-50, 60), Vector2(40, -60), Vector2(-90, -70), Vector2(90, 50), Vector2(-20, -30),
			Vector2(-110, 30), Vector2(30, 110), Vector2(100, -10), Vector2(-40, -100), Vector2(-100, 100), Vector2(120, 80)]:
		for p in _cluster(c, 12.0, 40, -1.0, 0.7):
			var f := Models.spawn(self, N + flowers[rng.randi() % 4] + ".gltf", rng.randf_range(0.35, 0.6), rng.randf() * 360.0)
			if f:
				f.position = Vector3(p.x, terrain.data.get_height(Vector3(p.x, 0, p.y)) - 0.03, p.y)


# --- looking around ---------------------------------------------------------------------------

func _free_camera() -> void:
	var cam := Camera3D.new()
	cam.far = 1500.0
	add_child(cam)
	cam.position = Vector3(-20, 14, 70)
	cam.look_at(Vector3(10, 4, 0))


func _tour(dir: String) -> void:
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(dir)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 1500.0
	add_child(cam)
	cam.make_current()
	var g := func(p: Vector2) -> float: return terrain.data.get_height(Vector3(p.x, 0, p.y))
	# [name, eye position (x, z, height above ground), look at (x, z, height above ground)]
	var views := [["river-bend", Vector3(-14, -2, 2.0), Vector3(2, -30, 1.0)], ["waterfall", Vector3(-112, -122, 3.0), Vector3(-140, -175, 14.0)],
		["meadow", Vector3(-30, 50, 1.8), Vector3(10, -10, 4.0)], ["forest-edge", Vector3(72, -30, 1.8), Vector3(110, -42, 4.0)],
		["lake", Vector3(40, 104, 2.0), Vector3(84, 84, 0.5)], ["windmill-hill", Vector3(-52, -20, 2.0), Vector3(-70, -40, 6.0)],
		["valley-above", Vector3(0, 160, 70.0), Vector3(0, 0, 0.0)], ["bridge", Vector3(16, -4, 1.8), Vector3(4, -16, 1.0)]]
	for f in 30:
		await get_tree().process_frame
	var total := 0.0
	for v in views:
		var e: Vector3 = v[1]
		var l: Vector3 = v[2]
		cam.global_position = Vector3(e.x, float(g.call(Vector2(e.x, e.y))) + e.z, e.y)
		cam.look_at(Vector3(l.x, float(g.call(Vector2(l.x, l.y))) + l.z, l.y), Vector3.UP)
		for f in 40:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for f in 60:
			await get_tree().process_frame
		var fps := 60.0 / ((Time.get_ticks_usec() - t0) / 1000000.0)
		total += fps
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(String(v[0]) + ".png"))
		print("[valley] %s: %.0f fps, %d draws" % [v[0], fps, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("[valley] average %.0f fps" % (total / views.size()))
	get_tree().quit()


## How far below its origin a model reaches (so it can stand on the ground, not float).
func _bottom(file: String) -> float:
	if not _bottoms.has(file):
		var path := KK + file + "_Color1.gltf"
		var m := Models.mesh_of(path) if ResourceLoader.exists(path) else {}
		_bottoms[file] = float(m.get("bottom", 0.0)) if not m.is_empty() else 0.0
	return _bottoms[file]


## Big rocks stacked along both sides of the waterfall, so the water pours down a rocky cleft.
func _fall_rocks() -> void:
	var a := Shape.FALL_TOP
	var b := Shape.FALL_FOOT
	var dir := (b - a).normalized()
	var side := dir.orthogonal()
	var items := {}
	for k in 14:
		var t := float(k) / 13.0
		for sgn in [-1.0, 1.0]:
			var p: Vector2 = a.lerp(b, t) + side * sgn * rng.randf_range(4.0, 6.5) + dir * rng.randf_range(-2.0, 2.0)
			var file: String = ["Rock_1_A", "Rock_3_A", "Rock_1_E", "Rock_3_F", "Rock_1_H"][rng.randi() % 5]
			if not items.has(file):
				items[file] = []
			(items[file] as Array).append([p, rng.randf_range(4.5, 8.0)])
	# a ring of rocks round the pool at the foot, open where the river leaves
	for k in 9:
		if k in [3, 4]:
			continue
		var p := b + Vector2.from_angle(k * TAU / 9.0 + 0.3) * rng.randf_range(5.5, 7.5)
		var file: String = ["Rock_1_A", "Rock_3_A", "Rock_1_D"][k % 3]
		if not items.has(file):
			items[file] = []
		(items[file] as Array).append([p, rng.randf_range(2.0, 3.6)])
	for file in items:
		_place(file, items[file])


## The island's swaying grass, grown over the valley floor in 16 m tiles that only draw nearby.
func _grass_field() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for b in 7:
		var a := r.randf() * TAU
		var rr := r.randf_range(0.0, 0.09)
		var root := Vector3(cos(a) * rr, 0, sin(a) * rr)
		var face := r.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face)) * r.randf_range(0.009, 0.015)
		var lean := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.02, 0.09)
		var h := r.randf_range(0.22, 0.4)
		var mid := root + lean * 0.4 + Vector3.UP * h * 0.5
		var top := root + lean + Vector3.UP * h
		var v := [root - side, root + side, mid - side * 0.7, mid + side * 0.7, top]
		var t := [0.0, 0.0, 0.5, 0.5, 1.0]
		for k in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			st.set_uv(Vector2(0, t[k]))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[k])
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://look/grass.gdshader")
	mat.set_shader_parameter("noise_tex", noise_tex)
	mesh.surface_set_material(0, mat)
	var patch := FastNoiseLite.new()
	patch.frequency = 0.005
	patch.seed = 9
	var res := int(Shape.SIZE)
	var spacing := 0.55
	var total := 0
	var tile := 16.0
	for tz in range(-10, 10):
		for tx in range(-10, 10):
			var x0 := tx * tile
			var z0 := tz * tile
			var xf: Array[Transform3D] = []
			var cols: Array[Color] = []
			var gx := 0.0
			while gx < tile:
				var gz := 0.0
				while gz < tile:
					var x := x0 + gx + rng.randf_range(-0.22, 0.22)
					var z := z0 + gz + rng.randf_range(-0.22, 0.22)
					gz += spacing
					var ix := int(x + res * 0.5)
					var iz := int(z + res * 0.5)
					if ix < 0 or iz < 0 or ix >= res or iz >= res or _grassable[iz * res + ix] == 0:
						continue
					var y := terrain.data.get_height(Vector3(x, 0, z))
					var s := rng.randf_range(0.8, 1.45)
					xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.3), s)), Vector3(x, y - 0.03, z)))
					var k := patch.get_noise_2d(x, z) * 0.5 + 0.5
					cols.append(Color(0.27, 0.48, 0.18).lerp(Color(0.5, 0.64, 0.27), k).lerp(Color(0.62, 0.66, 0.3), maxf(0.0, k - 0.7) * 2.0))
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
			mmi.visibility_range_end = 60.0
			add_child(mmi)
			total += xf.size()
	print("[valley] grass clumps: ", total)


## Soft white clouds drifting slowly over the valley.
func _clouds() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.78, 0.82, 0.9)
	m.emission_energy_multiplier = 0.45
	var holder := Node3D.new()
	add_child(holder)
	for i in 16:
		var c := Node3D.new()
		for k in rng.randi_range(5, 9):
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var rad := rng.randf_range(7.0, 14.0)
			sm.radius = rad
			sm.height = rad * 1.3
			sm.radial_segments = 12
			sm.rings = 6
			s.mesh = sm
			s.material_override = m
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			s.position = Vector3(rng.randf_range(-22, 22), rng.randf_range(-3, 4), rng.randf_range(-10, 10))
			c.add_child(s)
		var a := rng.randf() * TAU
		var d := rng.randf_range(60, 320)
		c.position = Vector3(cos(a) * d, rng.randf_range(95, 140), sin(a) * d)
		holder.add_child(c)
	var tw := holder.create_tween().set_loops()
	tw.tween_property(holder, "position:x", 60.0, 240.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(holder, "position:x", -60.0, 240.0).set_trans(Tween.TRANS_SINE)
