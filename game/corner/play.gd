extends Node
## Things to do on the island, beyond the animals:
##  - toys everywhere that answer her button with a word and a little action (a pumpkin, the tent,
##    a letter in the mailbox, signposts that say where they lead);
##  - activities: the swing, the slide, the merry-go-round, the spring horse, the seesaw, rowing the
##    boat round the pond, fishing off the jetty, sandcastles, flying the kite, the telescope, picking
##    a carrot in the garden (and the rocket, in space/trip.gd);
##  - the adventures board by the cottage: three picture cards to do, each done one earns a souvenir
##    for the shelf;
##  - for the parent: the photo button (F12 / right stick click), hop (H / left stick click),
##    stroll-for-me (hold T / d-pad up: she walks to the next place by herself) and the picture map
##    (M / d-pad down).

const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const Places := preload("res://corner/places.gd")
const Places2 := preload("res://corner/places2.gd")
const FK := "res://assets/kits/food/"
const PG := "res://assets/kits/playground/"
const A := "res://assets/animals/quaternius/"

## [id, words on the card, picture model, what counts (any part of an event)]
const ADVENTURES := [
	["horse", "Feed the horse", A + "horse.glb", ["fed horse"]],
	["cow", "Give the cow some hay", A + "cow.glb", ["fed cow"]],
	["cat", "Stroke the cat", A + "cat.glb", ["stroked cat"]],
	["dog", "Pat the dog", A + "dog.glb", ["stroked dog", "threw the ball"]],
	["pig", "Feed the pig", A + "pig.fbx", ["fed pig"]],
	["chick", "Find the little chick", A + "hen.glb", ["found the chick"]],
	["sheep", "Say hello to a sheep", A + "lamb.glb", ["stroked sheep", "fed sheep"]],
	["deer", "Say hello to the deer", A + "deer.glb", ["stroked deer", "fed deer"]],
	["pump", "Pump some water", "res://assets/kits/survival/bucket.glb", ["pumped water"]],
	["swing", "Go on the swing", PG + "swing_A_large.gltf", ["swing"]],
	["slide", "Go down the slide", PG + "slide_A.gltf", ["slide"]],
	["boat", "Row the boat", "res://assets/kits/water/boat-row-small.glb", ["boat"]],
	["fish", "Catch a fish", "res://assets/kits/survival/fish.glb", ["fish"]],
	["sandcastle", "Build a sandcastle", PG + "sandcastle_A.gltf", ["sandcastle"]],
	["carrot", "Pick a carrot", FK + "carrot.glb", ["carrot"]],
	["kite", "Fly the kite", "res://assets/kits/nature/flower_redA.glb", ["kite"]],
	["telescope", "Look at the Moon", "res://assets/kits/extra/telescope.glb", ["telescope"]],
	["lighthouse", "Visit the lighthouse", "res://assets/kits/extra/lighthouse.glb", ["visit:lighthouse"]],
	["pumpkin", "Find the pumpkins", FK + "pumpkin.glb", ["toy:pumpkin"]],
	["moon", "Fly to the Moon", "res://assets/kits/space/rocket_topA.glb", ["moon"]],
]

## Places she can stroll to, and where she says hello to them.
const PLACES := [
	["home", "Home", Terrain.START], ["pond", "The pond", Vector2(40.5, 21.0)],
	["farm", "The farm", Vector2(0.0, 4.0)], ["windmill", "The windmill", Terrain.HILL + Vector2(0.5, 6.0)],
	["orchard", "The orchard", Terrain.ORCHARD + Vector2(-2.0, 5.0)], ["wood", "The wood", Terrain.OAK + Vector2(-2.0, 2.0)],
	["lighthouse", "The lighthouse", Terrain.LIGHTHOUSE + Vector2(-4.0, -3.0)], ["rocket", "The rocket", Terrain.ROCKET + Vector2(-4.0, -4.0)],
	["zoo", "The zoo field", Terrain.VISITOR + Vector2(0.0, 7.5)],
]

var corner: Node3D
var life: Node3D
var explorer: CharacterBody3D
var save: RefCounted
# riding things (the swing, the boat): she is carried along a path for a while
var riding := false
var _ride_fn: Callable
var _ride_done: Callable
var _ride_t := 0.0
var _ride_len := 0.0
# sandcastles, fishing
var _castles: Array = []
var _fishing := false
# the board, the shelf, the map
var board: Node3D
var _board_cards: Array = []     # Label3D stars on the board
var board_ui: Control
var shelf: Node3D
var map_ui: Control
var _map_dot: Control
var _ui := CanvasLayer.new()
var _flash := ColorRect.new()
# stroll-for-me
var _stroll_route := PackedVector2Array()
var _stroll_i := 0
var _stroll_dest := -1
var _strolling := false
var _place_said := {}
var _near_t := 0.0
var _icons := {}


func setup(c: Node3D) -> void:
	corner = c
	life = c.life
	explorer = c.explorer
	save = life.save
	if not save.data.has("adventures"):
		save.data["adventures"] = {"current": [], "done": {}}
	_ui.layer = 6
	add_child(_ui)
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_flash)
	for t in corner.get_meta("toys", []):
		_register_toy(t)
	_activities()
	_more_things()
	_build_board()
	_build_shelf()
	life.happened.connect(_on_event)


func say(word: String, delay := 0.0) -> void:
	if life.stickers:
		life.stickers._say_later(word, delay)


func _event(what: String) -> void:
	life.events_said(what)


# --- toys -------------------------------------------------------------------------------------

func _register_toy(t: Dictionary) -> void:
	var n: Node3D = t["node"]
	if n == null or not is_instance_valid(n):
		return
	var kind: String = t["kind"]
	var word: String = t["word"]
	var reach := 2.0
	if kind in ["swing", "slide", "spin", "telescope", "seesaw"]:
		reach = 2.8
	life.interact.register({"name": "toy:" + word, "reach": reach, "priority": 0.3, "sparkle_height": 1.2,
		"label": _toy_label(word, kind), "icon": String(n.get_meta("file_path", "")),
		"pos": func() -> Vector3: return n.global_position + Vector3.UP * 0.4,
		"when": func() -> bool: return not riding,
		"act": func() -> String: return _press_toy(n, word, kind)})


func _toy_label(word: String, kind: String) -> String:
	match kind:
		"swing": return "Go on the swing"
		"slide": return "Go down the slide"
		"rock": return "Ride the horsey"
		"seesaw": return "Push the seesaw"
		"kite": return "Fly the kite"
		"telescope": return "Look at the Moon"
		"fire": return "Warm your hands"
		"mail": return "Open the mailbox"
		"rover": return "Drive the rover"
		"sign": return "Where does it go?"
		"pumpkin": return "Count the pumpkins"
		"mushroom": return "Boop the mushrooms"
		"wiggle": return "Wiggle the " + word.to_lower()
		"spin":
			return "Ride the merry-go-round" if word == "Round and round" else "Spin the dish"
	return "Bounce the " + word.to_lower()


func _press_toy(n: Node3D, word: String, kind: String) -> String:
	match kind:
		"swing":
			_swing(n)
			return "swing"
		"slide":
			_slide(n)
			return "slide"
		"spin":
			if word == "Round and round":
				_merry(n)
				return "merry-go-round"
			var tw := n.create_tween()
			tw.tween_property(n, "rotation:y", n.rotation.y + TAU, 2.0).set_trans(Tween.TRANS_SINE)
			life.sound.play_flat(life.sound.chime, -10.0)
		"rock":
			_spring_horse(n)
			return "horsey"
		"seesaw":
			var tw := n.create_tween()
			for k in 4:
				tw.tween_property(n, "rotation:z", 0.22, 0.5).set_trans(Tween.TRANS_SINE)
				tw.tween_property(n, "rotation:z", -0.22, 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(n, "rotation:z", 0.0, 0.4)
		"kite":
			_kite()
			return "kite"
		"telescope":
			_telescope(n)
			return "telescope"
		"wiggle":
			var tw := n.create_tween()
			for k in 3:
				tw.tween_property(n, "rotation:z", 0.12, 0.12)
				tw.tween_property(n, "rotation:z", -0.12, 0.12)
			tw.tween_property(n, "rotation:z", 0.0, 0.1)
		"fire":
			_burst(n.global_position + Vector3.UP * 0.3, Color(1.0, 0.6, 0.2), 40)
		"mail":
			_letter(n)
		"rover":
			var home := n.position
			var tw := n.create_tween()
			for k in 9:
				var a := k * TAU / 8.0
				tw.tween_property(n, "position", home + Vector3(sin(a) * 1.6, 0, 1.6 - cos(a) * 1.6), 0.45)
			tw.tween_property(n, "position", home, 0.3)
		"sign":
			var icon: Node3D = n.get_child(n.get_child_count() - 1) as Node3D
			if icon:
				icon.create_tween().tween_property(icon, "rotation:y", icon.rotation.y + TAU * 2.0, 1.0)
		_:
			_bounce(n)
	if kind in ["pumpkin", "mushroom", "bounce"]:
		_burst(n.global_position + Vector3.UP * 0.4, Color(1.0, 0.9, 0.4), 18)
	life.sound.play_flat(life.sound.pop, -8.0)
	explorer.act("interact-right", 0.6)
	say(word, 0.15)
	return "toy:" + word.to_lower()


func _bounce(n: Node3D) -> void:
	var s := n.scale
	var tw := n.create_tween()
	tw.tween_property(n, "scale", s * Vector3(1.15, 0.8, 1.15), 0.1)
	tw.tween_property(n, "scale", s * Vector3(0.92, 1.15, 0.92), 0.12)
	tw.tween_property(n, "scale", s, 0.18).set_trans(Tween.TRANS_BACK)


func _burst(at: Vector3, color: Color, count: int) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 50.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = color
	p.process_material = pm
	p.amount = count
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 0.9
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = preload("res://space/rocket.gd")._soft_dot()
	q.material = m
	p.draw_pass_1 = q
	corner.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _letter(mail: Node3D) -> void:
	var l := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.3, 0.02, 0.2)
	l.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.98, 0.92)
	l.material_override = m
	corner.add_child(l)
	l.global_position = mail.global_position + Vector3(0, 1.15, 0)
	var heart := Label3D.new()
	heart.text = "♥"
	heart.font_size = 64
	heart.pixel_size = 0.003
	heart.modulate = Color(0.95, 0.3, 0.35)
	heart.position = Vector3(0, 0.02, 0)
	heart.rotation_degrees.x = -90.0
	l.add_child(heart)
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.2, 0), 0.8).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(l, "rotation:y", TAU * 2.0, 1.6)
	tw.tween_interval(1.2)
	tw.tween_property(l, "scale", Vector3.ZERO, 0.3)
	tw.tween_callback(l.queue_free)


# --- things around the island: apple trees, beehives, benches, flowers, the lighthouse bell ----

func _more_things() -> void:
	var bell: AudioStream = load("res://assets/sounds/kit/impactBell_heavy_000.ogg")
	for n in corner.get_children():
		if not (n is Node3D) or not n.has_meta("file"):
			continue
		var node := n as Node3D
		var f: String = n.get_meta("file")
		if f == "CommonTree_1":
			life.interact.register({"name": "apple tree", "reach": 2.6, "priority": 0.15, "sparkle_height": 2.4,
				"label": "Shake the apple tree", "icon": "res://assets/kits/food/apple.glb",
				"pos": func() -> Vector3: return node.global_position + Vector3.UP * 0.5,
				"when": func() -> bool: return explorer.carrying == "",
				"act": func() -> String: return _shake_tree(node)})
		elif f == "Bench":
			life.interact.register({"name": "bench", "reach": 1.6, "priority": 0.1, "sparkle": false,
				"label": "Sit on the bench", "icon": "",
				"pos": func() -> Vector3: return node.global_position,
				"when": func() -> bool: return not riding,
				"act": func() -> String:
					var p := node.global_position + Vector3.UP * 0.2
					var face := node.global_rotation.y + PI
					ride(5.0, func(_k: float, _s: float) -> void: _place_her(p, face), func() -> void: explorer.global_position = p + Vector3(sin(face), 0, cos(face)) * 0.9)
					say("A little rest.", 0.5)
					return "sat on the bench"})
		elif f.begins_with("flower_"):
			life.interact.register({"name": "flower", "reach": 1.3, "priority": 0.05, "sparkle": false,
				"label": "Smell the flower", "icon": "res://assets/kits/nature/" + f + ".glb",
				"pos": func() -> Vector3: return node.global_position,
				"act": func() -> String:
					_burst(node.global_position + Vector3.UP * 0.4, Color(1.0, 0.6, 0.8), 16)
					explorer.act("interact-right", 0.8)
					say("Mmm, lovely!", 0.3)
					return "smelled a flower"})
	# the beehives at the orchard
	for k in 2:
		var hp := Terrain.ORCHARD + Vector2(10.5, -4.0 + k * 2.4)
		var at := Vector3(hp.x, Terrain.height(hp.x, hp.y), hp.y)
		life.interact.register({"name": "beehive", "reach": 2.0, "priority": 0.2, "sparkle_height": 1.4,
			"label": "Listen to the bees", "icon": "res://assets/kits/food/honey.glb",
			"pos": func() -> Vector3: return at,
			"act": func() -> String:
				_burst(at + Vector3.UP * 1.1, Color(1.0, 0.82, 0.15), 30)
				say("Buzz, buzz!", 0.2)
				return "listened to the bees"})
	# the lighthouse bell
	var l := Terrain.LIGHTHOUSE + Vector2(-3.2, -2.2)
	var lp := Vector3(l.x, Terrain.height(l.x, l.y), l.y)
	life.interact.register({"name": "lighthouse", "reach": 2.4, "priority": 0.2, "sparkle_height": 1.6,
		"label": "Ring the lighthouse bell", "icon": "res://assets/kits/extra/lighthouse.glb",
		"pos": func() -> Vector3: return lp,
		"act": func() -> String:
			life.sound.play_flat(bell, -6.0)
			for m in Places.glows:
				var g := m as StandardMaterial3D
				var was := g.emission_energy_multiplier
				var tw := create_tween()
				tw.tween_property(g, "emission_energy_multiplier", 6.0, 0.2)
				tw.tween_property(g, "emission_energy_multiplier", was, 1.2)
			say("Ding dong!", 0.4)
			return "visit:lighthouse bell"})


func _shake_tree(tree: Node3D) -> String:
	var tw := tree.create_tween()
	for k in 4:
		tw.tween_property(tree, "rotation:z", 0.04, 0.08)
		tw.tween_property(tree, "rotation:z", -0.04, 0.08)
	tw.tween_property(tree, "rotation:z", 0.0, 0.1)
	explorer.act("interact-left", 1.0)
	var apple := Models.spawn(corner, FK + "apple.glb", 0.16, 0.0)
	var from := tree.global_position + Vector3(randf_range(-0.6, 0.6), 2.6, randf_range(-0.6, 0.6))
	apple.global_position = from
	var hand: Vector3 = explorer.global_position + Vector3.UP * 0.5 + explorer.forward() * 0.3
	var fall := apple.create_tween()
	fall.tween_property(apple, "global_position", hand, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(func() -> void:
		apple.queue_free()
		life.take_food("apple"))
	say("An apple!", 0.6)
	return "picked up apple"


# --- rides ------------------------------------------------------------------------------------

## Carries her along fn(k, seconds) for a while; she can't walk meanwhile.
func ride(seconds: float, fn: Callable, done := Callable(), anim := "sit") -> void:
	riding = true
	_ride_t = 0.0
	_ride_len = seconds
	_ride_fn = fn
	_ride_done = done
	explorer.set_physics_process(false)
	explorer.velocity = Vector3.ZERO
	explorer.busy = seconds
	if explorer.player and explorer.player.has_animation(anim):
		explorer.player.play(anim, 0.2)


func _place_her(p: Vector3, facing: float) -> void:
	explorer.global_position = p
	explorer.facing = facing
	explorer.model.rotation.y = facing


func _swing(n: Node3D) -> void:
	var pivot := n.get_meta("pivot", null) as Node3D
	if pivot == null:
		return
	var yaw := n.global_rotation.y
	life.sound.play_flat(life.sound.chime, -10.0)
	say("Wheee!", 1.2)
	ride(8.0, func(k: float, s: float) -> void:
		var env := sin(clampf(k, 0.0, 1.0) * PI)
		pivot.rotation.x = sin(s * 2.2) * 0.62 * env
		var seat := pivot.global_transform * Vector3(0, -1.93, 0)
		_place_her(seat - Vector3(0, 0.12, 0), yaw),
		func() -> void:
			pivot.rotation.x = 0.0
			_place_her(n.global_transform * Vector3(-0.55, 0.05, 1.2), yaw))


func _slide(n: Node3D) -> void:
	var size: Vector3 = n.get_meta("size", Vector3(1.4, 2.0, 3.0))
	var along := Vector3(1, 0, 0) if size.x > size.z else Vector3(0, 0, 1)
	var half := maxf(size.x, size.z) * 0.5
	var c := n.global_position
	var top := c - along * (half * 0.55) + Vector3.UP * size.y * 0.72
	var start := c - along * (half + 0.4)
	var bottom := c + along * (half + 0.2)
	var face := atan2(along.x, along.z)
	say("Wheee!", 1.4)
	ride(3.4, func(k: float, _s: float) -> void:
		var want_anim := "walk" if k < 0.45 else "sit"
		if explorer.player and explorer.player.current_animation != want_anim:
			explorer.player.play(want_anim, 0.15)
		if k < 0.45:
			var u := k / 0.45
			_place_her(start.lerp(top, u), face)
		else:
			var u := (k - 0.45) / 0.55
			var e := u * u
			var p := top.lerp(bottom, e)
			p.y = lerpf(top.y, c.y + 0.1, sin(e * PI * 0.5))
			_place_her(p, face),
		func() -> void:
			explorer.global_position = bottom + Vector3(0, 0.05, 0) + along * 0.4)


func _merry(n: Node3D) -> void:
	var c := n.global_position
	say("Round and round!", 0.3)
	ride(6.0, func(k: float, s: float) -> void:
		var spin := s * 1.6
		n.rotation.y = spin
		var p := c + Vector3(sin(spin) * 0.75, 0.25, cos(spin) * 0.75)
		_place_her(p, spin + PI / 2.0),
		func() -> void:
			explorer.global_position = c + Vector3(1.6, 0.05, 0))


func _spring_horse(n: Node3D) -> void:
	var c := n.global_position
	var yaw := n.global_rotation.y
	say("Giddy up!", 0.3)
	ride(4.5, func(_k: float, s: float) -> void:
		var r := sin(s * 5.0) * 0.25
		n.rotation.x = r
		_place_her(c + Vector3(0, 0.45 + absf(r) * 0.1, 0), yaw),
		func() -> void:
			n.rotation.x = 0.0
			explorer.global_position = c + Vector3(0.9, 0.05, 0.0))


# --- activities: kite, telescope, boat, fishing, sandcastle, garden ---------------------------

func _kite() -> void:
	var kite := corner.get_node_or_null("Kite") as Node3D
	if kite == null:
		return
	if explorer.carrying == "":
		# she takes the string: the kite follows her wherever she walks
		for tw in kite.get_meta("tweens", []):
			(tw as Tween).kill()
		var spool := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.05
		c.height = 0.08
		spool.mesh = c
		spool.material_override = Places.mat(Color(0.95, 0.3, 0.35))
		explorer.carry("kite", spool)
		say("Up, up, up!", 0.2)
		return
	var tw := kite.create_tween()
	tw.tween_property(kite, "position:y", kite.position.y + 7.0, 2.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(kite, "rotation:z", TAU, 2.5)
	tw.tween_interval(1.5)
	tw.tween_property(kite, "position:y", kite.position.y, 2.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(kite, "rotation:z", 0.0, 2.5)


## She lets the kite go home to its stake on the hill.
func drop_kite() -> String:
	var kite := corner.get_node_or_null("Kite") as Node3D
	explorer.drop()
	if kite:
		var home: Vector3 = kite.get_meta("home")
		var stake: Vector3 = kite.get_meta("anchor_home", kite.get_meta("anchor"))
		kite.set_meta("anchor", stake)
		var back := kite.create_tween()
		back.tween_property(kite, "position", home, 2.5).set_trans(Tween.TRANS_SINE)
		back.tween_callback(func() -> void:
			var tw := kite.create_tween().set_loops()
			tw.tween_property(kite, "position", home + Vector3(1.5, 1.2, 0.8), 3.2).set_trans(Tween.TRANS_SINE)
			tw.tween_property(kite, "position", home + Vector3(-1.0, -0.6, -0.5), 3.8).set_trans(Tween.TRANS_SINE)
			kite.set_meta("tweens", [tw]))
	say("Bye bye, kite!", 0.2)
	return "kite home"


func _kite_follow(delta: float) -> void:
	if explorer.carrying != "kite":
		return
	var kite := corner.get_node_or_null("Kite") as Node3D
	if kite == null:
		return
	if not kite.has_meta("anchor_home"):
		kite.set_meta("anchor_home", kite.get_meta("anchor"))
	var here := explorer.global_position
	var back: Vector3 = -explorer.forward()
	var t := Time.get_ticks_msec() / 1000.0
	var side := Vector3(-back.z, 0, back.x)
	var want: Vector3 = here - back * 9.0 + side * 2.5 + Vector3(sin(t * 0.7) * 1.2, 3.6 + sin(t * 1.1) * 0.6, cos(t * 0.5) * 0.8)
	kite.position = kite.position.lerp(want, 1.0 - exp(-delta * 1.2))
	kite.rotation.z = sin(t * 1.3) * 0.25
	kite.set_meta("anchor", here + Vector3(0, 0.6, 0) + explorer.forward() * 0.25)


## Looking through the telescope: the eyepiece shows its own night sky, full of stars, with the
## real Moon big in the middle (high up, so no hill or tree is ever in the way).
func _telescope(n: Node3D) -> void:
	var cam := Camera3D.new()
	cam.fov = 9.0
	cam.near = 1.0
	cam.far = 3000.0
	var env := Environment.new()
	var sky := Sky.new()
	var stars := ShaderMaterial.new()
	stars.shader = preload("res://space/starfield.gdshader")
	stars.set_shader_parameter("milky", load("res://assets/space/8k_stars_milky_way.jpg"))
	stars.set_shader_parameter("milky_energy", 1.1)
	stars.set_shader_parameter("star_energy", 1.4)
	stars.set_shader_parameter("sun_dir", Vector3(0, -1, 0))
	sky.sky_material = stars
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.5
	cam.environment = env
	corner.add_child(cam)
	cam.global_position = n.global_position + Vector3.UP * 1.5
	var dir := Vector3(0.35, 0.75, -0.55).normalized()
	var moon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 16.0
	sphere.height = 32.0
	sphere.radial_segments = 96
	sphere.rings = 48
	moon.mesh = sphere
	var mm := ShaderMaterial.new()
	mm.shader = preload("res://space/moon_body.gdshader")
	mm.set_shader_parameter("surface", load("res://assets/space/8k_moon.jpg"))
	mm.set_shader_parameter("sun_dir", (Vector3(1.0, 0.2, 0.3) - dir * 0.6).normalized())
	moon.material_override = mm
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corner.add_child(moon)
	moon.global_position = cam.global_position + dir * 260.0
	moon.rotation = Vector3(0.2, 2.6, 0.0)
	cam.look_at(moon.global_position, Vector3.UP)
	cam.make_current()
	var ring := ColorRect.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;
void fragment() { vec2 p = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0); float r = length(p); COLOR = vec4(0.02, 0.02, 0.03, smoothstep(0.4, 0.43, r)); }"
	sm.shader = sh
	ring.material = sm
	_ui.add_child(ring)
	explorer.busy = 6.0
	say("Look, the Moon!", 0.5)
	# a slow drift, as if she is holding the telescope
	var tw := cam.create_tween()
	tw.tween_property(cam, "fov", 7.0, 5.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(5.5).timeout
	ring.queue_free()
	moon.queue_free()
	cam.queue_free()
	corner.follow.cam.make_current()


func _activities() -> void:
	# the rowing boat
	var boat := corner.get_meta("row_boat", null) as Node3D
	if boat:
		var dock := boat.position
		var dock_yaw := boat.rotation.y
		life.interact.register({"name": "boat", "reach": 2.6, "priority": 0.4, "sparkle_height": 0.9, "label": "Row the boat", "icon": "res://assets/kits/water/boat-row-small.glb",
			"pos": func() -> Vector3: return boat.global_position + Vector3.UP * 0.4,
			"when": func() -> bool: return not riding,
			"act": func() -> String:
				_row(boat, dock, dock_yaw)
				return "boat"})
	# fishing off the end of the jetty
	var p := Terrain.POND
	var jetty_end := Vector3(p.x + 2.5, 0.62, p.y + 5.4)
	life.interact.register({"name": "fishing", "reach": 1.8, "priority": 0.35, "sparkle_height": 0.8, "label": "Go fishing", "icon": "res://assets/kits/survival/fish.glb",
		"pos": func() -> Vector3: return jetty_end,
		"when": func() -> bool: return not riding and not _fishing,
		"act": func() -> String:
			_fish(jetty_end)
			return "fishing"})
	# sandcastles on the beach
	if corner.has_meta("sandcastle_spot"):
		var s: Vector2 = corner.get_meta("sandcastle_spot")
		life.interact.register({"name": "sandcastle", "reach": 2.6, "priority": 0.35, "sparkle_height": 0.8, "label": "Build a sandcastle", "icon": PG + "sandcastle_A.gltf",
			"pos": func() -> Vector3: return Vector3(s.x, Terrain.height(s.x, s.y) + 0.3, s.y),
			"when": func() -> bool: return not riding,
			"act": func() -> String:
				_sandcastle(s)
				return "sandcastle"})
	# the vegetable beds: pick a carrot to feed the animals
	var bed := Terrain.COTTAGE + Vector2(-6.8, 0.6)
	life.interact.register({"name": "garden", "reach": 3.4, "priority": 0.2, "sparkle_height": 0.6, "label": "Pull up a carrot", "icon": FK + "carrot.glb",
		"pos": func() -> Vector3: return Vector3(bed.x, Terrain.height(bed.x, bed.y) + 0.3, bed.y),
		"when": func() -> bool: return explorer.carrying == "",
		"act": func() -> String:
			var carrot := Models.spawn(corner, FK + "carrot.glb", 0.2, 0.0)
			corner.remove_child(carrot)
			explorer.carry("carrot", carrot)
			say("A carrot!", 0.3)
			_burst(Vector3(bed.x, Terrain.height(bed.x, bed.y) + 0.2, bed.y), Color(0.55, 0.4, 0.25), 20)
			return "picked a carrot"})


func _row(boat: Node3D, dock: Vector3, dock_yaw: float) -> void:
	var p := Terrain.POND
	var centre := Vector3(p.x, 0.0, p.y)
	var start_a := atan2(dock.z - centre.z, dock.x - centre.x)
	var r := Vector2(dock.x - centre.x, dock.z - centre.z).length()
	say("Row, row, row your boat!", 0.4)
	ride(16.0, func(k: float, s: float) -> void:
		var a := start_a + k * TAU
		var rr := lerpf(r, 5.2, sin(k * PI))
		var pos := centre + Vector3(cos(a) * rr, 0.03 + sin(s * 1.7) * 0.03, sin(a) * rr)
		boat.position = pos
		var tangent := Vector3(-sin(a), 0, cos(a))
		boat.rotation.y = atan2(tangent.x, tangent.z) + PI / 2.0
		boat.rotation.z = sin(s * 1.3) * 0.04
		_place_her(pos + Vector3(0, 0.12, 0), atan2(tangent.x, tangent.z)),
		func() -> void:
			boat.position = dock
			boat.rotation = Vector3(0, dock_yaw, 0)
			explorer.global_position = Vector3(p.x + 2.5, 0.62, p.y + 6.4))


func _fish(at: Vector3) -> void:
	_fishing = true
	explorer.busy = 5.5
	var fwd := Vector3(0, 0, -1)
	explorer.face(at + fwd)
	var rod := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.01
	c.bottom_radius = 0.02
	c.height = 1.4
	rod.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.33, 0.2)
	rod.material_override = m
	explorer.add_child(rod)
	rod.position = Vector3(0.15, 0.55, 0) + explorer.forward() * 0.4
	rod.rotation = Vector3(-0.9, explorer.facing, 0)
	var bob := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.05
	sp.height = 0.1
	bob.mesh = sp
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.95, 0.25, 0.2)
	bob.material_override = bm
	corner.add_child(bob)
	var spot: Vector3 = explorer.global_position + explorer.forward() * 2.2
	bob.global_position = Vector3(spot.x, 0.02, spot.z)
	var bt := bob.create_tween().set_loops(6)
	bt.tween_property(bob, "position:y", -0.03, 0.3)
	bt.tween_property(bob, "position:y", 0.03, 0.3)
	say("Fishing!", 0.2)
	await get_tree().create_timer(2.6).timeout
	var kind: String = ["Fish1", "Fish2", "Fish3"][randi() % 3]
	var fish := Models.spawn(corner, "res://assets/kits/fish/" + kind + ".fbx", 0.3, 0.0)
	if fish:
		fish.global_position = bob.global_position
		var tw := fish.create_tween()
		var top: Vector3 = bob.global_position + Vector3(0, 1.4, 0) - explorer.forward() * 0.8
		tw.tween_property(fish, "global_position", top, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(fish, "rotation:z", TAU, 1.0)
		tw.tween_property(fish, "global_position", bob.global_position + explorer.forward() * 0.6, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(fish.queue_free)
	_burst(bob.global_position, Color(0.7, 0.85, 1.0), 30)
	life.sound.play_flat(life.sound.chime, -6.0)
	say("A fish!", 0.3)
	_event("fish")
	if life.stickers:
		life.stickers.earn("fish")
	await get_tree().create_timer(2.0).timeout
	rod.queue_free()
	bob.queue_free()
	_fishing = false


func _sandcastle(s: Vector2) -> void:
	var off := Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	var q := s + off
	var kind: String = ["sandcastle_A", "sandcastle_B", "sandcastle_C"][_castles.size() % 3]
	var c := Models.spawn(corner, PG + kind + ".gltf", randf_range(0.4, 0.7), randf() * 360.0)
	if c == null:
		return
	c.position = Vector3(q.x, Terrain.height(q.x, q.y) - 0.03, q.y)
	c.scale = Vector3(1, 0.01, 1)
	c.create_tween().tween_property(c, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)
	_castles.append(c)
	if _castles.size() > 6:
		var old: Node3D = _castles.pop_front()
		old.create_tween().tween_property(old, "scale", Vector3(1, 0.01, 1), 0.6)
		get_tree().create_timer(0.7).timeout.connect(old.queue_free)
	explorer.act("interact-left", 0.9)
	_burst(c.position + Vector3.UP * 0.3, Color(0.95, 0.85, 0.6), 24)
	say("Sandcastle!", 0.2)


# --- the photo button, hop, stroll-for-me, the picture map ------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if life.trip and life.trip.active and not (event is InputEventKey and (event as InputEventKey).keycode == KEY_F12):
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.keycode:
			KEY_F12:
				photo()
			KEY_H:
				hop()
			KEY_M:
				toggle_map()
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed and pad.device == 0:
		match pad.button_index:
			JOY_BUTTON_RIGHT_STICK:
				photo()
			JOY_BUTTON_LEFT_STICK:
				hop()
			JOY_BUTTON_DPAD_DOWN:
				if not life.stickers.is_open:
					toggle_map()


## Saves what's on screen to Pictures\Toddler Island, with a camera flash.
func photo() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("Toddler Island")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", " ")
	img.save_png(dir.path_join("island %s.png" % stamp))
	_flash.color.a = 0.9
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	life.sound.play_flat(life.sound.pop, -4.0)


func hop() -> void:
	if explorer.is_on_floor() and explorer.is_physics_processing():
		explorer.velocity.y = 5.2
		life.sound.play_flat(life.sound.pop, -12.0)


func _process(delta: float) -> void:
	if riding:
		_ride_t += delta
		var k := clampf(_ride_t / _ride_len, 0.0, 1.0)
		_ride_fn.call(k, _ride_t)
		if k >= 1.0:
			riding = false
			explorer.set_physics_process(true)
			explorer.busy = 0.0
			if _ride_done.is_valid():
				_ride_done.call()
	_stroll()
	_kite_follow(delta)
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = 0.5
		_check_places()
	if map_ui and map_ui.visible:
		_update_map_dot()


func _stroll_held() -> bool:
	return Input.is_key_pressed(KEY_T) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)


func _stroll() -> void:
	var held: bool = _stroll_held() and not riding and not (life.trip and life.trip.active) and not life.stickers.is_open
	if held and not _strolling:
		_strolling = true
		var here := Vector2(explorer.global_position.x, explorer.global_position.z)
		# the next place along, not the one she is at
		var best := 0
		var best_d := INF
		for i in PLACES.size():
			var d := here.distance_to(PLACES[i][2])
			if d < best_d:
				best_d = d
				best = i
		_stroll_dest = (best + 1) % PLACES.size() if best_d < 12.0 else best
		_stroll_route = life.paths.route(here, PLACES[_stroll_dest][2])
		_stroll_i = 0
		say("Let's go to " + String(PLACES[_stroll_dest][1]).to_lower() + "!", 0.0)
	elif not held and _strolling:
		_strolling = false
		explorer.auto_input = Vector2.ZERO
	if not _strolling:
		return
	var here := Vector2(explorer.global_position.x, explorer.global_position.z)
	while _stroll_i < _stroll_route.size() and here.distance_to(_stroll_route[_stroll_i]) < 0.8:
		_stroll_i += 1
	if _stroll_i >= _stroll_route.size():
		explorer.auto_input = Vector2.ZERO
		return
	var d := (_stroll_route[_stroll_i] - here).normalized()
	var v := Basis(Vector3.UP, -explorer.camera_yaw) * Vector3(d.x, 0, d.y)
	explorer.auto_input = Vector2(v.x, -v.z)


## Says a place's name when she arrives there (once in a while), and tells the adventures.
func _check_places() -> void:
	var here := Vector2(explorer.global_position.x, explorer.global_position.z)
	var now := Time.get_ticks_msec() / 1000.0
	for pl in PLACES:
		if here.distance_to(pl[2]) < 6.0:
			if now - float(_place_said.get(pl[0], -999.0)) > 120.0:
				_place_said[pl[0]] = now
				if now > 5.0:
					say(pl[1], 0.0)
				_event("visit:" + String(pl[0]))


func toggle_map() -> void:
	if map_ui == null:
		_build_map()
	map_ui.visible = not map_ui.visible
	if map_ui.visible:
		_update_map_dot()
		say("The map!", 0.0)


const MAP_PX := 820.0


func _map_pos(p: Vector2) -> Vector2:
	return (p / Terrain.SIZE + Vector2(0.5, 0.5)) * MAP_PX


func _build_map() -> void:
	var res := 220
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	for j in res:
		for i in res:
			var x := (i + 0.5) / res * Terrain.SIZE - Terrain.SIZE * 0.5
			var z := (j + 0.5) / res * Terrain.SIZE - Terrain.SIZE * 0.5
			var h := Terrain.height(x, z)
			var col: Color
			if h < 0.0:
				col = Color(0.42, 0.68, 0.9).lerp(Color(0.25, 0.5, 0.8), clampf(-h / 2.5, 0.0, 1.0))
			elif Terrain.path_distance(x, z) < 1.4:
				col = Color(0.8, 0.66, 0.46)
			elif Terrain.is_sand(x, z) > 0.6:
				col = Color(0.95, 0.88, 0.66)
			else:
				col = Color(0.52, 0.76, 0.4).lerp(Color(0.36, 0.6, 0.3), clampf(h / 10.0, 0.0, 1.0))
			img.set_pixel(i, j, col)
	map_ui = Control.new()
	map_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ui.visible = false
	_ui.add_child(map_ui)
	var back := ColorRect.new()
	back.color = Color(0.98, 0.94, 0.84, 0.96)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ui.add_child(back)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.position = Vector2(-MAP_PX * 0.5, -MAP_PX * 0.5)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ui.add_child(holder)
	var pic := TextureRect.new()
	pic.texture = ImageTexture.create_from_image(img)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.size = Vector2(MAP_PX, MAP_PX)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	holder.add_child(pic)
	for pl in PLACES:
		var lab := Label.new()
		lab.text = pl[1]
		lab.add_theme_font_size_override("font_size", 26)
		lab.add_theme_color_override("font_color", Color(0.25, 0.2, 0.15))
		lab.add_theme_color_override("font_outline_color", Color(1, 1, 1))
		lab.add_theme_constant_override("outline_size", 8)
		lab.position = _map_pos(pl[2]) + Vector2(-60, -44)
		holder.add_child(lab)
		var dot := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.85, 0.3)
		sb.set_corner_radius_all(10)
		dot.add_theme_stylebox_override("panel", sb)
		dot.size = Vector2(20, 20)
		dot.position = _map_pos(pl[2]) - Vector2(10, 10)
		holder.add_child(dot)
	_map_dot = Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.95, 0.3, 0.35)
	ds.border_color = Color(1, 1, 1)
	ds.set_border_width_all(4)
	ds.set_corner_radius_all(18)
	_map_dot.add_theme_stylebox_override("panel", ds)
	_map_dot.size = Vector2(36, 36)
	holder.add_child(_map_dot)
	var pulse := _map_dot.create_tween().set_loops()
	pulse.tween_property(_map_dot, "modulate:a", 0.5, 0.5)
	pulse.tween_property(_map_dot, "modulate:a", 1.0, 0.5)


func _update_map_dot() -> void:
	var here := Vector2(explorer.global_position.x, explorer.global_position.z)
	_map_dot.position = _map_pos(here) - Vector2(18, 18)


# --- the adventures board and the souvenir shelf ----------------------------------------------

func _adv(id: String) -> Array:
	for a in ADVENTURES:
		if a[0] == id:
			return a
	return []


func _pick_cards() -> void:
	var st: Dictionary = save.data["adventures"]
	var done: Dictionary = st["done"]
	var fresh: Array = []
	for a in ADVENTURES:
		if not done.has(a[0]):
			fresh.append(a[0])
	if fresh.size() < 3:
		fresh = ADVENTURES.map(func(a: Array) -> String: return a[0])
	fresh.shuffle()
	st["current"] = fresh.slice(0, 3)
	st["ticked"] = {}
	save.write()


func _build_board() -> void:
	var st: Dictionary = save.data["adventures"]
	if (st.get("current", []) as Array).size() != 3:
		_pick_cards()
	var at := Places2.spot(corner, Terrain.COTTAGE + Vector2(-3.4, -7.2), 1.0)
	board = Places.root_at(corner, at, 200.0)
	var wood := Places.mat(Color(0.5, 0.35, 0.22))
	for side in [-0.75, 0.75]:
		Places.block(board, Vector3(0.1, 1.7, 0.1), Vector3(side, 0.85, 0), wood)
	Places.block(board, Vector3(1.8, 0.85, 0.08), Vector3(0, 1.3, 0), Places.mat(Color(0.85, 0.7, 0.5)))
	Places.block(board, Vector3(1.95, 0.12, 0.25), Vector3(0, 1.8, 0), Places.mat(Color(0.72, 0.32, 0.22)), Vector3(0, 0, 0))
	for k in 3:
		var card := Places.block(board, Vector3(0.48, 0.6, 0.02), Vector3(-0.56 + k * 0.56, 1.3, -0.05), Places.mat([Color(1.0, 0.95, 0.85), Color(0.92, 0.97, 1.0), Color(1.0, 0.92, 0.92)][k]))
		var star := Label3D.new()
		star.text = "★"
		star.font_size = 120
		star.pixel_size = 0.003
		star.modulate = Color(1.0, 0.8, 0.2)
		star.position = Vector3(-0.56 + k * 0.56, 1.3, -0.07)
		star.rotation.y = PI
		star.visible = false
		board.add_child(star)
		_board_cards.append(star)
		card.rotation.y = 0.0
	Places.solid(board, Vector3(1.8, 1.8, 0.3), Vector3(0, 0.9, 0))
	corner.blocked.append([at, 1.2])
	life.interact.register({"name": "board", "reach": 2.2, "priority": 0.5, "sparkle_height": 1.9, "label": "What shall we do today?", "icon": "res://assets/kits/survival/signpost.glb",
		"pos": func() -> Vector3: return board.global_position + Vector3.UP * 1.0,
		"act": func() -> String:
			_show_board()
			return "board"})
	_refresh_board()


func _refresh_board() -> void:
	var st: Dictionary = save.data["adventures"]
	var ticked: Dictionary = st.get("ticked", {})
	var cur: Array = st["current"]
	for k in 3:
		(_board_cards[k] as Label3D).visible = k < cur.size() and ticked.has(cur[k])


func _icon(path: String, id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = life.stickers._render_icon(path, id)
	return _icons[id]


func _show_board() -> void:
	if board_ui:
		board_ui.queue_free()
		board_ui = null
		return
	var st: Dictionary = save.data["adventures"]
	var ticked: Dictionary = st.get("ticked", {})
	board_ui = Control.new()
	board_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(board_ui)
	var back := ColorRect.new()
	back.color = Color(0.3, 0.2, 0.12, 0.55)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_ui.add_child(back)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_ui.add_child(row)
	var words: Array = []
	for id in st["current"]:
		var a := _adv(id)
		if a.is_empty():
			continue
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.97, 0.9)
		sb.set_corner_radius_all(30)
		sb.border_color = Color(1.0, 0.8, 0.3) if ticked.has(id) else Color(0.85, 0.7, 0.5)
		sb.set_border_width_all(10)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		card.add_theme_stylebox_override("panel", sb)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var box := VBoxContainer.new()
		card.add_child(box)
		var pic := TextureRect.new()
		pic.texture = _icon(a[2], "adv_" + String(id))
		pic.custom_minimum_size = Vector2(300, 300)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(pic)
		var lab := Label.new()
		lab.text = ("★ " if ticked.has(id) else "") + String(a[1])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 34)
		lab.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15))
		lab.custom_minimum_size = Vector2(300, 0)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(lab)
		row.add_child(card)
		words.append(a[1])
	say(". ".join(words), 0.2)
	explorer.busy = 1.0
	var me := board_ui
	await get_tree().create_timer(9.0).timeout
	if board_ui == me and is_instance_valid(me):
		me.queue_free()
		board_ui = null


func _on_event(what: String) -> void:
	var w := what.to_lower()
	var st: Dictionary = save.data["adventures"]
	if not st.has("ticked"):
		st["ticked"] = {}
	var ticked: Dictionary = st["ticked"]
	for id in st["current"]:
		if ticked.has(id):
			continue
		var a := _adv(id)
		if a.is_empty():
			continue
		for m in a[3]:
			if w.contains(String(m)):
				ticked[id] = true
				st["done"][id] = Time.get_date_string_from_system()
				save.data["souvenirs"][id] = true
				save.write()
				_adventure_done(a)
				break
	if ticked.size() >= 3:
		await get_tree().create_timer(6.0).timeout
		if (save.data["adventures"]["ticked"] as Dictionary).size() >= 3:
			_pick_cards()
			_refresh_board()


func _adventure_done(a: Array) -> void:
	_refresh_board()
	_refresh_shelf()
	life.sound.play_flat(life.sound.chime, -4.0)
	if life.audio:
		life.audio.play_voice(3.0)
	say("Hooray! " + String(a[1]) + "!", 1.6)
	var lab := Label.new()
	lab.text = "★  " + String(a[1]) + "  ★"
	lab.add_theme_font_size_override("font_size", 56)
	lab.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	lab.add_theme_color_override("font_outline_color", Color(0.4, 0.22, 0.05))
	lab.add_theme_constant_override("outline_size", 10)
	lab.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.position = Vector2(-500, 60)
	lab.custom_minimum_size = Vector2(1000, 0)
	_ui.add_child(lab)
	lab.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(lab, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.0)
	tw.tween_property(lab, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lab.queue_free)


## The souvenir shelf by the cottage door: one little keepsake for each adventure done.
func _build_shelf() -> void:
	var at := Places2.spot(corner, Terrain.COTTAGE + Vector2(-5.4, -4.4), 0.8)
	shelf = Places.root_at(corner, at, 180.0)
	var wood := Places.mat(Color(0.6, 0.42, 0.26))
	for side in [-0.85, 0.85]:
		Places.block(shelf, Vector3(0.08, 1.6, 0.4), Vector3(side, 0.8, 0), wood)
	for lvl in 3:
		Places.block(shelf, Vector3(1.78, 0.06, 0.4), Vector3(0, 0.3 + lvl * 0.55, 0), wood)
	Places.block(shelf, Vector3(1.9, 0.08, 0.5), Vector3(0, 1.64, 0), Places.mat(Color(0.72, 0.32, 0.22)))
	Places.solid(shelf, Vector3(1.8, 1.6, 0.45), Vector3(0, 0.8, 0))
	corner.blocked.append([at, 1.1])
	_refresh_shelf()


func _refresh_shelf() -> void:
	for n in shelf.get_children():
		if n.has_meta("souvenir"):
			n.queue_free()
	var got: Array = (save.data["souvenirs"] as Dictionary).keys()
	var slot := 0
	for id in got:
		var path := ""
		if id == "moon_rock":
			path = "res://assets/kits/space/rock.glb"
		else:
			var a := _adv(id)
			if a.is_empty():
				continue
			path = a[2]
		if slot >= 15:
			break
		var m := Models.spawn(shelf, path, 0.26, 20.0)
		if m:
			m.set_meta("souvenir", id)
			m.position = Vector3(-0.68 + (slot % 5) * 0.34, 0.33 + (slot / 5) * 0.55, 0.02)
			if id == "moon_rock":
				var glow := OmniLight3D.new()
				glow.light_color = Color(1.0, 0.85, 0.4)
				glow.light_energy = 0.6
				glow.omni_range = 0.8
				glow.position.y = 0.2
				m.add_child(glow)
		slot += 1
