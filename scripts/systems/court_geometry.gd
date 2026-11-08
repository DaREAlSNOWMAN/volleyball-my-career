class_name CourtGeometry
extends RefCounted

## Court dimensions according to FIVB official indoor regulations:
## Entire court is 18m long (Z axis) by 9m wide (X axis).
## Net is at Z = 0.
## Player's court half: Z in [0.0, 9.0]
## Opponent's court half: Z in [-9.0, 0.0]
## X is centered: X in [-4.5, 4.5]
## Lines are 5cm (0.05m) wide and are part of the court (in-bounds).
## Default men's net height is 2.43m. Net width is 9.5-10m across X axis.
## Attack lines are 3m from the center line:
## Player attack line: Z = +3.0m
## Opponent attack line: Z = -3.0m

const COURT_LENGTH: float = 18.0
const COURT_WIDTH: float = 9.0
const HALF_WIDTH: float = COURT_WIDTH / 2.0 # 4.5m
const HALF_LENGTH: float = COURT_LENGTH / 2.0 # 9.0m
const LINE_WIDTH: float = 0.05 # 5cm lines are part of the court
const DEFAULT_NET_HEIGHT: float = 2.43
const ATTACK_LINE_DISTANCE: float = 3.0

enum LandingZone {
	OUT_OF_BOUNDS = 0,
	PLAYER_COURT = 1,
	OPPONENT_COURT = 2
}

## Returns true if a given point (Vector3 or Vector2 in XZ plane) is inside the overall court boundaries (including lines)
static func is_in_court(point: Vector3, line_tolerance: float = 0.0) -> bool:
	var total_margin: float = (LINE_WIDTH / 2.0) + line_tolerance
	var min_x: float = -HALF_WIDTH - total_margin
	var max_x: float = HALF_WIDTH + total_margin
	var min_z: float = -HALF_LENGTH - total_margin
	var max_z: float = HALF_LENGTH + total_margin
	return (point.x >= min_x and point.x <= max_x and point.z >= min_z and point.z <= max_z)

## Returns true if a point is inside the opponent's court (Z < 0 side, including center and end/side lines)
static func is_in_opponent_court(point: Vector3, line_tolerance: float = 0.0) -> bool:
	var total_margin: float = (LINE_WIDTH / 2.0) + line_tolerance
	var min_x: float = -HALF_WIDTH - total_margin
	var max_x: float = HALF_WIDTH + total_margin
	var min_z: float = -HALF_LENGTH - total_margin
	# Center line at z = 0 is shared / neutral, line margin applies
	var max_z: float = 0.0 + total_margin
	return (point.x >= min_x and point.x <= max_x and point.z >= min_z and point.z <= max_z)

## Returns true if a point is inside the player's court (Z > 0 side, including lines)
static func is_in_player_court(point: Vector3, line_tolerance: float = 0.0) -> bool:
	var total_margin: float = (LINE_WIDTH / 2.0) + line_tolerance
	var min_x: float = -HALF_WIDTH - total_margin
	var max_x: float = HALF_WIDTH + total_margin
	var min_z: float = 0.0 - total_margin
	var max_z: float = HALF_LENGTH + total_margin
	return (point.x >= min_x and point.x <= max_x and point.z >= min_z and point.z <= max_z)

## Evaluates landing point and returns LandingZone enum
static func evaluate_landing(point: Vector3, line_tolerance: float = 0.0) -> LandingZone:
	if is_in_opponent_court(point, line_tolerance):
		return LandingZone.OPPONENT_COURT
	elif is_in_player_court(point, line_tolerance):
		return LandingZone.PLAYER_COURT
	else:
		return LandingZone.OUT_OF_BOUNDS

## Clamps player position to keep them on their court half (with configurable boundary margin)
static func clamp_player_to_training_area(pos: Vector3, margin: float = 0.3) -> Vector3:
	var clamped: Vector3 = pos
	clamped.x = clampf(clamped.x, -HALF_WIDTH + margin, HALF_WIDTH - margin)
	# Player cannot cross the net into opponent court (net is at z=0)
	clamped.z = clampf(clamped.z, 0.4, HALF_LENGTH - margin)
	return clamped
