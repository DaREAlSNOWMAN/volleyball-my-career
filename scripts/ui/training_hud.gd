class_name TrainingHUD
extends Control

@onready var exercise_title_label: Label = $MarginContainer/VBoxContainer/TopBar/ExerciseTitle
@onready var difficulty_label: Label = $MarginContainer/VBoxContainer/TopBar/DifficultyLabel
@onready var phase_label: Label = $MarginContainer/VBoxContainer/TopBar/PhaseLabel
@onready var stats_label: Label = $MarginContainer/VBoxContainer/TopBar/StatsContainer/StatsLabel
@onready var readiness_indicator: PanelContainer = $MarginContainer/VBoxContainer/ReadinessContainer/ReadinessPanel
@onready var readiness_label: Label = $MarginContainer/VBoxContainer/ReadinessContainer/ReadinessPanel/ReadinessLabel
@onready var feedback_panel: PanelContainer = $MarginContainer/VBoxContainer/CenterFeedback/FeedbackPanel
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/CenterFeedback/FeedbackPanel/FeedbackLabel
@onready var controls_hint_label: Label = $MarginContainer/VBoxContainer/BottomBar/ControlsHint

var feedback_timer: float = 0.0

func _ready():
	feedback_panel.visible = false
	readiness_indicator.visible = false

func _process(delta: float):
	if feedback_timer > 0.0:
		feedback_timer -= delta
		if feedback_timer <= 0.0:
			feedback_panel.visible = false

func set_exercise_title(title: String):
	if exercise_title_label:
		exercise_title_label.text = title

func set_difficulty_display(diff_name: String):
	if difficulty_label:
		difficulty_label.text = "[" + diff_name + "]"

func set_training_phase(phase_name: String):
	if phase_label:
		phase_label.text = "Phase: " + phase_name

func set_window_readiness(is_ready: bool):
	if readiness_indicator:
		readiness_indicator.visible = is_ready

func update_stats(
	feeds: int,
	completed: int,
	clean: int,
	weak: int,
	missed: int,
	untouched: int,
	in_bounds: int,
	out_of_bounds: int
):
	if stats_label:
		stats_label.text = "Feeds: %d | Done: %d | Hits: %d (C: %d, W: %d) | Miss: %d | Untouched: %d | In: %d | Out: %d" % [
			feeds, completed, (clean + weak), clean, weak, missed, untouched, in_bounds, out_of_bounds
		]

func show_feedback(message: String, is_positive: bool = true, duration: float = 2.0):
	if not feedback_panel or not feedback_label:
		return
	feedback_label.text = message
	var color = Color(0.2, 0.9, 0.3) if is_positive else Color(0.9, 0.3, 0.2)
	feedback_label.modulate = color
	feedback_panel.visible = true
	feedback_timer = duration
