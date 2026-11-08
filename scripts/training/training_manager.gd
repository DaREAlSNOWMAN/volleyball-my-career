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

signal attempt_started(attempt_id: int)
signal training_state_changed(old_state: int, new_state: int)
signal attempt_completed(result: Dictionary)

## Strict state sequence: IDLE -> PREPARING -> FEEDING -> ATTACKABLE -> RESOLVING -> RESULT -> RESET
enum Phase {
	IDLE = 0,
	PREPARING = 1,
	FEEDING = 2,
	ATTACKABLE = 3,
	RESOLVING = 4,
	RESULT = 5,
	RESET = 6
}

@export var player: PlayerController
@export var ball: VolleyballController
@export var launcher: TrainingLauncher
@export var hud: TrainingHUD
@export var settings: Resource # TrainingSettings

# Unique attempt identification to prevent stale callbacks
var current_attempt_id: int = 0

# Accounting metrics
var total_feeds: int = 0
var completed_attempts: int = 0
var clean_hits: int = 0
var weak_hits: int = 0
var missed_swings: int = 0
var untouched_feeds: int = 0
var net_faults: int = 0
var feed_net_collisions: int = 0
var in_bounds_hits: int = 0
var out_of_bounds_hits: int = 0
var manual_cancellations: int = 0

var current_phase: Phase = Phase.IDLE
var ball_has_been_hit: bool = false
var player_swung_at_ball: bool = false
var attempt_is_resolved: bool = false

var auto_reset_timer: float = 0.0
var feed_timeout_timer: float = 0.0

# Telemetry tracking for latest attempt
var telemetry_last_feed_time: float = 0.0
var telemetry_contact_time: float = 0.0
var telemetry_contact_distance: float = 0.0
var telemetry_landing_position: Vector3 = Vector3.ZERO
var telemetry_post_contact_velocity: Vector3 = Vector3.ZERO

func _ready():
	if not settings:
		settings = TrainingSettings.new()

	if player and settings:
		settings.apply_difficulty_preset(settings.current_difficulty, player.attributes)

	if player:
		player.attack_attempted.connect(_on_player_attack_attempted)
		if player.has_signal("attack_contact_check"):
			player.attack_contact_check.connect(_on_player_attack_contact_check)
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

	if current_phase == Phase.FEEDING or current_phase == Phase.ATTACKABLE:
		feed_timeout_timer += delta
		var max_timeout = settings.feed_timeout_duration if "feed_timeout_duration" in settings else 4.5
		if feed_timeout_timer >= max_timeout:
			_handle_feed_timeout()

	if Input.is_action_just_pressed("request_feed"):
		request_feed()
	elif Input.is_action_just_pressed("reset_ball"):
		manual_reset()

	_check_attack_window()

func set_difficulty(preset: TrainingSettings.DifficultyPreset):
	if settings:
		settings.apply_difficulty_preset(preset, player.attributes if player else null)
		_update_hud_display()
		if hud:
			hud.show_feedback("Difficulty: " + TrainingSettings.get_difficulty_name(preset), true, 1.5)

## Evaluates whether the ball is currently in the attackable window
func _check_attack_window():
	if current_phase != Phase.FEEDING and current_phase != Phase.ATTACKABLE:
		return

	if not ball or not player:
		return

	var ball_pos = ball.global_position if ball.is_inside_tree() else ball.position
	var player_pos = player.global_position if player.is_inside_tree() else player.position
	var facing_dir = player.get_player_facing_direction() if player.has_method("get_player_facing_direction") else Vector3(0, 0, -1)

	var anchor = ContactResolver.get_contact_anchor(player_pos, facing_dir, player.attributes)
	var dist = anchor.distance_to(ball_pos)
	var max_reach = player.attributes.hit_assist_tolerance

	var in_window = (dist <= max_reach and ball_pos.y >= 2.0 and not ball_has_been_hit)

	if in_window and current_phase == Phase.FEEDING:
		_set_phase(Phase.ATTACKABLE)
		if hud:
			hud.set_window_readiness(true)
	elif not in_window and current_phase == Phase.ATTACKABLE and not ball_has_been_hit:
		_set_phase(Phase.FEEDING)
		if hud:
			hud.set_window_readiness(false)

func request_feed():
	if not launcher or not ball:
		return

	if current_phase == Phase.FEEDING or current_phase == Phase.ATTACKABLE:
		manual_cancellations += 1

	current_attempt_id += 1
	var this_attempt = current_attempt_id

	auto_reset_timer = 0.0
	feed_timeout_timer = 0.0
	ball_has_been_hit = false
	player_swung_at_ball = false
	attempt_is_resolved = false
	telemetry_last_feed_time = Time.get_ticks_msec() / 1000.0
	telemetry_contact_distance = 0.0
	telemetry_post_contact_velocity = Vector3.ZERO
	total_feeds += 1

	_set_phase(Phase.PREPARING)
	if ball:
		ball.reset(Vector3(0, -10, 0))

	launcher.feed_ball(ball)
	_set_phase(Phase.FEEDING)

	if player and player.follow_camera and player.follow_camera.has_method("set_feed_tracking"):
		player.follow_camera.set_feed_tracking(true)

	_update_hud_display()
	if hud:
		hud.show_feedback("Incoming Set! Time your approach and jump", true, 1.5)
		hud.set_window_readiness(false)

	attempt_started.emit(this_attempt)

func manual_reset():
	if current_phase == Phase.FEEDING or current_phase == Phase.ATTACKABLE:
		manual_cancellations += 1
	reset_feed()

func reset_feed():
	current_attempt_id += 1
	auto_reset_timer = 0.0
	feed_timeout_timer = 0.0
	ball_has_been_hit = false
	player_swung_at_ball = false
	attempt_is_resolved = false

	if player and player.follow_camera and player.follow_camera.has_method("set_feed_tracking"):
		player.follow_camera.set_feed_tracking(false)

	if ball:
		ball.reset(Vector3(0, -10, 0))

	_set_phase(Phase.RESET)
	_set_phase(Phase.IDLE)
	_update_hud_display()
	if hud:
		hud.set_window_readiness(false)
		hud.show_feedback("Feed Reset. Press [F] for new ball", true, 1.2)

func _handle_feed_timeout():
	if attempt_is_resolved:
		return
	attempt_is_resolved = true
	completed_attempts += 1
	if not player_swung_at_ball and not ball_has_been_hit:
		untouched_feeds += 1
	_set_phase(Phase.RESULT)
	if hud:
		hud.show_feedback("Feed timed out.", false, 1.5)
		hud.set_window_readiness(false)
	_update_hud_display()
	auto_reset_timer = 1.0

## Invoked when player initiates attack swing
func _on_player_attack_attempted(
	player_pos: Vector3,
	is_airborne: bool,
	aim_direction: Vector3,
	facing_dir: Vector3 = Vector3(0, 0, -1),
	swing_phase: int = 1, # WINDUP
	swing_elapsed: float = 0.0
):
	if not ball or (current_phase != Phase.FEEDING and current_phase != Phase.ATTACKABLE):
		return

	player_swung_at_ball = true

	# Check contact attempt if executed in active contact phase
	if swing_phase == ContactResolver.AttackSwingPhase.ACTIVE_CONTACT:
		_evaluate_contact(player_pos, is_airborne, aim_direction, facing_dir, swing_phase, swing_elapsed)

## Continuous physics-frame contact check during ACTIVE_CONTACT frames
func _on_player_attack_contact_check(
	player_pos: Vector3,
	is_airborne: bool,
	aim_direction: Vector3,
	facing_dir: Vector3,
	swing_phase: int,
	swing_elapsed: float
):
	if not ball or ball_has_been_hit:
		return
	if current_phase != Phase.FEEDING and current_phase != Phase.ATTACKABLE:
		return

	_evaluate_contact(player_pos, is_airborne, aim_direction, facing_dir, swing_phase, swing_elapsed)

func _evaluate_contact(
	player_pos: Vector3,
	is_airborne: bool,
	aim_direction: Vector3,
	facing_dir: Vector3,
	swing_phase: int,
	swing_elapsed: float
):
	var ball_pos = ball.global_position if ball.is_inside_tree() else ball.position
	var contact_result = ContactResolver.resolve_spike(
		player_pos,
		is_airborne,
		ball_pos,
		aim_direction,
		player.attributes,
		facing_dir,
		swing_phase,
		swing_elapsed
	)

	player.register_contact_result(contact_result)

	if contact_result.quality != ContactResolver.HitQuality.MISS:
		var applied = ball.apply_spike(contact_result.post_contact_velocity, contact_result.quality)
		if applied:
			ball_has_been_hit = true
			telemetry_contact_distance = contact_result.distance_to_anchor
			telemetry_post_contact_velocity = contact_result.post_contact_velocity
			telemetry_contact_time = Time.get_ticks_msec() / 1000.0

			if contact_result.quality == ContactResolver.HitQuality.CLEAN:
				clean_hits += 1
			else:
				weak_hits += 1

			_set_phase(Phase.RESOLVING)
			if hud:
				hud.show_feedback(contact_result.message, true, 2.0)
				hud.set_window_readiness(false)
	else:
		# Only record missed swings if active contact completes without any hit
		if swing_phase == ContactResolver.AttackSwingPhase.ACTIVE_CONTACT and not ball_has_been_hit:
			# If swing completes or misses
			pass

	_update_hud_display()

func _on_ball_landed(landing_zone: int, pos: Vector3):
	if current_phase == Phase.IDLE or current_phase == Phase.PREPARING or current_phase == Phase.RESET or attempt_is_resolved:
		return

	attempt_is_resolved = true
	completed_attempts += 1
	telemetry_landing_position = pos
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
			missed_swings += 1
			if hud:
				hud.show_feedback("Swing missed! Ball landed", false, 1.5)

	_set_phase(Phase.RESULT)
	if player and player.follow_camera and player.follow_camera.has_method("set_feed_tracking"):
		player.follow_camera.set_feed_tracking(false)

	_update_hud_display()
	auto_reset_timer = settings.auto_reset_after_landing_delay

	var attempt_data = {
		"attempt_id": current_attempt_id,
		"feed_index": total_feeds,
		"was_hit": ball_has_been_hit,
		"player_swung": player_swung_at_ball,
		"is_in": is_in,
		"landing_zone": landing_zone,
		"landing_position": pos,
		"contact_distance": telemetry_contact_distance,
		"post_contact_velocity": telemetry_post_contact_velocity
	}
	attempt_completed.emit(attempt_data)

func _on_ball_net_hit():
	if current_phase == Phase.FEEDING or current_phase == Phase.ATTACKABLE:
		# Incoming set hit the net before player attack
		feed_net_collisions += 1
		if hud:
			hud.show_feedback("Feed clipped net!", false, 1.5)
	elif current_phase == Phase.RESOLVING:
		# Spiked ball hit the net
		net_faults += 1
		if hud:
			hud.show_feedback("Net Fault! Attack hit net", false, 1.5)

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
		var diff_name = TrainingSettings.get_difficulty_name(settings.current_difficulty) if settings else "Standard"
		if hud.has_method("set_difficulty_display"):
			hud.set_difficulty_display(diff_name)
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
