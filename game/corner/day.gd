extends Node
## The day passes from late morning to sunset over the session the parent sets (15 minutes unless
## changed in the parent menu). At sunset lights come on in the cottage and lighthouse, the animals
## walk home, and the screen settles into a sleepy night with the moon. Any button starts a new morning.

signal sleepy_time

var corner: Node3D
var life: Node3D
var session_minutes := 15.0      # 0 = no ending
var t := 0.0                     # seconds into the day
var ended := false
var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sent_home := false
var _overlay: ColorRect
var _moon: Label
var _glows: Array = []           # emissive materials that light up at dusk


func setup(c: Node3D, l: Node3D) -> void:
	corner = c
	life = l
	_sun = c.find_children("*", "DirectionalLight3D", false, false)[0]
	_env = c.get_meta("env")
	_sky = c.get_meta("sky")
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.07, 0.2, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	_moon = Label.new()
	_moon.text = "☾"
	_moon.add_theme_font_size_override("font_size", 160)
	_moon.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_moon.position = Vector2(1180, 80)
	_moon.modulate.a = 0.0
	layer.add_child(_moon)


func add_glow(m: StandardMaterial3D) -> void:
	_glows.append(m)


func day_fraction() -> float:
	return 0.0 if session_minutes <= 0.0 else clampf(t / (session_minutes * 60.0), 0.0, 1.0)


func sunset_now() -> void:
	t = maxf(t, session_minutes * 60.0 * 0.88) if session_minutes > 0.0 else t


func new_morning() -> void:
	t = 0.0
	ended = false
	_sent_home = false
	var tw := create_tween()
	tw.tween_property(_overlay, "color:a", 0.0, 1.5)
	tw.parallel().tween_property(_moon, "modulate:a", 0.0, 1.0)
	life.visitor_day(life.visit_count + 1)
	for a in life.animals:
		a._choose()


func _process(delta: float) -> void:
	if ended:
		return
	if session_minutes > 0.0:
		t += delta
	var f := day_fraction()
	# the light: high warm-white sun in the morning, low golden sun at the end
	var dusk := Terrain_sstep(0.7, 1.0, f)
	if corner.look:
		corner.look.night = Terrain_sstep(0.86, 1.0, f)
		corner.look.morning = 1.0 - Terrain_sstep(0.02, 0.14, f)
	_sun.rotation_degrees.x = -lerpf(42.0, 6.0, Terrain_sstep(0.0, 1.0, f))
	_sun.light_color = Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.62, 0.35), dusk)
	_sun.light_energy = lerpf(1.3, 0.75, dusk)
	_sky.sky_top_color = Color(0.32, 0.58, 0.88).lerp(Color(0.36, 0.38, 0.7), dusk)
	_sky.sky_horizon_color = Color(0.74, 0.85, 0.94).lerp(Color(1.0, 0.68, 0.5), dusk)
	_env.ambient_light_energy = lerpf(1.0, 0.65, dusk)
	_env.fog_light_color = Color(0.78, 0.87, 0.96).lerp(Color(0.95, 0.7, 0.6), dusk)
	for m in _glows:
		(m as StandardMaterial3D).emission_energy_multiplier = lerpf(0.0, 2.5, Terrain_sstep(0.8, 0.95, f))
	if f > 0.9 and not _sent_home:
		_sent_home = true
		for a in life.animals:
			a.go_home()
	if f >= 1.0 and session_minutes > 0.0:
		ended = true
		var tw := create_tween()
		tw.tween_property(_overlay, "color:a", 0.72, 3.0)
		tw.parallel().tween_property(_moon, "modulate:a", 1.0, 3.0)
		if corner.look:
			corner.look.night = 1.0
		sleepy_time.emit()


func Terrain_sstep(a: float, b: float, x: float) -> float:
	var k := clampf((x - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)
