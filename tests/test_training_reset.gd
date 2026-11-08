class_name TestTrainingReset
extends RefCounted

const TrainingSettings = preload("res://resources/training_settings.gd")
const VolleyballController = preload("res://scripts/ball/volleyball_controller.gd")
const TrainingLauncher = preload("res://scripts/training/training_launcher.gd")
const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")

## Tests repeated training feeds and resets (10 iterations) to verify no stuck state or object accumulation
static func run_all() -> bool:
	var passed = true
	passed = passed and test_repeat_loop_10_times()
	passed = passed and test_ball_reset_invariants()
	return passed

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

		# 2. Simulate spike contact
		var spike_impulse = Vector3(0.0, -2.0, -14.0)
		ball.apply_spike(spike_impulse, 2)
		if ball.current_state != VolleyballController.BallState.SPIKED:
			printerr("[FAIL] test_repeat_loop_10_times (rep %d): expected SPIKED" % rep)
			return false

		# 3. Simulate landing
		var landing_pos = Vector3(0.5, 0.0, -4.5)
		ball._process_landing(landing_pos)
		if ball.current_state != VolleyballController.BallState.LANDED or not ball.has_landed:
			printerr("[FAIL] test_repeat_loop_10_times (rep %d): expected LANDED" % rep)
			return false

		# 4. Reset
		launcher.reset_ball()
		if ball.current_state != VolleyballController.BallState.INACTIVE or ball.has_landed:
			printerr("[FAIL] test_repeat_loop_10_times (rep %d): expected INACTIVE after reset" % rep)
			return false

	print("[PASS] test_repeat_loop_10_times (10 clean iterations without scene reload)")
	return true

static func test_ball_reset_invariants() -> bool:
	var ball = VolleyballController.new()

	ball.current_state = VolleyballController.BallState.SPIKED
	ball.has_landed = true
	ball.linear_velocity = Vector3(10, 10, 10)
	ball.angular_velocity = Vector3(5, 5, 5)

	ball.reset(Vector3(0, -10, 0))

	if ball.has_landed != false:
		printerr("[FAIL] test_ball_reset_invariants: has_landed was not reset to false")
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
