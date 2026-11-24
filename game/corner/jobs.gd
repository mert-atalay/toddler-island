extends Node3D
## Small jobs, all answered by her one button and none of them can be failed:
## - Eggs: hens lay eggs by the coop now and then; walking over one puts it in the egg basket.
## - Ball: the ball by the kennel; carry it, press her button and she throws it; the dog fetches it.
## - Pump: her button by the pump fills the trough, and thirsty animals come to drink.
## - Gate: her button by the farm gate swings it open.
## - Lost chick: a chick peeps from somewhere on the island ("where is it?"); she finds it, it follows
##   her, and when she brings it back to the coop it runs to the hens. Later another one wanders off.

const Terrain := preload("res://corner/terrain.gd")
const Models := preload("res://lib/models.gd")
const Places := preload("res://corner/places.gd")
const COOP := Vector2(7.5, -10.5)
const PUMP := Vector2(4.0, -3.4)
const GATE_POS := Vector2(0.0, 1.0)
const CHICK_SPOTS := [Vector2(60.0, -20.0), Vector2(22.0, 30.0), Vector2(70.0, 20.0), Vector2(28.0, -36.0), Vector2(-20.0, 14.0), Vector2(48.0, 40.0)]

var life: Node3D
var eggs: Array = []        # egg nodes waiting on the ground
var basket_count := 0
var _basket: Node3D
var _egg_t := 20.0
var ball: Node3D
var ball_home := Vector2.ZERO
var ball_state := "home"    # home, carried, flying, ground, dog
var _ball_vel := Vector3.ZERO
var _pump_handle: Node3D
var _trough_water: MeshInstance3D
var _water_level := 0.3
var gate_open := false
var _gate_panels: Array = []
var chick: Node3D
var chick_state := "lost"   # lost, following, home
var _chick_voice := AudioStreamPlayer3D.new()
var _peep_t := 3.0
var _next_chick_t := 0.0
var done := {}              # job name -> times done, for the photo tour and the parent


func build(l: Node3D) -> void:
	life = l
	basket_count = int(life.save.data.get("eggs", 0))
	_egg_basket()
	_ball()
	_pump()
	_gate()
	_lost_chick()
	var it: Node = life.interact
	it.register({"name": "pump", "pos": func() -> Vector3: return Vector3(PUMP.x, Terrain.height(PUMP.x, PUMP.y), PUMP.y),
		"reach": 1.7, "act": func() -> String: return _press_pump(), "sparkle_height": 1.5, "label": "Pump some water", "icon": "res://assets/kits/survival/bucket.glb"})
	it.register({"name": "gate", "pos": func() -> Vector3: return Vector3(GATE_POS.x, Terrain.height(GATE_POS.x, GATE_POS.y), GATE_POS.y),
		"reach": 2.6, "act": func() -> String: return _press_gate(), "when": func() -> bool: return not gate_open, "sparkle_height": 1.4, "label": "Open the gate", "icon": "res://assets/kits/nature/fence_gate.glb"})
	it.register({"name": "chick", "pos": func() -> Vector3: return chick.global_position,
		"reach": 1.9, "act": func() -> String: return _press_chick(), "when": func() -> bool: return chick_state == "lost", "sparkle_height": 0.6, "priority": 0.5, "label": "Hello, little chick!", "icon": "res://assets/animals/quaternius/hen.glb"})
	it.register({"name": "ball", "pos": func() -> Vector3: return ball.global_position,
		"reach": 1.5, "sparkle_height": 0.5, "label": "Pick up the ball", "icon": "res://assets/kits/picnic/frisbee.gltf", "priority": 0.3,
		"act": func() -> String: return _pick_ball(),
		"when": func() -> bool: return ball_state in ["home", "ground"] and life.explorer.carrying == "" and is_instance_valid(ball) and ball.is_inside_tree()})
	for f in life.food_sources:
		var fp: Vector2 = f[1]
		it.register({"name": f[0], "pos": func() -> Vector3: return Vector3(fp.x, Terrain.height(fp.x, fp.y), fp.y),
			"reach": float(f[2]) + 0.9, "sparkle_height": 0.9, "priority": 0.2, "when": func() -> bool: return life.explorer.carrying != f[0],
			"label": "Pick up " + {"apple": "an apple", "carrot": "a carrot", "hay": "some hay", "seed": "some seeds"}.get(f[0], f[0]),
			"icon": {"apple": "res://assets/kits/food/apple.glb", "carrot": "res://assets/kits/food/carrot.glb", "seed": "res://assets/kits/food/corn.glb", "hay": "res://assets/kits/food/bread.glb"}.get(f[0], ""),
			"act": func() -> String: return life.take_food(f[0])})


func _press_pump() -> String:
	life.explorer.act("interact-right", 1.2)
	pump()
	return "pumped water"


func _press_gate() -> String:
	life.explorer.act("interact-right", 1.0)
	open_gate()
	return "opened the gate"


func _pick_ball() -> String:
	ball_state = "pick"
	return "picked up the ball"


func _press_chick() -> String:
	chick_state = "following"
	life.explorer.act("interact-right", 1.0)
	life.fx.hearts(chick.global_position + Vector3.UP * 0.3, 4)
	life.sound.call_from("hens", _chick_voice, true)
	return "found the chick"


# --- eggs -------------------------------------------------------------------------------------

func _egg_mesh() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.13
	m.mesh = s
	m.material_override = Places.mat(Color(0.98, 0.94, 0.86), 0.5)
	return m


func _egg_basket() -> void:
	_basket = Places.root_at(life.corner, COOP + Vector2(-1.8, 1.6))
	Places.block(_basket, Vector3(0.5, 0.25, 0.5), Vector3(0, 0.12, 0), Places.mat(Color(0.7, 0.52, 0.3)), Vector3.ZERO, 10)


func _lay_egg() -> void:
	if eggs.size() >= 4:
		return
	var a := randf() * TAU
	var p := COOP + Vector2(cos(a), sin(a)) * randf_range(1.8, 3.2)
	var e := _egg_mesh()
	e.position = Vector3(p.x, Terrain.height(p.x, p.y) + 0.06, p.y)
	life.corner.add_child(e)
	eggs.append(e)


func _collect_egg(e: Node3D) -> void:
	eggs.erase(e)
	e.queue_free()
	basket_count += 1
	var shown := _egg_mesh()
	shown.position = Vector3(randf_range(-0.12, 0.12), 0.27 + 0.05 * (basket_count / 6), randf_range(-0.12, 0.12))
	_basket.add_child(shown)
	life.fx.hearts(_basket.global_position + Vector3.UP * 0.4, 3)
	life.sound.play_flat(life.sound.chime, -10.0)
	done["egg"] = int(done.get("egg", 0)) + 1
	life.save.data["eggs"] = basket_count
	life.save.write()
	life.events_said("egg")


# --- the ball for the dog -----------------------------------------------------------------------

func _ball() -> void:
	ball_home = Terrain.COTTAGE + Vector2(4.6, 2.6)
	ball = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.22
	(ball as MeshInstance3D).mesh = s
	(ball as MeshInstance3D).material_override = Places.mat(Color(0.95, 0.25, 0.3), 0.4)
	life.corner.add_child(ball)
	_place_ball(ball_home)


func _place_ball(p: Vector2) -> void:
	if ball.get_parent() != life.corner:
		if ball.get_parent():
			ball.get_parent().remove_child(ball)
		life.corner.add_child(ball)
	ball.scale = Vector3.ONE
	ball.position = Vector3(p.x, Terrain.height(p.x, p.y) + 0.11, p.y)


func throw_ball() -> void:
	var ex: CharacterBody3D = life.explorer
	ex.release()
	ball.scale = Vector3.ONE
	life.corner.add_child(ball)
	_place_ball(Vector2(ex.global_position.x, ex.global_position.z))
	ball.position.y += 0.7
	_ball_vel = ex.forward() * 5.5 + Vector3.UP * 3.2
	ball_state = "flying"
	done["throw"] = int(done.get("throw", 0)) + 1


func dog_has_ball(dog: Node3D) -> void:
	ball_state = "dog"
	if ball.get_parent():
		ball.get_parent().remove_child(ball)
	dog.add_child(ball)
	ball.position = Vector3(0, 0.45, 0.42)


func dog_drops_ball(dog: Node3D) -> void:
	var p := Vector2(dog.global_position.x, dog.global_position.z) + Vector2(sin(dog.yaw), cos(dog.yaw)) * 0.6
	_place_ball(p)
	ball_state = "ground"
	life.fx.hearts(dog.global_position + Vector3.UP * 0.9, 4)
	done["fetch"] = int(done.get("fetch", 0)) + 1


# --- the pump and the trough --------------------------------------------------------------------

func _pump() -> void:
	var r := Places.root_at(life.corner, PUMP, 90.0)
	var iron := Places.mat(Color(0.22, 0.42, 0.32), 0.5)
	Places.block(r, Vector3(0.5, 0.15, 0.5), Vector3(0, 0.07, 0), Places.mat(Color(0.6, 0.58, 0.55)))
	Places.block(r, Vector3(0.2, 1.0, 0.2), Vector3(0, 0.6, 0), iron, Vector3.ZERO, 10)
	Places.block(r, Vector3(0.1, 0.1, 0.45), Vector3(0, 0.95, -0.28), iron)
	_pump_handle = Node3D.new()
	_pump_handle.position = Vector3(0, 1.08, 0.08)
	r.add_child(_pump_handle)
	Places.block(_pump_handle, Vector3(0.06, 0.06, 0.6), Vector3(0, 0, 0.3), iron)
	Places.solid(r, Vector3(0.5, 1.2, 0.5), Vector3(0, 0.6, 0))
	life.corner.blocked.append([PUMP, 0.5])
	for m in life.corner.find_children("*", "MeshInstance3D", false, false):
		var mi := m as MeshInstance3D
		if mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(1.76, 0.02, 0.5)):
			_trough_water = mi
	for node in life.corner.get_children():
		for child in node.get_children():
			var mi2 := child as MeshInstance3D
			if mi2 and mi2.mesh is BoxMesh and (mi2.mesh as BoxMesh).size.is_equal_approx(Vector3(1.76, 0.02, 0.5)):
				_trough_water = mi2


func pump() -> void:
	var tw := create_tween()
	for k in 3:
		tw.tween_property(_pump_handle, "rotation_degrees:x", -35.0, 0.18)
		tw.tween_property(_pump_handle, "rotation_degrees:x", 15.0, 0.18)
	tw.tween_property(_pump_handle, "rotation_degrees:x", 0.0, 0.15)
	_water_level = minf(1.0, _water_level + 0.35)
	life.fx.hearts(Vector3(2.6, Terrain.height(2.6, -3.2) + 0.7, -3.2), 3)
	life.sound.play_flat(life.sound.pop, -8.0)
	for a in life.animals:
		if a.cfg.get("drinks", true) and a.can_walk() and a.state in ["graze", "idle", "walk"]:
			a.thirst = 1.0
			a._choose()
	done["pump"] = int(done.get("pump", 0)) + 1


# --- the farm gate ------------------------------------------------------------------------------

func _gate() -> void:
	var wood := Places.mat(Color(0.55, 0.36, 0.22))
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(GATE_POS.x + side * 1.55, Terrain.height(GATE_POS.x, GATE_POS.y), GATE_POS.y)
		life.corner.add_child(hinge)
		for rail in [0.3, 0.65, 1.0]:
			Places.block(hinge, Vector3(1.5, 0.1, 0.07), Vector3(-side * 0.77, rail, 0), wood)
		Places.block(hinge, Vector3(0.08, 1.05, 0.08), Vector3(-side * 1.45, 0.55, 0), wood)
		Places.block(hinge, Vector3(1.6, 0.08, 0.06), Vector3(-side * 0.77, 0.65, 0), wood, Vector3(0, 0, side * 24.0))
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.5, 1.1, 0.15)
		shape.shape = box
		shape.position = Vector3(-side * 0.77, 0.55, 0)
		body.add_child(shape)
		hinge.add_child(body)
		_gate_panels.append([hinge, side])


func open_gate() -> void:
	if gate_open:
		return
	gate_open = true
	life.paths.set_gate(Vector2(-1.6, 1.0), Vector2(1.6, 1.0), true)
	for g in _gate_panels:
		var tw := create_tween()
		tw.tween_property(g[0], "rotation_degrees:y", float(g[1]) * -95.0, 1.2).set_trans(Tween.TRANS_SINE)
	life.sound.play_flat(life.sound.chime, -10.0)
	done["gate"] = 1


# --- the lost chick -----------------------------------------------------------------------------

func _lost_chick() -> void:
	chick = Node3D.new()
	life.corner.add_child(chick)
	var holder := Models.spawn(chick, "res://assets/animals/quaternius/hen2.glb", 0.22, 0.0)
	var players := holder.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap := players[0] as AnimationPlayer
		for n in ap.get_animation_list():
			if String(n).to_lower().ends_with("idle_peck"):
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
				ap.play(n)
	_chick_voice.unit_size = 5.0
	_chick_voice.pitch_scale = 1.7
	_chick_voice.max_distance = 60.0
	chick.add_child(_chick_voice)
	_lose_chick()


func _lose_chick() -> void:
	var p: Vector2 = CHICK_SPOTS.pick_random()
	chick.position = Vector3(p.x, Terrain.height(p.x, p.y), p.y)
	chick_state = "lost"


# --- her button and every frame -----------------------------------------------------------------

## Called by her button before strokes and feeding. Returns what happened, or "" if no job was near.
func try_button() -> String:
	var ex: CharacterBody3D = life.explorer
	var here := Vector2(ex.global_position.x, ex.global_position.z)
	if life.explorer.carrying == "ball":
		throw_ball()
		life.explorer.act("interact-right", 0.8)
		return "threw the ball"
	if here.distance_to(PUMP) < 1.6:
		life.explorer.face(Vector3(PUMP.x, 0, PUMP.y))
		life.explorer.act("interact-right", 1.2)
		pump()
		return "pumped water"
	if not gate_open and here.distance_to(GATE_POS) < 2.6:
		life.explorer.act("interact-right", 1.0)
		open_gate()
		return "opened the gate"
	if chick_state == "lost" and here.distance_to(Vector2(chick.position.x, chick.position.z)) < 1.8:
		chick_state = "following"
		life.explorer.act("interact-right", 1.0)
		life.fx.hearts(chick.global_position + Vector3.UP * 0.3, 4)
		life.sound.call_from("hens", _chick_voice, true)
		return "found the chick"
	return ""


func _process(delta: float) -> void:
	var ex: CharacterBody3D = life.explorer
	var here := Vector2(ex.global_position.x, ex.global_position.z)
	# eggs
	_egg_t -= delta
	if _egg_t <= 0.0:
		_egg_t = randf_range(25.0, 45.0)
		_lay_egg()
	for e in eggs.duplicate():
		if here.distance_to(Vector2(e.position.x, e.position.z)) < 0.8:
			_collect_egg(e)
	# the ball
	if ball_state == "flying":
		_ball_vel.y -= 12.0 * delta
		ball.position += _ball_vel * delta
		var g := Terrain.height(ball.position.x, ball.position.z) + 0.11
		if ball.position.y <= g:
			ball.position.y = g
			ball_state = "ground"
			for a in life.animals:
				if a.cfg.get("companion", false):
					a.fetch(Vector2(ball.position.x, ball.position.z))
	elif ball_state == "pick":
		ball.get_parent().remove_child(ball)
		ex.carry("ball", ball)
		ball_state = "carried"
	elif ball_state == "carried" and ex.carrying != "ball":
		if not is_instance_valid(ball) or ball.is_queued_for_deletion():
			_ball()  # she swapped it for food: a new ball waits by the kennel
		else:
			_place_ball(ball_home)
		ball_state = "home"
	# water level in the trough
	if _trough_water:
		_water_level = maxf(0.25, _water_level - delta / 300.0)
		_trough_water.position.y = 0.2 + 0.26 * _water_level
	# the chick
	if chick_state == "lost":
		_peep_t -= delta
		if _peep_t <= 0.0:
			_peep_t = randf_range(5.0, 8.0)
			life.sound.call_from("hens", _chick_voice, false)
	elif chick_state == "following":
		var cp := Vector2(chick.position.x, chick.position.z)
		var to := here - cp
		if to.length() > 1.0:
			var step := to.normalized() * minf(to.length() - 1.0, 3.2 * delta)
			chick.position.x += step.x
			chick.position.z += step.y
			chick.rotation.y = atan2(to.x, to.y)
		chick.position.y = Terrain.height(chick.position.x, chick.position.z)
		if cp.distance_to(COOP) < 4.5:
			chick_state = "home"
			_next_chick_t = 180.0
			life.fx.hearts(chick.global_position + Vector3.UP * 0.4, 8)
			life.sound.play_flat(life.sound.chime, -8.0)
			done["chick"] = int(done.get("chick", 0)) + 1
	elif chick_state == "home":
		_next_chick_t -= delta
		if _next_chick_t <= 0.0:
			_lose_chick()
