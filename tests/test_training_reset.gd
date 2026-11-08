class_name TestTrainingReset
extends RefCounted

const TrainingSettings = preload("res://resources/training_settings.gd")
const VolleyballController = preload("res://scripts/ball/volleyball_controller.gd")
const TrainingLauncher = preload("res://scripts/training/training_launcher.gd")
const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")
const ContactResolver = preload("res://scripts/systems/contact_resolver.gd")
const PlayerAttributes = preload("res://resources/player_attributes.gd")

## Tests repeatable training feeds, state integrity, and real contact pipeline integration
static func run_all() -> bool:
	var passed = true
	passed = passed and test_launcher_feed_arrival_region()
	passed = passed and test_real_contact_pipeline_integration()
	passed = passed and test_repeat_loop_10_times()
	passed = passed and test_ball_reset_invariants()
	passed = passed and test_prevent_multiple_spikes_per_feed()
	return passed

static func test_launcher_feed_arrival_region() -> bool:
	var launcher = TrainingLauncher.new()
	var settings = TrainingSettings.new()
	settings.feed_arc_height = 4.8
	settings.feed_target = Vector3(0.0, 2.9, 2.5)
	launcher.settings = settings

	var ball = VolleyballController.new()
	launcher.feed_ball(ball)

	var v_y = ball.linear_velocity.y
	var apex_y = launcher.get_launcher_position().y + (v_y * v_y) / (2.0 * 9.81)

	if apex_y < 4.0:
		printerr("[FAIL] test_launcher_feed_arrival_region: apex height too low (%f)" % apex_y)
		return false

	if ball.linear_velocity.z <= 0.0:
		printerr("[FAIL] test_launcher_feed_arrival_region: ball should travel toward player side (z > 0)")
		return false

	print("[PASS] test_launcher_feed_arrival_region")
	return true

static func test_real_contact_pipeline_integration() -> bool:
	var attr = PlayerAttributes.new()
	var player_pos = Vector3(0.0, 1.6, 2.5)
	var ball = VolleyballController.new()
	var anchor = ContactResolver.get_contact_anchor(player_pos, Vector3(0, 0, -1), attr)

	ball.launch(Vector3(0, 0, 0), Vector3(0, 5, 2))
	var aim_dir = Vector3(0.0, -0.20, -1.0)

	var contact_res = ContactResolver.resolve_spike(player_pos, true, anchor, aim_dir, attr)
	if contact_res.quality != ContactResolver.HitQuality.CLEAN:
		printerr("[FAIL] test_real_contact_pipeline_integration: expected clean contact")
		return false

	var applied = ball.apply_spike(contact_res.post_contact_velocity, contact_res.quality)
	if not applied or ball.current_state != VolleyballController.BallState.SPIKED:
		printerr("[FAIL] test_real_contact_pipeline_integration: ball failed to apply spike")
		return false

	if ball.linear_velocity.z >= 0.0:
		printerr("[FAIL] test_real_contact_pipeline_integration: spiked ball must travel toward opponent side (z < 0)")
		return false

	print("[PASS] test_real_contact_pipeline_integration")
	return true

static func test_prevent_multiple_spikes_per_feed() -> bool:
	var ball = VolleyballController.new()
	ball.launch(Vector3(0, 1, 0), Vector3(0, 2, 2))

	var first_hit = ball.apply_spike(Vector3(0, -2, -15), 2)
	var second_hit = ball.apply_spike(Vector3(0, -2, -15), 2)

	if not first_hit:
		printerr("[FAIL] test_prevent_multiple_spikes_per_feed: first hit should succeed")
		return false
	if second_hit:
		printerr("[FAIL] test_prevent_multiple_spikes_per_feed: second hit on same ball should be rejected")
		return false

	print("[PASS] test_prevent_multiple_spikes_per_feed")
	return true

static func test_repeat_loop_10_times() -> bool:
	var launcher = TrainingLauncher.new()
	var settings = TrainingSettings.new()
	launcher.settings = settings
	var ball = VolleyballController.new()

	for rep in range(1, 11):
		# 1. Request feed
		launcher.feed_ball(ball)
		if ball.current_state != VolleyballController.BallState.IN_FLIGHT:
			printerr("[FAIL] test_repeat_loop_10_times (rep %d): expected IN_FLIGHT, got %d" % [rep, ball.current_state])
			return false

		if ball.linear_velocity.length() < 1.0:
			printerr("[FAIL] test_repeat_loop_10_times (rep %d): ball launch velocity too low" % rep)
			return false

		# 2. Simulate spike contact through real ContactResolver
		var player_pos = Vector3(0.0, 1.6, 2.5)
		var attr = PlayerAttributes.new()
		var anchor = ContactResolver.get_contact_anchor(player_pos, Vector3(0, 0, -1), attr)
		var contact = ContactResolver.resolve_spike(player_pos, true, anchor, Vector3(0, -0.20, -1), attr)

		var hit_success = ball.apply_spike(contact.post_contact_velocity, contact.quality)
		if not hit_success or ball.current_state != VolleyballController.BallState.SPIKED:
			printerr("[FAIL] test_repeat_loop_10_times (rep %d): expected SPIKED" % rep)
			return false

		# 3. Simulate landing in opponent court
		var landing_pos = Vector3(0.5, 0.0, -4.5)
		ball._process_landing(landing_pos)
		if ball.current_state != VolleyballController.BallState.LANDED or not ball.has_landed:
			printerr("[FAIL] test_repeat_loop_10_times (rep %d): expected LANDED" % rep)
			return false

		# 4. Reset
		launcher.reset_ball()
		if ball.current_state != VolleyballController.BallState.INACTIVE or ball.has_landed or ball.has_been_hit:
			printerr("[FAIL] test_repeat_loop_10_times (rep %d): expected INACTIVE & unhit after reset" % rep)
			return false

	print("[PASS] test_repeat_loop_10_times (10 clean iterations without scene reload)")
	return true

static func test_ball_reset_invariants() -> bool:
	var ball = VolleyballController.new()

	ball.current_state = VolleyballController.BallState.SPIKED
	ball.has_landed = true
	ball.has_been_hit = true
	ball.linear_velocity = Vector3(10, 10, 10)
	ball.angular_velocity = Vector3(5, 5, 5)

	ball.reset(Vector3(0, -10, 0))

	if ball.has_landed != false:
		printerr("[FAIL] test_ball_reset_invariants: has_landed was not reset to false")
		return false
	if ball.has_been_hit != false:
		printerr("[FAIL] test_ball_reset_invariants: has_been_hit was not reset to false")
		return false
	if ball.current_state != VolleyballController.BallState.INACTIVE:
		printerr("[FAIL] test_ball_reset_invariants: current_state not INACTIVE")
		return false
	if ball.linear_velocity != Vector3.ZERO:
		printerr("[FAIL] test_ball_reset_invariants: linear_velocity not ZERO")
		return false
	if ball.angular_velocity != Vector3.ZERO:
		printerr("[FAIL] test_ball_reset_invariants: angular_velocity not ZERO")
		return false
	if ball.position != Vector3(0, -10, 0):
		printerr("[FAIL] test_ball_reset_invariants: position not reset to rest position (%s)" % ball.position)
		return false

	print("[PASS] test_ball_reset_invariants")
	return true
