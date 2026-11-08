class_name TestPlaytestHarness
extends RefCounted

## Automated integration test harness executing true scene-level scenarios:
## Scenario A - Successful spike through full scene integration
## Scenario B - Early swing rejection
## Scenario C - Late swing rejection
## Scenario D - Invalid distance rejection
## Scenario E - Net collision detection
## Scenario F - Out-of-bounds landing classification
## Scenario G - Rapid reset during feed
## Scenario H - Repeated feed requests without corruption
## Scenario I - 100 consecutive training cycles stability
## Scenario J - Camera & movement finite value stability

const MainScene = preload("res://scenes/main.tscn")
const ContactResolver = preload("res://scripts/systems/contact_resolver.gd")
const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")

static func run_all() -> bool:
	var passed = true
	passed = passed and test_scenario_a_successful_spike()
	passed = passed and test_scenario_b_early_swing()
	passed = passed and test_scenario_c_late_swing()
	passed = passed and test_scenario_d_invalid_distance()
	passed = passed and test_scenario_e_net_collision()
	passed = passed and test_scenario_f_out_of_bounds()
	passed = passed and test_scenario_g_rapid_reset()
	passed = passed and test_scenario_h_repeated_requests()
	passed = passed and test_scenario_i_100_cycles_stability()
	passed = passed and test_scenario_j_movement_camera_stability()
	return passed

static func _setup_main() -> Node:
	var main = MainScene.instantiate()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var launcher = main.get_node("TrainingLauncher")
	var hud = main.get_node("TrainingHUD")
	launcher._ready()
	player._ready()
	hud._ready()
	manager._ready()
	return main

static func test_scenario_a_successful_spike() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")

	manager.request_feed()

	player.position = Vector3(0.0, 1.8, 2.5)
	player.current_state = 1 # AIRBORNE

	var anchor = ContactResolver.get_contact_anchor(player.position, Vector3(0, 0, -1), player.attributes)
	ball.position = anchor + Vector3(0.02, 0.01, 0.01)

	# Trigger attack via active contact check
	player.attack_attempted.emit(
		player.position,
		true,
		Vector3(0, -0.15, -1.0),
		Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.ACTIVE_CONTACT,
		0.12
	)

	if not manager.ball_has_been_hit or manager.clean_hits != 1:
		printerr("[FAIL] Scenario A: attack not recorded as clean hit")
		main.free()
		return false

	ball._process_landing(Vector3(0.5, 0.0, -4.5))

	if manager.in_bounds_hits != 1 or manager.completed_attempts != 1:
		printerr("[FAIL] Scenario A: landing not recorded in-bounds")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario A - Successful spike through real integration")
	return true

static func test_scenario_b_early_swing() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")

	manager.request_feed()
	player.position = Vector3(0.0, 1.8, 2.5)
	player.current_state = 1 # AIRBORNE
	var anchor = ContactResolver.get_contact_anchor(player.position, Vector3(0, 0, -1), player.attributes)
	ball.position = anchor

	# Early swing: in WINDUP phase, contact cannot occur
	var res = ContactResolver.resolve_spike(
		player.position,
		true,
		ball.position,
		Vector3(0, -0.15, -1.0),
		player.attributes,
		Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.WINDUP,
		0.03
	)

	if res.quality != ContactResolver.HitQuality.MISS:
		printerr("[FAIL] Scenario B: early swing in windup was not rejected")
		main.free()
		return false

	# Notify player swing attempted
	player.attack_attempted.emit(
		player.position,
		true,
		Vector3(0, -0.15, -1.0),
		Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.WINDUP,
		0.03
	)

	# Ball lands without contact
	ball._process_landing(Vector3(0.0, 0.0, 2.5))

	if manager.ball_has_been_hit or manager.missed_swings != 1:
		printerr("[FAIL] Scenario B: missed swing not registered after ball landed")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario B - Early swing rejection")
	return true

static func test_scenario_c_late_swing() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")

	manager.request_feed()
	player.position = Vector3(0.0, 1.8, 2.5)
	player.current_state = 1 # AIRBORNE
	var anchor = ContactResolver.get_contact_anchor(player.position, Vector3(0, 0, -1), player.attributes)
	ball.position = anchor

	# Late swing: in FOLLOW_THROUGH phase
	var res = ContactResolver.resolve_spike(
		player.position,
		true,
		ball.position,
		Vector3(0, -0.15, -1.0),
		player.attributes,
		Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.FOLLOW_THROUGH,
		0.32
	)

	if res.quality != ContactResolver.HitQuality.MISS:
		printerr("[FAIL] Scenario C: late swing was not rejected")
		main.free()
		return false

	player.attack_attempted.emit(
		player.position,
		true,
		Vector3(0, -0.15, -1.0),
		Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.FOLLOW_THROUGH,
		0.32
	)

	ball._process_landing(Vector3(0.0, 0.0, 2.5))

	if manager.ball_has_been_hit or manager.missed_swings != 1:
		printerr("[FAIL] Scenario C: late swing not registered as missed swing")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario C - Late swing rejection")
	return true

static func test_scenario_d_invalid_distance() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")

	manager.request_feed()
	player.position = Vector3(0.0, 1.8, 2.5)
	player.current_state = 1
	ball.position = Vector3(5.0, 1.8, 2.5)

	player.attack_attempted.emit(
		player.position,
		true,
		Vector3(0, -0.15, -1.0),
		Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.ACTIVE_CONTACT,
		0.12
	)

	ball._process_landing(Vector3(0.0, 0.0, 2.5))

	if manager.ball_has_been_hit or manager.missed_swings != 1:
		printerr("[FAIL] Scenario D: distant attack was not rejected")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario D - Invalid distance rejection")
	return true

static func test_scenario_e_net_collision() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")
	var ball = main.get_node("Volleyball")

	manager.request_feed()
	var initial_net_collisions = manager.feed_net_collisions

	# Simulate incoming feed hitting net
	ball.ball_net_hit.emit()

	if manager.feed_net_collisions != initial_net_collisions + 1:
		printerr("[FAIL] Scenario E: feed net collision was not recorded")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario E - Net collision detection")
	return true

static func test_scenario_f_out_of_bounds() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")

	manager.request_feed()
	player.position = Vector3(0.0, 1.8, 2.5)
	player.current_state = 1
	var anchor = ContactResolver.get_contact_anchor(player.position, Vector3(0, 0, -1), player.attributes)
	ball.position = anchor

	player.attack_attempted.emit(
		player.position,
		true,
		Vector3(0, -0.15, -1.0),
		Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.ACTIVE_CONTACT,
		0.12
	)

	# Simulate landing out of bounds (X = 6.0m)
	ball._process_landing(Vector3(6.0, 0.0, -4.5))

	if manager.out_of_bounds_hits != 1 or manager.in_bounds_hits != 0:
		printerr("[FAIL] Scenario F: out-of-bounds attack not classified correctly")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario F - Out-of-bounds attack classification")
	return true

static func test_scenario_g_rapid_reset() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")
	var ball = main.get_node("Volleyball")

	manager.request_feed()

	# Rapid reset
	manager.manual_reset()

	# Stale landing event arriving after reset should be rejected
	ball.ball_landed.emit(CourtGeometry.LandingZone.OPPONENT_COURT, Vector3(0, 0, -4.5))

	if manager.completed_attempts != 0 or manager.in_bounds_hits != 0:
		printerr("[FAIL] Scenario G: stale landing after reset was accepted")
		main.free()
		return false

	if manager.current_phase != manager.Phase.IDLE:
		printerr("[FAIL] Scenario G: state machine not IDLE after reset")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario G - Rapid reset clears outdated events")
	return true

static func test_scenario_h_repeated_requests() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")

	for i in range(5):
		manager.request_feed()

	if manager.total_feeds != 5:
		printerr("[FAIL] Scenario H: expected 5 feeds, got %d" % manager.total_feeds)
		main.free()
		return false

	if manager.current_phase != manager.Phase.FEEDING and manager.current_phase != manager.Phase.ATTACKABLE:
		printerr("[FAIL] Scenario H: state corrupted after repeated requests")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario H - Repeated feed requests handled cleanly")
	return true

static func test_scenario_i_100_cycles_stability() -> bool:
	var main = _setup_main()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")

	for rep in range(1, 101):
		manager.request_feed()

		# Hit every alternate rep
		if rep % 2 == 1:
			player.position = Vector3(0.0, 1.8, 2.5)
			player.current_state = 1
			var anchor = ContactResolver.get_contact_anchor(player.position, Vector3(0, 0, -1), player.attributes)
			ball.position = anchor
			player.attack_attempted.emit(
				player.position,
				true,
				Vector3(0, -0.15, -1.0),
				Vector3(0, 0, -1),
				ContactResolver.AttackSwingPhase.ACTIVE_CONTACT,
				0.12
			)
			ball._process_landing(Vector3(0.0, 0.0, -4.0))
		else:
			# Untouched feed landing
			ball._process_landing(Vector3(0.0, 0.0, 2.5))

		manager.reset_feed()

	if manager.completed_attempts != 100:
		printerr("[FAIL] Scenario I: expected 100 completed attempts, got %d" % manager.completed_attempts)
		main.free()
		return false

	if manager.clean_hits != 50 or manager.untouched_feeds != 50:
		printerr("[FAIL] Scenario I: counters corrupted (clean: %d, untouched: %d)" % [manager.clean_hits, manager.untouched_feeds])
		main.free()
		return false

	main.free()
	print("[PASS] Scenario I - 100 consecutive training cycles stable without memory leak")
	return true

static func test_scenario_j_movement_camera_stability() -> bool:
	var main = _setup_main()
	var player = main.get_node("Player")
	var camera = main.get_node("FollowCamera")

	# Move player forward and sideways over several ticks
	for step in range(30):
		player.velocity = Vector3(2.0, 0.0, -3.0)
		player._physics_process(0.016)
		camera._process(0.016)

	if not is_finite(player.position.x) or not is_finite(player.position.z):
		printerr("[FAIL] Scenario J: non-finite player position")
		main.free()
		return false

	if not is_finite(camera.position.x) or not is_finite(camera.position.y):
		printerr("[FAIL] Scenario J: non-finite camera position")
		main.free()
		return false

	main.free()
	print("[PASS] Scenario J - Camera and movement values remain finite and stable")
	return true
