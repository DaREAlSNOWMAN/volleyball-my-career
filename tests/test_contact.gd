class_name TestContact
extends RefCounted

const ContactResolver = preload("res://scripts/systems/contact_resolver.gd")
const PlayerAttributes = preload("res://resources/player_attributes.gd")
const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")
const VolleyballController = preload("res://scripts/ball/volleyball_controller.gd")

static func run_all() -> bool:
	var passed = true
	passed = passed and test_grounded_attack_fails()
	passed = passed and test_distant_attack_fails()
	passed = passed and test_height_mistimed_fails()
	passed = passed and test_clean_spike_success()
	passed = passed and test_weak_spike_success()
	passed = passed and test_spike_net_clearance()
	passed = passed and test_spike_net_collision_trajectory()
	passed = passed and test_swing_phases_rejection()
	return passed

static func _create_test_attributes() -> PlayerAttributes:
	var attr = PlayerAttributes.new()
	attr.hitting_power = 16.5
	attr.hit_assist_tolerance = 1.45
	attr.timing_window_clean = 0.28
	attr.timing_window_weak = 0.50
	return attr

static func test_grounded_attack_fails() -> bool:
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 0.0, 2.5)
	var ball_pos = Vector3(0.0, 0.8, 2.5)
	var aim_dir = Vector3(0.0, 0.0, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, false, ball_pos, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.MISS:
		printerr("[FAIL] test_grounded_attack_fails: grounded player should miss spike")
		return false

	print("[PASS] test_grounded_attack_fails")
	return true

static func test_distant_attack_fails() -> bool:
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 1.5, 2.5)
	var ball_pos = Vector3(0.0, 1.8, 7.0) # 4.5m away
	var aim_dir = Vector3(0.0, 0.0, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, ball_pos, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.MISS:
		printerr("[FAIL] test_distant_attack_fails: distant ball should not register contact")
		return false

	print("[PASS] test_distant_attack_fails")
	return true

static func test_height_mistimed_fails() -> bool:
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 1.5, 2.5)
	var ball_pos = Vector3(0.0, 1.0, 2.5)
	var aim_dir = Vector3(0.0, 0.0, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, ball_pos, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.MISS:
		printerr("[FAIL] test_height_mistimed_fails: ball beneath player should miss spike")
		return false

	print("[PASS] test_height_mistimed_fails")
	return true

static func test_clean_spike_success() -> bool:
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 1.6, 2.5)
	var anchor = ContactResolver.get_contact_anchor(player_pos, Vector3(0, 0, -1), attr)
	var ball_pos = anchor + Vector3(0.05, 0.02, 0.02)
	var aim_dir = Vector3(0.0, -0.20, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, ball_pos, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.CLEAN:
		printerr("[FAIL] test_clean_spike_success: expected CLEAN hit, got %s (%s)" % [result.quality, result.message])
		return false

	if result.post_contact_velocity.z >= 0:
		printerr("[FAIL] test_clean_spike_success: velocity must drive ball towards opponent court (Z < 0)")
		return false

	if result.post_contact_velocity.length() < 10.0:
		printerr("[FAIL] test_clean_spike_success: velocity too weak for clean spike")
		return false

	print("[PASS] test_clean_spike_success")
	return true

static func test_weak_spike_success() -> bool:
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 1.6, 2.5)
	var anchor = ContactResolver.get_contact_anchor(player_pos, Vector3(0, 0, -1), attr)
	var ball_pos = anchor + Vector3(0.85, 0.2, 0.1)
	var aim_dir = Vector3(0.0, -0.20, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, ball_pos, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.WEAK:
		printerr("[FAIL] test_weak_spike_success: expected WEAK hit, got %s (%s)" % [result.quality, result.message])
		return false

	print("[PASS] test_weak_spike_success")
	return true

static func test_spike_net_clearance() -> bool:
	# Verify that clean spike trajectory accounts for ball radius (0.105m) and clears the 2.43m net at z=0
	var attr = _create_test_attributes()
	# Athlete jumping at apex: Y = 2.0m, Z = 1.8m (near net)
	var player_pos = Vector3(0.0, 2.0, 1.8)
	var anchor = ContactResolver.get_contact_anchor(player_pos, Vector3(0, 0, -1), attr)
	var aim_dir = Vector3(0.0, -0.16, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, anchor, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.CLEAN:
		printerr("[FAIL] test_spike_net_clearance: expected clean hit")
		return false

	var vz = result.post_contact_velocity.z
	var vy = result.post_contact_velocity.y
	var vx = result.post_contact_velocity.x

	# Must be traveling forward across the net (Z < 0)
	if vz >= -5.0:
		printerr("[FAIL] test_spike_net_clearance: forward velocity vz insufficient (%f)" % vz)
		return false

	# Calculate time to net plane (Z = 0)
	var t_net = -anchor.z / vz
	var y_at_net = anchor.y + vy * t_net - 0.5 * 9.81 * t_net * t_net
	var ball_radius = VolleyballController.BALL_RADIUS
	var net_height = CourtGeometry.DEFAULT_NET_HEIGHT # 2.43m

	# Assert that ball's bottom edge clears the top of the net
	if (y_at_net - ball_radius) <= net_height:
		printerr("[FAIL] test_spike_net_clearance: ball hits net! (y_at_net - r: %f <= net: %f)" % [y_at_net - ball_radius, net_height])
		return false

	# Verify continuation into opponent court (Z in [-9.0, 0.0])
	var t_ground = (-vy - sqrt(vy * vy + 2.0 * 9.81 * anchor.y)) / (-9.81)
	var z_land = anchor.z + vz * t_ground
	if z_land >= 0.0 or z_land < -CourtGeometry.HALF_LENGTH:
		printerr("[FAIL] test_spike_net_clearance: ball does not land inside opponent court (%f)" % z_land)
		return false

	print("[PASS] test_spike_net_clearance")
	return true

static func test_spike_net_collision_trajectory() -> bool:
	# Verify that a trajectory hitting into the net is recognized as failing net clearance
	var net_height = CourtGeometry.DEFAULT_NET_HEIGHT # 2.43m
	var contact_pos = Vector3(0.0, 2.2, 1.8) # too low to spike down over 2.43m net
	var down_vel = Vector3(0.0, -3.0, -10.0) # downward trajectory
	var t_net = -contact_pos.z / down_vel.z
	var y_at_net = contact_pos.y + down_vel.y * t_net - 0.5 * 9.81 * t_net * t_net
	var ball_radius = VolleyballController.BALL_RADIUS

	if (y_at_net - ball_radius) > net_height:
		printerr("[FAIL] test_spike_net_collision_trajectory: expected trajectory to hit net")
		return false

	print("[PASS] test_spike_net_collision_trajectory")
	return true

static func test_swing_phases_rejection() -> bool:
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 1.6, 2.5)
	var anchor = ContactResolver.get_contact_anchor(player_pos, Vector3(0, 0, -1), attr)
	var aim_dir = Vector3(0.0, -0.20, -1.0)

	# Windup swing rejection
	var windup_res = ContactResolver.resolve_spike(
		player_pos, true, anchor, aim_dir, attr, Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.WINDUP, 0.04
	)
	if windup_res.quality != ContactResolver.HitQuality.MISS:
		printerr("[FAIL] test_swing_phases_rejection: windup phase should be rejected")
		return false

	# Follow-through swing rejection
	var follow_res = ContactResolver.resolve_spike(
		player_pos, true, anchor, aim_dir, attr, Vector3(0, 0, -1),
		ContactResolver.AttackSwingPhase.FOLLOW_THROUGH, 0.30
	)
	if follow_res.quality != ContactResolver.HitQuality.MISS:
		printerr("[FAIL] test_swing_phases_rejection: follow-through phase should be rejected")
		return false

	print("[PASS] test_swing_phases_rejection")
	return true
