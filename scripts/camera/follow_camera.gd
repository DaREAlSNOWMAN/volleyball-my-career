class_name FollowCamera
extends Node3D

@export var target: Node3D
@export var ball_target: Node3D
@export var distance: float = 4.2
@export var height: float = 2.1
@export var min_pitch: float = -45.0
@export var max_pitch: float = 40.0
@export var mouse_sensitivity: float = 0.22
@export var follow_smooth_speed: float = 12.0
@export var enable_ball_tracking_assist: bool = true

var yaw: float = 0.0
var pitch: float = -10.0
var is_mouse_captured: bool = true
var is_feed_active: bool = false

@onready var camera: Camera3D = $Camera3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if target:
		global_position = target.global_position + Vector3(0, height, 0)
	_update_camera_orientation()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("toggle_mouse_capture"):
		_toggle_mouse_capture()
		return

	if is_mouse_captured and event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clampf(pitch, min_pitch, max_pitch)
		_update_camera_orientation()

func _process(delta: float):
	if not target:
		return

	var target_base_pos = target.global_position if target.is_inside_tree() else target.position
	var target_focus_pos = target_base_pos + Vector3(0, height, 0)

	# Frame-rate safe interpolation factor
	var follow_blend = 1.0 - exp(-follow_smooth_speed * delta)

	# Subtle framing assist: when ball is in flight, gently bias focus towards the ball
	if enable_ball_tracking_assist and is_feed_active and ball_target and is_instance_valid(ball_target):
		var ball_pos = ball_target.global_position if ball_target.is_inside_tree() else ball_target.position
		# Only bias if ball is in front of athlete (z < target.z + 1.5 and y > 1.0)
		if ball_pos.y > 1.0 and ball_pos.z < target_base_pos.z + 2.0:
			var blend_factor = 0.20 # gentle 20% blend toward ball to keep athlete central
			target_focus_pos = target_focus_pos.lerp(ball_pos, blend_factor)

	if is_inside_tree():
		global_position = global_position.lerp(target_focus_pos, follow_blend)
	else:
		position = position.lerp(target_focus_pos, follow_blend)

func set_feed_tracking(active: bool):
	is_feed_active = active

func toggle_ball_tracking():
	enable_ball_tracking_assist = not enable_ball_tracking_assist

func _update_camera_orientation():
	rotation_degrees.y = yaw
	if camera:
		camera.rotation_degrees.x = pitch
		camera.position = Vector3(0, 0, distance)

func _toggle_mouse_capture():
	is_mouse_captured = not is_mouse_captured
	if is_mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Returns the horizontal forward direction of the camera (Y=0)
func get_camera_forward() -> Vector3:
	var forward = -transform.basis.z
	forward.y = 0.0
	return forward.normalized()

## Returns the horizontal right direction of the camera
func get_camera_right() -> Vector3:
	var right = transform.basis.x
	right.y = 0.0
	return right.normalized()

## Returns attack aim vector in world space from camera center
func get_aim_direction() -> Vector3:
	if not camera:
		return -transform.basis.z
	return -camera.global_transform.basis.z
