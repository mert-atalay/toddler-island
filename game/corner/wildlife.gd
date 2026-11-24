extends Node3D
## The wild animals of the valley, each with its own little life and its own way with Mercan.
##
## Rabbits live in families round burrows in the meadows. They nibble, sit up to look about, wash
## their faces and hop about with a squash and a stretch. If she runs at them they thump off and
## dive into the burrow, peeping out again a little later; if she tiptoes (walks slowly), they let
## her come close, and she can say hello or give one a carrot.
##
## Squirrels live on the trees by the woods and the orchard. They forage in quick little dashes,
## sit up nibbling, chitter, and dash spiralling up the trunk if she runs near, watching from the top
## until she has gone. If she waits by the tree holding an apple or seeds, one comes down for it.
##
## Ducks paddle on the pond and the lake, leaving ripples: they dabble with their tails in the air,
## shake their feathers, quack, and sometimes waddle up the bank to rest. A mother leads her
## ducklings in a line. Seeds scattered at the water's edge bring them all racing over.
##
## Gulls circle over the lake, and now and then a flock flies across the sky.

const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const W := "res://assets/animals/wild/"
const RATE := 22050

var corner: Node3D
var life: Node3D
var explorer: CharacterBody3D
var rabbits: Array = []
var squirrels: Array = []
var ducks: Array = []
var gulls: Array = []
var flock: Array = []
var _flock_t := 20.0
var _t := 0.0
var _seen := {}
var _quack: AudioStreamWAV
var _chitter: AudioStreamWAV
var _thump: AudioStreamWAV
var _seed_spot := Vector2.INF
var _seed_t := 0.0


func setup(c: Node3D) -> void:
	corner = c
	life = c.life
	explorer = c.explorer
	_quack = _make_quack()
	_chitter = _make_chitter()
	_thump = _make_thump()
	_rabbits()
	_squirrels()
	_ducks()
	_gulls()


# --- helpers ----------------------------------------------------------------------------------

## A wild animal: a root that moves and turns, and a body under it that squashes, stretches and tips.
func _creature(path: String, height: float, tint := Color(0, 0, 0, 0)) -> Array:
	var root := Node3D.new()
	add_child(root)
	var body := Node3D.new()
	root.add_child(body)
	var m := Models.spawn(body, path, height, 0.0)
	if m and tint.a > 0.0:
		for g in m.find_children("*", "MeshInstance3D", true, false):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint
			mat.roughness = 1.0
			(g as MeshInstance3D).material_override = mat
	var ap: AnimationPlayer = null
	if m:
		ap = m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("Idle"):
			ap.play("Idle")
			ap.seek(randf() * 3.0, true)
	return [root, body, ap]


## Plays one of the rig's clips on a wild animal (the rabbit and squirrel models are rigged when
## they load, lib/autorig.gd, so their legs, head and tail move too).
func _clip(d: Dictionary, clip: String, speed := 1.0) -> void:
	var ap := d.get("anim") as AnimationPlayer
	if ap == null or not ap.has_animation(clip):
		return
	if ap.current_animation != clip or (clip == "Idle_2" and not ap.is_playing()):
		ap.play(clip, 0.2)
	ap.speed_scale = speed


func _ok_ground(p: Vector2) -> bool:
	if Terrain.height(p.x, p.y) < 0.3 or Terrain.river_distance(p) < 5.5 or p.distance_to(Terrain.POND) < 10.5:
		return false
	if p.distance_to(Terrain.LAKE) < Terrain.LAKE_R + 3.0 or Terrain.mountain(p) > 0.15:
		return false
	for b in corner.blocked:
		if p.distance_to(b[0]) < float(b[1]) + 0.3:
			return false
	return true


func _near_spot(c: Vector2, r: float) -> Vector2:
	for k in 80:
		var q := c + Vector2(randf_range(-r, r), randf_range(-r, r))
		if _ok_ground(q):
			return q
	return c


func _ground_y(p: Vector2) -> float:
	if corner.valley:
		return corner.valley.height_at(p.x, p.y)
	return Terrain.height(p.x, p.y)


func _her_speed() -> float:
	return Vector2(explorer.velocity.x, explorer.velocity.z).length()


func _say(word: String) -> void:
	if life.stickers:
		life.stickers._say_later(word, 0.1)


func _sound_at(stream: AudioStream, at: Vector3, db := -4.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "Animals"
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 5.0
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


## The first time she sees a wild animal close up, its sticker pops up.
func _spotted(kind: String, d: float) -> void:
	if d > 6.0 or _seen.has(kind) or life.stickers == null:
		return
	_seen[kind] = true
	if not life.stickers.earned.has(kind):
		life.stickers.earn(kind)


# --- rabbits ----------------------------------------------------------------------------------

func _rabbits() -> void:
	var homes := [Vector2(-28, 16), Vector2(18, 38), Vector2(-12, -48), Vector2(80, -38), Vector2(8, 62), Vector2(-40, -10)]
	for h in homes:
		var home := _near_spot(h, 8.0)
		_burrow(home)
		for k in randi_range(2, 3):
			var c := _creature(W + "grayrabbit.glb", 0.32 if k == 0 else 0.24, Color(0.62, 0.52, 0.42) if k % 2 == 0 else Color(0.72, 0.64, 0.55))
			var root: Node3D = c[0]
			var p := _near_spot(home, 2.5)
			root.position = Vector3(p.x, _ground_y(p), p.y)
			root.rotation.y = randf() * TAU
			var r := {"root": root, "body": c[1], "anim": c[2], "home": home, "state": "graze", "t": randf_range(1.0, 4.0), "hop": 0.0,
				"from": root.position, "to": root.position, "hop_len": 0.3, "hop_h": 0.2, "flee": 0, "dir": Vector2.ZERO, "hidden": 0.0}
			rabbits.append(r)
			_register_rabbit(r)


func _burrow(at: Vector2) -> void:
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 0.4
	mound.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.48, 0.36, 0.24)
	m.roughness = 1.0
	mound.material_override = m
	add_child(mound)
	mound.position = Vector3(at.x, _ground_y(at) - 0.12, at.y)
	mound.scale = Vector3(1.3, 0.6, 1.0)
	var hole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.17
	cm.bottom_radius = 0.17
	cm.height = 0.02
	hole.mesh = cm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.08, 0.06, 0.04)
	hole.material_override = hm
	add_child(hole)
	hole.position = Vector3(at.x + 0.42, _ground_y(at) + 0.08, at.y)
	hole.rotation.z = 0.9


func _register_rabbit(r: Dictionary) -> void:
	var root: Node3D = r["root"]
	life.interact.register({"name": "rabbit", "reach": 1.9, "priority": 0.25, "sparkle": false, "icon": W + "grayrabbit.glb",
		"pos": func() -> Vector3: return root.global_position,
		"when": func() -> bool: return root.visible and r["state"] in ["graze", "sit", "wash", "watch"],
		"label": func() -> String: return "Give the bunny a carrot" if explorer.carrying == "carrot" else "Say hello to the bunny",
		"act": func() -> String:
			r["state"] = "happy"
			r["t"] = 2.2
			explorer.act("interact-right", 1.0)
			life.fx.hearts(root.global_position + Vector3.UP * 0.4, 6)
			if explorer.carrying == "carrot":
				explorer.drop()
				_say("Crunch, crunch!")
				return "fed rabbit"
			_say("Hello, bunny!")
			return "stroked rabbit"})


func _rabbit_hop(r: Dictionary, to: Vector2, height: float, time: float) -> void:
	var root: Node3D = r["root"]
	r["from"] = root.position
	r["to"] = Vector3(to.x, _ground_y(to), to.y)
	r["hop"] = 0.0
	r["hop_len"] = time
	r["hop_h"] = height
	root.rotation.y = atan2(to.x - root.position.x, to.y - root.position.z)


func _rabbit_tick(r: Dictionary, delta: float, here: Vector2) -> void:
	var root: Node3D = r["root"]
	var body: Node3D = r["body"]
	var p := Vector2(root.position.x, root.position.z)
	var d := p.distance_to(here)
	_spotted("rabbit", d)
	# in the middle of a hop: squash, stretch in the air, squash on landing
	if r["hop"] < r["hop_len"]:
		r["hop"] += delta
		var k: float = clampf(r["hop"] / r["hop_len"], 0.0, 1.0)
		var pos: Vector3 = (r["from"] as Vector3).lerp(r["to"], k)
		pos.y += sin(k * PI) * float(r["hop_h"])
		root.position = pos
		var stretch := 1.0 + sin(k * PI) * 0.1
		body.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch))
		body.rotation.x = lerpf(-0.2, 0.15, k) * sin(k * PI)
		_clip(r, "Gallop" if r["state"] == "flee" else "Walk", 0.55 / maxf(float(r["hop_len"]), 0.1))
		return
	body.scale = body.scale.lerp(Vector3.ONE, 1.0 - exp(-delta * 12.0))
	r["t"] -= delta
	# Mercan running at them: thump and flee to the burrow
	var running := _her_speed() > 2.4
	if r["state"] != "flee" and r["state"] != "hidden" and (d < 2.0 or (d < 6.0 and running)):
		r["state"] = "flee"
		r["flee"] = 8
		r["t"] = 0.0
		_sound_at(_thump, root.global_position, -10.0)
	match r["state"]:
		"graze":
			body.rotation.x = lerpf(body.rotation.x, 0.0, 1.0 - exp(-delta * 6.0))
			_clip(r, "Eating")
			if d < 6.0:
				r["state"] = "watch"
				r["t"] = randf_range(1.5, 3.0)
			elif r["t"] <= 0.0:
				var pick := randf()
				if pick < 0.25:
					r["state"] = "sit"
					r["t"] = randf_range(1.5, 3.5)
				elif pick < 0.4:
					r["state"] = "wash"
					r["t"] = randf_range(1.2, 2.2)
				else:
					var to := p + Vector2.from_angle(randf() * TAU) * randf_range(0.4, 0.8)
					var home: Vector2 = r["home"]
					if to.distance_to(home) > 5.0:
						to = p + (home - p).normalized() * 0.6
					if _ok_ground(to):
						_rabbit_hop(r, to, 0.16, 0.26)
					r["t"] = randf_range(1.0, 3.5)
		"sit", "watch":
			# sitting up, looking about (towards her while she is near)
			body.rotation.x = lerpf(body.rotation.x, -0.55, 1.0 - exp(-delta * 8.0))
			_clip(r, "Idle")
			if r["state"] == "watch":
				root.rotation.y = lerp_angle(root.rotation.y, atan2(here.x - p.x, here.y - p.y), 1.0 - exp(-delta * 3.0))
			else:
				root.rotation.y += sin(_t * 1.3 + root.position.z) * delta * 0.8
			if r["t"] <= 0.0:
				r["state"] = "graze" if d > 4.0 else "watch"
				r["t"] = randf_range(1.5, 4.0)
		"wash":
			body.rotation.x = -0.4
			body.rotation.z = sin(_t * 18.0) * 0.12
			_clip(r, "Idle", 2.5)
			if r["t"] <= 0.0:
				body.rotation.z = 0.0
				r["state"] = "graze"
				r["t"] = randf_range(1.0, 3.0)
		"happy":
			_clip(r, "Idle_2")
			if r["t"] > 1.6 and r["hop"] >= r["hop_len"]:
				_rabbit_hop(r, p, 0.35, 0.3)  # a happy jump on the spot
			if r["t"] <= 0.0:
				r["state"] = "watch"
				r["t"] = 2.0
		"flee":
			if r["t"] > 0.0:
				return
			var home: Vector2 = r["home"]
			var to_home := home - p
			if to_home.length() < 0.8:
				r["state"] = "hidden"
				r["hidden"] = randf_range(6.0, 10.0)
				root.visible = false
				return
			var dir := to_home.normalized().rotated(randf_range(-0.35, 0.35))
			if (p + dir).distance_to(here) < p.distance_to(here) and d < 3.0:
				dir = (p - here).normalized()
			var step := minf(1.2, to_home.length())
			_rabbit_hop(r, p + dir * step, 0.32, 0.28)
			r["t"] = 0.02
		"hidden":
			r["hidden"] -= delta
			if r["hidden"] <= 0.0 and d > 7.0:
				var home: Vector2 = r["home"]
				var out := home + Vector2(0.6, 0.0)
				root.position = Vector3(out.x, _ground_y(out), out.y)
				root.visible = true
				body.scale = Vector3(1, 0.2, 1)
				r["state"] = "watch"
				r["t"] = 2.5


# --- squirrels --------------------------------------------------------------------------------

func _squirrels() -> void:
	var near: Array = []
	for t in corner.trunks:
		var tp: Vector2 = t[0]
		if tp.distance_to(Terrain.OAK) < 30.0 or tp.distance_to(Terrain.ORCHARD) < 16.0 or tp.distance_to(Vector2(-42, -72)) < 26.0 \
				or tp.distance_to(Vector2(-62, 28)) < 24.0 or tp.distance_to(Vector2(92, -12)) < 22.0:
			near.append(t)
	near.shuffle()
	for k in mini(9, near.size()):
		var t: Array = near[k]
		var tp: Vector2 = t[0]
		var start := tp + Vector2(1.2, 0.6)
		var c := _creature(W + "squirrel.glb", 0.24)
		var root: Node3D = c[0]
		root.position = Vector3(start.x, _ground_y(start), start.y)
		var s := {"root": root, "body": c[1], "anim": c[2], "tree": t, "state": "forage", "t": randf_range(1.0, 3.0), "trees": near,
			"from": root.position, "to": root.position, "move": 1.0, "move_len": 0.0, "wait": 0.0}
		squirrels.append(s)
		_register_squirrel(s)


func _register_squirrel(s: Dictionary) -> void:
	var root: Node3D = s["root"]
	life.interact.register({"name": "squirrel", "reach": 1.9, "priority": 0.25, "sparkle": false, "icon": W + "squirrel.glb",
		"pos": func() -> Vector3: return root.global_position,
		"when": func() -> bool: return s["state"] in ["forage", "nibble", "come"],
		"label": func() -> String: return "Give the squirrel a treat" if explorer.carrying in ["apple", "seed"] else "Say hello to the squirrel",
		"act": func() -> String:
			explorer.act("interact-right", 1.0)
			life.fx.hearts(root.global_position + Vector3.UP * 0.3, 5)
			_sound_at(_chitter, root.global_position, -6.0, 1.2)
			s["state"] = "nibble"
			s["t"] = 4.0
			if explorer.carrying in ["apple", "seed"]:
				explorer.drop()
				_say("Nibble, nibble!")
				return "fed squirrel"
			_say("Hello, squirrel!")
			return "stroked squirrel"})


func _sq_move(s: Dictionary, to: Vector3, time: float) -> void:
	var root: Node3D = s["root"]
	s["from"] = root.position
	s["to"] = to
	s["move"] = 0.0
	s["move_len"] = time


func _squirrel_tick(s: Dictionary, delta: float, here: Vector2) -> void:
	var root: Node3D = s["root"]
	var body: Node3D = s["body"]
	var p := Vector2(root.position.x, root.position.z)
	var d := p.distance_to(here)
	_spotted("squirrel", d)
	var tree: Array = s["tree"]
	var tp: Vector2 = tree[0]
	var tr: float = float(tree[1]) + 0.12
	if s["move"] < s["move_len"]:
		s["move"] += delta
		var k: float = clampf(s["move"] / s["move_len"], 0.0, 1.0)
		var pos: Vector3 = (s["from"] as Vector3).lerp(s["to"], k)
		if s["state"] in ["forage", "come"]:
			pos.y += absf(sin(k * PI * 3.0)) * 0.06  # bounding
		root.position = pos
		_clip(s, "Gallop", 1.3)
		return
	s["t"] -= delta
	var running := _her_speed() > 2.4
	var on_ground: bool = s["state"] in ["forage", "nibble", "come"]
	if on_ground and (d < 2.0 or (d < 5.0 and running)) and s["state"] != "nibble":
		# dash to the tree and spiral up it
		s["state"] = "climb"
		var base := tp + (p - tp).normalized() * tr
		root.rotation.y = atan2(base.x - p.x, base.y - p.y)
		_sq_move(s, Vector3(base.x, _ground_y(base), base.y), maxf(0.15, p.distance_to(base) / 7.0))
		_sound_at(_chitter, root.global_position, -6.0)
		s["t"] = 0.0
		return
	match s["state"]:
		"forage":
			body.rotation.x = 0.0
			_clip(s, "Eating", 1.6)
			# a hungry squirrel comes over if she stands still nearby holding a treat
			if explorer.carrying in ["apple", "seed"] and d < 7.0 and _her_speed() < 0.3:
				s["wait"] += delta
				if s["wait"] > 1.5:
					s["state"] = "come"
					s["wait"] = 0.0
			else:
				s["wait"] = 0.0
			if s["t"] <= 0.0:
				if randf() < 0.35:
					s["state"] = "nibble"
					s["t"] = randf_range(1.5, 3.0)
				else:
					if randf() < 0.25:
						var trees: Array = s["trees"]
						s["tree"] = trees[randi() % trees.size()]
						tree = s["tree"]
						tp = tree[0]
					var to := tp + Vector2.from_angle(randf() * TAU) * randf_range(1.0, 3.0)
					if Terrain.height(to.x, to.y) > 0.3 and to.distance_to(p) < 12.0:
						root.rotation.y = atan2(to.x - p.x, to.y - p.y)
						_sq_move(s, Vector3(to.x, _ground_y(to), to.y), to.distance_to(p) / 3.5)
					s["t"] = randf_range(0.6, 2.5)
		"nibble":
			# sitting up holding something, nibbling fast
			body.rotation.x = lerpf(body.rotation.x, -0.7, 1.0 - exp(-delta * 10.0))
			body.rotation.z = sin(_t * 30.0) * 0.04
			_clip(s, "Idle", 2.0)
			if s["t"] <= 0.0:
				body.rotation.z = 0.0
				s["state"] = "forage"
				s["t"] = randf_range(0.5, 1.5)
		"come":
			var to := here + (p - here).normalized() * 1.3
			root.rotation.y = atan2(here.x - p.x, here.y - p.y)
			if p.distance_to(to) > 0.3:
				_sq_move(s, Vector3(to.x, _ground_y(to), to.y), minf(1.5, p.distance_to(to) / 3.0))
			elif explorer.carrying == "":
				s["state"] = "forage"
		"climb":
			var gy := _ground_y(tp)
			var top := randf_range(2.6, 3.8)
			body.rotation.x = -PI / 2.0
			var a0 := atan2(p.y - tp.y, p.x - tp.x)
			var spiral := Vector3(tp.x + cos(a0 + 2.5) * tr, gy + top, tp.y + sin(a0 + 2.5) * tr)
			_sq_move(s, spiral, 0.9)
			s["state"] = "perch"
			s["t"] = randf_range(6.0, 10.0)
		"perch":
			_clip(s, "Idle")
			root.rotation.y = lerp_angle(root.rotation.y, atan2(here.x - p.x, here.y - p.y), 1.0 - exp(-delta * 2.0))
			if fmod(_t, 4.0) < delta:
				_sound_at(_chitter, root.global_position, -12.0, randf_range(0.9, 1.2))
			if s["t"] <= 0.0 and d > 7.0:
				body.rotation.x = PI / 2.0
				_sq_move(s, Vector3(p.x, _ground_y(p), p.y), 0.9)
				s["state"] = "down"
		"down":
			body.rotation.x = 0.0
			s["state"] = "forage"
			s["t"] = 1.0


# --- ducks ------------------------------------------------------------------------------------

func _ducks() -> void:
	# the pond: a mother with four ducklings, a drake and a white duck
	var mother := _duck(W + "mallard.glb", 0.42, Terrain.POND, 6.0, null, 0)
	for k in 4:
		_duck(W + "duckling.glb", 0.18, Terrain.POND, 6.0, mother, k + 1)
	_duck(W + "mallard.glb", 0.44, Terrain.POND, 6.0, null, 0)
	_duck(W + "duck2.glb", 0.4, Terrain.POND, 6.0, null, 0)
	# the lake: another family and a pair
	var lm := _duck(W + "mallard.glb", 0.42, Terrain.LAKE, Terrain.LAKE_R - 5.0, null, 0)
	for k in 3:
		_duck(W + "duckling.glb", 0.18, Terrain.LAKE, Terrain.LAKE_R - 5.0, lm, k + 1)
	_duck(W + "duck2.glb", 0.4, Terrain.LAKE, Terrain.LAKE_R - 5.0, null, 0)
	_duck(W + "mallard.glb", 0.44, Terrain.LAKE, Terrain.LAKE_R - 5.0, null, 0)
	for dk in ducks:
		if dk["leader"] != null:
			continue
		var root: Node3D = dk["root"]
		life.interact.register({"name": "duck", "reach": 4.5, "priority": 0.2, "sparkle": false, "icon": W + "mallard.glb",
			"pos": func() -> Vector3: return root.global_position,
			"label": func() -> String: return "Feed the ducks" if explorer.carrying == "seed" else "Say hello to the duck",
			"act": func() -> String:
				_sound_at(_quack, root.global_position, -2.0, randf_range(0.95, 1.1))
				if explorer.carrying == "seed":
					explorer.act("interact-left", 1.0)
					var at: Vector3 = explorer.global_position + explorer.forward() * 2.5
					_feed_ducks(Vector2(at.x, at.z))
					explorer.drop()
					_say("Here, ducks!")
					return "fed duck"
				dk["state"] = "shake"
				dk["t"] = 0.8
				_say("Quack, quack!")
				return "said hello to the duck"})


func _duck(path: String, h: float, water: Vector2, radius: float, leader: Variant, offset: int) -> Node3D:
	var c := _creature(path, h)
	var root: Node3D = c[0]
	var a := randf() * TAU
	var p: Vector2 = water + Vector2(cos(a), sin(a)) * randf_range(1.0, radius * 0.8)
	root.position = Vector3(p.x, 0.02, p.y)
	ducks.append({"root": root, "body": c[1], "water": water, "radius": radius, "leader": leader, "offset": offset,
		"target": p, "state": "swim", "t": randf_range(1.0, 5.0), "ripple": 0.0, "speed": randf_range(0.6, 0.9)})
	return root


## Seeds scattered on the water: every duck races to the spot.
func _feed_ducks(at: Vector2) -> void:
	_seed_spot = at
	_seed_t = 8.0
	for k in 14:
		life.fx.ripple(Vector3(at.x + randf_range(-0.8, 0.8), 0.04, at.y + randf_range(-0.8, 0.8)))


func _duck_tick(dk: Dictionary, delta: float, here: Vector2) -> void:
	var root: Node3D = dk["root"]
	var body: Node3D = dk["body"]
	var water: Vector2 = dk["water"]
	var radius: float = dk["radius"]
	var p := Vector2(root.position.x, root.position.z)
	var d := p.distance_to(here)
	_spotted("duck", d)
	dk["t"] -= delta
	var want: Vector2 = dk["target"]
	var speed: float = dk["speed"]
	if dk["leader"] != null:
		# ducklings follow in a line behind their mother
		var lead: Node3D = dk["leader"]
		var back := -Vector2(sin(lead.rotation.y), cos(lead.rotation.y))
		want = Vector2(lead.position.x, lead.position.z) + back * (0.42 * float(dk["offset"]))
		speed = 2.4
		if (lead.position.y > 0.2) != (root.position.y > 0.2):
			want = Vector2(lead.position.x, lead.position.z) + back * (0.42 * float(dk["offset"]))
	else:
		var fed := _seed_t > 0.0 and _seed_spot.distance_to(water) < radius + 4.0
		if fed:
			want = _seed_spot + Vector2.from_angle(float(dk["offset"]) + _t) * 0.6
			speed = 2.2
			if p.distance_to(_seed_spot) < 1.2 and dk["state"] == "swim" and randf() < delta * 1.5:
				dk["state"] = "dabble"
				dk["t"] = 1.0
		match dk["state"]:
			"swim":
				body.rotation.x = lerpf(body.rotation.x, 0.0, 1.0 - exp(-delta * 6.0))
				body.rotation.z = 0.0
				if p.distance_to(want) < 0.6 or dk["t"] <= 0.0:
					var a := randf() * TAU
					dk["target"] = water + Vector2(cos(a), sin(a)) * randf_range(0.0, radius)
					dk["t"] = randf_range(3.0, 8.0)
					var pick := randf()
					if pick < 0.25:
						dk["state"] = "dabble"
						dk["t"] = randf_range(1.2, 2.2)
					elif pick < 0.35:
						dk["state"] = "shake"
						dk["t"] = 0.8
					elif pick < 0.45:
						_sound_at(_quack, root.global_position, -8.0, randf_range(0.9, 1.15))
					elif pick < 0.5 and radius < 8.0:
						# waddle up onto the bank for a rest
						var bank := water + (p - water).normalized() * 10.6
						dk["target"] = bank
						dk["state"] = "to_bank"
						dk["t"] = 20.0
				# paddle away if she comes running along the bank
				if d < 3.5 and _her_speed() > 2.0:
					dk["target"] = water + (p - here).normalized() * radius * 0.8
			"dabble":
				# tail up, head under
				body.rotation.x = lerpf(body.rotation.x, 1.6, 1.0 - exp(-delta * 8.0))
				speed = 0.0
				if dk["t"] <= 0.0:
					dk["state"] = "swim"
					life.fx.ripple(Vector3(p.x, 0.04, p.y))
			"shake":
				body.rotation.z = sin(_t * 40.0) * 0.25
				body.rotation.x = -0.2
				speed = 0.0
				if dk["t"] <= 0.0:
					body.rotation.z = 0.0
					dk["state"] = "swim"
			"to_bank":
				if p.distance_to(want) < 0.4 or dk["t"] <= 0.0:
					dk["state"] = "rest"
					dk["t"] = randf_range(8.0, 15.0)
			"rest":
				speed = 0.0
				body.rotation.x = lerpf(body.rotation.x, 0.15, 1.0 - exp(-delta * 4.0))
				if dk["t"] <= 0.0 or d < 3.0:
					dk["state"] = "swim"
					dk["target"] = water + (p - water).normalized() * -2.0
					dk["t"] = 6.0
	var step := (want - p)
	if step.length() > 0.02 and speed > 0.0:
		var mv := step.normalized() * minf(step.length(), speed * delta)
		var next := p + mv
		root.rotation.y = lerp_angle(root.rotation.y, atan2(mv.x, mv.y), 1.0 - exp(-delta * 6.0))
		var on_land := next.distance_to(water) > radius + 2.5 and Terrain.height(next.x, next.y) > 0.05
		var y := _ground_y(next) if on_land else 0.02 + sin(_t * 2.0 + float(dk["offset"])) * 0.015
		root.position = Vector3(next.x, y, next.y)
		if on_land:
			body.rotation.z = sin(_t * 12.0) * 0.12  # waddle
		else:
			dk["ripple"] -= delta
			if dk["ripple"] <= 0.0 and mv.length() > speed * delta * 0.5:
				dk["ripple"] = 0.7
				life.fx.ripple(Vector3(p.x, 0.04, p.y))


# --- gulls and flocks -------------------------------------------------------------------------

func _gulls() -> void:
	for k in 3:
		var n := Models.spawn(self, W + "seagull.glb", 0.5, 0.0)
		if n == null:
			return
		gulls.append({"node": n, "centre": Terrain.LAKE + Vector2(-6 + k * 4, 4), "radius": randf_range(10.0, 18.0),
			"height": randf_range(12.0, 18.0), "phase": randf() * TAU, "speed": randf_range(0.18, 0.28) * (1 if k % 2 else -1)})


func _new_flock() -> void:
	for f in flock:
		(f["node"] as Node3D).queue_free()
	flock.clear()
	var a := randf() * TAU
	var start := Terrain.CENTRE + Vector2(cos(a), sin(a)) * 170.0
	var end := Terrain.CENTRE - Vector2(cos(a), sin(a)) * 170.0 + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	var h := randf_range(28.0, 40.0)
	var dir := (end - start).normalized()
	var side := Vector2(-dir.y, dir.x)
	for k in randi_range(4, 7):
		var n := Models.spawn(self, W + "seagull.glb", 0.5, 0.0)
		if n == null:
			return
		var row := (k + 1) / 2
		var s := 1 if k % 2 else -1
		var off := -dir * row * 2.2 + side * s * row * 2.0
		flock.append({"node": n, "start": start + off, "end": end + off, "h": h + randf_range(-0.6, 0.6), "t": 0.0, "len": start.distance_to(end) / 9.0})


func _process(delta: float) -> void:
	_t += delta
	if life.trip and life.trip.active:
		return
	_seed_t -= delta
	var ex: Vector3 = explorer.global_position
	var here := Vector2(ex.x, ex.z)
	var cam := get_viewport().get_camera_3d()
	var cp := Vector2(cam.global_position.x, cam.global_position.z) if cam else here
	for r in rabbits:
		var root: Node3D = r["root"]
		if cp.distance_to(Vector2(root.position.x, root.position.z)) < 90.0:
			_rabbit_tick(r, delta, here)
	for s in squirrels:
		var root: Node3D = s["root"]
		if cp.distance_to(Vector2(root.position.x, root.position.z)) < 90.0:
			_squirrel_tick(s, delta, here)
	for dk in ducks:
		var root: Node3D = dk["root"]
		if cp.distance_to(Vector2(root.position.x, root.position.z)) < 110.0:
			_duck_tick(dk, delta, here)
	for g in gulls:
		var n: Node3D = g["node"]
		g["phase"] += float(g["speed"]) * delta
		var a: float = g["phase"]
		var c: Vector2 = g["centre"]
		var r: float = g["radius"]
		n.position = Vector3(c.x + cos(a) * r, float(g["height"]) + sin(a * 2.0) * 1.5, c.y + sin(a) * r)
		var tangent := Vector3(-sin(a), 0, cos(a)) * signf(g["speed"])
		n.rotation = Vector3(0, atan2(tangent.x, tangent.z), -signf(g["speed"]) * 0.3)
	_flock_t -= delta
	if _flock_t <= 0.0:
		_flock_t = randf_range(35.0, 70.0)
		_new_flock()
	for f in flock:
		var n: Node3D = f["node"]
		f["t"] += delta
		var k: float = f["t"] / float(f["len"])
		var p: Vector2 = (f["start"] as Vector2).lerp(f["end"], k)
		var dd: Vector2 = (f["end"] as Vector2) - (f["start"] as Vector2)
		n.position = Vector3(p.x, float(f["h"]) + sin(f["t"] * 1.3) * 0.4, p.y)
		n.rotation = Vector3(0, atan2(dd.x, dd.y), sin(f["t"] * 2.0) * 0.08)
		n.visible = k < 1.0


# --- sounds, made once in code ----------------------------------------------------------------

func _wav(s: PackedFloat32Array, level: float) -> AudioStreamWAV:
	var peak := 0.0001
	for x in s:
		peak = maxf(peak, absf(x))
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i] / peak * level, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## "Quack": a nasal buzz that falls in pitch, twice.
func _make_quack() -> AudioStreamWAV:
	var n := int(RATE * 0.55)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var x := float(i) / RATE
		var env := 0.0
		for q in 2:
			var t0 := q * 0.26
			if x > t0 and x < t0 + 0.2:
				var u := (x - t0) / 0.2
				env = sin(PI * minf(u * 3.0, 1.0)) * (1.0 - u * 0.6)
		var f := lerpf(620.0, 420.0, fmod(x, 0.26) / 0.26)
		ph += TAU * f / RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		s[i] = env * (saw * 0.6 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0) * 0.2)
	return _wav(s, 0.6)


## A squirrel's chitter: a fast run of tiny high clicks.
func _make_chitter() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var t := 0.0
	while t < 0.55:
		var a := int(t * RATE)
		var f := rng.randf_range(2600.0, 3600.0)
		for k in int(0.018 * RATE):
			if a + k < n:
				var x := float(k) / RATE
				s[a + k] += sin(TAU * f * x) * exp(-x * 260.0)
		t += rng.randf_range(0.03, 0.05)
	return _wav(s, 0.5)


## A rabbit's warning thump on the ground.
func _make_thump() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var x := float(i) / RATE
		s[i] = sin(TAU * 70.0 * x) * exp(-x * 25.0) + sin(TAU * 140.0 * x) * exp(-x * 45.0) * 0.4
	return _wav(s, 0.7)
