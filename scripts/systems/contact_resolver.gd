class_name ContactResolver
extends RefCounted

## Assisted spike contact resolver.
## Evaluates distance, attack contact region relative to athlete height/reach,
## airborne status, aiming direction, and timing windows (clean vs weak vs miss)
## to produce a realistic physical response without magnetizing/teleporting.

enum HitQuality {
	MISS = 0,
	WEAK = 1,
	CLEAN = 2
}

class ContactResult:
	var quality: HitQuality = HitQuality.MISS
	var impulse: Vector3 = Vector3.ZERO
	var contact_point: Vector3 = Vector3.ZERO
	var message: String = "Miss"
	var distance_to_sweet_spot: float = 0.0
	var timing_offset: float = 0.0

## Computes the plausible hitting contact sweet spot in world space.
## In volleyball, an athlete contacts the ball at their maximum comfortable reach:
## slightly in front (toward net / facing dir) and above the athlete's head.
static func get_attack_sweet_spot(player_pos: Vector3, facing_dir: Vector3, attributes: PlayerAttributes) -> Vector3:
	var f_dir = facing_dir.normalized()
	if f_dir.length_squared() < 0.01:
		f_dir = Vector3(0, 0, -1)
	# Reach height: approx 0.5m - 0.7m above character center/head
	var reach_height = 0.55
	var forward_offset = f_dir * 0.35
	var sweet_spot = player_pos + Vector3(0, reach_height, 0) + forward_offset
	return sweet_spot

## Evaluates whether a spike contact succeeds and computes the resulting velocity vector.
static func resolve_spike(
	player_pos: Vector3,
	player_is_airborne: bool,
	ball_pos: Vector3,
	aim_direction: Vector3,
	attributes: PlayerAttributes,
	facing_dir: Vector3 = Vector3(0, 0, -1),
	jump_apex_time_diff: float = 0.0
) -> ContactResult:
	var result = ContactResult.new()
	result.contact_point = ball_pos

	# Requirement 1: Player must be airborne to execute an authentic spike
	if not player_is_airborne:
		result.quality = HitQuality.MISS
		result.message = "Must be airborne to spike"
		return result

	# Compute hitting sweet spot
	var sweet_spot = get_attack_sweet_spot(player_pos, facing_dir, attributes)
	var dist_to_sweet_spot = sweet_spot.distance_to(ball_pos)
	result.distance_to_sweet_spot = dist_to_sweet_spot

	# Contact tolerance from player attributes
	var max_reach = attributes.hit_assist_tolerance

	# Height check: ball must be within vertical striking region
	var height_diff = ball_pos.y - player_pos.y
	if height_diff < 0.2:
		result.quality = HitQuality.MISS
		result.message = "Ball too low to spike"
		return result
	if height_diff > 2.2:
		result.quality = HitQuality.MISS
		result.message = "Ball too high out of reach"
		return result

	if dist_to_sweet_spot > max_reach:
		result.quality = HitQuality.MISS
		result.message = "Ball out of reach (too far)"
		return result

	# Timing window evaluation:
	# Assess spatial distance normalized by sweet spot radius and jump timing offset
	var clean_ratio = 0.55
	if attributes.timing_window_weak > 0.0:
		clean_ratio = clampf(attributes.timing_window_clean / attributes.timing_window_weak, 0.4, 0.7)
	var clean_threshold = max_reach * clean_ratio
	var timing_penalty = absf(jump_apex_time_diff) * 1.2

	var effective_dist = dist_to_sweet_spot + timing_penalty

	# Power and spike trajectory calculations:
	var power = attributes.hitting_power
	var fwd = aim_direction.normalized()
	if fwd.length_squared() < 0.001:
		fwd = Vector3(0, -0.22, -1.0).normalized()

	# Spike depression angle: authentic downward vector that guarantees crossing the 2.43m net
	var spike_dir = Vector3(fwd.x, -0.22, fwd.z).normalized()
	if spike_dir.z > -0.1:
		spike_dir.z = -0.6
		spike_dir = spike_dir.normalized()

	if effective_dist <= clean_threshold:
		result.quality = HitQuality.CLEAN
		result.message = "Clean Spike!"
		result.impulse = spike_dir * power
	elif effective_dist <= max_reach:
		result.quality = HitQuality.WEAK
		result.message = "Weak Contact (Off-timing)"
		var weak_dir = (spike_dir + Vector3(randf_range(-0.15, 0.15), 0.12, randf_range(-0.1, 0.1))).normalized()
		result.impulse = weak_dir * (power * 0.65)
	else:
		result.quality = HitQuality.MISS
		result.message = "Mistimed swing"

	return result
