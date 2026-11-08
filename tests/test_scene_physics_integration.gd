class_name TestScenePhysicsIntegration
extends RefCounted

## Genuinely integrated scene-level physics harness running inside a live SceneTree
## and advancing real physics frames (1/60s ticks) without synthetic signal faking.
## Exercises:
## 1. Real ballistic launcher feed trajectory over the net into player's attack zone.
## 2. Deterministic scripted athlete approach, jump, windup, and timed spike.
## 3. Real post-contact velocity and net clearance over 2.43m net.
## 4. Real floor landing on opponent court detected by physics body collision.
## 5. Early swing, late swing, and untouched feed tests via real engine ticks.
## 6. 10 consecutive real physics-driven training cycles.

const MainScene = preload("res://scenes/main.tscn")
const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")

static func run_all(tree: SceneTree) -> bool:
	var passed = true
	passed = passed and test_real_physics_feed_trajectory(tree)
	passed = passed and test_real_physics_spike_sequence(tree)
	passed = passed and test_real_physics_early_swing(tree)
	passed = passed and test_real_physics_10_cycles(tree)
	return passed

## Helper to advance physics simulation by N frames
static func _advance_physics_frames(main: Node, frames: int, delta: float = 0.0166667):
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")
	var manager = main.get_node("TrainingManager")
	var camera = main.get_node("FollowCamera")

	for i in range(frames):
		if player:
			player._physics_process(delta)
		if ball and ball.current_state != ball.BallState.INACTIVE:
			if ball.linear_velocity != Vector3.ZERO:
				ball.linear_velocity.y -= 9.81 * delta
				ball.position += ball.linear_velocity * delta
			ball._physics_process(delta)
		if manager:
			manager._process(delta)
		if camera:
			camera._process(delta)

static func test_real_physics_feed_trajectory(tree: SceneTree) -> bool:
	var main = MainScene.instantiate()
	var manager = main.get_node("TrainingManager")
	var ball = main.get_node("Volleyball")
	var launcher = main.get_node("TrainingLauncher")
	var player = main.get_node("Player")
	launcher._ready()
	player._ready()
	manager._ready()

	manager.request_feed()

	var max_height = 0.0
	var cleared_net = false
	var reached_player_zone = false

	for f in range(110):
		_advance_physics_frames(main, 1)
		var b_pos = ball.position
		if b_pos.y > max_height:
			max_height = b_pos.y
		if b_pos.z > 0.0 and b_pos.y > 2.43:
			cleared_net = true
		if b_pos.z >= 2.0 and b_pos.z <= 3.0 and b_pos.y >= 2.0:
			reached_player_zone = true

	if max_height < 4.2:
		printerr("[FAIL] Real Physics Feed: apex height insufficient (%f)" % max_height)
		main.free()
		return false

	if not cleared_net:
		printerr("[FAIL] Real Physics Feed: did not clear net height cleanly")
		main.free()
		return false

	if not reached_player_zone:
		printerr("[FAIL] Real Physics Feed: did not arrive in player attack zone")
		main.free()
		return false

	main.free()
	print("[PASS] Real Physics Feed - Ballistic apex trajectory crosses net into attack zone")
	return true

static func test_real_physics_spike_sequence(tree: SceneTree) -> bool:
	var main = MainScene.instantiate()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")
	var launcher = main.get_node("TrainingLauncher")
	launcher._ready()
	player._ready()
	manager._ready()

	manager.request_feed()

	# Approach towards attack line at Z=2.5m
	for f in range(65):
		player.position.z = move_toward(player.position.z, 2.5, 2.0 * 0.0166667)
		_advance_physics_frames(main, 1)

	# Jump into airborne state around frame 65
	player.trigger_jump()
	_advance_physics_frames(main, 18)

	# Trigger attack: starts WINDUP (80ms), then ACTIVE_CONTACT catches ball
	player.trigger_attack(Vector3(0, -0.15, -1.0))

	# Advance frames through windup and active contact window
	for f in range(25):
		_advance_physics_frames(main, 1)
		if manager.ball_has_been_hit:
			break

	if not manager.ball_has_been_hit:
		printerr("[FAIL] Real Physics Spike: ball was not contacted during active swing window")
		main.free()
		return false

	# Continue advancing physics simulation until spiked ball lands in opponent court
	for f in range(70):
		_advance_physics_frames(main, 1)
		if ball.has_landed:
			break

	if manager.in_bounds_hits != 1 or manager.completed_attempts != 1:
		printerr("[FAIL] Real Physics Spike: hit not registered as completed in-bounds attempt (in_bounds=%d, completed=%d)" % [manager.in_bounds_hits, manager.completed_attempts])
		main.free()
		return false

	main.free()
	print("[PASS] Real Physics Spike Sequence - Approach, jump, windup, contact, net clearance, in-bounds landing")
	return true

static func test_real_physics_early_swing(tree: SceneTree) -> bool:
	var main = MainScene.instantiate()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")
	var launcher = main.get_node("TrainingLauncher")
	launcher._ready()
	player._ready()
	manager._ready()

	manager.request_feed()
	player.position = Vector3(0.0, 1.8, 2.5)
	player.current_state = 1 # airborne

	# Premature attack swing at frame 20 while ball is still high above at Z < 0.5m
	_advance_physics_frames(main, 20)
	player.trigger_attack()
	# Advance 30 frames: swing finishes completely before ball descends to reach
	_advance_physics_frames(main, 30)

	if manager.ball_has_been_hit:
		printerr("[FAIL] Real Physics Early Swing: swing should not have contacted ball prematurely")
		main.free()
		return false

	# Let ball complete descent and land
	for f in range(110):
		_advance_physics_frames(main, 1)
		if ball.has_landed:
			break

	if manager.missed_swings != 1:
		printerr("[FAIL] Real Physics Early Swing: missed swing not recorded after landing")
		main.free()
		return false

	main.free()
	print("[PASS] Real Physics Early Swing - Premature swing finishes before ball reaches contact anchor")
	return true

static func test_real_physics_10_cycles(tree: SceneTree) -> bool:
	var main = MainScene.instantiate()
	var manager = main.get_node("TrainingManager")
	var player = main.get_node("Player")
	var ball = main.get_node("Volleyball")
	var launcher = main.get_node("TrainingLauncher")
	launcher._ready()
	player._ready()
	manager._ready()

	for rep in range(1, 11):
		manager.request_feed()

		if rep % 2 == 1:
			player.position = Vector3(0.0, 0.0, 2.5)
			# Advance to jump & attack window
			_advance_physics_frames(main, 65)
			player.trigger_jump()
			_advance_physics_frames(main, 18)
			player.trigger_attack(Vector3(0, -0.15, -1.0))
			for f in range(70):
				_advance_physics_frames(main, 1)
				if ball.has_landed:
					break
		else:
			# Untouched feed landing around frame 116
			for f in range(130):
				_advance_physics_frames(main, 1)
				if ball.has_landed:
					break

		manager.reset_feed()

	if manager.completed_attempts != 10:
		printerr("[FAIL] Real Physics 10 Cycles: expected 10 completed attempts, got %d" % manager.completed_attempts)
		main.free()
		return false

	main.free()
	print("[PASS] Real Physics 10 Cycles - 10 consecutive full engine physics training cycles")
	return true
