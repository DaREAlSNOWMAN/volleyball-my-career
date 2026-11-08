class_name ContactResolver
extends RefCounted

## Assisted spike contact resolver.
## Evaluates distance, height, airborne status, aiming direction, and timing
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
	var distance: float = 0.0

## Evaluates whether a spike contact succeeds and computes the resulting velocity vector.
static func resolve_spike(
	player_pos: Vector3,
	player_is_airborne: bool,
	ball_pos: Vector3,
	aim_direction: Vector3,
	attributes: PlayerAttributes
) -> ContactResult:
	var result = ContactResult.new()
	result.contact_point = ball_pos

	var dist_3d: float = player_pos.distance_to(ball_pos)
	result.distance = dist_3d

	# Requirement 1: Player must be airborne to execute a spike
	if not player_is_airborne:
		result.quality = HitQuality.MISS
		result.message = "Must be airborne to spike"
		return result

	# Requirement 2: Ball must be within plausible striking reach
	# Vertical reach: ball should be above ground and around/above player's head
	var height_diff: float = ball_pos.y - player_pos.y
	# Maximum 3D reach based on attributes
	var max_reach: float = attributes.hit_assist_tolerance
	var min_height_diff: float = 0.2
	var max_height_diff: float = 1.9

	if dist_3d > max_reach:
		result.quality = HitQuality.MISS
		result.message = "Ball out of reach (too far)"
		return result

	if height_diff < min_height_diff or height_diff > max_height_diff:
		result.quality = HitQuality.MISS
		result.message = "Ball height mistimed"
		return result

	# Determine hit quality based on distance to sweet spot
	# Sweet spot is slightly in front of and above the player's head
	var sweet_spot_dist: float = dist_3d
	var clean_threshold: float = max_reach * 0.55
	var power: float = attributes.hitting_power

	# Compute aim direction: ensure it aims forward across the net (towards negative Z) and slightly downwards
	var forward_dir: Vector3 = aim_direction.normalized()
	if forward_dir.length_squared() < 0.001:
		forward_dir = Vector3(0, -0.25, -1.0).normalized()

	# Spike trajectory: downwards angle across the net
	# If aim_direction didn't specify downwards slope, inject authentic spike depression angle
	var spike_dir: Vector3 = Vector3(forward_dir.x, -0.28, forward_dir.z).normalized()
	# Ensure the hit moves towards opponent side (Z < 0)
	if spike_dir.z > -0.1:
		spike_dir.z = -0.5
		spike_dir = spike_dir.normalized()

	if sweet_spot_dist <= clean_threshold:
		result.quality = HitQuality.CLEAN
		result.message = "Clean Spike!"
		result.impulse = spike_dir * power
	else:
		result.quality = HitQuality.WEAK
		result.message = "Weak Contact (Off-center)"
		# Weak hits have less forward drive and higher dispersion
		var weak_dir: Vector3 = (spike_dir + Vector3(randf_range(-0.15, 0.15), 0.1, randf_range(-0.1, 0.1))).normalized()
		result.impulse = weak_dir * (power * 0.6)

	return result
