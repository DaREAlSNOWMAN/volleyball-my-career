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

signal attempt_started(feed_index: int)
signal training_state_changed(old_state: int, new_state: int)
signal attempt_completed(result: Dictionary)

## Training state sequence: IDLE -> FEEDING -> ATTACK_WINDOW -> RESULT -> RESET
enum Phase {
	IDLE = 0,
	FEEDING = 1,
	ATTACK_WINDOW = 2,
	RESULT = 3,
	RESET = 4
}

@export var player: PlayerController
@export var ball: VolleyballController
@export var launcher: TrainingLauncher
@export var hud: TrainingHUD
@export var settings: Resource # TrainingSettings

# Statistics tracking
var total_feeds: int = 0
var completed_attempts: int = 0
var clean_hits: int = 0
var weak_hits: int = 0
var missed_swings: int = 0
var untouched_feeds: int = 0
var in_bounds_hits: int = 0
var out_of_bounds_hits: int = 0

var current_phase: Phase = Phase.IDLE
var ball_has_been_hit: bool = false
var player_swung_at_ball: bool = false
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

	_check_attack_window()

## Evaluates whether the ball is currently in the attackable window for HUD and state
func _check_attack_window():
	if current_phase != Phase.FEEDING and current_phase != Phase.ATTACK_WINDOW:
		return

	if not ball or not player:
		return

	var ball_pos = ball.global_position if ball.is_inside_tree() else ball.position
	var player_pos = player.global_position if player.is_inside_tree() else player.position
	var facing_dir = player.get_player_facing_direction() if player.has_method("get_player_facing_direction") else Vector3(0, 0, -1)

	var sweet_spot = ContactResolver.get_attack_sweet_spot(player_pos, facing_dir, player.attributes)
	var dist = sweet_spot.distance_to(ball_pos)
	var max_reach = player.attributes.hit_assist_tolerance

	var in_window = (dist <= max_reach and ball_pos.y >= 2.0 and not ball_has_been_hit)

	if in_window and current_phase == Phase.FEEDING:
		_set_phase(Phase.ATTACK_WINDOW)
		if hud:
			hud.set_window_readiness(true)
	elif not in_window and current_phase == Phase.ATTACK_WINDOW and not ball_has_been_hit:
		_set_phase(Phase.FEEDING)
		if hud:
			hud.set_window_readiness(false)

func request_feed():
	if not launcher or not ball:
		return

	auto_reset_timer = 0.0
	ball_has_been_hit = false
	player_swung_at_ball = false
	total_feeds += 1

	_set_phase(Phase.FEEDING)
	launcher.feed_ball(ball)

	if player and player.follow_camera and player.follow_camera.has_method("set_feed_tracking"):
		player.follow_camera.set_feed_tracking(true)

	_update_hud_display()
	if hud:
		hud.show_feedback("Incoming Set! Time your approach and jump", true, 1.5)
		hud.set_window_readiness(false)

	attempt_started.emit(total_feeds)

func reset_feed():
	auto_reset_timer = 0.0
	ball_has_been_hit = false
	player_swung_at_ball = false

	if player and player.follow_camera and player.follow_camera.has_method("set_feed_tracking"):
		player.follow_camera.set_feed_tracking(false)

	if ball:
		ball.reset(Vector3(0, -10, 0))

	_set_phase(Phase.IDLE)
	_update_hud_display()
	if hud:
		hud.set_window_readiness(false)
		hud.show_feedback("Feed Ready. Press [F] for ball", true, 1.2)

func _on_player_attack_attempted(player_pos: Vector3, is_airborne: bool, aim_direction: Vector3, facing_dir: Vector3 = Vector3(0, 0, -1)):
	if not ball or (current_phase != Phase.FEEDING and current_phase != Phase.ATTACK_WINDOW):
		return

	player_swung_at_ball = true

	var ball_pos = ball.global_position if ball.is_inside_tree() else ball.position
	var contact_result = ContactResolver.resolve_spike(
		player_pos,
		is_airborne,
		ball_pos,
		aim_direction,
		player.attributes,
		facing_dir
	)

	player.register_contact_result(contact_result)

	if contact_result.quality != ContactResolver.HitQuality.MISS:
		# Attempt to apply spike to ball (returns false if ball already spiked)
		var applied = ball.apply_spike(contact_result.impulse, contact_result.quality)
		if applied:
			ball_has_been_hit = true
			if contact_result.quality == ContactResolver.HitQuality.CLEAN:
				clean_hits += 1
			else:
				weak_hits += 1

			_set_phase(Phase.RESULT)
			if hud:
				hud.show_feedback(contact_result.message, true, 2.0)
				hud.set_window_readiness(false)
	else:
		missed_swings += 1
		if hud:
			hud.show_feedback(contact_result.message, false, 1.5)

	_update_hud_display()

func _on_ball_landed(landing_zone: int, pos: Vector3):
	if current_phase == Phase.IDLE or current_phase == Phase.RESET:
		return

	completed_attempts += 1
	var zone_desc = ""
	var is_in = false

	if ball_has_been_hit:
		if landing_zone == CourtGeometry.LandingZone.OPPONENT_COURT:
			in_bounds_hits += 1
			is_in = true
			zone_desc = "IN-BOUNDS! Point!"
		elif landing_zone == CourtGeometry.LandingZone.PLAYER_COURT:
			out_of_bounds_hits += 1
			zone_desc = "Fell on player side"
		else:
			out_of_bounds_hits += 1
			zone_desc = "OUT OF BOUNDS!"
		if hud:
			hud.show_feedback("%s (%0.1f, %0.1f)" % [zone_desc, pos.x, pos.z], is_in, 2.2)
	else:
		if not player_swung_at_ball:
			untouched_feeds += 1
			if hud:
				hud.show_feedback("Feed untouched. Press [F] to try again", false, 1.5)
		else:
			if hud:
				hud.show_feedback("Swing missed! Ball landed", false, 1.5)

	_set_phase(Phase.RESULT)
	if player and player.follow_camera and player.follow_camera.has_method("set_feed_tracking"):
		player.follow_camera.set_feed_tracking(false)

	_update_hud_display()
	auto_reset_timer = settings.auto_reset_after_landing_delay

	var attempt_data = {
		"feed_index": total_feeds,
		"was_hit": ball_has_been_hit,
		"player_swung": player_swung_at_ball,
		"is_in": is_in,
		"landing_zone": landing_zone,
		"landing_position": pos
	}
	attempt_completed.emit(attempt_data)

func _on_ball_net_hit():
	if hud and (current_phase == Phase.FEEDING or current_phase == Phase.ATTACK_WINDOW or current_phase == Phase.RESULT):
		hud.show_feedback("Ball contacted net!", false, 1.5)

func _set_phase(new_phase: Phase):
	if current_phase == new_phase:
		return
	var old = current_phase
	current_phase = new_phase
	if hud:
		hud.set_training_phase(Phase.keys()[new_phase])
	training_state_changed.emit(old, new_phase)

func _update_hud_display():
	if hud:
		var successful_hits = clean_hits + weak_hits
		hud.update_stats(
			total_feeds,
			completed_attempts,
			clean_hits,
			weak_hits,
			missed_swings,
			untouched_feeds,
			in_bounds_hits,
			out_of_bounds_hits
		)
