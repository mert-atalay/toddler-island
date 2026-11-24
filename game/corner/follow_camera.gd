extends Node3D
## A camera behind the explorer's shoulder. It follows smoothly, swings round behind her when she
## walks, and never goes through hills or walls. Mouse drag or the right stick turn it.

var target: Node3D
var yaw := 0.0
var pitch := -0.30
var distance := 4.6
var arm := SpringArm3D.new()
var cam := Camera3D.new()
var _manual_timer := 0.0
var fixed := false  # the photo tour places the camera itself
var _focus: Node3D
var _focus_t := 0.0
var _focus_side := 1.0


## Moves in close for a few seconds so the animal's face fills the screen (a stroke or a feed).
func focus(subject: Node3D, seconds := 2.8) -> void:
	_focus = subject
	_focus_t = seconds
	var to := subject.global_position - target.global_position
	var side_a := atan2(to.x, to.z) + PI / 2.0
	# pick the side of the pair nearer to where the camera already is
	_focus_side = 1.0 if absf(angle_difference(yaw, side_a)) < PI / 2.0 else -1.0


func _ready() -> void:
	arm.spring_length = distance
	arm.margin = 0.3
	arm.rotation.x = pitch
	add_child(arm)
	cam.fov = 55.0
	cam.near = 0.05
	cam.far = 1200.0
	arm.add_child(cam)
	cam.make_current()
	if target:
		global_position = target.global_position + Vector3.UP * 1.1
		arm.add_excluded_object((target as CollisionObject3D).get_rid())


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
		yaw -= motion.relative.x * 0.005
		pitch = clampf(pitch - motion.relative.y * 0.003, -0.9, 0.05)
		_manual_timer = 2.0


func _process(delta: float) -> void:
	if fixed or target == null:
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.2:
		yaw -= stick.x * 1.8 * delta
		pitch = clampf(pitch - stick.y * 1.0 * delta, -0.9, 0.05)
		_manual_timer = 2.0
	if Input.is_key_pressed(KEY_Q):
		yaw += 1.6 * delta
		_manual_timer = 2.0
	if Input.is_key_pressed(KEY_E):
		yaw -= 1.6 * delta
		_manual_timer = 2.0
	_manual_timer -= delta
	# swing gently round behind her while she walks, unless the parent just turned the camera
	var body := target as CharacterBody3D
	var flat := Vector2(body.velocity.x, body.velocity.z)
	if _manual_timer <= 0.0 and flat.length() > 0.5:
		var behind := atan2(-body.velocity.x, -body.velocity.z)
		yaw = lerp_angle(yaw, behind, 1.0 - exp(-delta * 1.2))
	var want_pos := target.global_position + Vector3.UP * 1.1
	var want_len := distance
	var want_pitch := pitch
	if _focus_t > 0.0 and is_instance_valid(_focus):
		_focus_t -= delta
		var a := target.global_position
		var b := _focus.global_position
		want_pos = a.lerp(b, 0.5) + Vector3.UP * 0.75
		var to := b - a
		yaw = lerp_angle(yaw, atan2(to.x, to.z) + PI / 2.0 * _focus_side, 1.0 - exp(-delta * 4.0))
		want_len = clampf(to.length() * 1.2 + 1.8, 2.4, 4.0)
		want_pitch = -0.16
		_manual_timer = 0.8
	global_position = global_position.lerp(want_pos, 1.0 - exp(-delta * 6.0))
	arm.spring_length = lerpf(arm.spring_length, want_len, 1.0 - exp(-delta * 4.0))
	rotation.y = yaw
	arm.rotation.x = lerpf(arm.rotation.x, want_pitch, 1.0 - exp(-delta * 5.0))
	target.set("camera_yaw", yaw)
