class_name TrainingManager
extends Node

const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")
const ContactResolver = preload("res://scripts/systems/contact_resolver.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const VolleyballController = preload("res://scripts/ball/volleyball_controller.gd")
const TrainingLauncher = preload("res://scripts/training/training_launcher.gd")
const TrainingHUD = preload("res://scripts/ui/training_hud.gd")
const TrainingSettings = preload("res://resources/training_settings.gd")
const PlayerAttributes = preload("res://resources/player_attributes.gd")

signal attempt_started()
signal attempt_completed(result: Dictionary)

@export var player: PlayerController
@export var ball: VolleyballController
@export var launcher: TrainingLauncher
@export var hud: TrainingHUD
@export var settings: Resource # TrainingSettings

# Statistics tracking
var total_reps: int = 0
var successful_hits: int = 0
var missed_attempts: int = 0
var in_bounds_hits: int = 0
var out_of_bounds_hits: int = 0

var current_feed_active: bool = false
var ball_has_been_hit_in_feed: bool = false
var auto_reset_timer: float = 0.0

func _ready():
	if not settings:
		settings = TrainingSettings.new()

	if player:
		player.attack_attempted.connect(_on_player_attack_attempted)
	if ball:
		ball.ball_landed.connect(_on_ball_landed)
		ball.ball_net_hit.connect(_on_ball_net_hit)

	_update_hud_display()
	# Kick off initial feed shortly after startup
	call_deferred("_initial_feed")

func _initial_feed():
	request_feed()

func _process(delta: float):
	if auto_reset_timer > 0.0:
		auto_reset_timer -= delta
		if auto_reset_timer <= 0.0:
			reset_feed()

	if Input.is_action_just_pressed("request_feed"):
		request_feed()
	elif Input.is_action_just_pressed("reset_ball"):
		reset_feed()

func request_feed():
	if not launcher or not ball:
		return

	auto_reset_timer = 0.0
	current_feed_active = true
	ball_has_been_hit_in_feed = false
	launcher.feed_ball(ball)
	total_reps += 1
	_update_hud_display()
	if hud:
		hud.show_feedback("Incoming Set! Time your jump and spike", true, 1.5)
	attempt_started.emit()

func reset_feed():
	auto_reset_timer = 0.0
	current_feed_active = false
	ball_has_been_hit_in_feed = false
	if ball:
		ball.reset(Vector3(0, -10, 0))
	if hud:
		hud.show_feedback("Feed Reset. Press [F] for new ball", true, 1.2)

func _on_player_attack_attempted(player_pos: Vector3, is_airborne: bool, aim_direction: Vector3):
	if not ball or not current_feed_active:
		return

	var contact_result = ContactResolver.resolve_spike(
		player_pos,
		is_airborne,
		ball.global_position,
		aim_direction,
		player.attributes
	)

	player.register_contact_result(contact_result)

	if contact_result.quality != ContactResolver.HitQuality.MISS:
		ball_has_been_hit_in_feed = true
		successful_hits += 1
		ball.apply_spike(contact_result.impulse, contact_result.quality)
		if hud:
			hud.show_feedback(contact_result.message, true, 2.0)
	else:
		missed_attempts += 1
		if hud:
			hud.show_feedback(contact_result.message, false, 1.5)

	_update_hud_display()

func _on_ball_landed(landing_zone: int, pos: Vector3):
	if not current_feed_active:
		return

	var zone_desc = ""
	var is_in = false

	if ball_has_been_hit_in_feed:
		if landing_zone == CourtGeometry.LandingZone.OPPONENT_COURT:
			in_bounds_hits += 1
			is_in = true
			zone_desc = "IN-BOUNDS! Point!"
		elif landing_zone == CourtGeometry.LandingZone.PLAYER_COURT:
			out_of_bounds_hits += 1
			zone_desc = "Fell on own side"
		else:
			out_of_bounds_hits += 1
			zone_desc = "OUT OF BOUNDS!"
		if hud:
			hud.show_feedback("%s (%0.1f, %0.1f)" % [zone_desc, pos.x, pos.z], is_in, 2.2)
	else:
		if hud:
			hud.show_feedback("Ball landed untouched. Press [F] for next feed", false, 1.5)

	_update_hud_display()
	current_feed_active = false
	auto_reset_timer = settings.auto_reset_after_landing_delay

	var attempt_data = {
		"reps": total_reps,
		"was_hit": ball_has_been_hit_in_feed,
		"is_in": is_in,
		"landing_zone": landing_zone,
		"landing_position": pos
	}
	attempt_completed.emit(attempt_data)

func _on_ball_net_hit():
	if hud and current_feed_active:
		hud.show_feedback("Hit the net!", false, 1.5)

func _update_hud_display():
	if hud:
		hud.update_stats(successful_hits, missed_attempts, in_bounds_hits, out_of_bounds_hits, total_reps)
