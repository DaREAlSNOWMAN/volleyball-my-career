class_name TrainingSettings
extends Resource

enum DifficultyPreset {
	BEGINNER = 0,
	STANDARD = 1,
	ADVANCED = 2
}

@export var current_difficulty: DifficultyPreset = DifficultyPreset.BEGINNER

@export_group("Launcher Setup")
@export var launcher_position: Vector3 = Vector3(2.5, 0.8, -4.5)
@export var feed_target: Vector3 = Vector3(0.0, 2.9, 2.5) # Attack sweet spot near net
@export var feed_arc_height: float = 4.8 # Ballistic apex height
@export var feed_duration: float = 1.6 # Total travel time
@export var auto_feed_delay: float = 2.5

@export_group("Spike Training")
@export var exercise_name: String = "Spike Training (M1.2)"
@export var required_reps: int = 10
@export var auto_reset_after_landing_delay: float = 2.0
@export var feed_timeout_duration: float = 4.5 # Safeguard timeout for trapped balls

## Applies preset settings to player attributes and feed tolerances
func apply_difficulty_preset(preset: DifficultyPreset, player_attrs: PlayerAttributes = null):
	current_difficulty = preset
	match preset:
		DifficultyPreset.BEGINNER:
			feed_arc_height = 5.2
			feed_target = Vector3(0.0, 2.9, 2.5)
			if player_attrs:
				player_attrs.hit_assist_tolerance = 1.60
				player_attrs.timing_window_clean = 0.35
				player_attrs.timing_window_weak = 0.60
				player_attrs.hitting_power = 16.5
		DifficultyPreset.STANDARD:
			feed_arc_height = 4.8
			feed_target = Vector3(0.2, 2.9, 2.3)
			if player_attrs:
				player_attrs.hit_assist_tolerance = 1.35
				player_attrs.timing_window_clean = 0.25
				player_attrs.timing_window_weak = 0.45
				player_attrs.hitting_power = 17.0
		DifficultyPreset.ADVANCED:
			feed_arc_height = 4.4
			feed_target = Vector3(0.5, 2.9, 2.1)
			if player_attrs:
				player_attrs.hit_assist_tolerance = 1.15
				player_attrs.timing_window_clean = 0.18
				player_attrs.timing_window_weak = 0.35
				player_attrs.hitting_power = 18.0

static func get_difficulty_name(preset: DifficultyPreset) -> String:
	match preset:
		DifficultyPreset.BEGINNER:
			return "Beginner"
		DifficultyPreset.STANDARD:
			return "Standard"
		DifficultyPreset.ADVANCED:
			return "Advanced"
		_:
			return "Standard"
