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

## Feeds a ball along a predictable, readable arc toward the player attack zone
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
	var duration = settings.feed_duration
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.81)

	# Calculate ballistic launch velocity required to land/arrive at target_pos in duration seconds
	var vx = (target_pos.x - start_pos.x) / duration
	var vz = (target_pos.z - start_pos.z) / duration
	var vy = (target_pos.y - start_pos.y + 0.5 * gravity * duration * duration) / duration

	var launch_velocity = Vector3(vx, vy, vz)
	active_ball.launch(start_pos, launch_velocity)
	ball_launched.emit(active_ball)
	return active_ball

func reset_ball():
	if active_ball:
		active_ball.reset(Vector3(0, -10, 0))
