extends Node3D
## The trip to the Moon, in eight stages: climb aboard in the rocket meadow, the countdown, lift-off
## and the climb through the sky, Earth from orbit, the cruise to the Moon, the landing, a walk on
## the Moon (low gravity, footprints, a flag), and home again. Every stage moves on by itself; the
## parent's shoulder button (or N) moves on sooner. After her first ten steps on the Moon she earns
## "You are my moonshine": a golden banner, a photo saved to Pictures, a sticker and a souvenir.
##
## The space sets are built far below the island (so nothing of the island gets in the way) and the
## island is hidden while she is away; it waits exactly as she left it.

const Rocket := preload("res://space/rocket.gd")
const MoonGround := preload("res://space/moon_ground.gd")
const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const EARTH := preload("res://space/earth.gdshader")
const ATMO := preload("res://space/atmosphere.gdshader")
const MOON := preload("res://space/moon_body.gdshader")
const SUN := preload("res://space/sun.gdshader")
const STARS := preload("res://space/starfield.gdshader")

const SET := Vector3(0, -3000, 0)        # orbit and cruise
const SURF := Vector3(0, -3000, 4000)    # the Moon's surface
const SUN_DIR := Vector3(0.55, 0.45, 0.7)
const MOON_SUN := Vector3(0.75, 0.2, 0.62)  # low over the Moon, for long shadows
const EARTH_R := 420.0
const MOON_R := 120.0
const STEPS_FOR_MOONSHINE := 10
const STEP_LEN := 0.55
const LANDING_SITE := Vector2(0.41, 0.012)  # where she lands on the island's Moon (lon, lat, radians)

enum { OFF, MEADOW, COUNTDOWN, CLIMB, ORBIT, CRUISE, LANDING, ON_MOON, HOME }
const LENGTH := {MEADOW: 4.2, COUNTDOWN: 6.2, CLIMB: 10.0, ORBIT: 18.0, CRUISE: 16.0, LANDING: 9.0, ON_MOON: 0.0, HOME: 7.0}

var corner: Node3D
var life: Node3D
var explorer: CharacterBody3D
var active := false
var stage := OFF
var t := 0.0
var cam := Camera3D.new()
var pad_rocket: Node3D
var _pad_home: Vector3
var _pad_fx: Array
var _rise := 0.0
var _rise_v := 0.0
# space sets
var space: Node3D
var ship: Node3D
var _ship_fx: Array
var earth: MeshInstance3D
var earth_mat: ShaderMaterial
var atmo: MeshInstance3D
var moon_body: MeshInstance3D
var surface: Node3D
var lander: Node3D
var _lander_fx: Array
var _dust: GPUParticles3D
var sky_earth: MeshInstance3D
var flag: Node3D
# the walk
var steps := 0
var _walked := 0.0
var _last := Vector3.ZERO
var _foot_side := 1.0
var _prints: Array = []
var _print_mesh: QuadMesh
var helmet: MeshInstance3D
var buddy: Node3D
var _buddy_anim: AnimationPlayer
var _buddy_hold := 0.0
# the island while she is away
var _hidden: Array = []
var _env_island: Environment
var env_space: Environment
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _sun_xf: Transform3D
var _sun_energy := 1.0
var _sky_top := Color()
var _sky_hor := Color()
# screen
var ui := CanvasLayer.new()
var fade := ColorRect.new()
var big := Label.new()
var banner: Control
var rumble := AudioStreamPlayer.new()
var shots_mode := false   # the photo tour drives the trip itself
var photo_dir := ""       # where photos go instead of Pictures (the photo tour)


func setup(c: Node3D) -> void:
	corner = c
	life = c.life
	explorer = c.explorer
	pad_rocket = c.get_meta("rocket")
	_pad_home = pad_rocket.position
	_pad_fx = Rocket.engine_effects(pad_rocket)
	_world_env = c.find_children("*", "WorldEnvironment", false, false)[0]
	_env_island = _world_env.environment
	_sun = c.find_children("*", "DirectionalLight3D", false, false)[0]
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 40000.0
	add_child(cam)
	_build_ui()
	rumble.stream = _brown_noise()
	rumble.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	add_child(rumble)
	var stand := Terrain.ROCKET + Vector2(-3.4, -1.4)
	life.interact.register({"name": "rocket", "reach": 3.2, "sparkle_height": 1.6, "priority": 1.0, "label": "Fly to the Moon!", "icon": "res://assets/kits/space/rocket_topA.glb",
		"pos": func() -> Vector3: return Vector3(stand.x, Terrain.height(stand.x, stand.y) + 0.6, stand.y),
		"when": func() -> bool: return not active,
		"act": func() -> String:
			start()
			return "rocket"})
	if life.save.data["achievements"].has("moonshine"):
		_mark_island_moon()


# --- the director -----------------------------------------------------------------------------

func start() -> void:
	if active:
		return
	active = true
	steps = 0
	_walked = 0.0
	_enter(MEADOW)


## The parent's shoulder button: on to the next stage.
func advance() -> void:
	if not active:
		return
	match stage:
		ON_MOON:
			_enter(HOME)
		HOME:
			_finish()
		_:
			_enter(stage + 1)


## What her button does right now in the trip, for the prompt.
func prompt() -> Array:
	match stage:
		ON_MOON:
			var here := explorer.global_position
			if lander and Vector2(here.x - lander.global_position.x, here.z - lander.global_position.z).length() < 3.6 and steps >= 3:
				return ["Fly home", "res://assets/kits/space/rocket_topA.glb"]
			if flag == null:
				return ["Plant our flag", ""]
			return ["Moon jump!", ""]
	return ["", ""]


## Her button during the trip.
func her_button() -> String:
	match stage:
		ON_MOON:
			var here := explorer.global_position
			if Vector2(here.x - lander.global_position.x, here.z - lander.global_position.z).length() < 3.6 and steps >= 3:
				_enter(HOME)
				return "home"
			if flag == null:
				_plant_flag()
				return "flag"
			if explorer.is_on_floor():
				explorer.velocity.y = 3.2
				life.sound.play_flat(life.sound.pop, -8.0)
				return "hop"
		CLIMB, ORBIT, CRUISE:
			life.sound.play_flat(life.sound.chime, -10.0)
			_say("Whee!")
			return "whee"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.keycode in [KEY_N, KEY_PAGEDOWN]:
			advance()
		elif key.keycode == KEY_P and life.menu:
			life.menu.toggle()
		elif not life._parent_key(key.keycode):
			her_button()
		get_viewport().set_input_as_handled()
		return
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed:
		if pad.device == 0 and pad.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			advance()
		elif pad.device == 0 and pad.button_index == JOY_BUTTON_START and life.menu:
			life.menu.toggle()
		elif pad.device != 0 or pad.button_index <= JOY_BUTTON_Y:
			her_button()
		get_viewport().set_input_as_handled()


func _enter(s: int) -> void:
	corner.note("trip stage %d" % s)
	var was := stage
	stage = s
	t = 0.0
	match s:
		MEADOW:
			life.day.process_mode = Node.PROCESS_MODE_DISABLED
			cam.make_current()
			_say("Let's go to the Moon!")
			_board()
		COUNTDOWN:
			explorer.visible = false
			if _dog:
				_dog.visible = false
			life.sound.play_flat(life.sound.chime, -8.0)
		CLIMB:
			big.text = ""
			_say("Lift off!")
			for p in _pad_fx:
				(p as GPUParticles3D).emitting = true
			rumble.volume_db = -20.0 if life.save.setting("quiet_launch", false) else -6.0
			rumble.play()
			_sky_top = (corner.get_meta("sky") as ProceduralSkyMaterial).sky_top_color
			_sky_hor = (corner.get_meta("sky") as ProceduralSkyMaterial).sky_horizon_color
			_rise = 0.0
			_rise_v = 0.0
		ORBIT:
			await _white(0.5)
			if stage != ORBIT:
				return
			for p in _pad_fx:
				(p as GPUParticles3D).emitting = false
			_restore_sky()
			_go_to_space()
			_build_space()
			space.visible = true
			if surface:
				surface.visible = false
			rumble.volume_db -= 10.0
			_unwhite(1.2)
			if life.audio:
				life.audio.space_music(true)
			_say("Look! That's our Earth!")
		CRUISE:
			if was != ORBIT:
				_go_to_space()
				_build_space()
				space.visible = true
			_say("Off to the Moon!")
		LANDING:
			await _white(0.5)
			if stage != LANDING:
				return
			_go_to_space()
			_build_space()
			_build_surface()
			space.visible = false
			surface.visible = true
			_sun.global_transform = Transform3D(Basis.looking_at(-MOON_SUN.normalized()), Vector3.ZERO)
			_sun.light_energy = 1.4
			lander.position = Vector3(0, 70, 0)
			(_lander_fx[0] as GPUParticles3D).emitting = true
			rumble.volume_db = -14.0 if not life.save.setting("quiet_launch", false) else -26.0
			if not rumble.playing:
				rumble.play()
			_unwhite(1.0)
			_say("Here's the Moon!")
		ON_MOON:
			for p in _lander_fx:
				(p as GPUParticles3D).emitting = false
			_dust.emitting = false
			rumble.stop()
			lander.position = Vector3.ZERO
			_moon_walk(true)
			_say("Let's walk on the Moon!")
		HOME:
			_moon_walk(false)
			explorer.visible = false
			explorer.set_physics_process(false)
			cam.make_current()
			for p in _lander_fx:
				(p as GPUParticles3D).emitting = true
			rumble.volume_db = -14.0
			rumble.play()
			_say("Time to go home!")


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	var length: float = LENGTH.get(stage, 0.0)
	match stage:
		MEADOW:
			_shot_meadow(t / length)
		COUNTDOWN:
			_shot_meadow(1.0 + t / length)
			var n := 5 - int(floor(t - 0.6))
			var label := str(n) if n >= 1 and n <= 5 and t >= 0.6 else ""
			if label != big.text:
				big.text = label
				if label != "":
					_say(label)
					big.scale = Vector2.ONE * 1.4
					create_tween().tween_property(big, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
		CLIMB:
			_rise_v += (2.0 + t * 1.6) * delta
			_rise += _rise_v * delta
			pad_rocket.position = _pad_home + Vector3(0, _rise, 0)
			pad_rocket.rotation.z = sin(t * 23.0) * 0.004 * clampf(3.0 - t, 0.0, 1.0)
			_shot_climb()
			var sky := corner.get_meta("sky") as ProceduralSkyMaterial
			var k := clampf((t - 3.0) / 6.0, 0.0, 1.0)
			sky.sky_top_color = _sky_top.lerp(Color(0.02, 0.03, 0.1), k)
			sky.sky_horizon_color = _sky_hor.lerp(Color(0.25, 0.35, 0.6), k * 0.8)
		ORBIT:
			_shot_orbit(t)
		CRUISE:
			_shot_cruise(clampf(t / length, 0.0, 1.0))
		LANDING:
			_shot_landing(clampf(t / length, 0.0, 1.0))
		ON_MOON:
			_walk(delta)
		HOME:
			_shot_home(t)
	if earth and space and space.visible:
		earth.rotate_object_local(Vector3.UP, delta * 0.01)
		earth_mat.set_shader_parameter("cloud_shift", t * 0.0015)
	if length > 0.0 and t >= length and stage != ON_MOON:
		if stage == HOME:
			_finish()
		else:
			_enter(stage + 1)


# --- camera shots -----------------------------------------------------------------------------

## Mercan and the dog climb the gantry and hop in through the hatch.
var _dog: Node3D
var _dog_home := Vector3.ZERO


func _board() -> void:
	explorer.set_physics_process(false)
	explorer.busy = 9.0
	_dog = null
	for a in life.animals:
		if a.get_meta("kind", "") == "dog":
			_dog = a
	var g := Terrain.ROCKET + Vector2(-2.6, -0.4)
	var base := Vector3(g.x, Terrain.height(g.x, g.y), g.y)
	var top := base + Vector3(0, 3.25, 0)
	var hatch := pad_rocket.global_position + Vector3(0, 3.3, 0)
	var ex := explorer
	if ex.player:
		ex.player.play("walk", 0.2)
	ex.face(base)
	var tw := create_tween()
	tw.tween_property(ex, "global_position", base + Vector3(-0.6, 0, -0.6), 1.0)
	tw.tween_callback(func() -> void: ex.face(hatch))
	tw.tween_property(ex, "global_position", top, 1.3)
	tw.tween_property(ex, "global_position", hatch, 0.7)
	tw.tween_callback(func() -> void:
		ex.visible = false
		life.sound.play_flat(life.sound.pop, -8.0))
	if _dog:
		_dog.set_process(false)
		_dog.set_physics_process(false)
		_dog_home = _dog.global_position
		_dog._play("run")
		var dt := create_tween()
		dt.tween_interval(0.4)
		dt.tween_property(_dog, "global_position", base + Vector3(-1.0, 0, -0.2), 1.0)
		dt.tween_property(_dog, "global_position", top + Vector3(0, 0.4, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dt.tween_property(_dog, "global_position", top, 0.25)
		dt.tween_interval(0.6)
		dt.tween_property(_dog, "global_position", hatch + Vector3(0, 0.5, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dt.tween_property(_dog, "global_position", hatch, 0.2)
		dt.tween_callback(func() -> void:
			_dog.visible = false
			life.sound.call_from("dog", _dog.voice, true))


func _shot_meadow(k: float) -> void:
	var r := pad_rocket.global_position
	var a := deg_to_rad(-140.0) + k * 0.25
	cam.global_position = r + Vector3(sin(a) * 15.0, 3.0, cos(a) * 15.0)
	cam.look_at(r + Vector3(0, 4.5, 0), Vector3.UP)


func _shot_climb() -> void:
	var r := pad_rocket.global_position
	var base := Vector3(_pad_home.x, _pad_home.y, _pad_home.z)
	var a := deg_to_rad(-120.0)
	if t < 4.0:
		cam.global_position = base + Vector3(sin(a) * 18.0, 2.0, cos(a) * 18.0)
	else:
		# ride alongside, looking up at the rocket against a darkening sky
		cam.global_position = r + Vector3(sin(a) * 14.0, -6.0, cos(a) * 14.0)
	cam.look_at(r + Vector3(0, 6.0, 0), Vector3.UP)


func _shot_orbit(time: float) -> void:
	if ship == null:
		return
	var a := time * 0.12 + 0.6
	var s := ship.global_position
	cam.global_position = s + Vector3(sin(a) * 16.0, 4.0, cos(a) * 16.0)
	cam.look_at(s + Vector3(0, -3.5, 0), Vector3.UP)
	ship.rotation.z = sin(time * 0.4) * 0.05


func _shot_cruise(k: float) -> void:
	if ship == null:
		return
	var e := k * k * (3.0 - 2.0 * k)
	# the Earth falls away behind and the Moon grows ahead
	earth.position = Vector3(0, -460, 0).lerp(Vector3(-900, -2600, 5200), e)
	atmo.position = earth.position
	moon_body.position = Vector3(800, 900, -14000).lerp(Vector3(40, -60, -330), e)
	ship.rotation = Vector3(-PI / 2.0 * minf(k * 4.0, 1.0), 0, 0)
	var s := ship.global_position
	var w := smoothstep(0.45, 0.66, k)
	var back := Vector3(7.0, 3.0, -18.0).lerp(Vector3(-10.0, 4.0, 6.0), w)
	cam.global_position = s + back
	var look := earth.global_position.lerp(moon_body.global_position, w)
	cam.look_at(look, Vector3.UP)


func _shot_landing(k: float) -> void:
	if lander == null or not surface.visible:
		return
	var e := 1.0 - pow(1.0 - k, 2.4)
	lander.position = Vector3(0, lerpf(70.0, 0.0, e), 0)
	_dust.emitting = lander.position.y < 9.0
	var l := lander.global_position
	cam.global_position = surface.global_position + Vector3(-14, 3.0, 16)
	cam.look_at(l + Vector3(0, 5.0, 0), Vector3.UP)


func _shot_home(time: float) -> void:
	var up := 0.6 * time * time
	lander.position = Vector3(0, up, 0)
	_dust.emitting = up < 6.0
	var l := lander.global_position
	cam.global_position = surface.global_position + Vector3(-16, 2.5, 14)
	cam.look_at(l + Vector3(0, 5.0, 0), Vector3.UP)
	if time > 5.6 and fade.color.a < 0.05:
		_white(1.2)


# --- the space sets ---------------------------------------------------------------------------

func _go_to_space() -> void:
	if not _hidden.is_empty():
		return
	for n in corner.get_children():
		if n == self or n == explorer or n == corner.follow or n is DirectionalLight3D or not (n is Node3D):
			continue
		if (n as Node3D).visible:
			(n as Node3D).visible = false
			_hidden.append(n)
	life.process_mode = Node.PROCESS_MODE_DISABLED
	if env_space == null:
		env_space = Environment.new()
		var sky := Sky.new()
		var starfield := ShaderMaterial.new()
		starfield.shader = STARS
		starfield.set_shader_parameter("milky", load("res://assets/space/8k_stars_milky_way.jpg"))
		starfield.set_shader_parameter("sun_dir", SUN_DIR.normalized())
		sky.sky_material = starfield
		sky.radiance_size = Sky.RADIANCE_SIZE_64
		env_space.background_mode = Environment.BG_SKY
		env_space.sky = sky
		env_space.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env_space.ambient_light_color = Color(0.45, 0.5, 0.65)
		env_space.ambient_light_energy = 0.25
		env_space.tonemap_mode = Environment.TONE_MAPPER_ACES
		env_space.tonemap_white = 6.0
		env_space.glow_enabled = true
		env_space.glow_intensity = 0.6
		env_space.glow_bloom = 0.08
		env_space.glow_hdr_threshold = 1.2
	_world_env.environment = env_space
	_sun_xf = _sun.global_transform
	_sun_energy = _sun.light_energy
	_sun.global_transform = Transform3D(Basis.looking_at(-SUN_DIR.normalized()), Vector3.ZERO)
	_sun.light_energy = 1.6
	_sun.directional_shadow_max_distance = 80.0


func _back_home() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			(n as Node3D).visible = true
	_hidden.clear()
	life.process_mode = Node.PROCESS_MODE_INHERIT
	life.day.process_mode = Node.PROCESS_MODE_INHERIT
	_world_env.environment = _env_island
	_sun.global_transform = _sun_xf
	_sun.light_energy = _sun_energy
	_sun.directional_shadow_max_distance = 65.0
	if space:
		space.visible = false
	if surface:
		surface.visible = false


func _restore_sky() -> void:
	var sky := corner.get_meta("sky") as ProceduralSkyMaterial
	if _sky_top != Color():
		sky.sky_top_color = _sky_top
		sky.sky_horizon_color = _sky_hor


func _sphere(r: float, segs: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = segs / 2
	return m


func _earth_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = EARTH
	m.set_shader_parameter("day_tex", load("res://assets/space/8k_earth_daymap.jpg"))
	m.set_shader_parameter("night_tex", load("res://assets/space/8k_earth_nightmap.jpg"))
	m.set_shader_parameter("cloud_tex", load("res://assets/space/8k_earth_clouds.jpg"))
	m.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	return m


func _build_space() -> void:
	if space:
		return
	space = Node3D.new()
	space.name = "Space"
	space.position = SET
	add_child(space)
	earth = MeshInstance3D.new()
	earth.mesh = _sphere(EARTH_R, 160)
	earth_mat = _earth_material()
	earth.material_override = earth_mat
	earth.position = Vector3(0, -460, 0)
	earth.rotation = Vector3(deg_to_rad(-62.0), 0.0, 0.0)
	earth.rotate_object_local(Vector3.UP, 1.2)
	earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	space.add_child(earth)
	atmo = MeshInstance3D.new()
	atmo.mesh = _sphere(EARTH_R * 1.07, 96)
	var am := ShaderMaterial.new()
	am.shader = ATMO
	am.set_shader_parameter("radius", EARTH_R)
	am.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	atmo.material_override = am
	atmo.position = earth.position
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	space.add_child(atmo)
	moon_body = MeshInstance3D.new()
	moon_body.mesh = _sphere(MOON_R, 128)
	var mm := ShaderMaterial.new()
	mm.shader = MOON
	mm.set_shader_parameter("surface", load("res://assets/space/8k_moon.jpg"))
	mm.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	moon_body.material_override = mm
	moon_body.position = Vector3(800, 900, -14000)
	moon_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	space.add_child(moon_body)
	var sun := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1400, 1400)
	sun.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = SUN
	sun.material_override = sm
	sun.position = SUN_DIR.normalized() * 15000.0
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	space.add_child(sun)
	ship = Rocket.build(space, 12.0)
	ship.position = Vector3(0, -6, 0)
	_ship_fx = Rocket.engine_effects(ship)
	(_ship_fx[0] as GPUParticles3D).emitting = true
	_window_face(ship)


## Her face at the rocket's window: a little round porthole glow so it reads as "she's inside".
func _window_face(r: Node3D) -> void:
	var glow := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.32
	s.height = 0.64
	glow.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.5)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.45)
	m.emission_energy_multiplier = 2.0
	glow.material_override = m
	glow.position = Vector3(0, float(r.get_meta("height")) * 0.62, 1.05)
	glow.scale = Vector3(1, 1, 0.3)
	r.add_child(glow)


func _build_surface() -> void:
	if surface:
		return
	surface = Node3D.new()
	surface.name = "MoonSurface"
	surface.position = SURF
	add_child(surface)
	MoonGround.build(surface)
	lander = Rocket.build(surface, 12.0)
	lander.rotation_degrees.y = 160.0
	_lander_fx = Rocket.engine_effects(lander)
	_window_face(lander)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 12.0
	shape.shape = cyl
	shape.position.y = 6.0
	body.add_child(shape)
	lander.add_child(body)
	_dust = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.5
	pm.emission_ring_inner_radius = 0.5
	pm.emission_ring_height = 0.1
	pm.direction = Vector3(1, 0.15, 0)
	pm.spread = 180.0
	pm.flatness = 0.9
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -1.62, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 1.5
	pm.scale_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.74, 0.72, 0.6))
	g.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_dust.process_material = pm
	_dust.amount = 120
	_dust.lifetime = 2.5
	var dq := QuadMesh.new()
	dq.size = Vector2(1.2, 1.2)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.vertex_color_use_as_albedo = true
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.albedo_texture = Rocket._soft_dot()
	dq.material = dm
	_dust.draw_pass_1 = dq
	_dust.emitting = false
	_dust.position = Vector3(0, 0.3, 0)
	surface.add_child(_dust)
	# the Earth hanging in the black sky
	sky_earth = MeshInstance3D.new()
	sky_earth.mesh = _sphere(110.0, 128)
	var em := _earth_material()
	em.set_shader_parameter("sun_dir", (Vector3(0.93, 0.1, 0.36) + Vector3(0.45, 0.4, -0.75)).normalized())
	sky_earth.material_override = em
	sky_earth.position = Vector3(-0.93, 0.115, -0.36).normalized() * 1500.0
	sky_earth.rotation = Vector3(0.3, 1.2, 0)
	sky_earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.add_child(sky_earth)
	var sa := MeshInstance3D.new()
	sa.mesh = _sphere(110.0 * 1.07, 64)
	var am := ShaderMaterial.new()
	am.shader = ATMO
	am.set_shader_parameter("radius", 110.0)
	am.set_shader_parameter("sun_dir", (Vector3(0.93, 0.1, 0.36) + Vector3(0.45, 0.4, -0.75)).normalized())
	sa.material_override = am
	sa.position = sky_earth.position
	sa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.add_child(sa)
	var sun := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(900, 900)
	sun.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = SUN
	sun.material_override = sm
	sun.position = MOON_SUN.normalized() * 9000.0
	surface.add_child(sun)
	_print_mesh = QuadMesh.new()
	_print_mesh.size = Vector2(0.13, 0.22)
	_print_mesh.orientation = PlaneMesh.FACE_Y
	var pmm := StandardMaterial3D.new()
	pmm.albedo_color = Color(0.3, 0.3, 0.3, 0.8)
	pmm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmm.roughness = 1.0
	_print_mesh.material = pmm


# --- walking on the Moon ----------------------------------------------------------------------

func _moon_walk(on: bool) -> void:
	if on:
		var spot := surface.global_position + Vector3(3.2, 0.0, 2.6)
		explorer.global_position = spot + Vector3(0, MoonGround.height(3.2, 2.6) + 0.2, 0)
		explorer.velocity = Vector3.ZERO
		explorer.visible = true
		explorer.set_physics_process(true)
		explorer.gravity = 3.0
		# the Earth and the Sun hang far away: let her camera see that far while on the Moon
		corner.follow.cam.far = 12000.0
		explorer.sea_check = false
		explorer.busy = 0.0
		_last = explorer.global_position
		if helmet == null:
			helmet = MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.3
			s.height = 0.6
			helmet.mesh = s
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.75, 0.88, 1.0, 0.22)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.3
			m.roughness = 0.05
			m.rim_enabled = true
			m.rim = 0.6
			helmet.material_override = m
			helmet.position = Vector3(0, 0.78, 0)
			helmet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			explorer.add_child(helmet)
		helmet.visible = true
		_spawn_buddy(spot + Vector3(1.2, MoonGround.height(4.4, 2.6), 0.6))
		var f: Node3D = corner.follow
		f.global_position = explorer.global_position + Vector3.UP * 1.1
		f.yaw = deg_to_rad(40.0)
		corner.follow.cam.make_current()
	else:
		explorer.gravity = 18.0
		corner.follow.cam.far = 1200.0
		explorer.sea_check = true
		if helmet:
			helmet.visible = false
		if buddy:
			buddy.visible = false


func _spawn_buddy(at: Vector3) -> void:
	if buddy == null:
		buddy = Models.spawn(surface, "res://assets/animals/quaternius/dog.glb", 0.75, 0.0)
		var players := buddy.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_buddy_anim = players[0]
		var h := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.28
		s.height = 0.56
		h.mesh = s
		h.material_override = helmet.material_override
		h.position = Vector3(0, 0.62, 0.32)
		buddy.add_child(h)
	buddy.visible = true
	var hatch := lander.global_position + Vector3(0.9, 2.4, 0.9)
	buddy.global_position = hatch
	var tw := buddy.create_tween()
	tw.tween_property(buddy, "global_position", (hatch + at) * 0.5 + Vector3(0, 1.0, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(buddy, "global_position", at, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_buddy_hold = 1.4


func _anim(p: AnimationPlayer, names: Array) -> void:
	if p == null:
		return
	for n in names:
		for a in p.get_animation_list():
			if String(a).to_lower().ends_with(n):
				if p.current_animation != a:
					p.play(a, 0.2)
				return


func _walk(delta: float) -> void:
	var here := explorer.global_position
	var local := here - surface.global_position
	# keep her within the landing area
	var flat := Vector2(local.x, local.z)
	if flat.length() > 70.0:
		var back := flat.normalized() * 69.5
		explorer.global_position = surface.global_position + Vector3(back.x, local.y, back.y)
	var moved := Vector2(here.x - _last.x, here.z - _last.z).length()
	_last = here
	if explorer.is_on_floor() and moved < 1.0:
		_walked += moved
	while _walked >= STEP_LEN:
		_walked -= STEP_LEN
		steps += 1
		_footprint()
		if steps == STEPS_FOR_MOONSHINE:
			_moonshine()
	# the dog bounces along beside her
	_buddy_hold -= delta
	if buddy and _buddy_hold <= 0.0:
		var want: Vector3 = here + Vector3(cos(explorer.facing) * 1.0, 0, -sin(explorer.facing) * 1.0) - explorer.forward() * 0.6
		var to: Vector3 = want - buddy.global_position
		to.y = 0.0
		var speed: float = to.length()
		if speed > 0.2:
			buddy.global_position += to.normalized() * minf(speed, maxf(1.5, speed * 2.0) * delta)
			buddy.rotation.y = atan2(to.x, to.z)
			_anim(_buddy_anim, ["gallop", "walk", "run"])
		else:
			_anim(_buddy_anim, ["idle", "idle_2", "eating"])
		var bl := buddy.global_position - surface.global_position
		var hop := absf(sin(t * 4.0)) * 0.25 if speed > 0.2 else 0.0
		buddy.global_position.y = surface.global_position.y + MoonGround.height(bl.x, bl.z) + hop


func _footprint() -> void:
	var p := explorer.global_position - surface.global_position
	var side := Vector3(cos(explorer.facing), 0, -sin(explorer.facing)) * 0.09 * _foot_side
	_foot_side = -_foot_side
	var at := p + side
	var mi := MeshInstance3D.new()
	mi.mesh = _print_mesh
	mi.position = Vector3(at.x, MoonGround.height(at.x, at.z) + 0.03, at.z)
	mi.rotation.y = explorer.facing
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.add_child(mi)
	_prints.append(mi)
	if _prints.size() > 300:
		(_prints.pop_front() as Node).queue_free()


func _plant_flag() -> void:
	var p: Vector3 = explorer.global_position - surface.global_position + explorer.forward() * 0.7
	flag = Node3D.new()
	flag.position = Vector3(p.x, MoonGround.height(p.x, p.z), p.z)
	surface.add_child(flag)
	var pole := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.025
	c.height = 1.6
	pole.mesh = c
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.9, 0.9, 0.92)
	pm.metallic = 0.6
	pole.material_override = pm
	pole.position.y = 0.8
	flag.add_child(pole)
	# the flag: a star on a sky-blue cloth, our own island flag
	var cloth := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.75, 0.48, 0.01)
	cloth.mesh = b
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.35, 0.6, 0.95)
	cloth.material_override = cm
	cloth.position = Vector3(0.4, 1.34, 0)
	flag.add_child(cloth)
	var star := Label3D.new()
	star.text = "★"
	star.font_size = 96
	star.pixel_size = 0.004
	star.modulate = Color(1.0, 0.88, 0.3)
	star.position = Vector3(0.4, 1.34, 0.012)
	star.outline_size = 0
	flag.add_child(star)
	var back := star.duplicate() as Label3D
	back.position.z = -0.012
	back.rotation.y = PI
	flag.add_child(back)
	flag.scale = Vector3(1, 0.05, 1)
	create_tween().tween_property(flag, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	explorer.act("interact-right", 0.8)
	life.sound.play_flat(life.sound.chime, -6.0)
	_say("A flag on the Moon!")


# --- "You are my moonshine" -------------------------------------------------------------------

func _moonshine() -> void:
	var a: Dictionary = life.save.data["achievements"]
	var times := 1
	if a.has("moonshine") and a["moonshine"] is Dictionary:
		times = int(a["moonshine"].get("times", 0)) + 1
	a["moonshine"] = {"date": Time.get_date_string_from_system(), "times": times}
	life.save.data["souvenirs"]["moon_rock"] = true
	life.save.write()
	_show_banner()
	if life.audio:
		life.audio.play_moonshine()
		life.audio.play_voice(11.0)
	_mark_island_moon()
	if life.stickers:
		get_tree().create_timer(10.5).timeout.connect(func() -> void: life.stickers.earn("moon", true))
	life.events_said("moon")
	await get_tree().create_timer(5.4).timeout
	_save_photo("moonshine")


func _mark_island_moon() -> void:
	if corner.look and corner.look.moon_mat:
		corner.look.moon_mat.set_shader_parameter("sparkle_lonlat", LANDING_SITE)


## A picture of the moment, saved to Pictures\Toddler Island.
func _save_photo(tag: String) -> String:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := photo_dir if photo_dir != "" else OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("Toddler Island")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", " ")
	var path := dir.path_join("%s %s.png" % [tag, stamp])
	img.save_png(path)
	print("[trip] photo saved: ", path)
	return path


func _show_banner() -> void:
	if banner:
		banner.queue_free()
	var name: String = String(life.save.setting("child_name", "Mercan")).strip_edges()
	var vs := get_viewport().get_visible_rect().size
	banner = Control.new()
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(banner)
	# a soft night-blue veil, darker at the edges, so the words glow
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	var vsh := Shader.new()
	vsh.code = "shader_type canvas_item;\nuniform float a = 0.0;\nvoid fragment() { vec2 p = UV - 0.5; float r = length(p * vec2(1.6, 1.0)); COLOR = vec4(0.03, 0.04, 0.14, a * (0.35 + 0.55 * smoothstep(0.25, 0.85, r))); }"
	vm.shader = vsh
	veil.material = vm
	banner.add_child(veil)
	# a big warm moon glow behind the words
	var glow := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.93, 0.65, 0.85))
	g.add_point(0.35, Color(1.0, 0.85, 0.45, 0.35))
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.8, 0.4, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	glow.texture = gt
	glow.size = Vector2(900, 900)
	glow.position = Vector2(vs.x * 0.5 - 450, vs.y * 0.42 - 450)
	glow.pivot_offset = glow.size * 0.5
	glow.scale = Vector2(0.2, 0.2)
	glow.modulate.a = 0.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(glow)
	var line1 := _glow_label("You are my moonshine,", 96, Color(1.0, 0.95, 0.82))
	banner.add_child(line1)
	line1.position = Vector2(0, vs.y * 0.3)
	line1.size = Vector2(vs.x, 130)
	line1.visible_ratio = 0.0
	var line2 := _glow_label(name, 170, Color(1.0, 0.84, 0.35))
	banner.add_child(line2)
	line2.position = Vector2(0, vs.y * 0.3 + 120)
	line2.size = Vector2(vs.x, 220)
	line2.pivot_offset = Vector2(vs.x * 0.5, 110)
	line2.scale = Vector2(0.3, 0.3)
	line2.modulate.a = 0.0
	var sub := _glow_label("First steps on the Moon  ·  " + _nice_date(), 34, Color(0.85, 0.88, 1.0))
	sub.add_theme_constant_override("shadow_outline_size", 8)
	banner.add_child(sub)
	sub.position = Vector2(0, vs.y * 0.3 + 350)
	sub.size = Vector2(vs.x, 60)
	sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: vm.set_shader_parameter("a", v), 0.0, 1.0, 1.0)
	tw.parallel().tween_property(glow, "modulate:a", 1.0, 1.4)
	tw.parallel().tween_property(glow, "scale", Vector2.ONE, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(line1, "visible_ratio", 1.0, 2.2)
	tw.tween_callback(func() -> void: _sparkle_burst(Vector2(vs.x * 0.5, vs.y * 0.3 + 230), 60))
	tw.tween_property(line2, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(line2, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(line2, "scale", Vector2.ONE, 0.3)
	tw.tween_property(sub, "modulate:a", 1.0, 0.8)
	tw.tween_interval(5.5)
	tw.tween_property(banner, "modulate:a", 0.0, 1.6)
	tw.tween_callback(banner.queue_free)
	# the glow breathes
	var pulse := glow.create_tween().set_loops(6)
	pulse.tween_property(glow, "modulate", Color(1.15, 1.1, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "modulate", Color(1, 1, 1, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
	# a gentle shower of golden stars all the while
	for k in 40:
		var s := Label.new()
		s.text = "✦" if k % 3 else "★"
		s.add_theme_font_size_override("font_size", randi_range(18, 54))
		s.add_theme_color_override("font_color", Color(1.0, randf_range(0.78, 0.95), randf_range(0.35, 0.7)))
		s.position = Vector2(randf() * vs.x, -60.0)
		s.modulate.a = randf_range(0.6, 1.0)
		banner.add_child(s)
		var st := create_tween()
		st.tween_interval(randf() * 6.0)
		st.tween_property(s, "position", Vector2(s.position.x + randf_range(-80, 80), vs.y + 60.0), randf_range(4.0, 7.0)).set_trans(Tween.TRANS_SINE)
		st.parallel().tween_property(s, "rotation", randf_range(-2.0, 2.0), 5.0)
		st.tween_callback(s.queue_free)


func _glow_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.55, 0.32, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, size / 14))
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.8, 0.35, 0.55))
	l.add_theme_constant_override("shadow_outline_size", maxi(10, size / 5))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _nice_date() -> String:
	var d := Time.get_date_dict_from_system()
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	return "%d %s %d" % [d["day"], months[int(d["month"]) - 1], d["year"]]


func _sparkle_burst(at: Vector2, count: int) -> void:
	for k in count:
		var s := Label.new()
		s.text = "✦"
		s.add_theme_font_size_override("font_size", randi_range(16, 40))
		s.add_theme_color_override("font_color", Color(1.0, randf_range(0.8, 1.0), randf_range(0.4, 0.8)))
		s.position = at
		banner.add_child(s)
		var a := randf() * TAU
		var r := randf_range(160.0, 520.0)
		var st := create_tween()
		st.tween_property(s, "position", at + Vector2(cos(a), sin(a) * 0.6) * r, randf_range(0.8, 1.6)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(s, "modulate:a", 0.0, 1.6)
		st.tween_callback(s.queue_free)


# --- home -------------------------------------------------------------------------------------

func _finish() -> void:
	if stage == OFF:
		return
	stage = OFF
	if fade.color.a < 0.9:
		await _white(0.6)
	rumble.stop()
	for p in _lander_fx:
		(p as GPUParticles3D).emitting = false
	_moon_walk(false)
	_back_home()
	pad_rocket.position = _pad_home
	pad_rocket.rotation.z = 0.0
	var stand := Terrain.ROCKET + Vector2(-4.2, -2.6)
	explorer.global_position = Vector3(stand.x, Terrain.height(stand.x, stand.y) + 0.2, stand.y)
	explorer.velocity = Vector3.ZERO
	explorer.visible = true
	explorer.busy = 0.0
	explorer.set_physics_process(true)
	if _dog:
		var ds := stand + Vector2(1.3, 0.6)
		_dog.global_position = Vector3(ds.x, Terrain.height(ds.x, ds.y), ds.y)
		_dog.visible = true
		_dog.set_process(true)
		_dog.set_physics_process(true)
	var f: Node3D = corner.follow
	f.global_position = explorer.global_position + Vector3.UP * 1.1
	corner.follow.cam.make_current()
	big.text = ""
	active = false
	if life.audio:
		life.audio.space_music(false)
	_unwhite(1.2)
	_say("Home again!")


# --- screen and sound -------------------------------------------------------------------------

func _build_ui() -> void:
	ui.layer = 7
	add_child(ui)
	fade.color = Color(1, 1, 1, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	big.set_anchors_preset(Control.PRESET_FULL_RECT)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 260)
	big.add_theme_color_override("font_color", Color(1, 1, 1))
	big.add_theme_color_override("font_outline_color", Color(0.15, 0.25, 0.55))
	big.add_theme_constant_override("outline_size", 24)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(big)
	big.resized.connect(func() -> void: big.pivot_offset = big.size * 0.5)


func _white(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, seconds)
	await tw.finished


func _unwhite(seconds: float) -> void:
	create_tween().tween_property(fade, "color:a", 0.0, seconds)


func _say(text: String) -> void:
	if shots_mode:
		print("[trip] says: ", text)
		return
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	DisplayServer.tts_speak(text, voices[0], 75, 1.0, 0.9)


## A soft rocket rumble: two seconds of brown noise that loops.
func _brown_noise() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	var v := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		v = (v + rng.randf_range(-1.0, 1.0) * 0.08) * 0.995
		samples[i] = v
	# cross-fade the ends so the loop has no click
	var fadeN := 2000
	for i in fadeN:
		var k := float(i) / fadeN
		samples[i] = samples[i] * k + samples[n - fadeN + i] * (1.0 - k)
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	for i in n:
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n - fadeN
	return w
