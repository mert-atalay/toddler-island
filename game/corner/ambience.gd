extends Node3D
## The feel of the place, beyond what's in it:
##  - specks of pollen and dust drifting in the sunlight round her, and leaves twirling down in the
##    wood and the orchard;
##  - a warmer, richer picture and soft light shafts through the air (if the computer keeps up);
##  - layered sound by place: leaves rustling near the trees, frogs croaking at the pond, crickets in
##    the late afternoon, and now and then a woodpecker knocking in the wood.

const Terrain := preload("res://corner/terrain.gd")
const RATE := 22050

var corner: Node3D
var life: Node3D
var explorer: Node3D
var _motes: GPUParticles3D
var _leaves: Array = []
var _rustle := AudioStreamPlayer.new()
var _crickets := AudioStreamPlayer.new()
var _frog_t := 4.0
var _pecker_t := 20.0
var _frog: AudioStreamWAV
var _knock: AudioStreamWAV


func setup(c: Node3D) -> void:
	corner = c
	life = c.life
	explorer = c.explorer
	_air()
	_falling_leaves(Terrain.OAK + Vector2(-4, 0), 14.0, 26)
	_falling_leaves(Terrain.ORCHARD, 9.0, 14)
	_grade()
	_sounds()


func _soft() -> Texture2D:
	return preload("res://space/rocket.gd")._soft_dot()


# --- air ---------------------------------------------------------------------------------------

func _air() -> void:
	_motes = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 3, 14)
	pm.direction = Vector3(1, 0.2, 0.3)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0.05, 0.01, 0.02)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.75, 0.0))
	g.add_point(0.25, Color(1, 0.95, 0.75, 0.55))
	g.add_point(0.75, Color(1, 0.95, 0.75, 0.55))
	g.set_color(g.get_point_count() - 1, Color(1, 0.95, 0.75, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_motes.process_material = pm
	_motes.amount = 160
	_motes.lifetime = 9.0
	_motes.preprocess = 9.0
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft()
	q.material = m
	_motes.draw_pass_1 = q
	_motes.local_coords = false
	_motes.visibility_aabb = AABB(Vector3(-16, -4, -16), Vector3(32, 8, 32))
	add_child(_motes)


func _falling_leaves(centre: Vector2, radius: float, amount: int) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius, 1.0, radius)
	pm.direction = Vector3(0.3, -1, 0.1)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.15, -0.35, 0.05)
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 2.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.color = Color(0.85, 0.6, 0.2)
	var hue := Gradient.new()
	hue.set_color(0, Color(0.95, 0.7, 0.25))
	hue.set_color(1, Color(0.6, 0.75, 0.25))
	var ht := GradientTexture1D.new()
	ht.gradient = hue
	pm.color_initial_ramp = ht
	p.process_material = pm
	p.amount = amount
	p.lifetime = 12.0
	p.preprocess = 12.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.06)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(centre.x, Terrain.height(centre.x, centre.y) + 7.0, centre.y)
	p.visibility_aabb = AABB(Vector3(-radius - 2, -9, -radius - 2), Vector3(radius * 2 + 4, 12, radius * 2 + 4))
	p.visibility_range_end = 70.0
	add_child(p)
	_leaves.append(p)


## A warmer, softer, richer picture; and gentle light shafts through the air.
func _grade() -> void:
	var env: Environment = corner.get_meta("env")
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.02
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.06
	env.fog_light_color = Color(0.82, 0.88, 0.95)
	env.fog_sun_scatter = 0.25
	if not OS.get_cmdline_user_args().has("--no-shafts"):
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.006
		env.volumetric_fog_albedo = Color(1.0, 0.97, 0.9)
		env.volumetric_fog_anisotropy = 0.7
		env.volumetric_fog_length = 48.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_sky_affect = 0.0
		env.volumetric_fog_ambient_inject = 0.2
	var sun := corner.find_children("*", "DirectionalLight3D", false, false)[0] as DirectionalLight3D
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_volumetric_fog_energy = 1.4


# --- sound ------------------------------------------------------------------------------------

func _sounds() -> void:
	_rustle.stream = _noise(0.93, 0.7, 31)
	_rustle.bus = "Ambience"
	_rustle.volume_db = -60.0
	add_child(_rustle)
	_rustle.play()
	_crickets.stream = _cricket_loop()
	_crickets.bus = "Ambience"
	_crickets.volume_db = -60.0
	add_child(_crickets)
	_crickets.play()
	_frog = _croak()
	_knock = _pecker()


func _to_wav(s: PackedFloat32Array, loop: bool, level: float) -> AudioStreamWAV:
	var n := s.size()
	var peak := 0.0001
	for x in s:
		peak = maxf(peak, absf(x))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(s[i] / peak * level, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n - 1
	return w


## Leaves in the wind: noise that swells and fades in gusts, with a soft high hiss.
func _noise(smooth: float, gusty: float, seed: int) -> AudioStreamWAV:
	var n := RATE * 6
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := PackedFloat32Array()
	s.resize(n)
	var v := 0.0
	var prev := 0.0
	for i in n:
		var white := rng.randf_range(-1.0, 1.0)
		v = v * smooth + white * (1.0 - smooth)
		var hiss := white - prev
		prev = white
		var x := float(i) / n
		var gust := 0.5 + 0.5 * sin(TAU * x * 2.0) * sin(TAU * x * 3.0 + 1.0)
		s[i] = (v * 0.7 + hiss * 0.08) * (1.0 - gusty + gusty * gust)
	# fade the loop ends together
	var xf := 4000
	for i in xf:
		var k := float(i) / xf
		s[i] = s[i] * k + s[n - xf + i] * (1.0 - k)
	s.resize(n - xf)
	return _to_wav(s, true, 0.6)


## Crickets: bursts of quick high chirps, a few insects at different rates.
func _cricket_loop() -> AudioStreamWAV:
	var n := RATE * 4
	var s := PackedFloat32Array()
	s.resize(n)
	for c in 3:
		var f: float = [4300.0, 4700.0, 3900.0][c]
		var period: float = [0.62, 0.81, 1.07][c]
		var offset: float = [0.0, 0.23, 0.51][c]
		var t: float = offset
		while t < 4.0 - 0.2:
			for pulse in 3:
				var a := int((t + pulse * 0.035) * RATE)
				for k in int(0.022 * RATE):
					if a + k < n:
						var x := float(k) / RATE
						s[a + k] += sin(TAU * f * x) * sin(PI * x / 0.022) * 0.3
			t += period
	return _to_wav(s, true, 0.5)


## A frog: two low throaty pulses.
func _croak() -> AudioStreamWAV:
	var n := int(RATE * 0.55)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var x := float(i) / RATE
		var env := 0.0
		for c in 2:
			var t0 := c * 0.22
			if x > t0 and x < t0 + 0.18:
				env = sin(PI * (x - t0) / 0.18)
		var buzz: float = sin(TAU * 140.0 * x) * (0.6 + 0.4 * signf(sin(TAU * 32.0 * x)))
		s[i] = buzz * env
	return _to_wav(s, false, 0.7)


## A woodpecker: a quick roll of knocks.
func _pecker() -> AudioStreamWAV:
	var n := int(RATE * 0.7)
	var s := PackedFloat32Array()
	s.resize(n)
	for k in 12:
		var a := int((k * 0.05) * RATE)
		for i in int(0.03 * RATE):
			if a + i < n:
				var x := float(i) / RATE
				s[a + i] += sin(TAU * 900.0 * x) * exp(-x * 160.0) + sin(TAU * 1700.0 * x) * exp(-x * 220.0) * 0.5
	return _to_wav(s, false, 0.7)


func _play_at(stream: AudioStream, at: Vector3, db: float, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "Ambience"
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		_motes.global_position = cam.global_position + (-cam.global_basis.z) * 6.0
	var away: bool = life.trip != null and life.trip.active
	_motes.emitting = not away
	var here: Vector3 = explorer.global_position
	var h2 := Vector2(here.x, here.z)
	# leaves rustle near trees: how many trunks are close
	var near := 0
	for t in corner.trunks:
		if h2.distance_to(t[0]) < 12.0:
			near += 1
	var want := -60.0 if away else lerpf(-34.0, -15.0, clampf(near / 12.0, 0.0, 1.0)) if near > 0 else -60.0
	_rustle.volume_db = lerpf(_rustle.volume_db, want, 1.0 - exp(-delta * 1.0))
	# crickets in the late afternoon and at dusk, away from the beach
	var late: float = life.day.day_fraction() if life.day else 0.0
	var on_land := Terrain.is_sand(here.x, here.z) < 0.5
	var cw := -60.0 if away or not on_land else lerpf(-60.0, -20.0, clampf((late - 0.55) / 0.3, 0.0, 1.0))
	_crickets.volume_db = lerpf(_crickets.volume_db, cw, 1.0 - exp(-delta * 0.7))
	if away:
		return
	# frogs at the pond
	_frog_t -= delta
	if _frog_t <= 0.0:
		_frog_t = randf_range(3.0, 9.0)
		if h2.distance_to(Terrain.POND) < 28.0:
			var a := randf() * TAU
			var at := Vector3(Terrain.POND.x + cos(a) * 9.5, 0.2, Terrain.POND.y + sin(a) * 9.5)
			_play_at(_frog, at, -6.0, randf_range(0.85, 1.15))
	# a woodpecker in the wood now and then
	_pecker_t -= delta
	if _pecker_t <= 0.0:
		_pecker_t = randf_range(18.0, 40.0)
		if h2.distance_to(Terrain.OAK) < 35.0:
			var t: Array = corner.trunks[randi() % corner.trunks.size()]
			var tp: Vector2 = t[0]
			_play_at(_knock, Vector3(tp.x, Terrain.height(tp.x, tp.y) + 5.0, tp.y), -8.0)
