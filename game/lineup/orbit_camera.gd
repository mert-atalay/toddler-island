extends Node3D
## A simple look-around camera for the lineup.
## Drag with the mouse to orbit, scroll to zoom, W A S D to move, number keys for the rows, Tab for the next.

signal preset_changed(index: int)

var presets: Array = []
var index := 0
var target := Vector3.ZERO
var yaw := 0.0
var pitch := -0.2
var dist := 8.0
var cam := Camera3D.new()

var _goal_target := Vector3.ZERO
var _goal_yaw := 0.0
var _goal_pitch := -0.2
var _goal_dist := 8.0


func _ready() -> void:
	cam.fov = 45.0
	cam.near = 0.05
	cam.far = 1500.0
	add_child(cam)
	cam.make_current()


func go_to(i: int, snap := false) -> void:
	if presets.is_empty():
		return
	index = posmod(i, presets.size())
	var p: Dictionary = presets[index]
	_goal_target = p["target"]
	_goal_yaw = p["yaw"]
	_goal_pitch = p["pitch"]
	_goal_dist = p["dist"]
	if snap:
		target = _goal_target
		yaw = _goal_yaw
		pitch = _goal_pitch
		dist = _goal_dist
		_apply()
	preset_changed.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		if motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
			_goal_yaw -= motion.relative.x * 0.005
			_goal_pitch = clampf(_goal_pitch - motion.relative.y * 0.004, -1.4, 0.05)
		elif motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var right := cam.global_transform.basis.x
			_goal_target += (-right * motion.relative.x + Vector3.UP * motion.relative.y) * dist * 0.0015
		return
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_goal_dist = maxf(1.0, _goal_dist * 0.88)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_goal_dist = minf(400.0, _goal_dist * 1.14)
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.keycode >= KEY_1 and key.keycode <= KEY_9:
			# number keys jump to the whole-row views; Tab steps through every view, close-ups included
			var wanted := key.keycode - KEY_1
			var count := -1
			for i in presets.size():
				if not String(presets[i]["key"]).contains("-close"):
					count += 1
					if count == wanted:
						go_to(i)
						break
		elif key.keycode == KEY_TAB:
			go_to(index - 1 if key.shift_pressed else index + 1)
		elif key.keycode == KEY_ESCAPE:
			get_tree().quit()


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if move != Vector3.ZERO:
		_goal_target += move.normalized().rotated(Vector3.UP, yaw) * dist * 0.6 * delta
	var k := 1.0 - exp(-delta * 6.0)
	target = target.lerp(_goal_target, k)
	yaw = lerp_angle(yaw, _goal_yaw, k)
	pitch = lerpf(pitch, _goal_pitch, k)
	dist = lerpf(dist, _goal_dist, k)
	_apply()


func _apply() -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.global_position = target + offset
	cam.look_at(target, Vector3.UP)
