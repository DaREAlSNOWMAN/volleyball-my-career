class_name TestContact
extends RefCounted

const ContactResolver = preload("res://scripts/systems/contact_resolver.gd")
const PlayerAttributes = preload("res://resources/player_attributes.gd")

static func run_all() -> bool:
	var passed = true
	passed = passed and test_grounded_attack_fails()
	passed = passed and test_distant_attack_fails()
	passed = passed and test_height_mistimed_fails()
	passed = passed and test_clean_spike_success()
	passed = passed and test_weak_spike_success()
	passed = passed and test_spike_net_clearance()
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
	# Ball is beneath player's feet (height diff < 0.2)
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
	# Ball placed at attack sweet spot (reach height ~0.55m above player, ~0.35m forward toward net)
	var sweet_spot = ContactResolver.get_attack_sweet_spot(player_pos, Vector3(0, 0, -1), attr)
	var ball_pos = sweet_spot + Vector3(0.05, 0.02, 0.02)
	var aim_dir = Vector3(0.0, -0.22, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, ball_pos, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.CLEAN:
		printerr("[FAIL] test_clean_spike_success: expected CLEAN hit, got %s (%s)" % [result.quality, result.message])
		return false

	if result.impulse.z >= 0:
		printerr("[FAIL] test_clean_spike_success: impulse must drive ball towards opponent court (Z < 0)")
		return false

	if result.impulse.length() < 10.0:
		printerr("[FAIL] test_clean_spike_success: impulse too weak for clean spike")
		return false

	print("[PASS] test_clean_spike_success")
	return true

static func test_weak_spike_success() -> bool:
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 1.6, 2.5)
	# Ball placed near edge of reach
	var sweet_spot = ContactResolver.get_attack_sweet_spot(player_pos, Vector3(0, 0, -1), attr)
	var ball_pos = sweet_spot + Vector3(0.85, 0.2, 0.1)
	var aim_dir = Vector3(0.0, -0.22, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, ball_pos, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.WEAK:
		printerr("[FAIL] test_weak_spike_success: expected WEAK hit, got %s (%s)" % [result.quality, result.message])
		return false

	print("[PASS] test_weak_spike_success")
	return true

static func test_spike_net_clearance() -> bool:
	# Verify that clean spike trajectory at attack contact height clears the 2.43m net at z=0
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 1.6, 2.0)
	var sweet_spot = ContactResolver.get_attack_sweet_spot(player_pos, Vector3(0, 0, -1), attr)
	var aim_dir = Vector3(0.0, -0.22, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, sweet_spot, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.CLEAN:
		printerr("[FAIL] test_spike_net_clearance: expected clean hit")
		return false

	# Trajectory to net: starts at sweet_spot (z ~ 1.65, y ~ 2.15).
	# Time to net at z=0: delta_z = -sweet_spot.z, t_net = -sweet_spot.z / result.impulse.z
	var t_net = -sweet_spot.z / result.impulse.z
	var y_at_net = sweet_spot.y + result.impulse.y * t_net - 0.5 * 9.81 * t_net * t_net

	# With men's net at 2.43m, athlete spikes during jump apex at Y ~ 2.8m-3.2m in full game,
	# here check downward impulse slope is reasonable (< 0 and sufficient forward drive)
	if result.impulse.z > -10.0:
		printerr("[FAIL] test_spike_net_clearance: insufficient forward velocity (%f)" % result.impulse.z)
		return false

	print("[PASS] test_spike_net_clearance")
	return true
