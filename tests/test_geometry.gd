class_name TestGeometry
extends RefCounted

const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")

static func run_all() -> bool:
	var passed = true
	passed = passed and test_court_dimensions()
	passed = passed and test_line_boundary_inclusion()
	passed = passed and test_opponent_and_player_courts()
	passed = passed and test_player_clamping()
	return passed

static func test_court_dimensions() -> bool:
	# Center of opponent court
	var opp_center = Vector3(0.0, 0.0, -4.5)
	if not CourtGeometry.is_in_court(opp_center):
		printerr("[FAIL] test_court_dimensions: opp_center should be in court")
		return false

	# Center of player court
	var player_center = Vector3(0.0, 0.0, 4.5)
	if not CourtGeometry.is_in_court(player_center):
		printerr("[FAIL] test_court_dimensions: player_center should be in court")
		return false

	# Far outside points
	var out_point1 = Vector3(5.5, 0.0, 0.0) # beyond 4.5m width
	var out_point2 = Vector3(0.0, 0.0, 10.0) # beyond 9.0m length
	var out_point3 = Vector3(-6.0, 0.0, -12.0)

	if CourtGeometry.is_in_court(out_point1) or CourtGeometry.is_in_court(out_point2) or CourtGeometry.is_in_court(out_point3):
		printerr("[FAIL] test_court_dimensions: points outside court reported inside")
		return false

	print("[PASS] test_court_dimensions")
	return true

static func test_line_boundary_inclusion() -> bool:
	# Official rules: line is inside the court
	# Right sideline is at x = 4.5
	var on_sideline = Vector3(4.5, 0.0, -3.0)

	if not CourtGeometry.is_in_court(on_sideline):
		printerr("[FAIL] test_line_boundary_inclusion: line should be in bounds")
		return false

	# Baseline at z = -9.0
	var on_baseline = Vector3(0.0, 0.0, -9.0)
	if not CourtGeometry.is_in_court(on_baseline):
		printerr("[FAIL] test_line_boundary_inclusion: baseline should be in bounds")
		return false

	# Point clearly beyond line margin
	var beyond_baseline = Vector3(0.0, 0.0, -9.5)
	if CourtGeometry.is_in_court(beyond_baseline):
		printerr("[FAIL] test_line_boundary_inclusion: beyond baseline should be out")
		return false

	print("[PASS] test_line_boundary_inclusion")
	return true

static func test_opponent_and_player_courts() -> bool:
	var opp_point = Vector3(1.0, 0.0, -5.0)
	var player_point = Vector3(1.0, 0.0, 5.0)
	var out_point = Vector3(6.0, 0.0, -5.0)

	if CourtGeometry.evaluate_landing(opp_point) != CourtGeometry.LandingZone.OPPONENT_COURT:
		printerr("[FAIL] test_opponent_and_player_courts: expected OPPONENT_COURT")
		return false

	if CourtGeometry.evaluate_landing(player_point) != CourtGeometry.LandingZone.PLAYER_COURT:
		printerr("[FAIL] test_opponent_and_player_courts: expected PLAYER_COURT")
		return false

	if CourtGeometry.evaluate_landing(out_point) != CourtGeometry.LandingZone.OUT_OF_BOUNDS:
		printerr("[FAIL] test_opponent_and_player_courts: expected OUT_OF_BOUNDS")
		return false

	print("[PASS] test_opponent_and_player_courts")
	return true

static func test_player_clamping() -> bool:
	var target_cross_net = Vector3(0.0, 0.0, -2.0)
	var clamped = CourtGeometry.clamp_player_to_training_area(target_cross_net)
	if clamped.z < 0.4:
		printerr("[FAIL] test_player_clamping: player crossed net to opponent side")
		return false

	var target_outside_sideline = Vector3(10.0, 0.0, 5.0)
	var clamped_sideline = CourtGeometry.clamp_player_to_training_area(target_outside_sideline)
	if clamped_sideline.x > CourtGeometry.HALF_WIDTH:
		printerr("[FAIL] test_player_clamping: player exceeded sideline boundary")
		return false

	print("[PASS] test_player_clamping")
	return true
