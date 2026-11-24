extends Node3D
## A living farm animal. Needs (hunger, thirst, tiredness) rise over time and the strongest one picks
## what it does next: graze, walk to the trough to drink, rest in the shade, or wander near its herd.
## It notices the explorer, loves being stroked, eats from her hand and then follows her for a while.
## It never flees or threatens.

const Terrain := preload("res://corner/terrain.gd")

var cfg: Dictionary            # species settings, see corner.gd SPECIES
var world: Node                # the corner: explorer, obstacles, places, herds, sound, fx
var player: AnimationPlayer
var anims := {}                # role -> animation name: graze idle rest happy walk run
var voice := AudioStreamPlayer3D.new()
var bubble: Node3D
var yaw := 0.0
var hunger := 0.0
var thirst := 0.0
var tired := 0.0
var state := "idle"
var timer := 0.0
var target := Vector2.ZERO
var then := ""                 # what to do on arrival
var follow_time := 0.0
var greet_cooldown := 0.0
var used := {}                 # behaviours seen, for the soak test
var route := PackedVector2Array()  # waypoints round fences and buildings
var _route_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var body: AnimatableBody3D


func setup(holder: Node3D, settings: Dictionary, corner: Node) -> void:
	cfg = settings
	world = corner
	var players := holder.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		player = players[0]
		for n in player.get_animation_list():
			var s := String(n).get_slice("|", String(n).get_slice_count("|") - 1).to_lower()
			var role := ""
			if s.begins_with("eat") or s.contains("peck") or s.contains("eating"):
				role = "graze"
			elif s == "idle" or s == "idlecat":
				role = "idle"
			elif s.contains("headlow"):
				role = "rest"
			elif s == "idle_2" or s.begins_with("jump"):
				role = "happy" if not anims.has("happy") or s == "idle_2" else ""
			elif s == "walk":
				role = "walk"
			elif s == "run" or s == "gallop":
				role = "run"
			if role != "" and not anims.has(role):
				anims[role] = n
		for role in ["graze", "idle", "rest", "walk", "run"]:
			if anims.has(role):
				player.get_animation(anims[role]).loop_mode = Animation.LOOP_LINEAR
		if anims.has("happy"):
			player.get_animation(anims["happy"]).loop_mode = Animation.LOOP_NONE
	voice.position.y = float(cfg["height"]) * 0.8
	voice.pitch_scale = float(cfg.get("pitch", 1.0))
	voice.max_distance = 70.0
	add_child(voice)
	body = AnimatableBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = cfg["radius"]
	cyl.height = maxf(0.6, float(cfg["height"]))
	shape.shape = cyl
	shape.position.y = cyl.height * 0.5
	body.add_child(shape)
	add_child(body)
	hunger = randf_range(0.35, 0.75)
	thirst = randf_range(0.0, 0.5)
	tired = randf_range(0.0, 0.5)
	greet_cooldown = randf_range(4.0, 12.0)
	_choose()


func pos2() -> Vector2:
	return Vector2(position.x, position.z)


func likes(food: String) -> bool:
	return food in cfg["likes"]


func can_walk() -> bool:
	return float(cfg["speed"]) > 0.0 and (anims.has("walk") or anims.has("run"))


# --- what to do next ----------------------------------------------------------------------

func _choose() -> void:
	if world.seed_spots.size() > 0 and likes("seed") and can_walk():
		var spot: Vector2 = world.nearest_seed(pos2())
		if spot.distance_to(pos2()) < 14.0 and (cfg["area"] as Rect2).grow(1.0).has_point(spot):
			_go(spot + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)), "peck")
			return
	if not can_walk():
		_set_state("graze" if anims.has("graze") and randf() < 0.5 else "idle", randf_range(4.0, 9.0))
		return
	var water: Array = cfg.get("water", world.places["water"])
	var shade: Array = cfg.get("shade", world.places["shade"])
	if thirst > 0.7 and cfg.get("drinks", true) and not water.is_empty():
		_go(_near_place(water), "drink")
		return
	if tired > 0.75 and not shade.is_empty() and anims.has("rest"):
		_go(_near_place(shade), "rest")
		return
	# babies keep close to their mother
	if cfg.has("mother"):
		var mum: Node3D = world.mother_of(self)
		if mum and mum.pos2().distance_to(pos2()) > 2.5:
			var near: Vector2 = mum.pos2() + Vector2(randf_range(-1.6, 1.6), randf_range(-1.6, 1.6))
			_go(near, "graze" if anims.has("graze") else "idle")
			return
	var herd: Vector2 = world.herd_centre(self)
	if herd != Vector2.INF and herd.distance_to(pos2()) > 6.0:
		_go(herd + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)), "graze")
		return
	var r := randf()
	if r < 0.5 and anims.has("graze"):
		var around := herd if herd != Vector2.INF else pos2()
		_go(world.free_spot_near(around, 4.0, cfg["area"]), "graze")
	elif r < 0.8:
		_go(world.free_spot_near(pos2(), 7.0, cfg["area"]), "idle")
	else:
		_set_state("idle", randf_range(3.0, 6.0))


func _near_place(list: Array) -> Vector2:
	var best: Vector2 = list[0]
	for p in list:
		if (p as Vector2).distance_to(pos2()) < best.distance_to(pos2()):
			best = p
	# spread out so two animals don't stand in one spot
	return best + Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))


func _go(where: Vector2, on_arrival: String) -> void:
	target = world.clamp_to_area(where, (cfg["area"] as Rect2).grow(-0.6))
	then = on_arrival
	_plan()
	_set_state("walk", 20.0)


## Asks the route map for a way to the target.
func _plan() -> void:
	route = world.paths.route(pos2(), target)
	if route.size() > 0:
		route.remove_at(0)


## The next point to head for: a little way along the route, or the target itself.
func _waypoint() -> Vector2:
	while route.size() > 1 and pos2().distance_to(route[0]) < 0.7:
		route.remove_at(0)
	return route[0] if route.size() > 0 else target


func _set_state(s: String, duration: float) -> void:
	state = s
	timer = duration
	used[s] = true
	match s:
		"walk", "follow":
			_play("walk" if anims.has("walk") else "run", (cfg.get("walk_anim_scale", 1.0)))
		"graze", "drink", "peck", "eat_hand":
			_play("graze" if anims.has("graze") else "idle")
		"rest":
			_play("rest" if anims.has("rest") else "idle")
		"happy":
			_play("happy" if anims.has("happy") else "idle")
		_:
			_play("idle")


func _play(role: String, speed := 1.0) -> void:
	if player and anims.has(role):
		if player.current_animation != anims[role] or role == "happy":
			player.play(anims[role], 0.35)
		player.speed_scale = speed


# --- the explorer ---------------------------------------------------------------------------

## Her button beside this animal: it turns to her, makes its happy sound, and hearts rise.
func stroke(from: Vector3) -> void:
	_face_now(from)
	_set_state("happy", 2.8)
	world.sound.call_from(cfg["sound"], voice, true)
	world.fx.hearts(global_position + Vector3.UP * float(cfg["height"]) * 1.05)
	greet_cooldown = 15.0


## She offers food. Returns true if the animal takes it.
func feed(food: String, from: Vector3) -> bool:
	_face_now(from)
	if not likes(food):
		_set_state("idle", 1.5)
		return false
	hunger = 0.0
	_set_state("eat_hand", 3.0)
	then = "follow"
	world.sound.call_from(cfg["sound"], voice, true)
	world.fx.hearts(global_position + Vector3.UP * float(cfg["height"]) * 1.05, 8)
	return true


## The parent calls: animals look up, and those that can come over.
func called(from: Vector3) -> void:
	if state in ["happy", "eat_hand"]:
		return
	_face_now(from)
	if can_walk() and Vector2(from.x, from.z).distance_to(pos2()) < 26.0:
		# stop in a ring around her rather than all aiming for the spot she stands on
		var f2 := Vector2(from.x, from.z)
		var away := (pos2() - f2).normalized().rotated(randf_range(-0.6, 0.6))
		target = world.clamp_to_area(f2 + away * (float(cfg["radius"]) + 1.8 + randf() * 1.2), (cfg["area"] as Rect2).grow(-0.6))
		then = "notice"
		_plan()
		_set_state("walk", 16.0)
		used["called"] = true
	else:
		_set_state("idle", 2.0)


## Sunset: walk home (barn, coop, kennel) and settle down for the night.
func go_home() -> void:
	if not cfg.has("home") or not can_walk():
		_set_state("rest" if anims.has("rest") else "idle", 9999.0)
		return
	follow_time = 0.0
	_go(cfg["home"] + Vector2(randf_range(-1.8, 1.8), randf_range(-1.2, 1.2)), "sleep")


## Fetch: run to the ball, then bring it back to her.
func fetch(ball_at: Vector2) -> void:
	target = world.clamp_to_area(ball_at, cfg["area"])
	then = "fetch"
	_plan()
	_set_state("walk", 16.0)


func _face_now(from: Vector3) -> void:
	yaw = atan2(from.x - position.x, from.z - position.z) + float(cfg.get("yaw_offset", 0.0))


# --- every frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	hunger = minf(1.0, hunger + delta / 140.0)
	thirst = minf(1.0, thirst + delta / 160.0)
	tired = minf(1.0, tired + delta / 220.0)
	greet_cooldown -= delta
	timer -= delta
	var ex: Node3D = world.explorer
	var ex2 := Vector2(ex.global_position.x, ex.global_position.z)
	var d_ex := ex2.distance_to(pos2())

	# animals greet first: they stop, turn to her and call once
	if greet_cooldown <= 0.0 and d_ex < 5.5 and state in ["graze", "idle", "walk"] and world.can_greet():
		greet_cooldown = randf_range(25.0, 40.0)
		_face_now(ex.global_position)
		_set_state("notice", 2.5)
		world.sound.call_from(cfg["sound"], voice, true)
		world.greeted()

	match state:
		"walk":
			var speed: float = cfg["run_speed"] if then in ["peck", "notice", "fetch", "return_ball"] and cfg.has("run_speed") else cfg["speed"]
			var wp := _waypoint()
			var reached := _steer(wp, speed, delta)
			if reached and route.size() > 0:
				route.remove_at(0)
			if (reached and route.is_empty() and wp == target) or pos2().distance_to(target) < 0.4 or timer <= 0.0:
				_arrive()
		"follow":
			follow_time -= delta
			var goal := ex2 + (pos2() - ex2).normalized() * (float(cfg["radius"]) + 1.4)
			if d_ex > float(cfg["radius"]) + 2.4:
				_play("walk" if anims.has("walk") else "run", cfg.get("walk_anim_scale", 1.0))
				_route_t -= delta
				if _route_t <= 0.0:
					_route_t = 0.8
					target = world.clamp_to_area(goal, cfg["area"])
					_plan()
				var fwp := _waypoint()
				if _steer(fwp, float(cfg.get("run_speed", cfg["speed"])) if d_ex > 5.0 else float(cfg["speed"]), delta, false) and route.size() > 0:
					route.remove_at(0)
			else:
				_play("idle")
				_turn_to(ex2, delta)
			if follow_time <= 0.0:
				_choose()
		"notice", "happy", "eat_hand":
			_turn_to(ex2, delta)
			if timer <= 0.0:
				if state == "eat_hand" and then == "follow" and not can_walk():
					_choose()
				elif state == "eat_hand" and then == "follow":
					follow_time = 30.0 if not cfg.get("companion", false) else 9999.0
					_set_state("follow", follow_time)
				elif cfg.get("companion", false):
					follow_time = 9999.0
					_set_state("follow", follow_time)
				else:
					_choose()
		"drink":
			thirst = maxf(0.0, thirst - delta / 4.0)
			if timer <= 0.0:
				_choose()
		"rest":
			tired = maxf(0.0, tired - delta / 10.0)
			if timer <= 0.0:
				_choose()
		"graze":
			hunger = maxf(0.0, hunger - delta / 60.0) if likes("grass") else hunger
			if timer <= 0.0:
				_choose()
		"peck":
			if timer <= 0.0 or world.seed_spots.is_empty():
				_choose()
		_:
			if timer <= 0.0:
				_choose()

	# companions (the dog) keep near her when she wanders off
	if cfg.get("companion", false) and state not in ["follow", "happy", "notice", "rest"] and then not in ["sleep", "fetch", "return_ball"] and d_ex > 9.0:
		follow_time = 9999.0
		_set_state("follow", follow_time)

	position.y = Terrain.height(position.x, position.z)
	rotation.y = yaw
	if bubble:
		var wants := hunger > 0.5 and state not in ["eat_hand", "happy"] and d_ex < 18.0
		bubble.visible = wants
		bubble.position.y = float(cfg["height"]) + 0.45 + sin(Time.get_ticks_msec() / 400.0) * 0.05


func _arrive() -> void:
	match then:
		"drink":
			_set_state("drink", randf_range(4.0, 6.0))
		"rest":
			_set_state("rest", randf_range(10.0, 18.0))
		"graze":
			_set_state("graze", randf_range(7.0, 14.0))
		"peck":
			_set_state("peck", randf_range(4.0, 8.0))
		"notice":
			_face_now(world.explorer.global_position)
			_set_state("notice", 2.0)
		"sleep":
			_set_state("rest" if anims.has("rest") else "idle", 9999.0)
		"fetch":
			world.jobs.dog_has_ball(self)
			var ex: Vector3 = world.explorer.global_position
			target = world.clamp_to_area(Vector2(ex.x, ex.z), cfg["area"])
			then = "return_ball"
			_plan()
			_set_state("walk", 16.0)
		"return_ball":
			world.jobs.dog_drops_ball(self)
			_face_now(world.explorer.global_position)
			_set_state("happy", 2.0)
		_:
			_set_state("idle", randf_range(2.0, 5.0))


func _turn_to(p: Vector2, delta: float) -> void:
	var want := atan2(p.x - position.x, p.y - position.z) + float(cfg.get("yaw_offset", 0.0))
	yaw = lerp_angle(yaw, want, 1.0 - exp(-delta * 4.0))


## Walks toward a point around obstacles and other animals. Returns true on arrival.
func _steer(goal: Vector2, speed: float, delta: float, check_stuck := true) -> bool:
	var here := pos2()
	var to := goal - here
	if to.length() < (1.1 if then in ["notice", "return_ball"] else (0.8 if then == "peck" else 0.35)):
		return true
	var dir := to.normalized()
	dir += world.avoid(here, float(cfg["radius"]), self, dir)
	if dir.length() < 0.01:
		dir = to.normalized().orthogonal()
	var want := atan2(dir.x, dir.y)
	yaw = lerp_angle(yaw, want, 1.0 - exp(-delta * 3.5))
	var facing := Vector2(sin(yaw), cos(yaw))
	var step := facing * speed * clampf(facing.dot(dir.normalized()), 0.15, 1.0) * delta
	var next: Vector2 = world.clamp_to_area(here + step, cfg["area"])
	if Terrain.height(next.x, next.y) < 0.2:
		next = here
	position.x = next.x
	position.z = next.y
	# give up on a target it can't reach
	_stuck_t += delta
	if _stuck_t > 3.0 and check_stuck:
		if _last_pos.distance_to(here) < 0.4 and here.distance_to(goal) > 1.0:
			used["stuck"] = int(used.get("stuck", 0)) + 1
			if OS.get_cmdline_user_args().has("--soak"):
				print("[stuck] %s at (%.1f, %.1f) going to (%.1f, %.1f) for %s, state %s" % [name, here.x, here.y, goal.x, goal.y, then, state])
			_choose()
		_last_pos = here
		_stuck_t = 0.0
	return false
