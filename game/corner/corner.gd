extends Node3D
## Step 2 look test: one corner of the island, about 50 m square, laid out by hand.
## A path leads from the start to the farm gate. Inside the fence are the barn, the coop, a trough,
## a cow and two hens; outside are an apple tree with crates, a cart, a well and flowers.
## Behind are the hill with its windmill (north), the wood (east) and the beach and sea (west).
## Run with "-- --shots <folder>" for the photo tour: fixed views saved as pictures, then quit.

const SunnyLook := preload("res://look/sunny_look.gd")
const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const Explorer := preload("res://corner/explorer.gd")
const FollowCamera := preload("res://corner/follow_camera.gd")
const Life := preload("res://corner/life.gd")
const Places := preload("res://corner/places.gd")
const Places2 := preload("res://corner/places2.gd")
const ValleyWorld := preload("res://corner/valley_world.gd")
const Places3 := preload("res://corner/places3.gd")
const Places4 := preload("res://corner/places4.gd")
const Scenery := preload("res://corner/scenery.gd")
const Trip := preload("res://space/trip.gd")
const Play := preload("res://corner/play.gd")
const Critters := preload("res://corner/critters.gd")
const AudioLife := preload("res://corner/audio_life.gd")
const Wildlife := preload("res://corner/wildlife.gd")
const Ambience := preload("res://corner/ambience.gd")
const WorldLook := preload("res://corner/world_look.gd")
const FOLIAGE := preload("res://look/foliage.gdshader")

const N := "res://assets/nature/quaternius/"
const P := "res://assets/props/quaternius/"
const B := "res://assets/buildings/quaternius-farm/"
const A := "res://assets/animals/quaternius/"

## The fenced farmyard and its gate (a gap in the front fence).
const PADDOCK := [Vector2(-24, -21), Vector2(12, -21), Vector2(12, 1), Vector2(-24, 1)]
const GATE := Vector2(-1.7, 1.7)  # x range of the opening in the front fence

var shots_dir := ""
var rng := RandomNumberGenerator.new()
var blocked: Array = []  # [Vector2 centre, radius] kept clear of plants
var fence_points: Array = []  # points along the fences, for planting along them
var fence_lines: Array = []  # [a, b] for every fence run, for the route map
var trunks: Array = []  # [Vector2, radius] for every tree trunk, for the route map
var explorer: CharacterBody3D
var follow: Node3D
var sea_mat: StandardMaterial3D
var no_sway := false
var life: Node3D
var look: Node3D
var valley: Node3D
var trip: Node3D
var audio: Node
var play: Node
var shadow_tiles: Array = []  # [MultiMeshInstance3D, tile centre]: trees cast shadows only near her
var _shadow_t := 0.0
var _f11_down := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var k := args.find("--shots")
	if k >= 0 and k + 1 < args.size():
		shots_dir = args[k + 1]
	rng.seed = 2026
	get_window().title = "Toddler Island"
	get_tree().auto_accept_quit = false
	# the downloadable build opens full screen, like the launcher does (F11 switches back)
	if OS.has_feature("template") and args.is_empty():
		get_window().mode = Window.MODE_FULLSCREEN
	if get_window().mode == Window.MODE_FULLSCREEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	no_sway = args.has("--no-sway")
	SunnyLook.apply(self, 42.0, -32.0)
	WorldLook.globals()
	look = WorldLook.new()
	look.corner = self
	add_child(look)
	valley = ValleyWorld.new()
	valley.corner = self
	valley.name = "Valley"
	add_child(valley)
	valley.light()
	await valley.build_ground()
	_farm()
	_props()
	Places.build(self)
	Places2.build(self)
	Scenery.build(self)
	look.build_sky()
	valley.build_plants()
	_plants()
	valley.build_clouds()
	_animals()
	_explorer()
	if shots_dir != "":
		_photo_tour()
	elif args.has("--bench"):
		_bench(args)
	elif args.has("--toy-test"):
		_toy_test(args)
	elif args.has("--quit-test"):
		_quit_test(args)
	elif args.has("--trip-full"):
		_trip_full()
	elif args.has("--review"):
		_review(args)
	elif args.has("--play-test"):
		_play_test(args)
	elif args.has("--moonshine-test"):
		_moonshine_test()
	elif args.has("--audit"):
		_audit()
	elif args.has("--trip"):
		_trip_tour(args)
	elif args.has("--soak"):
		life.soak(7.0 if args.has("--short") else 20.0)


## Speed check: average frame rate, draw calls and triangles at three views, with optional switches
## (--no-ssil --no-ssao --no-shadows --no-trees --no-grass) to find what costs the most.
func _bench(args: PackedStringArray) -> void:
	get_window().size = Vector2i(1600, 900)
	var env: Environment = (find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment
	if args.has("--no-msaa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if args.has("--fxaa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if args.has("--no-ssil"):
		env.ssil_enabled = false
	if args.has("--no-ssao"):
		env.ssao_enabled = false
	if args.has("--no-glow"):
		env.glow_enabled = false
	if args.has("--msaa0"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if args.has("--pssm2"):
		for l in find_children("*", "DirectionalLight3D", false, false):
			(l as DirectionalLight3D).directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if args.has("--lod4"):
		get_viewport().mesh_lod_threshold = 4.0
	if args.has("--taa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().use_taa = true
	if args.has("--no-shadows"):
		for l in find_children("*", "DirectionalLight3D", false, false):
			(l as DirectionalLight3D).shadow_enabled = false
	for mmi in find_children("*", "MultiMeshInstance3D", false, false):
		var f := (mmi as MultiMeshInstance3D).multimesh.mesh.resource_name
		var n := (mmi as MultiMeshInstance3D).multimesh.instance_count
		if args.has("--no-trees") and (mmi as MultiMeshInstance3D).visibility_range_end == 0.0:
			mmi.visible = false
		if args.has("--no-grass") and (mmi as MultiMeshInstance3D).visibility_range_end > 0.0:
			mmi.visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 1200.0
	add_child(cam)
	cam.make_current()
	for v in [["start", Vector3(0.4, 3.0, 29.6), Vector3(0, 1, 0)], ["wood", Vector3(5.0, 1.7, 11.0), Vector3(40.0, 4.0, -2.0)],
			["above", Vector3(28.0, 24.0, 38.0), Vector3(-2.0, 0.0, -5.0)]]:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for f in 30:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		var frames := 0
		var calls := 0
		var prims := 0
		while Time.get_ticks_usec() - t0 < 3000000:
			await get_tree().process_frame
			frames += 1
			calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			prims = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var secs := (Time.get_ticks_usec() - t0) / 1000000.0
		print("[bench] %s: %.0f fps, %d draw calls, %.2f M triangles" % [v[0], frames / secs, calls, prims / 1000000.0])
	quit_game()


func _process(delta: float) -> void:
	# F11 switches full screen (for the TV)
	if Input.is_key_pressed(KEY_F11) and not _f11_down:
		get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	_f11_down = Input.is_key_pressed(KEY_F11)
	_shadow_t -= delta
	if _shadow_t <= 0.0 and explorer:
		_shadow_t = 0.5
		var cam := get_viewport().get_camera_3d()
		var here := cam.global_position if cam else explorer.global_position
		for t in shadow_tiles:
			var near: bool = Vector2(here.x, here.z).distance_to(t[1]) < 30.0
			(t[0] as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if sea_mat:
		sea_mat.uv1_offset += Vector3(0.004, 0.0025, 0.0) * delta
	if Input.is_key_pressed(KEY_ESCAPE):
		quit_game()
	_heartbeat(delta)


# --- quitting: always closes ------------------------------------------------------------------

var _quitting := false
var _watchdog: Thread


## Quits for sure: speech and sound stop, the engine is asked to close, and if it is still there
## after a moment (a rare race in its shutdown) the process ends. Everything is saved as it happens.
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	DisplayServer.tts_stop()
	AudioServer.set_bus_mute(0, true)
	_watchdog = Thread.new()
	_watchdog.start(func() -> void:
		OS.delay_msec(2500)
		OS.kill(OS.get_process_id()))
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


# --- breadcrumbs: if the game ever freezes, user://heartbeat.txt says what it was doing ----------

var _beat_t := 0.0
var events: Array = []


func note(what: String) -> void:
	events.append("%s %s" % [Time.get_time_string_from_system(), what])
	if events.size() > 30:
		events.pop_front()


func _heartbeat(delta: float) -> void:
	_beat_t -= delta
	if _beat_t > 0.0 or explorer == null:
		return
	_beat_t = 2.0
	var f := FileAccess.open("user://heartbeat.txt", FileAccess.WRITE)
	if f == null:
		return
	var p := explorer.global_position
	f.store_line("time %s  fps %d  stage %d  at (%.1f, %.1f, %.1f)  carrying '%s'  busy %.1f  riding %s" % [Time.get_time_string_from_system(), Engine.get_frames_per_second(),
		trip.stage if trip else -1, p.x, p.y, p.z, explorer.carrying, explorer.busy, play.riding if play else false])
	f.store_line("draws %d  objects %d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	for e in events:
		f.store_line(e)
	f.close()


# --- ground and sea -----------------------------------------------------------------------

## The island ground is gone: the valley (corner/valley_world.gd) builds the ground now.
func _ground() -> void:
	pass


func _sea() -> void:
	var normal := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	normal.noise = fn
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 6.0
	sea_mat = StandardMaterial3D.new()
	sea_mat.albedo_color = Color(0.20, 0.56, 0.66, 0.82)
	sea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea_mat.roughness = 0.12
	sea_mat.metallic_specular = 0.6
	sea_mat.normal_enabled = true
	sea_mat.normal_texture = normal
	sea_mat.normal_scale = 0.35
	sea_mat.uv1_scale = Vector3(0.06, 0.06, 1.0) * 30.0
	sea_mat.proximity_fade_enabled = true
	sea_mat.proximity_fade_distance = 1.6
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	var sea := MeshInstance3D.new()
	sea.mesh = plane
	sea.material_override = sea_mat
	sea.position.y = Terrain.SEA
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


# --- placing things -------------------------------------------------------------------------

## Places a model at real size on the ground. `solid` adds a box the explorer bumps into.
func put(path: String, height: float, x: float, z: float, yaw := 0.0, solid := true, clear := -1.0) -> Node3D:
	var holder := Models.spawn(self, path, height, yaw)
	if holder == null:
		return null
	holder.position = Vector3(x, _ground_under(holder, x, z), z)
	holder.set_meta("file", path.get_file().get_basename())
	var size: Vector3 = holder.get_meta("size")
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x * 0.9, size.y, size.z * 0.9)
		shape.shape = box
		shape.position.y = size.y * 0.5
		body.add_child(shape)
		holder.add_child(body)
	blocked.append([Vector2(x, z), clear if clear >= 0.0 else maxf(size.x, size.z) * 0.55])
	return holder


## Lowest ground under a model's footprint, so nothing floats on a slope.
func _ground_under(holder: Node3D, x: float, z: float) -> float:
	var size: Vector3 = holder.get_meta("size")
	var hx := size.x * 0.4
	var hz := size.z * 0.4
	return minf(minf(Terrain.height(x - hx, z - hz), Terrain.height(x + hx, z - hz)),
		minf(Terrain.height(x - hx, z + hz), Terrain.height(x + hx, z + hz))) - 0.03


func _fence_line(a: Vector2, b: Vector2) -> void:
	fence_lines.append([a, b])
	var probe := Models.spawn(self, B + "Fence.fbx", 1.1, 0.0)
	var seg: float = (probe.get_meta("size") as Vector3).x
	probe.queue_free()
	var d := b - a
	var count := maxi(1, roundi(d.length() / seg))
	var yaw := atan2(-d.y, d.x)
	for i in count:
		var c := a + d * (i + 0.5) / count
		var holder := Models.spawn(self, B + "Fence.fbx", 1.1, 0.0)
		holder.position = Vector3(c.x, Terrain.height(c.x, c.y) - 0.05, c.y)
		holder.rotation.y = yaw
		holder.scale.x = (d.length() / count) / seg
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(seg, 1.2, 0.3)
		shape.shape = box
		shape.position.y = 0.6
		body.add_child(shape)
		holder.add_child(body)
	for t in range(0, int(d.length()), 1):
		fence_points.append([a + d.normalized() * t, Vector2(-d.y, d.x).normalized()])


func _farm() -> void:
	var c: Array = PADDOCK
	_fence_line(c[0], c[1])
	_fence_line(c[1], c[2])
	_fence_line(c[2], Vector2(GATE.y, c[2].y))
	_fence_line(Vector2(GATE.x, c[3].y), c[3])
	_fence_line(c[3], c[0])
	# gate posts either side of the opening
	for gx in [GATE.x, GATE.y]:
		var post := put(P + "Barrel.gltf", 0.9, gx + (-0.5 if gx < 0 else 0.5), c[3].y + 0.6, 0.0, true, 0.6)
	put(B + "Barn.fbx", 7.5, -6.5, -13.0, 6.0, true, 7.0)
	put(B + "ChickenCoop.fbx", 2.3, 7.5, -10.5, -25.0, true, 2.2)
	put(B + "Silo.fbx", 9.0, -28.0, -15.0, 0.0, true, 3.0)
	put(B + "Well.fbx", 2.2, 5.5, 14.5, -20.0, true, 1.6)
	_trough(2.6, -3.2, 0.2)


## A simple wooden water trough (no free model had one).
func _trough(x: float, z: float, yaw: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(x, Terrain.height(x, z) - 0.02, z)
	root.rotation.y = yaw
	add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.48, 0.33, 0.2)
	wood.roughness = 0.9
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.25, 0.55, 0.62)
	water.roughness = 0.1
	for part in [[Vector3(1.9, 0.08, 0.62), Vector3(0, 0.12, 0)], [Vector3(1.9, 0.42, 0.07), Vector3(0, 0.33, 0.28)],
			[Vector3(1.9, 0.42, 0.07), Vector3(0, 0.33, -0.28)], [Vector3(0.07, 0.42, 0.62), Vector3(0.92, 0.33, 0)],
			[Vector3(0.07, 0.42, 0.62), Vector3(-0.92, 0.33, 0)], [Vector3(0.12, 0.12, 0.7), Vector3(0.75, 0.06, 0)],
			[Vector3(0.12, 0.12, 0.7), Vector3(-0.75, 0.06, 0)]]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		m.mesh = bm
		m.material_override = wood
		m.position = part[1]
		root.add_child(m)
	var w := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(1.76, 0.02, 0.5)
	w.mesh = wm
	w.material_override = water
	w.position = Vector3(0, 0.46, 0)
	root.add_child(w)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.6, 0.65)
	shape.shape = box
	shape.position.y = 0.3
	body.add_child(shape)
	root.add_child(body)
	blocked.append([Vector2(x, z), 1.2])


func _props() -> void:
	# the apple tree by the path, with the harvest under it
	put(N + "CommonTree_1.gltf", 5.0, 7.8, 7.2, 40.0, false, 1.6)
	_trunk(7.8, 7.2, 0.35)
	_apples(7.8, 7.2)
	put(P + "FarmCrate_Apple.gltf", 0.45, 6.2, 8.9, 20.0)
	put(P + "Barrel_Apples.gltf", 0.95, 9.4, 5.8, -10.0)
	put(P + "Bench.gltf", 0.48, 9.5, 12.9, 100.0)
	# the cart with the vegetables, on the other side of the path
	put(P + "Stall_Cart_Empty.gltf", 2.3, -6.8, 6.6, 35.0, true, 2.2)
	put(P + "FarmCrate_Carrot.gltf", 0.45, -4.4, 5.0, -15.0)
	# (the yard itself is kept clear: a few crates and buckets made it look cluttered)
	# rocks at the hill foot and on the beach
	for r in [[-24.0, -20.0, 1.6], [-27.0, -18.5, 1.0], [14.5, -18.0, 1.3], [-36.0, 4.0, 1.4], [-34.5, 18.0, 1.1],
			[-38.0, 13.0, 0.8], [17.0, 12.0, 1.0], [-11.0, 24.0, 0.9]]:
		put(N + ("Rock_Medium_1.gltf" if int(r[0]) % 2 == 0 else "Rock_Medium_3.gltf"), r[2], r[0], r[1], rng.randf() * 360.0, true)


## Red apples hung in the orchard tree's crown and a few fallen in the grass (the tree model has none).
func _apples(x: float, z: float) -> void:
	var apple := SphereMesh.new()
	apple.radius = 0.065
	apple.height = 0.13
	apple.radial_segments = 10
	apple.rings = 6
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.82, 0.12, 0.10)
	red.roughness = 0.45
	apple.material = red
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = apple
	mm.instance_count = 46
	var ground := Terrain.height(x, z)
	for i in 46:
		var p: Vector3
		if i < 38:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.9, 1.55)
			p = Vector3(x + cos(a) * r, ground + rng.randf_range(2.4, 4.2), z + sin(a) * r)
		else:
			var a2 := rng.randf() * TAU
			var r2 := rng.randf_range(0.4, 2.0)
			p = Vector3(x + cos(a2) * r2, Terrain.height(x + cos(a2) * r2, z + sin(a2) * r2) + 0.05, z + sin(a2) * r2)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _trunk(x: float, z: float, r: float) -> void:
	trunks.append([Vector2(x, z), r])
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = 3.0
	shape.shape = cyl
	body.position = Vector3(x, Terrain.height(x, z) + 1.5, z)
	body.add_child(shape)
	add_child(body)


# --- many copies: trees and plants ---------------------------------------------------------

func _is_free(x: float, z: float, margin: float) -> bool:
	if Terrain.height(x, z) < 0.25 or Terrain.path_distance(x, z) < 1.25 + margin * 0.5 or Terrain.stream_distance(x, z) < 1.7 + margin * 0.3:
		return false
	for b in blocked:
		if Vector2(x, z).distance_to(b[0]) < b[1] + margin:
			return false
	return true


func _trees() -> void:
	var spots: Array = []
	var lists := {"pine": ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"],
		"broad": ["CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"]}
	for i in 16000:
		var x := rng.randf_range(-55.0, 112.0)
		var z := rng.randf_range(-75.0, 90.0)
		var p := Vector2(x, z)
		var from_centre := p.distance_to(Terrain.CENTRE)
		if from_centre > 76.0:
			continue
		# keep the places open: pond, cottage garden, orchard, hill top, lighthouse
		if p.distance_to(Terrain.POND) < 16.0 or p.distance_to(Terrain.COTTAGE) < 15.0 or p.distance_to(Terrain.ORCHARD) < 13.0 				or p.distance_to(Terrain.HILL) < 9.0 or p.distance_to(Terrain.LIGHTHOUSE) < 10.0 or p.distance_to(Terrain.OAK) < 7.0 or p.distance_to(Terrain.VISITOR) < 12.0 or p.distance_to(Terrain.CAMP) < Terrain.CAMP_R + 1.0 or p.distance_to(Terrain.SAFARI) < Terrain.SAFARI_R + 12.0:
			continue
		var wood := Terrain.sstep(64.0, 72.0, x)
		var hill := Terrain.sstep(34.0, 18.0, p.distance_to(Terrain.HILL)) * 0.32
		var edge := Terrain.sstep(52.0, 66.0, from_centre) * 0.12
		if rng.randf() > maxf(maxf(wood * 0.8, hill), maxf(edge * 1.6, 0.05)):
			continue
		if not _is_free(x, z, 2.0) or Terrain.is_sand(x, z) > 0.2:
			continue
		var near := false
		# the deep woods, away from the paths, are a little thinner (trees are the costliest thing to draw)
		var gap := 6.6 if Terrain.path_distance(x, z) > 9.0 else 5.2
		for s in spots:
			if Vector2(x, z).distance_to(s) < gap:
				near = true
				break
		if near:
			continue
		spots.append(Vector2(x, z))
	var groups := {}
	for s in spots:
		var pine := rng.randf() < 0.45
		var names: Array = lists["pine" if pine else "broad"]
		var file: String = names[rng.randi() % names.size()]
		var h := rng.randf_range(9.0, 14.0)
		(groups.get_or_add(file, []) as Array).append([s.x, s.y, h, rng.randf() * TAU])
		_trunk(s.x, s.y, 0.4)
	print("[corner] trees: ", spots.size())
	for file in groups:
		_multi(N + file + ".gltf", groups[file], 0.012, true)


func _plants() -> void:
	var grass: Dictionary = {"Grass_Common_Short": [], "Grass_Wispy_Short": [], "Grass_Common_Tall": [], "Grass_Wispy_Tall": []}
	var flowers: Dictionary = {"Flower_3_Group": [], "Flower_4_Group": [], "Flower_3_Single": [], "Flower_4_Single": []}
	var other: Dictionary = {"Bush_Common": [], "Bush_Common_Flowers": [], "Fern_1": [], "Clover_1": [], "Clover_2": [],
		"Mushroom_Common": [], "Plant_1": [], "Plant_7": [], "Pebble_Round_2": [], "Pebble_Round_3": [],
		"RockPath_Round_Small_1": [], "RockPath_Round_Small_2": []}
	# grass tufts in clumps everywhere, thicker along fences and against buildings
	for i in 2300:
		var cx := rng.randf_range(-50.0, 108.0)
		var cz := rng.randf_range(-70.0, 86.0)
		if Vector2(cx, cz).distance_to(Terrain.CENTRE) > 72.0 or Terrain.in_farm(Vector2(cx, cz)) or Vector2(cx, cz).distance_to(Terrain.CAMP) < Terrain.CAMP_R:
			continue
		_clump(grass, ["Grass_Common_Short", "Grass_Wispy_Short", "Grass_Common_Short"], cx, cz, rng.randi_range(5, 12), 1.8, 0.24, 0.48)
	for fp in fence_points:
		for side in [-1.0, 1.0]:
			var p: Vector2 = fp[0] + fp[1] * side * rng.randf_range(0.3, 0.9)
			# only outside the farmyard fence, and not every post
			if Terrain.in_yard(p) or rng.randf() < 0.5:
				continue
			_clump(grass, ["Grass_Common_Tall", "Grass_Wispy_Tall", "Grass_Common_Short"], p.x, p.y, rng.randi_range(2, 4), 0.5, 0.35, 0.65)
	# flowers along both sides of the paths and outside the fence
	for line in Terrain.PATHS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var steps := int(a.distance_to(b) / 2.2)
			for s in steps:
				var p := a.lerp(b, (s + rng.randf()) / maxf(steps, 1))
				var side := Vector2(-(b - a).y, (b - a).x).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
				var q := p + side * rng.randf_range(1.6, 2.8)
				var kind: String = ["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single"].pick_random()
				_clump(flowers, [kind], q.x, q.y, rng.randi_range(2, 5), 0.6, 0.3, 0.5)
	for fp in fence_points:
		if rng.randf() < 0.18:
			var p: Vector2 = fp[0] + fp[1] * rng.randf_range(0.6, 1.4)
			_clump(flowers, [["Flower_3_Group", "Flower_4_Group"].pick_random()], p.x, p.y, rng.randi_range(2, 4), 0.5, 0.3, 0.5)
		if rng.randf() < 0.08:
			var p2: Vector2 = fp[0] + fp[1] * rng.randf_range(1.0, 1.6)
			_clump(other, ["Bush_Common_Flowers"], p2.x, p2.y, 1, 0.1, 0.8, 1.15)
	for i in 170:
		_clump(flowers, [["Flower_3_Group", "Flower_4_Group", "Flower_3_Single"].pick_random()],
			rng.randf_range(-45.0, 100.0), rng.randf_range(-65.0, 80.0), rng.randi_range(3, 7), 1.0, 0.3, 0.5)
	# wildflowers thick in the orchard and round the cottage garden
	for i in 40:
		var o: Vector2 = [Terrain.ORCHARD, Terrain.COTTAGE, Terrain.HILL].pick_random()
		_clump(flowers, [["Flower_3_Group", "Flower_4_Group", "Flower_4_Single"].pick_random()],
			o.x + rng.randf_range(-12.0, 12.0), o.y + rng.randf_range(-12.0, 12.0), rng.randi_range(4, 8), 1.2, 0.3, 0.55)
	# reeds round the pond
	for i in 60:
		var a := rng.randf() * TAU
		var r := rng.randf_range(9.6, 11.5)
		_clump(grass, ["Grass_Common_Tall", "Grass_Wispy_Tall"], Terrain.POND.x + cos(a) * r, Terrain.POND.y + sin(a) * r, rng.randi_range(3, 6), 0.6, 0.6, 1.0)
	for i in 50:
		_clump(other, ["Clover_1", "Clover_2"], rng.randf_range(-40.0, 100.0), rng.randf_range(-60.0, 80.0), rng.randi_range(4, 9), 0.9, 0.1, 0.18)
	# bushes and ferns along the wood's edge and under the trees, mushrooms in the shade
	for i in 260:
		var x := rng.randf_range(64.0, 105.0)
		var z := rng.randf_range(-45.0, 45.0)
		if Vector2(x, z).distance_to(Terrain.CAMP) < Terrain.CAMP_R:
			continue
		_clump(other, ["Fern_1", "Fern_1", "Plant_1"], x, z, rng.randi_range(1, 4), 1.2, 0.5, 0.9)
	for i in 40:
		_clump(other, ["Bush_Common_Flowers", "Bush_Common_Flowers", "Bush_Common_Flowers", "Bush_Common_Flowers", "Bush_Common_Flowers", "Bush_Common_Flowers"], rng.randf_range(60.0, 70.0), rng.randf_range(-40.0, 40.0), 1, 0.1, 0.8, 1.3)
	for i in 30:
		_clump(other, ["Mushroom_Common"], rng.randf_range(66.0, 100.0), rng.randf_range(-40.0, 40.0), rng.randi_range(2, 4), 0.4, 0.08, 0.14)
	for i in 40:
		_clump(other, ["Bush_Common_Flowers", "Bush_Common_Flowers", "Bush_Common_Flowers", "Bush_Common_Flowers", "Bush_Common_Flowers", "Bush_Common_Flowers"], rng.randf_range(-35.0, 95.0), rng.randf_range(-55.0, 75.0), 1, 0.1, 0.8, 1.2)
	# stones at the path edges
	for line in Terrain.PATHS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			for s in int(a.distance_to(b) / 2.5):
				var p := a.lerp(b, rng.randf())
				var side := Vector2(-(b - a).y, (b - a).x).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
				var q := p + side * rng.randf_range(0.9, 1.4)
				var kind: String = ["Pebble_Round_2", "Pebble_Round_3", "Pebble_Round_2", "RockPath_Round_Small_1"].pick_random()
				var size := rng.randf_range(0.03, 0.06) if kind.begins_with("RockPath") else rng.randf_range(0.05, 0.1)
				(other[kind] as Array).append([q.x, q.y, size, rng.randf() * TAU])
	for d in [grass, flowers, other]:
		for file in d:
			var sway := 0.0 if file.begins_with("Pebble") or file.begins_with("RockPath") or file.begins_with("Mushroom") else 0.07
			if file.begins_with("Bush"):
				sway = 0.025
			_multi(N + file + ".gltf", d[file], sway, file.begins_with("Bush") or file.begins_with("Fern") or file.begins_with("Plant"))


func _clump(into: Dictionary, kinds: Array, cx: float, cz: float, count: int, spread: float, h0: float, h1: float) -> void:
	for i in count:
		var x := cx + rng.randfn(0.0, spread * 0.5)
		var z := cz + rng.randfn(0.0, spread * 0.5)
		if not _is_free(x, z, 0.0) or Terrain.is_sand(x, z) > 0.4:
			continue
		var kind: String = kinds.pick_random()
		(into[kind] as Array).append([x, z, rng.randf_range(h0, h1), rng.randf() * TAU])


## Draws many copies of one plant or tree in a single call. Each entry: [x, z, height, yaw].
func _multi(path: String, entries: Array, sway: float, shadows: bool) -> void:
	if entries.is_empty() or not ResourceLoader.exists(path):
		return
	var info := Models.mesh_of(path)
	if info.is_empty():
		return
	var mesh: Mesh = (info["mesh"] as Mesh).duplicate()
	var file_h: float = info["height"]
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if sway > 0.0 and not no_sway and m is BaseMaterial3D and _is_foliage(m as BaseMaterial3D):
			mesh.surface_set_material(s, _foliage_material(m as BaseMaterial3D, file_h, sway))
	var xf: Transform3D = info["xf"]
	var bottom: float = info["bottom"]
	# split into 16 m tiles so tiles out of view or far away are skipped (one batch per tile)
	var fade := _view_distance(path)
	var tiles := {}
	for e in entries:
		var tile := 16.0 if fade == 0.0 else 32.0  # trees in small squares: far squares use simpler trees
		var key := Vector2i(floori(e[0] / tile), floori(e[1] / tile))
		(tiles.get_or_add(key, []) as Array).append(e)
	for key in tiles:
		var list: Array = tiles[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var e: Array = list[i]
			var s: float = e[2] / file_h
			var basis := Basis(Vector3.UP, e[3]).scaled(Vector3(s, s, s))
			var pos := Vector3(e[0], Terrain.height(e[0], e[1]) - bottom * s - 0.03, e[1])
			mm.set_instance_transform(i, Transform3D(basis, pos) * xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var tsz := 16.0 if fade == 0.0 else 32.0
		var tile_centre := Vector2((key.x + 0.5) * tsz, (key.y + 0.5) * tsz)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if shadows and fade == 0.0:
			shadow_tiles.append([mmi, tile_centre])
		if fade > 0.0:
			mmi.visibility_range_end = fade
			mmi.visibility_range_end_margin = 12.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


## How far away each kind of plant is still drawn (0 = always).
func _view_distance(path: String) -> float:
	var f := path.get_file()
	if f.begins_with("Pebble") or f.begins_with("RockPath") or f.begins_with("Clover") or f.begins_with("Mushroom"):
		return 45.0
	if f.begins_with("Grass"):
		return 55.0
	if f.begins_with("Flower"):
		return 75.0
	if f.begins_with("Fern") or f.begins_with("Plant"):
		return 75.0
	if f.begins_with("Bush"):
		return 110.0
	return 0.0


func _is_foliage(m: BaseMaterial3D) -> bool:
	if m.albedo_texture == null:
		return false
	var p := m.albedo_texture.resource_path.get_file().to_lower() + " " + m.resource_name.to_lower()
	for word in ["leaves", "leaf", "grass", "flower", "petal", "fern", "plant", "clover", "bush"]:
		if p.contains(word):
			return true
	return m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED


func _foliage_material(m: BaseMaterial3D, file_h: float, sway: float) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = FOLIAGE
	sm.set_shader_parameter("albedo_tex", m.albedo_texture)
	sm.set_shader_parameter("tint", m.albedo_color)
	sm.set_shader_parameter("alpha_cut", m.alpha_scissor_threshold if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.35)
	sm.set_shader_parameter("sway", file_h * sway)
	sm.set_shader_parameter("sway_height", file_h)
	return sm


# --- the animals and the explorer -----------------------------------------------------------

func _animals() -> void:
	pass  # the animals are part of life.gd, built once the explorer exists


func _explorer() -> void:
	explorer = Explorer.new()
	explorer.position = Vector3(Terrain.START.x, Terrain.height(Terrain.START.x, Terrain.START.y) + 0.1, Terrain.START.y)
	add_child(explorer)
	follow = FollowCamera.new()
	follow.target = explorer
	follow.yaw = 0.0
	add_child(follow)
	life = Life.new()
	add_child(life)
	life.build(self, explorer)
	print("[corner] grass clumps: ", valley.build_grass())
	trip = Trip.new()
	add_child(trip)
	trip.setup(self)
	life.trip = trip
	play = Play.new()
	add_child(play)
	play.setup(self)
	life.play = play
	var critters := Critters.new()
	add_child(critters)
	critters.setup(self)
	var p3 := Places3.new()
	add_child(p3)
	p3.setup(self)
	var p4 := Places4.new()
	add_child(p4)
	p4.setup(self)
	var wild := Wildlife.new()
	add_child(wild)
	wild.setup(self)
	var amb := Ambience.new()
	add_child(amb)
	amb.setup(self)
	audio = AudioLife.new()
	add_child(audio)
	audio.setup(self)
	life.audio = audio
	_bake_blocks()
	_batch_props()
	_tune_draw()


## Speed: lots of identical static models (fence pieces, crops, garden flowers, pumpkins, stones,
## barrels) are drawn as one batch per model instead of one draw each. Their holder nodes stay, so
## anything that refers to where they are still works; toys that wiggle keep their own meshes.
const BATCH := ["Fence", "pumpkin", "stone_", "Rock_Medium", "Bucket_Wooden", "Barrel", "FarmCrate", "Crate_", "Stool", "rock_small"]


func _batch_props() -> void:
	var toys := {}
	for t in get_meta("toys", []):
		toys[t["node"]] = true
	var groups := {}   # key -> [mesh, materials Array, transforms Array, shadow]
	var count := 0
	for h in get_children():
		if not (h is Node3D) or not h.has_meta("size") or toys.has(h) or h.get_child_count() == 0:
			continue
		var src: String = String(h.get_child(0).scene_file_path).get_file()
		var ok := false
		for b in BATCH:
			if src.begins_with(b):
				ok = true
				break
		if not ok:
			continue
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null or m.skeleton != NodePath("") and m.get_node_or_null(m.skeleton) is Skeleton3D:
				continue
			var mats: Array = []
			for k in m.mesh.get_surface_count():
				mats.append(m.get_surface_override_material(k) if m.get_surface_override_material(k) else m.mesh.surface_get_material(k))
			var key := str(m.mesh.get_rid().get_id()) + "|" + str(m.material_override)
			if not groups.has(key):
				groups[key] = [m.mesh, mats, [], m.cast_shadow, m.material_override]
			(groups[key][2] as Array).append(m.global_transform)
			m.queue_free()
			count += 1
	for key in groups:
		var g: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = g[0]
		var xfs: Array = g[2]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = g[3]
		if g[4]:
			mmi.material_override = g[4]
		else:
			var mesh: Mesh = g[0]
			var differs := false
			for k in (g[1] as Array).size():
				if g[1][k] != mesh.surface_get_material(k):
					differs = true
			if differs and mesh is ArrayMesh:
				var copy := (mesh as ArrayMesh).duplicate() as ArrayMesh
				for k in (g[1] as Array).size():
					copy.surface_set_material(k, g[1][k])
				mm.mesh = copy
		mmi.visibility_range_end = 160.0
		add_child(mmi)
	print("[corner] batched %d props into %d draws" % [count, groups.size()])


## Speed: the hand-built things (cottage, jetty, bridges, treehouse, gantry...) are made of many
## blocks. Blocks under the same parent are merged into one mesh per material, so a cottage costs a
## few draws instead of dozens. They still move with their parent (the gate, the swing seat).
func _bake_blocks() -> void:
	var parents := {}
	for n in find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("block") and n.get_child_count() == 0 and (n as MeshInstance3D).visible:
			var par: Node = n.get_parent()
			if not parents.has(par):
				parents[par] = []
			(parents[par] as Array).append(n)
	var before := 0
	var after := 0
	for par in parents:
		var list: Array = parents[par]
		if list.size() < 2:
			continue
		var by_mat := {}
		for mi in list:
			var m: Material = (mi as MeshInstance3D).material_override
			if not by_mat.has(m):
				by_mat[m] = []
			(by_mat[m] as Array).append(mi)
		var mesh := ArrayMesh.new()
		var shadow := false
		for m in by_mat:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for mi in by_mat[m]:
				var b := mi as MeshInstance3D
				st.append_from(b.mesh, 0, b.transform)
				shadow = shadow or b.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, m)
		var merged := MeshInstance3D.new()
		merged.mesh = mesh
		merged.name = "Baked"
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(par as Node).add_child(merged)
		before += list.size()
		after += 1
		for mi in list:
			(mi as Node).queue_free()
	print("[corner] baked %d blocks into %d meshes" % [before, after])


## Speed: every small thing fades out with distance (the island is small, so far-off small things
## are a few pixels), and small things cast no shadow. Landmarks, the ground, water, sky, grass and
## trees (which have their own ranges) and the space sets are left alone.
func _tune_draw() -> void:
	var count := 0
	for h in find_children("*", "Node3D", true, false):
		if not h.has_meta("file") or not h.has_meta("size"):
			continue
		var size: Vector3 = h.get_meta("size")
		var big := maxf(size.x, maxf(size.y, size.z))
		if big > 1.5:
			continue
		for g in h.find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if gi is GPUParticles3D or gi is Label3D or gi.visibility_range_end > 0.0:
				continue
			gi.visibility_range_end = 70.0 + big * 40.0
			gi.visibility_range_end_margin = 12.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			count += 1
	print("[corner] distance-faded: ", count)


## Runs each activity and photographs it (--play-test <dir>).
func _play_test(args: PackedStringArray) -> void:
	get_window().size = Vector2i(1600, 900)
	var k := args.find("--play-test")
	var dir := args[k + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	for f in 60:
		await get_tree().process_frame
	var snap := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
		print("[play-test] %s at %d fps" % [name, Engine.get_frames_per_second()])
	var wait := func(t: float) -> void:
		await get_tree().create_timer(t).timeout
	var go := func(p: Vector2, look: Vector2) -> void:
		explorer.global_position = Vector3(p.x, Terrain.height(p.x, p.y) + 0.1, p.y)
		explorer.face(Vector3(look.x, 0, look.y))
		follow.yaw = atan2(p.x - look.x, p.y - look.y)
		follow.global_position = explorer.global_position + Vector3.UP * 1.1
	var upto := int(args[args.find("--upto") + 1]) if args.has("--upto") else 99
	var press := func() -> String:
		var r: String = life.her_button()
		print("[play-test] pressed -> ", r)
		return r
	# the prompt at the apple crate, then picking up
	await go.call(Vector2(6.2, 10.2), Vector2(6.2, 8.9))
	await wait.call(1.0)
	await snap.call("01-prompt-apple")
	await press.call()
	await wait.call(0.8)
	await snap.call("02-carrying-apple")
	explorer.drop()
	if upto <= 1:
		quit_game()
		return
	# the swing
	var sw: Node3D = get_meta("swing")
	var swp := Vector2(sw.global_position.x, sw.global_position.z)
	await go.call(swp + Vector2(-0.6, 1.4), swp)
	await wait.call(0.5)
	await snap.call("03-prompt-swing")
	await press.call()
	await wait.call(2.2)
	await snap.call("04-swinging")
	await wait.call(6.5)
	if upto <= 2:
		quit_game()
		return
	# the kite
	var kite := get_node("Kite") as Node3D
	var anchor: Vector3 = kite.get_meta("anchor")
	await go.call(Vector2(anchor.x + 1.0, anchor.z + 1.0), Vector2(anchor.x, anchor.z))
	await wait.call(0.5)
	await press.call()
	await wait.call(0.6)
	explorer.auto_input = Vector2(0.0, 1.0)
	await wait.call(3.0)
	explorer.auto_input = Vector2.ZERO
	await wait.call(1.5)
	await snap.call("05-kite-held")
	await press.call()
	if upto <= 3:
		quit_game()
		return
	# the apple tree in the orchard
	var tree_at := Terrain.ORCHARD + Vector2(0, -6.5)
	await go.call(tree_at + Vector2(0, 1.6), tree_at)
	await wait.call(0.6)
	await snap.call("06-prompt-tree")
	await press.call()
	await wait.call(1.2)
	await snap.call("07-apple-fell")
	explorer.drop()
	if upto <= 4:
		quit_game()
		return
	# the boat
	var boat: Node3D = get_meta("row_boat")
	await go.call(Vector2(boat.global_position.x - 1.2, boat.global_position.z + 1.6), Vector2(boat.global_position.x, boat.global_position.z))
	await wait.call(0.5)
	await press.call()
	await wait.call(5.0)
	await snap.call("08-rowing")
	await wait.call(11.5)
	if upto <= 5:
		quit_game()
		return
	# the horse: the choice of what to do, then a ride
	var horse: Node3D = null
	for a in life.animals:
		if a.get_meta("kind", "") == "horse":
			horse = a
	if horse:
		var hp := Vector2(horse.global_position.x, horse.global_position.z)
		await go.call(hp + Vector2(1.4, 0.2), hp)
		await wait.call(0.6)
		await snap.call("09-horse-choices")
		if life.prompt.has_method("choose"):
			life.prompt.choose(1)
		await press.call()
		await wait.call(2.5)
		await snap.call("10-horse-ride")
		await wait.call(7.0)
	if upto <= 6:
		quit_game()
		return
	# the slide
	for t in get_meta("toys", []):
		if t["kind"] == "slide":
			var sl: Node3D = t["node"]
			var sp := Vector2(sl.global_position.x, sl.global_position.z)
			await go.call(sp + Vector2(0, 2.4), sp)
			await wait.call(0.4)
			await press.call()
			await wait.call(2.2)
			await snap.call("11-slide")
			await wait.call(2.0)
	if upto <= 7:
		quit_game()
		return
	# the bridges
	for b in get_meta("bridges", []):
		var at: Vector2 = b[0]
		var dir2: Vector2 = b[1]
		var side := Vector2(-dir2.y, dir2.x)
		await go.call(at - dir2 * 4.5, at)
		await wait.call(0.4)
		explorer.auto_input = Vector2(0.0, 1.0)
		await wait.call(1.6)
		await snap.call("12-on-bridge-%d" % int(at.x))
		explorer.auto_input = Vector2.ZERO
		var cam2 := Camera3D.new()
		add_child(cam2)
		cam2.make_current()
		cam2.global_position = Vector3(at.x, Terrain.height(at.x, at.y, false), at.y) + Vector3(side.x * 6.0, 1.2, side.y * 6.0)
		cam2.look_at(Vector3(at.x, Terrain.height(at.x, at.y, false), at.y), Vector3.UP)
		await wait.call(0.4)
		await snap.call("13-bridge-side-%d" % int(at.x))
		cam2.queue_free()
		follow.cam.make_current()
	if upto <= 8:
		quit_game()
		return
	# wildlife and the pond
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(Terrain.POND.x - 9.0, 2.0, Terrain.POND.y + 9.0)
	cam.look_at(Vector3(Terrain.POND.x, 0.2, Terrain.POND.y), Vector3.UP)
	await wait.call(1.0)
	await snap.call("14-ducks")
	life.stickers.toggle()
	await wait.call(0.6)
	await snap.call("15-sticker-book")
	life.stickers.toggle()
	life.play._show_board()
	await wait.call(1.5)
	await snap.call("16-board")
	quit_game()


func _moonshine_test() -> void:
	for f in 30:
		await get_tree().process_frame
	trip._show_banner()
	audio.play_moonshine()
	await get_tree().create_timer(5.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[-1])
	quit_game()


## Stands her at spots round the island and photographs the normal view (--review <dir>).
func _review(args: PackedStringArray) -> void:
	var k := args.find("--review")
	var dir := args[k + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	for f in 90:
		await get_tree().process_frame
	var spots := [["start", Terrain.START, Vector2(37.5, 38.0)], ["loop-south", Vector2(26.7, 31.4), Vector2(17.7, 24.2)],
		["farm-path", Vector2(6.0, 11.0), Vector2(0.0, 2.0)], ["loop-west", Vector2(12.7, 2.2), Vector2(17.7, -8.2)],
		["hill-path", Vector2(32.0, -28.0), Vector2(26.5, -44.0)], ["hill-top", Terrain.HILL + Vector2(2, 6), Vector2(38.0, 8.0)],
		["orchard", Vector2(59.0, -14.0), Terrain.ORCHARD], ["wood", Vector2(71.0, 6.0), Terrain.OAK],
		["beach-path", Vector2(63.0, 34.0), Terrain.LIGHTHOUSE], ["rocket-path", Vector2(46.0, 44.5), Terrain.ROCKET],
		["visitor-path", Vector2(4.0, -28.0), Terrain.VISITOR], ["pond-jetty", Vector2(40.5, 24.0), Terrain.POND]]
	var total := 0.0
	for s in spots:
		var p: Vector2 = s[1]
		var look: Vector2 = s[2]
		explorer.global_position = Vector3(p.x, Terrain.height(p.x, p.y) + 0.1, p.y)
		explorer.face(Vector3(look.x, 0, look.y))
		follow.yaw = atan2(p.x - look.x, p.y - look.y)
		follow.global_position = explorer.global_position + Vector3.UP * 1.1
		for f in 50:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for f in 60:
			await get_tree().process_frame
		var fps := 60.0 / ((Time.get_ticks_usec() - t0) / 1000000.0)
		total += fps
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(String(s[0]) + ".png"))
		print("[review] %s: %.0f fps, %d draws, %.2f M tris" % [s[0], fps, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000000.0])
	print("[review] average %.0f fps" % (total / spots.size()))
	quit_game()


## The whole trip at its real pace, then life back home, then quit (--trip-full).
func _trip_full() -> void:
	trip.shots_mode = not OS.get_cmdline_user_args().has("--tts")
	trip.photo_dir = OS.get_user_data_dir().path_join("test-photos")
	for f in 60:
		await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	var log := func(what: String) -> void:
		print("[trip-full] %6.1fs %s (stage %d, fps %d)" % [(Time.get_ticks_msec() - t0) / 1000.0, what, trip.stage, Engine.get_frames_per_second()])
	trip.start()
	var last := -1
	while trip.stage != 7:
		if trip.stage != last:
			last = trip.stage
			log.call("stage")
		await get_tree().process_frame
	log.call("on the Moon")
	await get_tree().create_timer(1.5).timeout
	explorer.auto_input = Vector2(0.3, 1.0)
	await get_tree().create_timer(4.0).timeout
	explorer.auto_input = Vector2.ZERO
	log.call("walked %d steps" % trip.steps)
	await get_tree().create_timer(12.0).timeout
	log.call("after the banner")
	trip.her_button()
	await get_tree().create_timer(1.0).timeout
	trip.her_button()
	# back to the rocket and home
	var l: Vector3 = trip.lander.global_position
	explorer.global_position = l + Vector3(2.0, 0.3, 1.0)
	await get_tree().create_timer(0.5).timeout
	log.call("pressing at the rocket: " + trip.her_button())
	while trip.active:
		if trip.stage != last:
			last = trip.stage
			log.call("stage")
		await get_tree().process_frame
	log.call("home")
	explorer.auto_input = Vector2(0.0, 1.0)
	await get_tree().create_timer(10.0).timeout
	explorer.auto_input = Vector2(1.0, 0.0)
	await get_tree().create_timer(10.0).timeout
	explorer.auto_input = Vector2.ZERO
	log.call("walked about at home")
	if OS.get_cmdline_user_args().has("--twice") and not has_meta("second"):
		set_meta("second", true)
		explorer.global_position = Vector3(Terrain.ROCKET.x - 3.4, Terrain.height(Terrain.ROCKET.x - 3.4, Terrain.ROCKET.y - 1.4) + 0.2, Terrain.ROCKET.y - 1.4)
		log.call("second trip")
		_trip_full()
		return
	quit_game()


func _quit_test(args: PackedStringArray) -> void:
	for f in 120:
		await get_tree().process_frame
	if args.has("--speak"):
		for w in ["One", "Two", "Three", "Hello there little one", "A carrot!", "Wheee!", "Up, up, up!", "Bye bye, kite!", "An apple!", "Row, row, row your boat!", "Giddy up!", "Wheee!", "Round and round!", "The map!", "Hooray! Feed the horse!"]:
			life.stickers._say_later(w, 0.0)
		await get_tree().create_timer(0.5).timeout
	if args.has("--board"):
		play._show_board()
		await get_tree().create_timer(0.5).timeout
	print("[quit-test] quitting")
	quit_game()


## Presses every single thing that answers her button and photographs the moment, then lays the
## photos out on contact sheets of 12 (--toy-test <dir>). Results go to <dir>/results.txt.
func _toy_test(args: PackedStringArray) -> void:
	get_window().size = Vector2i(1280, 720)
	var dir := args[args.find("--toy-test") + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	for f in 60:
		await get_tree().process_frame
	var lines: Array = []
	var shots: Array = []
	var done := {}
	var entries: Array = life.interact.entries.duplicate()
	var idx := 0
	for e in entries:
		if not e.has("act") or not life.interact.available(e):
			continue
		var name: String = e["name"]
		if name == "rocket" or (args.has("--from-toys") and not (name.begins_with("toy:") or name in ["boat", "fishing", "sandcastle", "garden", "apple tree", "bench", "flower", "beehive", "lighthouse", "board", "frog", "crab", "duck"])):
			continue
		var p: Vector3 = (e["pos"] as Callable).call()
		var key := "%s@%d,%d" % [name, int(p.x / 3.0), int(p.z / 3.0)]
		if done.has(key) or name in ["bench", "flower"] and done.has(name):
			continue
		done[key] = true
		done[name] = true
		# stand her a little way off, on open ground, facing it
		var best := Vector2(p.x + 1.5, p.z)
		for k in 12:
			var a := k * TAU / 12.0
			var reach: float = minf(float(e["reach"]) * 0.7, 2.0)
			var q := Vector2(p.x, p.z) + Vector2.from_angle(a) * reach
			if Terrain.height(q.x, q.y) > 0.2 and life._clear(q, 0.2):
				best = q
				break
		explorer.drop()
		explorer.busy = 0.0
		explorer.global_position = Vector3(best.x, Terrain.height(best.x, best.y) + 0.1, best.y)
		explorer.face(p)
		follow.yaw = atan2(best.x - p.x, best.y - p.y)
		follow.global_position = explorer.global_position + Vector3.UP * 1.1
		for f in 20:
			await get_tree().process_frame
		var label: Variant = e.get("label", "")
		if label is Callable:
			label = (label as Callable).call()
		var r := ""
		r = (e["act"] as Callable).call()
		await get_tree().create_timer(1.3).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		idx += 1
		var file := dir.path_join("%03d %s.png" % [idx, name.replace(":", "-").replace("/", "-")])
		img.save_png(file)
		shots.append([file, "%d %s" % [idx, name]])
		lines.append("%3d  %-22s %-30s -> %s   at (%.1f, %.1f)" % [idx, name, String(label), r, p.x, p.z])
		print("[toy-test] ", lines[-1])
		# let rides and busy actions finish
		var wait := 0.0
		while (play.riding or explorer.busy > 0.3) and wait < 20.0:
			await get_tree().create_timer(0.5).timeout
			wait += 0.5
		if play.board_ui:
			play._show_board()
		if explorer.carrying == "kite":
			play.drop_kite()
		explorer.drop()
	var out := FileAccess.open(dir.path_join("results.txt"), FileAccess.WRITE)
	for l in lines:
		out.store_line(l)
	out.close()
	# contact sheets
	var sheet_i := 0
	for s in range(0, shots.size(), 12):
		var sheet := Image.create(1920, 810, false, Image.FORMAT_RGB8)
		for k in mini(12, shots.size() - s):
			var im := Image.load_from_file(shots[s + k][0])
			im.resize(480, 270)
			sheet.blit_rect(im, Rect2i(0, 0, 480, 270), Vector2i((k % 4) * 480, (k / 4) * 270))
		sheet_i += 1
		sheet.save_png(dir.path_join("sheet-%02d.png" % sheet_i))
	print("[toy-test] %d things pressed, %d sheets" % [lines.size(), sheet_i])
	quit_game()


# --- release audit: things on top of each other, on paths, in water, floating ---------------

func _audit() -> void:
	var things: Array = []
	for n in find_children("*", "Node3D", true, false):
		if n.has_meta("file") and n.has_meta("size"):
			var s: Vector3 = n.get_meta("size")
			var p := (n as Node3D).global_position
			things.append([String(n.get_meta("file")), Vector2(p.x, p.z), maxf(s.x, s.z) * 0.45, p.y, s.y])
	print("[audit] placed models: ", things.size())
	var small := ["crops_dirtRow", "crop_carrot", "crop_pumpkin", "crops_cornStageD", "crop_turnip", "crops_leafsStageB", "crop_melon", "pumpkin", "flower_yellowA", "flower_redA", "flower_purpleA", "mushroom_red", "mushroom_tan", "mushroom_redGroup", "campfire_logs", "campfire_stones"]
	var n_over := 0
	for i in things.size():
		for j in range(i + 1, things.size()):
			var a: Array = things[i]
			var b: Array = things[j]
			if a[0] in small and b[0] in small:
				continue
			if a[2] < 0.15 or b[2] < 0.15:
				continue
			var d := (a[1] as Vector2).distance_to(b[1])
			if d < (float(a[2]) + float(b[2])) * 0.75:
				n_over += 1
				print("[audit] OVERLAP %s @%s r%.1f  x  %s @%s r%.1f  d=%.2f" % [a[0], a[1], a[2], b[0], b[1], b[2], d])
	for t in things:
		var p: Vector2 = t[1]
		var h := Terrain.height(p.x, p.y)
		var nm: String = t[0]
		if not nm.begins_with("signpost") and not nm.begins_with("bridge") and float(t[2]) > 0.15 and Terrain.path_distance(p.x, p.y) < float(t[2]) * 0.6 + 0.9:
			print("[audit] ON PATH %s @%s r%.1f path=%.2f" % [nm, p, t[2], Terrain.path_distance(p.x, p.y)])
		if h < 0.05 and not (nm.begins_with("boat") or nm.begins_with("buoy") or nm.begins_with("lily") or nm.begins_with("bridge") or nm.begins_with("stone") or nm.begins_with("Fish")):
			print("[audit] IN WATER %s @%s ground=%.2f" % [nm, p, h])
		if float(t[3]) - h > 0.35 and not nm.begins_with("bridge") and not nm.begins_with("lily"):
			print("[audit] FLOATING %s @%s y=%.2f ground=%.2f" % [nm, p, t[3], h])
		if float(t[3]) + float(t[4]) * 0.5 < h and not nm.begins_with("bridge"):
			print("[audit] BURIED %s @%s y=%.2f ground=%.2f" % [nm, p, t[3], h])
	for b in find_children("*", "Node3D", true, false):
		if b.has_meta("file") and String(b.get_meta("file")).begins_with("bridge"):
			var p := (b as Node3D).global_position
			print("[audit] BRIDGE @(%.1f, %.1f) base y=%.2f bank=%.2f water=%.2f" % [p.x, p.z, p.y, Terrain.height(p.x, p.z, false), Terrain.height(p.x, p.z, false) - 0.22])
	print("[audit] overlaps: ", n_over)
	var groups := {}
	for g in find_children("*", "GeometryInstance3D", true, false):
		if not (g as GeometryInstance3D).is_visible_in_tree():
			continue
		var key := g.get_class()
		var n: Node = g
		while n and n != self:
			if n.has_meta("file"):
				key = String(n.get_meta("file"))
				break
			if n == life:
				key = "animals"
				break
			n = n.get_parent()
		groups[key] = int(groups.get(key, 0)) + 1
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a] > groups[b])
	for k2 in keys.slice(0, 18):
		print("[audit] draw group %s: %d" % [k2, groups[k2]])
	for f in 30:
		await get_tree().process_frame
	print("[audit] objects in view: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), " draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " triangles: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("[audit] nodes: ", get_tree().get_node_count(), "  mesh instances: ", find_children("*", "MeshInstance3D", true, false).size(), "  skinned: ", find_children("*", "Skeleton3D", true, false).size())
	quit_game()


# --- the Moon trip, photographed stage by stage (--trip <dir>) ---------------------------

func _trip_tour(args: PackedStringArray) -> void:
	get_window().size = Vector2i(1600, 900)
	var k := args.find("--trip")
	var dir := args[k + 1] if k + 1 < args.size() else OS.get_user_data_dir().path_join("trip")
	DirAccess.make_dir_recursive_absolute(dir)
	trip.shots_mode = true
	trip.photo_dir = dir
	for f in 60:
		await get_tree().process_frame
	var snap := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
		print("[trip-tour] %s at %d fps, stage %d" % [name, Engine.get_frames_per_second(), trip.stage])
	var wait := func(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout
	trip.start()
	await wait.call(2.2)
	await snap.call("1-meadow")
	await wait.call(1.6)
	await snap.call("1b-boarding")
	trip.advance()
	await wait.call(3.0)
	await snap.call("2-countdown")
	trip.advance()
	await wait.call(3.0)
	await snap.call("3a-liftoff")
	await wait.call(4.5)
	await snap.call("3b-climb")
	trip.advance()
	await wait.call(3.0)
	await snap.call("4a-orbit")
	await wait.call(5.0)
	await snap.call("4b-orbit")
	trip.advance()
	await wait.call(6.0)
	await snap.call("5a-cruise")
	await wait.call(8.5)
	await snap.call("5b-moon-near")
	trip.advance()
	await wait.call(4.0)
	await snap.call("6-landing")
	trip.advance()
	await wait.call(1.5)
	await snap.call("7a-on-moon")
	explorer.auto_input = Vector2(0.35, 1.0)
	await wait.call(4.0)
	explorer.auto_input = Vector2.ZERO
	await wait.call(3.2)
	await snap.call("7b-moonshine")
	trip.her_button()
	await wait.call(1.5)
	await snap.call("7c-flag")
	trip.her_button()
	await wait.call(0.35)
	await snap.call("7d-hop")
	print("[trip-tour] steps ", trip.steps, " achievements ", life.save.data["achievements"])
	trip.advance()
	await wait.call(3.0)
	await snap.call("8a-leaving")
	trip.advance()
	await wait.call(2.5)
	await snap.call("8b-home")
	quit_game()


# --- photo tour -------------------------------------------------------------------------

func _photo_tour() -> void:
	get_window().size = Vector2i(1600, 900)
	# --clean leaves out the on-screen prompt (pictures for the project page)
	if OS.get_cmdline_user_args().has("--clean") and life.prompt:
		life.prompt.visible = false
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 1200.0
	add_child(cam)
	# [name, camera position, look-at point]; the first view is the normal follow camera at the start
	var views := [
		["start", null, null],
		["cottage", Vector3(31.0, 2.0, 37.0), Vector3(37.0, 2.5, 50.0)],
		["pond-jetty", Vector3(34.0, 2.2, 30.0), Vector3(40.0, 0.5, 10.0)],
		["orchard", Vector3(55.0, 2.0, -8.0), Vector3(63.0, 2.0, -22.0)],
		["windmill-hill", Vector3(37.0, 2.0, -16.0), Vector3(26.0, 10.0, -50.0)],
		["tall-oak", Vector3(62.0, 2.0, 9.0), Vector3(78.0, 6.0, 2.0)],
		["lighthouse", Vector3(64.0, 2.5, 36.0), Vector3(80.0, 6.0, 52.0)],
		["island-from-above", Vector3(30.0, 75.0, 110.0), Vector3(30.0, 0.0, 5.0)],
		["gate", Vector3(2.2, 1.7, 8.0), Vector3(-3.0, 2.2, -10.0)],
		["babies-yard", Vector3(4.0, 2.2, 3.0), Vector3(-1.0, 0.6, -4.0)],
		["visitor-field", Vector3(-6.0, 2.4, -24.0), Vector3(-6.0, 1.0, -35.0)],
		["fawn-wood", Vector3(66.0, 2.0, -2.0), Vector3(75.0, 1.0, -9.0)],
		["rocket-meadow", Vector3(45.0, 2.5, 43.0), Vector3(55.0, 5.0, 54.0)],
		["garden-back", Vector3(27.0, 2.4, 60.0), Vector3(37.0, 1.0, 51.0)],
		["bridge", Vector3(27.0, 2.0, -11.0), Vector3(32.5, 0.0, -17.5)],
		["farm-patch", Vector3(-4.0, 2.2, 12.0), Vector3(-12.0, 0.8, 4.0)],
		["waterfall", Vector3(44.0, 4.0, -84.0), Vector3(51.0, 14.0, -128.0)],
		["lookout-ramp", Vector3(62.0, 2.5, -38.0), Vector3(84.0, 8.0, -72.0)],
		["lookout-top", Vector3(83.0, 12.5, -71.0), Vector3(30.0, 2.0, 8.0)],
		["hollow-gap", Vector3(-40.0, 2.2, -44.0), Vector3(-62.0, 1.0, -50.0)],
		["hollow-inside", Vector3(-55.0, 2.0, -46.0), Vector3(-66.0, 1.0, -52.0)],
		["lake", Vector3(70.0, 3.0, 50.0), Vector3(103.0, 0.0, 70.0)],
		["rabbits", Vector3(-24.0, 1.6, 22.0), Vector3(-28.0, 0.6, 16.0)],
		["stream-bridge", Vector3(28.0, 3.0, -11.0), Vector3(32.5, 0.5, -17.2)],
		["sheep", Vector3(56.0, 2.0, -14.0), Vector3(62.0, 0.8, -22.0)],
		["wood-sign", Vector3(60.0, 2.4, 13.0), Vector3(67.0, 1.0, 8.0)],
		["rocket-play", Vector3(40.0, 3.0, 62.0), Vector3(52.0, 1.5, 54.0)],
		["garden-beds", Vector3(27.0, 2.2, 46.0), Vector3(31.0, 0.4, 51.0)],
		["farm-above", Vector3(10.0, 16.0, 18.0), Vector3(-3.0, 0.0, -8.0)],
		["farm-inside", Vector3(6.0, 2.0, 2.0), Vector3(-6.0, 0.8, -10.0)],
		["farm-west", Vector3(-14.0, 2.2, 6.0), Vector3(-2.0, 0.8, -8.0)],
		["safari", Vector3(-14.0, 7.0, 24.0), Vector3(-32.0, 1.0, 44.0)],
		["safari-low", Vector3(-26.0, 2.0, 32.0), Vector3(-34.0, 1.5, 46.0)],
		["waterhole", Vector3(-14.0, 3.0, 44.0), Vector3(-22.0, 0.5, 49.0)],
		["camp", Vector3(84.0, 6.0, 2.0), Vector3(96.0, 3.0, -11.0)],
		["treehouse", Vector3(92.0, 3.0, 1.0), Vector3(98.5, 4.0, -13.0)],
		["camp-fire", Vector3(86.0, 2.2, -1.0), Vector3(91.0, 0.8, -7.0)],
		["crabs", Vector3(67.0, 1.6, 55.0), Vector3(70.0, 0.4, 60.0)],
		["elephants", Vector3(-28.0, 2.4, 40.0), Vector3(-34.0, 1.5, 50.0)],
	]
	# --only a,b,c photographs just those views
	var oa := OS.get_cmdline_user_args().find("--only")
	if oa >= 0:
		var keep := OS.get_cmdline_user_args()[oa + 1].split(",")
		views = views.filter(func(v: Array) -> bool: return String(v[0]) in keep)
	for v in views:
		if v[1] == null:
			cam.current = false
			follow.cam.make_current()
			for f in 90:
				await get_tree().process_frame
		else:
			cam.make_current()
			cam.global_position = v[1]
			cam.look_at(v[2], Vector3.UP)
			for f in 40:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := shots_dir.path_join("%s.png" % v[0])
		img.save_png(path)
		print("[corner] saved %s at %d fps" % [v[0], Engine.get_frames_per_second()])
	if oa < 0:
		await _interaction_shots(cam)
	quit_game()


## Pictures of the things she can do, staged with the real game code.
func _interaction_shots(cam: Camera3D) -> void:
	var save := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
		print("[corner] saved ", name)
	var wait := func(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout
	var stand := func(at: Vector2, look: Vector3) -> void:
		explorer.global_position = Vector3(at.x, Terrain.height(at.x, at.y) + 0.05, at.y)
		explorer.face(look)
	var close := func(side: float, height := 1.3, dist := 2.6) -> void:
		var f: Vector3 = explorer.forward()
		var right := Vector3(f.z, 0, -f.x)
		cam.global_position = explorer.global_position + right * side * dist + f * 0.9 + Vector3.UP * height
		cam.look_at(explorer.global_position + f * 0.9 + Vector3.UP * 0.6, Vector3.UP)
	cam.make_current()
	# an apple in her hand
	stand.call(Vector2(6.6, 10.2), Vector3(6.2, 0, 8.9))
	await wait.call(1.6)
	stand.call(Vector2(5.0, 9.4), Vector3(0, 0, 9.4))
	close.call(1.0, 0.9, 1.8)
	await wait.call(0.6)
	await save.call("carry-apple")
	# the horse wants an apple: the bubble over its head
	var horse: Node3D = life.animals.filter(func(a): return a.cfg["sound"] == "horse")[0]
	horse.hunger = 0.9
	cam.global_position = horse.global_position + Vector3(3.2, 1.8, 2.4)
	cam.look_at(horse.global_position + Vector3.UP * 1.3, Vector3.UP)
	await wait.call(0.5)
	await save.call("wants-apple")
	# feeding the horse from her hand
	var hp: Vector2 = horse.pos2()
	stand.call(hp + Vector2(1.5, 0.4), horse.global_position)
	explorer.busy = 0.0
	life.her_button()
	close.call(-1.0, 1.4, 3.2)
	await wait.call(0.7)
	await save.call("feed-horse")
	# stroking a cow: hearts rise
	var cow: Node3D = life.animals.filter(func(a): return a.cfg["sound"] == "cow")[0]
	var cp: Vector2 = cow.pos2()
	explorer.drop()
	stand.call(cp + Vector2(1.2, 0.8), cow.global_position)
	explorer.busy = 0.0
	life.her_button()
	close.call(1.0, 1.4, 3.4)
	await wait.call(0.8)
	await save.call("stroke-cow")
	# scattering seed: the hens come running
	stand.call(Vector2(9.6, -14.0), Vector3(7.0, 0, -16.5))
	explorer.carry("seed", life._food_model("seed", 0.28))
	explorer.busy = 0.0
	life.her_button()
	await wait.call(4.0)
	cam.global_position = explorer.global_position + Vector3(2.8, 2.2, 1.0)
	cam.look_at(explorer.global_position + Vector3(0, 0.3, -1.6), Vector3.UP)
	await save.call("seed-hens")
	# nothing near: a butterfly answers
	explorer.drop()
	stand.call(Vector2(-3.0, 18.0), Vector3(-3.0, 0, 10.0))
	explorer.busy = 0.0
	life.her_button()
	close.call(1.0, 1.2, 3.0)
	await wait.call(1.2)
	await save.call("butterfly")
	# pumping water into the trough
	stand.call(Vector2(4.0, -2.0), Vector3(4.0, 0, -3.4))
	explorer.busy = 0.0
	life.her_button()
	close.call(1.0, 1.3, 2.6)
	await wait.call(0.5)
	await save.call("pump")
	# the sticker book
	life.stickers.toggle()
	await wait.call(0.6)
	await save.call("sticker-book")
	life.stickers.toggle()
	# sunset, then sleepy time
	life.day.session_minutes = 15.0
	life.day.t = 15.0 * 60.0 * 0.95
	stand.call(Vector2(37.0, 40.0), Vector3(38.0, 0, 8.0))
	cam.global_position = Vector3(33.0, 3.0, 47.0)
	cam.look_at(Vector3(37.0, 2.0, 30.0), Vector3.UP)
	await wait.call(1.5)
	await save.call("sunset")
	life.day.t = 15.0 * 60.0
	await wait.call(4.0)
	await save.call("sleepy-time")
