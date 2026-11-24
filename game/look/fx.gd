extends Node3D
## Little visual answers: hearts rising from a happy animal, a butterfly when no animal is near,
## and a "wants" bubble over an animal's head showing the food it would like.

const Models := preload("res://lib/models.gd")

var _heart_tex: ImageTexture
var _disc_tex: ImageTexture


func _ready() -> void:
	_heart_tex = _make_texture(64, func(x: float, y: float) -> Color:
		# a heart shape: (x² + y² - 1)³ - x² y³ <= 0, drawn with a white rim
		var px := x * 2.6
		var py := -y * 2.6 + 0.35
		var v := pow(px * px + py * py - 1.0, 3.0) - px * px * py * py * py
		if v > 0.0:
			return Color(0, 0, 0, 0)
		return Color(1.0, 0.36, 0.55) if v < -0.02 else Color(1, 1, 1))
	_disc_tex = _make_texture(64, func(x: float, y: float) -> Color:
		var d := Vector2(x, y).length()
		if d > 0.48:
			return Color(0, 0, 0, 0)
		return Color(1, 1, 1, 0.92) if d < 0.44 else Color(0.55, 0.5, 0.45, 0.9))


func _make_texture(size: int, shade: Callable) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for j in size:
		for i in size:
			img.set_pixel(i, j, shade.call((i + 0.5) / size - 0.5, (j + 0.5) / size - 0.5))
	return ImageTexture.create_from_image(img)


func hearts(at: Vector3, count := 6) -> void:
	for i in count:
		var s := Sprite3D.new()
		s.texture = _heart_tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.006
		s.shaded = false
		s.no_depth_test = false
		s.position = at + Vector3(randf_range(-0.35, 0.35), randf_range(0.0, 0.2), randf_range(-0.35, 0.35))
		s.scale = Vector3.ZERO
		add_child(s)
		var t := create_tween()
		t.tween_interval(i * 0.09)
		t.tween_property(s, "scale", Vector3.ONE * randf_range(0.8, 1.2), 0.18)
		t.parallel().tween_property(s, "position", s.position + Vector3(randf_range(-0.3, 0.3), 1.3, randf_range(-0.3, 0.3)), 1.6)
		t.tween_property(s, "modulate:a", 0.0, 0.4)
		t.tween_callback(s.queue_free)


## A butterfly that flutters across in front of the explorer.
func butterfly(near: Vector3, facing: float) -> void:
	var g := Node3D.new()
	add_child(g)
	var colors := [Color(1.0, 0.7, 0.28), Color(0.6, 0.82, 1.0), Color(1.0, 0.56, 0.82), Color(1.0, 0.94, 0.48)]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colors.pick_random()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var wings: Array[MeshInstance3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		g.add_child(pivot)
		var w := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.3, 0.24)
		w.mesh = q
		w.material_override = mat
		w.position = Vector3(0.15 * side, 0, 0)
		w.rotation.x = -PI / 2
		pivot.add_child(w)
		wings.append(w)
		pivot.set_meta("side", side)
	var fwd := Vector3(sin(facing), 0, cos(facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var side_sign := -1.0 if randf() < 0.5 else 1.0
	var base := near + fwd * 1.3 + Vector3.UP * 1.0
	var a := base - right * 1.8 * side_sign
	var b := base + right * 1.8 * side_sign + Vector3.UP * 0.5
	g.position = a
	var t := create_tween()
	t.tween_method(func(p: float) -> void:
		g.position = a.lerp(b, p) + Vector3.UP * sin(p * PI * 3.0) * 0.25
		g.look_at(b, Vector3.UP)
		for pivot in g.get_children():
			pivot.rotation.z = sin(p * 90.0) * 1.1 * float(pivot.get_meta("side")), 0.0, 1.0, 4.0)
	t.tween_callback(g.queue_free)


## A butterfly that keeps drifting round a spot (small life for the flowery places).
func drifting_butterfly(anchor: Vector3) -> void:
	var g := Node3D.new()
	add_child(g)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = [Color(1.0, 0.7, 0.28), Color(0.6, 0.82, 1.0), Color(1.0, 0.56, 0.82), Color(1.0, 0.94, 0.48)].pick_random()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.set_meta("side", side)
		g.add_child(pivot)
		var w := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 0.16)
		w.mesh = q
		w.material_override = mat
		w.position = Vector3(0.1 * side, 0, 0)
		w.rotation.x = -PI / 2
		pivot.add_child(w)
	var seed := randf() * 100.0
	var t := create_tween().set_loops()
	t.tween_method(func(p: float) -> void:
		var k := seed + p
		var at := anchor + Vector3(sin(k * 0.31) * 4.0 + sin(k * 0.77) * 1.5, 0.8 + 0.5 * sin(k * 1.3), cos(k * 0.27) * 4.0 + cos(k * 0.91) * 1.5)
		var dir := at - g.position
		if dir.length() > 0.001:
			g.rotation.y = atan2(-dir.x, -dir.z)
		g.position = at
		for pivot in g.get_children():
			pivot.rotation.z = sin(k * 30.0) * 1.1 * float(pivot.get_meta("side")), 0.0, 60.0, 60.0)


## A ring spreading on water, as if a fish came up.
func ripple(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.position = at
	ring.scale = Vector3(0.2, 0.05, 0.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var t := create_tween()
	t.tween_property(ring, "scale", Vector3(1.4, 0.05, 1.4), 2.2)
	t.parallel().tween_property(m, "albedo_color:a", 0.0, 2.2)
	t.tween_callback(ring.queue_free)


## A bubble over an animal's head with a tiny model of the food it wants. Returns the bubble node.
func want_bubble(food_model: Node3D) -> Node3D:
	var bubble := Node3D.new()
	var disc := Sprite3D.new()
	disc.texture = _disc_tex
	disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	disc.pixel_size = 0.009
	disc.shaded = false
	disc.render_priority = -1
	bubble.add_child(disc)
	if food_model:
		food_model.position = Vector3(0, -0.1, 0.05)
		bubble.add_child(food_model)
	return bubble
