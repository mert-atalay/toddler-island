extends Node3D
## Everything that answers her button registers here with where it is, how far it reaches and what it
## does. Her button picks the thing she is facing (not a fixed order), and things she can press
## twinkle with a little sparkle when she is near, so you both know where to press.
##
## An entry: {"name", "pos": Callable -> Vector3, "reach": float, "act": Callable -> String,
##            "when": Callable -> bool (optional), "sparkle": bool, "priority": float}

var entries: Array = []
var explorer: CharacterBody3D
var _sparkles := {}   # entry index -> Sprite3D
var _star: ImageTexture
var _t := 0.0


func _ready() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for j in 64:
		for i in 64:
			var p := Vector2(i - 31.5, j - 31.5) / 31.5
			var a := atan2(p.y, p.x)
			var r := p.length()
			var star := 0.42 + 0.5 * pow(absf(cos(a * 2.0)), 6.0)  # four-pointed twinkle
			var v := clampf((star - r) * 6.0, 0.0, 1.0)
			img.set_pixel(i, j, Color(1.0, 0.97, 0.75, v))
	_star = ImageTexture.create_from_image(img)


func register(entry: Dictionary) -> void:
	entry.merge({"reach": 1.6, "sparkle": true, "priority": 0.0}, false)
	entries.append(entry)


func available(e: Dictionary) -> bool:
	return not e.has("when") or (e["when"] as Callable).call()


## The thing she is facing within reach, or {} if nothing.
func pick() -> Dictionary:
	var here := explorer.global_position
	var fwd: Vector3 = explorer.forward()
	var best: Dictionary = {}
	var best_score := INF
	for e in entries:
		if not e.has("act") or not available(e):
			continue
		var p: Vector3 = (e["pos"] as Callable).call()
		var d := Vector2(p.x - here.x, p.z - here.z)
		var dist := d.length()
		if dist > float(e["reach"]):
			continue
		var ang := absf(Vector2(fwd.x, fwd.z).angle_to(d)) if dist > 0.05 else 0.0
		if ang > 1.9 and dist > 0.9:
			continue
		var score := ang * 1.2 + dist * 0.35 - float(e["priority"])
		if score < best_score:
			best_score = score
			best = e
	return best


## Up to n things in reach, best first (for the choice cards).
func candidates(n: int) -> Array:
	var here := explorer.global_position
	var fwd: Vector3 = explorer.forward()
	var scored: Array = []
	for e in entries:
		if not e.has("act") or not available(e):
			continue
		var p: Vector3 = (e["pos"] as Callable).call()
		var d := Vector2(p.x - here.x, p.z - here.z)
		var dist := d.length()
		if dist > float(e["reach"]):
			continue
		var ang := absf(Vector2(fwd.x, fwd.z).angle_to(d)) if dist > 0.05 else 0.0
		if ang > 1.9 and dist > 0.9:
			continue
		scored.append([ang * 1.2 + dist * 0.35 - float(e["priority"]), e])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return scored.slice(0, n).map(func(x: Array) -> Dictionary: return x[1])


func _process(delta: float) -> void:
	if explorer == null:
		return
	_t += delta
	var here := explorer.global_position
	for i in entries.size():
		var e: Dictionary = entries[i]
		if not e["sparkle"]:
			continue
		var show := false
		var p := Vector3.ZERO
		if available(e):
			p = (e["pos"] as Callable).call()
			show = Vector2(p.x - here.x, p.z - here.z).length() < float(e["reach"]) + 2.5
		var s: Sprite3D = _sparkles.get(i)
		if show and s == null:
			s = Sprite3D.new()
			s.texture = _star
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.shaded = false
			s.pixel_size = 0.006
			s.no_depth_test = true
			s.render_priority = 2
			add_child(s)
			_sparkles[i] = s
		if s:
			s.visible = show
			if show:
				s.global_position = p + Vector3.UP * (float(e.get("sparkle_height", 1.0)) + 0.08 * sin(_t * 3.0 + i))
				var k := 0.75 + 0.35 * sin(_t * 5.0 + i * 1.7)
				s.scale = Vector3.ONE * k
				s.rotation.z = _t * 0.8
