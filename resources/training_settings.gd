class_name TrainingSettings
extends Resource

## Configuration for volleyball training launcher & court setup
@export_group("Launcher Setup")
@export var launcher_position: Vector3 = Vector3(2.5, 0.8, -4.5)
@export var feed_target: Vector3 = Vector3(0.0, 3.2, 2.5)
@export var feed_arc_height: float = 4.8
@export var feed_duration: float = 1.6
@export var auto_feed_delay: float = 2.5

@export_group("Spike Training")
@export var exercise_name: String = "Spike Training (M1)"
@export var required_reps: int = 10
@export var auto_reset_after_landing_delay: float = 2.0
