class_name TrainingLauncher
extends Node3D

const VolleyballController = preload("res://scripts/ball/volleyball_controller.gd")
const TrainingSettings = preload("res://resources/training_settings.gd")

signal ball_launched(ball: VolleyballController)

@export var ball_scene: PackedScene
@export var settings: Resource # TrainingSettings

var active_ball: VolleyballController = null

func _ready():
	if not settings:
		settings = TrainingSettings.new()

func get_launcher_position() -> Vector3:
	return global_position if is_inside_tree() else position

## Feeds a ball along a predictable, readable arc toward the player attack zone using apex height
func feed_ball(ball_instance: VolleyballController = null) -> VolleyballController:
	if ball_instance:
		active_ball = ball_instance
	elif not active_ball and ball_scene:
		active_ball = ball_scene.instantiate()
		get_parent().add_child(active_ball)

	if not active_ball:
		printerr("TrainingLauncher: No ball available to launch")
		return null

	var start_pos = get_launcher_position()
	var target_pos = settings.feed_target
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.81)

	# Calculate ballistic arc utilizing settings.feed_arc_height:
	# Peak height H must be at least slightly higher than start and target
	var min_apex = maxf(start_pos.y, target_pos.y) + 0.6
	var apex_height = maxf(settings.feed_arc_height, min_apex)

	# Upward velocity to reach apex from start: v_y = sqrt(2 * g * (apex - y_start))
	var vy = sqrt(2.0 * gravity * (apex_height - start_pos.y))
	# Time to ascend to apex: t_up = vy / g
	var t_up = vy / gravity
	# Time to descend from apex to target: t_down = sqrt(2 * (apex - y_target) / g)
	var t_down = sqrt(2.0 * (apex_height - target_pos.y) / gravity)
	var total_time = t_up + t_down

	# Horizontal velocities to hit target_pos exactly at total_time
	var vx = (target_pos.x - start_pos.x) / total_time
	var vz = (target_pos.z - start_pos.z) / total_time

	var launch_velocity = Vector3(vx, vy, vz)
	active_ball.launch(start_pos, launch_velocity)
	ball_launched.emit(active_ball)
	return active_ball

func reset_ball():
	if active_ball:
		active_ball.reset(Vector3(0, -10, 0))
