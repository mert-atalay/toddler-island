extends CharacterBody3D
## The little explorer. The parent steers with W A S D or the arrow keys, or the controller's left
## stick; movement is relative to the camera. She can't walk into the sea.

const Models := preload("res://lib/models.gd")
const Terrain := preload("res://corner/terrain.gd")
const MODEL := "res://assets/characters/kenney/character-female-b.glb"
const HEIGHT := 0.95
const WALK := 2.3
const RUN := 3.6
const DEADZONE := 0.2

var camera_yaw := 0.0  # set by the follow camera every frame
var player: AnimationPlayer
var model: Node3D
var facing := PI  # model faces +Z, so PI faces north (-Z)
var auto_input := Vector2.ZERO  # used by the photo tour
var busy := 0.0  # seconds left of a stroke, feed or wave; she stands still meanwhile
var carrying := ""  # food in her hand: apple, carrot, hay, seed
var _held: Node3D
var _hand: BoneAttachment3D
var gravity := 18.0     # 3 on the Moon
var sea_check := true   # off on the Moon


## Plays a one-off action (stroke, feed, wave, pick up) and stands still for its length.
func act(anim: String, duration: float) -> void:
	busy = duration
	if player and player.has_animation(anim):
		player.play(anim, 0.15)
		player.speed_scale = 1.0


func face(p: Vector3) -> void:
	facing = atan2(p.x - global_position.x, p.z - global_position.z)
	model.rotation.y = facing


func forward() -> Vector3:
	return Vector3(sin(facing), 0.0, cos(facing))


## Puts a food in her right hand (replacing whatever she held).
func carry(kind: String, food: Node3D) -> void:
	drop()
	carrying = kind
	if _hand == null:
		var skel := model.find_children("*", "Skeleton3D", true, false)
		if not skel.is_empty():
			_hand = BoneAttachment3D.new()
			_hand.bone_name = "arm-right"
			skel[0].add_child(_hand)
	_held = food
	if _hand:
		_hand.add_child(food)
		# the hand is at the end of the arm bone; the model's own units are scaled up from the file
		var s: float = model.get_child(0).scale.x
		food.scale = Vector3.ONE / s
		food.position = Vector3(-0.16, -0.12, 0.06)
	else:
		add_child(food)
		food.position = Vector3(0.25, 0.45, 0.2)
	act("pick-up", 0.5)


## Lets go of what she holds without throwing it away (the ball). Returns it.
func release() -> Node3D:
	var held := _held
	if held and held.get_parent():
		held.get_parent().remove_child(held)
	_held = null
	carrying = ""
	return held


func drop() -> void:
	if _held:
		_held.queue_free()
	_held = null
	carrying = ""


## Is this spot on one of the footbridges (where the water underneath does not stop her)?
func _on_bridge(p: Vector3) -> bool:
	var c := get_parent()
	if c == null:
		return false
	for b in c.get_meta("bridges", []):
		var at: Vector2 = b[0]
		var dir: Vector2 = b[1]
		var q := Vector2(p.x, p.z) - at
		if absf(q.dot(dir)) < float(b[2]) + 0.6 and absf(q.dot(dir.orthogonal())) < float(b[3]) * 0.5 + 0.3:
			return true
	return false


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)
	model = Models.spawn(self, MODEL, HEIGHT, 0.0)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		player = players[0]
		for n in ["idle", "walk", "sprint"]:
			if player.has_animation(n):
				player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		player.play("idle")


func read_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y -= 1.0
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > DEADZONE:
		v = stick * ((stick.length() - DEADZONE) / (1.0 - DEADZONE)) / stick.length()
	if auto_input != Vector2.ZERO:
		v = auto_input
	return v.limit_length(1.0)


func _physics_process(delta: float) -> void:
	var move := read_move()
	busy -= delta
	if busy > 0.0:
		move = Vector2.ZERO
	var running := Input.is_key_pressed(KEY_SHIFT) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	var dir := Basis(Vector3.UP, camera_yaw) * Vector3(move.x, 0.0, -move.y)
	var speed := (RUN if running else WALK) * move.length()
	var want := dir.normalized() * speed if dir.length() > 0.01 else Vector3.ZERO
	# the sea and the edge of the world turn her back
	var ahead := global_position + want * 0.6
	if sea_check and Terrain.height(ahead.x, ahead.z) < Terrain.SEA - 0.15 and not _on_bridge(ahead):
		want = Vector3.ZERO
	velocity.x = move_toward(velocity.x, want.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 14.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y <= 0.0:
		velocity.y = -0.5
	move_and_slide()

	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.2:
		facing = lerp_angle(facing, atan2(velocity.x, velocity.z), 1.0 - exp(-delta * 10.0))
	model.rotation.y = facing
	if player and busy <= 0.0:
		var anim := "idle"
		if flat.length() > 2.9 and player.has_animation("sprint"):
			anim = "sprint"
		elif flat.length() > 0.25:
			anim = "walk"
		if player.current_animation != anim:
			player.play(anim, 0.2)
		player.speed_scale = clampf(flat.length() / (3.4 if anim == "sprint" else 1.9), 0.7, 1.4) if anim != "idle" else 1.0
