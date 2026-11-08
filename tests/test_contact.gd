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
	return passed

static func _create_test_attributes() -> PlayerAttributes:
	var attr = PlayerAttributes.new()
	attr.hitting_power = 16.0
	attr.hit_assist_tolerance = 1.4
	return attr

static func test_grounded_attack_fails() -> bool:
	var attr = _create_test_attributes()
	var player_pos = Vector3(0.0, 0.0, 2.5)
	var ball_pos = Vector3(0.0, 0.8, 2.5) # nearby, but player is grounded
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
	var ball_pos = Vector3(0.0, 1.8, 7.0) # 4.5m away, impossible contact
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
	# Ball is beneath player's feet (height diff negative or < 0.2)
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
	# Ball is nicely situated 0.5m above player and in front
	var ball_pos = Vector3(0.0, 2.1, 2.2)
	var aim_dir = Vector3(0.0, -0.3, -1.0)

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
	# Ball is at outer edge of tolerance (e.g. 1.1m away)
	var ball_pos = Vector3(0.8, 2.2, 2.5)
	var aim_dir = Vector3(0.0, -0.3, -1.0)

	var result = ContactResolver.resolve_spike(player_pos, true, ball_pos, aim_dir, attr)
	if result.quality != ContactResolver.HitQuality.WEAK:
		printerr("[FAIL] test_weak_spike_success: expected WEAK hit, got %s (%s)" % [result.quality, result.message])
		return false

	print("[PASS] test_weak_spike_success")
	return true
