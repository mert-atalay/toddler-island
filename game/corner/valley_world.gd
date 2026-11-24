extends Node3D
## The valley round the places: Terrain3D ground (sculpted from corner/terrain.gd and painted with
## stylized grass, rock, paths and sandy banks), the water (one surface at level 0 that shows in the
## river, the pond and the lake), the waterfall in its rocky cleft, woods and meadows of KayKit trees,
## bushes and rocks drawn through the terrain's instancer, the swaying grass field, clouds, and the
## warm light. The corner calls these in order: ground first, plants after the places are built (so
## nothing grows through a fence or a house), grass and clouds last.

const Terrain := preload("res://corner/terrain.gd")
const Models := preload("res://lib/models.gd")
const WATER_SHADER := preload("res://world/valley_water.gdshader")
const KK := "res://assets/kaykit/"

var corner: Node3D
var terrain: Terrain3D
var noise_tex: NoiseTexture2D
var rng := RandomNumberGenerator.new()
var _heights := PackedFloat32Array()
var _ground_ids := PackedByteArray()
var _mesh_ids := {}
var _bottoms := {}
var water_mat: ShaderMaterial   # the valley water, for the smaller pools the places add
const RES := 512
const HALF := 256


func _ready() -> void:
	rng.seed = 2027
	noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.width = 256
	noise_tex.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	noise_tex.noise = fn


# --- light ------------------------------------------------------------------------------------

func light() -> void:
	var sun := corner.find_children("*", "DirectionalLight3D", false, false)[0] as DirectionalLight3D
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.4
	sun.directional_shadow_max_distance = 80.0
	sun.light_volumetric_fog_energy = 1.2
	var env: Environment = corner.get_meta("env")
	var sky: ProceduralSkyMaterial = corner.get_meta("sky")
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


# --- the ground -------------------------------------------------------------------------------

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


func build_ground() -> void:
	var grass := await _texture("Grass", [Color(0.27, 0.48, 0.18), Color(0.4, 0.6, 0.24), Color(0.6, 0.66, 0.3)], 512, 0.005, 0.04)
	grass.uv_scale = 0.035
	var rock := await _texture("Rock", [Color(0.5, 0.48, 0.44), Color(0.6, 0.57, 0.52), Color(0.66, 0.62, 0.55)], 512, 0.008, 0.03)
	rock.uv_scale = 0.08
	var dirt := await _texture("Path", [Color(0.66, 0.53, 0.37), Color(0.74, 0.62, 0.45), Color(0.8, 0.7, 0.52)], 512, 0.03, 0.07)
	dirt.uv_scale = 0.12
	var bank := await _texture("Bank", [Color(0.78, 0.72, 0.56), Color(0.84, 0.78, 0.62), Color(0.88, 0.83, 0.68)], 512, 0.05, 0.08)
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
	_heights.resize(RES * RES)
	_ground_ids.resize(RES * RES)
	var img := Image.create_empty(RES, RES, false, Image.FORMAT_RF)
	for y in RES:
		for x in RES:
			var h := Terrain.height(x - HALF, y - HALF)
			_heights[y * RES + x] = h
			img.set_pixel(x, y, Color(h, 0, 0, 1))
	terrain.data.import_images([img, null, null], Vector3(-HALF, 0, -HALF), 0.0, 1.0)
	for y in RES:
		for x in RES:
			var wx := x - HALF
			var wz := y - HALF
			if Vector2(wx, wz).distance_to(Terrain.CENTRE) > 150.0:
				continue
			var g := Terrain.ground(wx, wz)
			_ground_ids[y * RES + x] = g
			if g != 0:
				var p := Vector3(wx, 0, wz)
				terrain.data.set_control_auto(p, false)
				terrain.data.set_control_base_id(p, g)
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL)
	terrain.collision.mode = Terrain3DCollision.FULL_GAME
	_build_water()


func height_at(x: float, z: float) -> float:
	var h := terrain.data.get_height(Vector3(x, 0, z))
	return Terrain.height(x, z) if is_nan(h) else h


# --- water ------------------------------------------------------------------------------------

func _build_water() -> void:
	var res := 256
	var flow := Image.create_empty(res, res, false, Image.FORMAT_RGB8)
	flow.fill(Color(0.5, 0.5, 0.5))
	for line in [Terrain.RIVER, Terrain.OUTFLOW]:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var d := (b - a).normalized()
			var steps := int(a.distance_to(b))
			for s in steps:
				var p := a.lerp(b, float(s) / steps)
				for oy in range(-4, 5):
					for ox in range(-4, 5):
						var q := p + Vector2(ox, oy) * 0.5
						var px := int((q.x / Terrain.SIZE + 0.5) * res)
						var py := int((q.y / Terrain.SIZE + 0.5) * res)
						if px >= 0 and py >= 0 and px < res and py < res:
							flow.set_pixel(px, py, Color(d.x * 0.5 + 0.5, d.y * 0.5 + 0.5, 0.5))
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("flow_tex", ImageTexture.create_from_image(flow))
	mat.set_shader_parameter("world_size", Terrain.SIZE)
	water_mat = mat
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(150, 230)
	pm.subdivide_width = 6
	pm.subdivide_depth = 6
	plane.mesh = pm
	plane.material_override = mat
	plane.position = Vector3(70, Terrain.WATER, -20)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	_waterfall()
	_fall_rocks()


func _waterfall() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Terrain.FALL_TOP
	var b := Terrain.FALL_FOOT
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x) * 3.0
	var n := 24
	for k in n:
		var u0 := float(k) / n
		var u1 := float(k + 1) / n
		var p0 := a.lerp(b, u0)
		var p1 := a.lerp(b, u1)
		var y0 := maxf(Terrain.height(p0.x, p0.y) + 0.25, Terrain.WATER)
		var y1 := maxf(Terrain.height(p1.x, p1.y) + 0.25, Terrain.WATER)
		var v := [Vector3(p0.x - side.x, y0, p0.y - side.y), Vector3(p0.x + side.x, y0, p0.y + side.y),
			Vector3(p1.x - side.x, y1, p1.y - side.y), Vector3(p1.x + side.x, y1, p1.y + side.y)]
		for i in [0, 1, 2, 1, 3, 2]:
			st.set_uv(Vector2(i % 2, u0 if i < 2 else u1))
			st.add_vertex(v[i])
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.88)
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
	spray.position = Vector3(b.x, Terrain.WATER + 0.5, b.y)
	spray.visibility_range_end = 160.0
	add_child(spray)


func _fall_rocks() -> void:
	var a := Terrain.FALL_TOP
	var b := Terrain.FALL_FOOT
	var dir := (b - a).normalized()
	var side := dir.orthogonal()
	var items := {}
	for k in 14:
		var t := float(k) / 13.0
		for sgn in [-1.0, 1.0]:
			var p: Vector2 = a.lerp(b, t) + side * sgn * rng.randf_range(6.2, 8.5) + dir * rng.randf_range(-2.0, 2.0)
			var file: String = ["Q:Rock_Medium_1", "Q:Rock_Medium_2", "Q:Rock_Medium_3"][rng.randi() % 3]
			(items.get_or_add(file, []) as Array).append([p, rng.randf_range(2.2, 3.8)])
	for k in 9:
		if k in [3, 4]:
			continue
		var p := b + Vector2.from_angle(k * TAU / 9.0 + 0.3) * rng.randf_range(5.5, 7.5)
		var file: String = ["Q:Rock_Medium_1", "Q:Rock_Medium_2", "Q:Rock_Medium_3"][k % 3]
		(items.get_or_add(file, []) as Array).append([p, rng.randf_range(1.2, 2.2)])
	_pending.merge(items)


# --- plants -----------------------------------------------------------------------------------

var _pending := {}   # file -> [[Vector2, scale]] waiting to be placed


## A model file: "Q:<name>" is a Quaternius nature model, anything else a KayKit one.
func _path(file: String) -> String:
	if file.begins_with("Q:"):
		return "res://assets/nature/quaternius/" + file.substr(2) + ".gltf"
	return KK + file + "_Color1.gltf"


func _bottom(file: String) -> float:
	if not _bottoms.has(file):
		var path := _path(file)
		var m := Models.mesh_of(path) if ResourceLoader.exists(path) else {}
		_bottoms[file] = float(m.get("bottom", 0.0)) if not m.is_empty() else 0.0
	return _bottoms[file]


func _mesh_id(file: String) -> int:
	if _mesh_ids.has(file):
		return _mesh_ids[file]
	var ma := Terrain3DMeshAsset.new()
	ma.name = file
	ma.scene_file = load(_path(file))
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
		var y := height_at(p.x, p.y)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, y - (_bottom(file) + 0.06) * s, p.y)))
	terrain.instancer.add_transforms(_mesh_id(file), xforms)


## Open for wild plants: not on paths or water, and clear of everything the places put down.
func _free(p: Vector2, margin := 0.0) -> bool:
	if not Terrain.is_open(p, margin):
		return false
	if Terrain.mountain(p) > 0.62:
		return false
	for b in corner.blocked:
		if p.distance_to(b[0]) < float(b[1]) + 1.0 + margin:
			return false
	# the farmyard
	if Terrain.in_farm(p):
		return false
	# the safari plain and the treehouse clearing keep their own few trees
	if p.distance_to(Terrain.SAFARI) < Terrain.SAFARI_R + 14.0 or p.distance_to(Terrain.CAMP) < Terrain.CAMP_R + 1.0:
		return false
	return true


func _cluster(c: Vector2, radius: float, n: int, margin := 0.0, spacing := 0.0) -> Array:
	var out: Array = []
	for i in n * 5:
		if out.size() >= n:
			break
		var a := rng.randf() * TAU
		var r := radius * sqrt(rng.randf())
		var p := c + Vector2(cos(a), sin(a)) * r
		if not _free(p, margin):
			continue
		var ok := true
		for q in out:
			if p.distance_to(q) < spacing:
				ok = false
				break
		if ok:
			out.append(p)
	return out


func build_plants() -> void:
	var trees := ["Tree_1_A", "Tree_1_B", "Tree_1_C", "Tree_2_A", "Tree_2_B", "Tree_2_C", "Tree_3_A", "Tree_3_B", "Tree_4_A", "Tree_4_B"]
	var by_file := _pending
	var tree_spots: Array = []
	var add := func(file: String, p: Vector2, s: float) -> void:
		(by_file.get_or_add(file, []) as Array).append([p, s])
		if file.begins_with("Tree"):
			tree_spots.append([p, s])
	# woods round the valley, with clearings, and the island's own wood east of the tall oak
	var groves := [[Vector2(92, -12), 20.0, 30], [Vector2(-42, -72), 26.0, 30], [Vector2(-62, 28), 24.0, 26], [Vector2(-24, 74), 22.0, 22],
		[Vector2(8, -96), 22.0, 22], [Vector2(104, -62), 22.0, 22], [Vector2(128, 18), 20.0, 18], [Vector2(40, 104), 20.0, 18],
		[Vector2(-60, -20), 16.0, 14], [Vector2(108, -92), 16.0, 14]]
	for g in groves:
		for p in _cluster(g[0], g[1], g[2], 2.0, 5.5):
			add.call(trees[rng.randi() % trees.size()], p, rng.randf_range(2.0, 3.0))
		for k in int(float(g[2]) * 0.7):
			var a := rng.randf() * TAU
			var p: Vector2 = g[0] + Vector2(cos(a), sin(a)) * float(g[1]) * rng.randf_range(0.9, 1.25)
			if _free(p, 0.5):
				add.call(["Bush_1_A", "Bush_2_A", "Bush_3_A", "Bush_4_A", "Bush_2_B", "Bush_1_C"][rng.randi() % 6], p, rng.randf_range(1.6, 2.6))
	# lone meadow trees, each with a bush at its foot
	for i in 220:
		var p := Terrain.CENTRE + Vector2(rng.randf_range(-115, 115), rng.randf_range(-115, 115))
		if not _free(p, 5.0) or Terrain.mountain(p) > 0.2:
			continue
		add.call(trees[rng.randi() % trees.size()], p, rng.randf_range(2.4, 3.2))
		add.call("Bush_2_A", p + Vector2(1.6, 0.8), rng.randf_range(1.5, 2.2))
	# trees climbing the lower mountain slopes
	for i in 2600:
		var a := rng.randf() * TAU
		var p := Terrain.CENTRE + Vector2(cos(a), sin(a) / 1.08) * rng.randf_range(125, 205)
		var m := Terrain.mountain(p)
		if m < 0.04 or m > 0.6 or rng.randf() < m * 1.4:
			continue
		var h0 := Terrain.height(p.x, p.y)
		if absf(Terrain.height(p.x + 2.0, p.y) - h0) > 4.5 or absf(Terrain.height(p.x, p.y + 2.0) - h0) > 4.5:
			continue
		if Terrain._line_dist(p, [Terrain.FALL_TOP, Terrain.FALL_FOOT]) < 12.0:
			continue
		add.call(trees[rng.randi() % trees.size()], p, rng.randf_range(2.2, 3.4))
	# along the river: bushes and rocks on the bends
	for line in [Terrain.RIVER, Terrain.OUTFLOW]:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var side := (b - a).normalized().orthogonal()
			for s in 3:
				var p := a.lerp(b, rng.randf()) + side * (6.8 + rng.randf() * 3.0) * (1 if rng.randf() < 0.5 else -1)
				if _free(p, -2.0) or Terrain.path_distance(p.x, p.y) > 3.0 and Terrain.river_distance(p) > 6.0:
					add.call(["Bush_3_A", "Bush_4_A", "Bush_1_B"][rng.randi() % 3], p, rng.randf_range(1.4, 2.2))
			var r := a.lerp(b, 0.5) + side * 5.6 * (1 if i % 2 == 0 else -1)
			if Terrain.path_distance(r.x, r.y) > 3.0:
				add.call(["Q:Rock_Medium_1", "Q:Rock_Medium_2", "Q:Rock_Medium_3"][i % 3], r, rng.randf_range(0.8, 1.4))
				add.call("Rock_2_A", r + side * 1.2, rng.randf_range(1.0, 1.5))
	# rocks and bush clumps dotted about the meadows; boulders at the mountains' foot
	for i in 160:
		var p := Terrain.CENTRE + Vector2(rng.randf_range(-115, 115), rng.randf_range(-115, 115))
		if not _free(p, 1.0) or Terrain.mountain(p) > 0.2:
			continue
		if rng.randf() < 0.5:
			add.call(["Rock_1_A", "Rock_1_B", "Rock_3_B", "Rock_2_B"][rng.randi() % 4], p, rng.randf_range(0.8, 1.8))
			add.call("Rock_2_A", p + Vector2(0.9, 0.5), rng.randf_range(0.6, 1.0))
		else:
			for k in 3:
				add.call(["Bush_1_A", "Bush_2_A", "Bush_4_A"][k], p + Vector2.from_angle(k * 2.1) * 1.0, rng.randf_range(1.4, 2.2))
	for i in 90:
		var a := rng.randf() * TAU
		var p := Terrain.CENTRE + Vector2(cos(a), sin(a) / 1.08) * rng.randf_range(118, 150)
		if _free(p, 2.0):
			add.call(["Q:Rock_Medium_1", "Q:Rock_Medium_2", "Q:Rock_Medium_3"][rng.randi() % 3], p, rng.randf_range(1.6, 3.4))
	# grass tufts on open ground, thicker in patches
	var patch := FastNoiseLite.new()
	patch.frequency = 0.03
	patch.seed = 3
	for i in 15000:
		var p := Terrain.CENTRE + Vector2(rng.randf_range(-135, 135), rng.randf_range(-135, 135))
		if not Terrain.is_open(p, -1.5) or Terrain.mountain(p) > 0.35 or Terrain.in_farm(p):
			continue
		# the new places stay tidy: few tall tufts on the safari plain, none in the treehouse clearing
		if p.distance_to(Terrain.CAMP) < Terrain.CAMP_R + 1.0 or (p.distance_to(Terrain.SAFARI) < Terrain.SAFARI_R + 2.0 and rng.randf() < 0.75):
			continue
		if patch.get_noise_2d(p.x, p.y) < -0.1 and rng.randf() < 0.6:
			continue
		add.call(["Grass_1_A", "Grass_1_B", "Grass_1_C", "Grass_1_D", "Grass_2_A"][rng.randi() % 5], p, rng.randf_range(0.6, 1.05))
	for file in by_file:
		_place(file, by_file[file])
	_pending = {}
	# trees near the places get trunks the explorer and animals bump into, and join the route map
	var n := 0
	for t in tree_spots:
		var p: Vector2 = t[0]
		if p.distance_to(Terrain.CENTRE) < 130.0:
			corner._trunk(p.x, p.y, 0.32 * float(t[1]) * 0.6)
			n += 1
	print("[valley] trees: %d (%d with trunks)" % [tree_spots.size(), n])


# --- the grass field and clouds ---------------------------------------------------------------

func build_grass() -> int:
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
	var spacing := 0.55
	var total := 0
	var tile := 16.0
	for tz in range(-8, 8):
		for tx in range(-8, 8):
			var x0 := Terrain.CENTRE.x + tx * tile
			var z0 := Terrain.CENTRE.y + tz * tile
			var near_blocked: Array = []
			for b in corner.blocked:
				var c: Vector2 = b[0]
				if c.x > x0 - 8.0 and c.x < x0 + tile + 8.0 and c.y > z0 - 8.0 and c.y < z0 + tile + 8.0:
					near_blocked.append(b)
			var xf: Array[Transform3D] = []
			var cols: Array[Color] = []
			var gx := 0.0
			while gx < tile:
				var gz := 0.0
				while gz < tile:
					var x := x0 + gx + rng.randf_range(-0.22, 0.22)
					var z := z0 + gz + rng.randf_range(-0.22, 0.22)
					gz += spacing
					var ix := int(x + HALF)
					var iz := int(z + HALF)
					if ix < 0 or iz < 0 or ix >= RES or iz >= RES:
						continue
					var cell := iz * RES + ix
					if _ground_ids[cell] != 0 or _heights[cell] < 0.3:
						continue
					if Terrain.mountain(Vector2(x, z)) > 0.25:
						continue
					var inside := false
					for b in near_blocked:
						if Vector2(x, z).distance_to(b[0]) < float(b[1]) * 0.8:
							inside = true
							break
					if inside:
						continue
					var y := height_at(x, z)
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
	return total


func build_clouds() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.78, 0.82, 0.9)
	m.emission_energy_multiplier = 0.45
	var holder := Node3D.new()
	holder.name = "Clouds"
	add_child(holder)
	for i in 14:
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
		c.position = Vector3(Terrain.CENTRE.x + cos(a) * d, rng.randf_range(95, 140), Terrain.CENTRE.y + sin(a) * d)
		holder.add_child(c)
	var tw := holder.create_tween().set_loops()
	tw.tween_property(holder, "position:x", 60.0, 240.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(holder, "position:x", -60.0, 240.0).set_trans(Tween.TRANS_SINE)
