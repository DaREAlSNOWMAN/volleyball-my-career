class_name ContactResolver
extends RefCounted

## Assisted spike contact resolver.
## Evaluates swing lifecycle phases (WINDUP, ACTIVE_CONTACT, FOLLOW_THROUGH, RECOVERY),
## contact anchor position (hitting hand), timing windows, reach, and aim direction.

enum HitQuality {
	MISS = 0,
	WEAK = 1,
	CLEAN = 2
}

enum AttackSwingPhase {
	READY = 0,
	WINDUP = 1,
	ACTIVE_CONTACT = 2,
	FOLLOW_THROUGH = 3,
	RECOVERY = 4
}

class ContactResult:
	var quality: HitQuality = HitQuality.MISS
	var post_contact_velocity: Vector3 = Vector3.ZERO
	var contact_point: Vector3 = Vector3.ZERO
	var message: String = "Miss"
	var distance_to_anchor: float = 0.0
	var timing_offset: float = 0.0
	var swing_phase: AttackSwingPhase = AttackSwingPhase.READY

## Computes the striking hand contact anchor in world space.
## In authentic volleyball, right-handed spike contact occurs high above and slightly in front/right of the athlete.
static func get_contact_anchor(player_pos: Vector3, facing_dir: Vector3, attributes: PlayerAttributes) -> Vector3:
	var f_dir = facing_dir.normalized()
	if f_dir.length_squared() < 0.01:
		f_dir = Vector3(0, 0, -1)
	var right_dir = Vector3(-f_dir.z, 0, f_dir.x).normalized()

	# Vertical striking reach: athlete's hitting hand at maximum extension
	var reach_height = 0.85 # Character center to extended hand (~2.8m - 3.2m during jump)
	var forward_offset = f_dir * 0.40
	var lateral_offset = right_dir * 0.20

	var anchor = player_pos + Vector3(0, reach_height, 0) + forward_offset + lateral_offset
	return anchor

## Evaluates whether a spike contact succeeds and computes the post-contact velocity vector.
static func resolve_spike(
	player_pos: Vector3,
	player_is_airborne: bool,
	ball_pos: Vector3,
	aim_direction: Vector3,
	attributes: PlayerAttributes,
	facing_dir: Vector3 = Vector3(0, 0, -1),
	swing_phase: AttackSwingPhase = AttackSwingPhase.ACTIVE_CONTACT,
	swing_elapsed: float = 0.0
) -> ContactResult:
	var result = ContactResult.new()
	result.contact_point = ball_pos
	result.swing_phase = swing_phase

	# Requirement 1: Player must be airborne to execute a spike attack
	if not player_is_airborne:
		result.quality = HitQuality.MISS
		result.message = "Must be airborne to spike"
		return result

	# Requirement 2: Swing must be in ACTIVE_CONTACT phase
	if swing_phase == AttackSwingPhase.WINDUP:
		result.quality = HitQuality.MISS
		result.message = "Early swing (In windup)"
		return result
	elif swing_phase == AttackSwingPhase.FOLLOW_THROUGH or swing_phase == AttackSwingPhase.RECOVERY:
		result.quality = HitQuality.MISS
		result.message = "Late swing (In follow-through)"
		return result

	# Compute hand contact anchor
	var anchor = get_contact_anchor(player_pos, facing_dir, attributes)
	var dist_to_anchor = anchor.distance_to(ball_pos)
	result.distance_to_anchor = dist_to_anchor

	var max_reach = attributes.hit_assist_tolerance

	# Height check: ball must be within vertical striking region
	var height_diff = ball_pos.y - player_pos.y
	if height_diff < 0.25:
		result.quality = HitQuality.MISS
		result.message = "Ball too low to spike"
		return result
	if height_diff > 2.4:
		result.quality = HitQuality.MISS
		result.message = "Ball too high out of reach"
		return result

	if dist_to_anchor > max_reach:
		result.quality = HitQuality.MISS
		result.message = "Ball out of reach (too far)"
		return result

	# Timing window evaluation
	var clean_ratio = 0.55
	if attributes.timing_window_weak > 0.0:
		clean_ratio = clampf(attributes.timing_window_clean / attributes.timing_window_weak, 0.4, 0.7)
	var clean_threshold = max_reach * clean_ratio

	# Calculate post-contact velocity (in m/s)
	# Ball must clear the net (net height 2.43m at z=0) and land on opponent court (z < 0)
	var speed = attributes.hitting_power
	var fwd = aim_direction.normalized()
	if fwd.length_squared() < 0.001:
		fwd = Vector3(0, -0.15, -1.0).normalized()

	# Spike depression angle: realistic slope that clears the net (net height 2.43m)
	# When contacting at Y ~ 2.8m-3.0m and Z ~ 1.5m-2.5m, a slight downward angle (-0.12 to -0.16)
	# safely clears the 2.43m net with margin and drives down onto the opponent court.
	var desired_pitch = clampf(fwd.y, -0.18, 0.05)
	var spike_dir = Vector3(fwd.x, desired_pitch, fwd.z).normalized()
	if spike_dir.z > -0.1:
		spike_dir.z = -0.6
		spike_dir = spike_dir.normalized()

	if dist_to_anchor <= clean_threshold:
		result.quality = HitQuality.CLEAN
		result.message = "Clean Spike!"
		result.post_contact_velocity = spike_dir * speed
	elif dist_to_anchor <= max_reach:
		result.quality = HitQuality.WEAK
		result.message = "Weak Contact (Off-timing)"
		var weak_dir = (spike_dir + Vector3(randf_range(-0.15, 0.15), 0.12, randf_range(-0.1, 0.1))).normalized()
		result.post_contact_velocity = weak_dir * (speed * 0.65)
	else:
		result.quality = HitQuality.MISS
		result.message = "Mistimed swing"

	return result
