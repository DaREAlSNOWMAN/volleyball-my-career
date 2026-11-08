class_name PlayerController
extends CharacterBody3D

const PlayerState = preload("res://scripts/player/player_state.gd")
const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")
const ContactResolver = preload("res://scripts/systems/contact_resolver.gd")
const PlayerAttributes = preload("res://resources/player_attributes.gd")
const FollowCamera = preload("res://scripts/camera/follow_camera.gd")

signal state_changed(old_state: int, new_state: int)
signal swing_started(swing_phase: int)
signal attack_contact_check(player_pos: Vector3, is_airborne: bool, aim_direction: Vector3, facing_dir: Vector3, swing_phase: int, swing_elapsed: float)
signal attack_attempted(player_pos: Vector3, is_airborne: bool, aim_direction: Vector3, facing_dir: Vector3, swing_phase: int, swing_elapsed: float)
signal ball_hit(quality: int, velocity: Vector3, message: String)

@export var attributes: Resource # PlayerAttributes
@export var follow_camera: Node3D # FollowCamera

var current_state: int = PlayerState.State.GROUNDED
var attack_cooldown_timer: float = 0.0
var jump_timer: float = 0.0
var has_attacked_in_current_jump: bool = false
var landing_recovery_timer: float = 0.0

# Attack swing lifecycle timings (total: ~0.45s)
# READY -> WINDUP (0.08s) -> ACTIVE_CONTACT (0.16s) -> FOLLOW_THROUGH (0.12s) -> RECOVERY (0.09s) -> READY
const WINDUP_DURATION: float = 0.08
const ACTIVE_DURATION: float = 0.16
const FOLLOW_THROUGH_DURATION: float = 0.12
const RECOVERY_DURATION: float = 0.09
const TOTAL_SWING_DURATION: float = WINDUP_DURATION + ACTIVE_DURATION + FOLLOW_THROUGH_DURATION + RECOVERY_DURATION

var current_swing_phase: int = ContactResolver.AttackSwingPhase.READY
var swing_timer: float = 0.0
var swing_elapsed: float = 0.0
var has_contacted_in_current_swing: bool = false
var current_aim_dir: Vector3 = Vector3(0, -0.15, -1)

@onready var visuals: Node3D = $Visuals
@onready var right_arm_pivot: Node3D = $Visuals/RightArmPivot
@onready var left_arm: Node3D = $Visuals/LeftArm

func _ready():
	if not attributes:
		attributes = PlayerAttributes.new()

func _physics_process(delta: float):
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if jump_timer > 0.0:
		jump_timer -= delta
	if landing_recovery_timer > 0.0:
		landing_recovery_timer -= delta

	_update_attack_swing_lifecycle(delta)
	_handle_gravity_and_grounding(delta)
	_handle_input_movement(delta)
	_handle_jump()
	_handle_attack_input()
	_update_procedural_body_posture(delta)

	if is_inside_tree():
		move_and_slide()
		var clamped_pos = CourtGeometry.clamp_player_to_training_area(global_position)
		global_position.x = clamped_pos.x
		global_position.z = clamped_pos.z
	else:
		position += velocity * delta
		var clamped_pos = CourtGeometry.clamp_player_to_training_area(position)
		position.x = clamped_pos.x
		position.z = clamped_pos.z

func _update_attack_swing_lifecycle(delta: float):
	if current_swing_phase == ContactResolver.AttackSwingPhase.READY:
		if right_arm_pivot:
			var rest_angle = -PI * 0.4 if (current_state == PlayerState.State.AIRBORNE or current_state == PlayerState.State.ATTACKING) else 0.0
			right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, rest_angle, 10.0 * delta)
		return

	swing_timer += delta
	swing_elapsed = swing_timer

	if swing_timer < WINDUP_DURATION:
		# Authentic WINDUP phase: arm prepares and draws back, NO contact allowed yet
		current_swing_phase = ContactResolver.AttackSwingPhase.WINDUP
		if right_arm_pivot:
			var t = swing_timer / WINDUP_DURATION
			right_arm_pivot.rotation.x = lerpf(0.0, PI * 0.65, t)
	elif swing_timer < (WINDUP_DURATION + ACTIVE_DURATION):
		# ACTIVE_CONTACT phase: arm snaps forward through hitting zone
		current_swing_phase = ContactResolver.AttackSwingPhase.ACTIVE_CONTACT
		if right_arm_pivot:
			var t = (swing_timer - WINDUP_DURATION) / ACTIVE_DURATION
			right_arm_pivot.rotation.x = lerpf(PI * 0.65, -PI * 0.25, t)

		# Check contact on physics ticks during active contact window if not yet contacted
		if not has_contacted_in_current_swing:
			var p_pos = global_position if is_inside_tree() else position
			var on_ground = is_on_floor() if is_inside_tree() else (position.y <= 0.05)
			var is_airborne = (current_state == PlayerState.State.AIRBORNE or not on_ground)
			var facing = get_player_facing_direction()
			attack_contact_check.emit(p_pos, is_airborne, current_aim_dir, facing, current_swing_phase, swing_elapsed)

	elif swing_timer < (WINDUP_DURATION + ACTIVE_DURATION + FOLLOW_THROUGH_DURATION):
		current_swing_phase = ContactResolver.AttackSwingPhase.FOLLOW_THROUGH
		if right_arm_pivot:
			var t = (swing_timer - (WINDUP_DURATION + ACTIVE_DURATION)) / FOLLOW_THROUGH_DURATION
			right_arm_pivot.rotation.x = lerpf(-PI * 0.25, -PI * 0.36, t)
	elif swing_timer < TOTAL_SWING_DURATION:
		current_swing_phase = ContactResolver.AttackSwingPhase.RECOVERY
		if right_arm_pivot:
			var t = (swing_timer - (WINDUP_DURATION + ACTIVE_DURATION + FOLLOW_THROUGH_DURATION)) / RECOVERY_DURATION
			right_arm_pivot.rotation.x = lerpf(-PI * 0.36, 0.0, t)
	else:
		# Swing complete, return to ready
		current_swing_phase = ContactResolver.AttackSwingPhase.READY
		swing_timer = 0.0
		swing_elapsed = 0.0
		has_contacted_in_current_swing = false
		if current_state == PlayerState.State.ATTACKING:
			var on_ground = is_on_floor() if is_inside_tree() else (position.y <= 0.05)
			_set_state(PlayerState.State.GROUNDED if on_ground else PlayerState.State.AIRBORNE)

func _update_procedural_body_posture(delta: float):
	if not visuals:
		return

	var target_scale_y = 1.0
	if landing_recovery_timer > 0.0:
		target_scale_y = 0.92
	elif current_state == PlayerState.State.AIRBORNE or current_state == PlayerState.State.ATTACKING:
		target_scale_y = 1.05

	visuals.scale.y = lerpf(visuals.scale.y, target_scale_y, 12.0 * delta)

func _handle_gravity_and_grounding(delta: float):
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.81)

	var on_ground = is_on_floor() if is_inside_tree() else (position.y <= 0.05)

	if not on_ground:
		velocity.y -= gravity * delta
		if current_state == PlayerState.State.GROUNDED:
			_set_state(PlayerState.State.AIRBORNE)
	else:
		if current_state == PlayerState.State.AIRBORNE or current_state == PlayerState.State.ATTACKING:
			_set_state(PlayerState.State.GROUNDED)
			has_attacked_in_current_jump = false
			landing_recovery_timer = 0.15

func _handle_input_movement(delta: float):
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0

	var move_direction = Vector3.ZERO
	if follow_camera and follow_camera.has_method("get_camera_forward"):
		var cam_forward = follow_camera.get_camera_forward()
		var cam_right = follow_camera.get_camera_right()
		move_direction = (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()
	else:
		move_direction = Vector3(input_dir.x, 0, -input_dir.y).normalized()

	var target_speed = attributes.move_speed
	var accel = attributes.acceleration if move_direction.length_squared() > 0.0 else attributes.deceleration

	var target_vel_x = move_direction.x * target_speed
	var target_vel_z = move_direction.z * target_speed

	velocity.x = move_toward(velocity.x, target_vel_x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel_z, accel * delta)

	var turn_rate = attributes.turn_speed if "turn_speed" in attributes else 14.0

	if move_direction.length_squared() > 0.01 and visuals:
		var target_angle = atan2(-move_direction.x, -move_direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, turn_rate * delta)
	elif visuals and (current_state == PlayerState.State.AIRBORNE or current_state == PlayerState.State.ATTACKING):
		var target_angle = 0.0
		if follow_camera and follow_camera.has_method("get_camera_forward"):
			var cam_fwd = follow_camera.get_camera_forward()
			target_angle = atan2(-cam_fwd.x, -cam_fwd.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, turn_rate * delta)

func _handle_jump():
	var on_ground = is_on_floor() if is_inside_tree() else (position.y <= 0.05)
	if Input.is_action_just_pressed("jump") and on_ground and jump_timer <= 0.0:
		velocity.y = attributes.jump_impulse
		jump_timer = attributes.jump_cooldown
		has_attacked_in_current_jump = false
		_set_state(PlayerState.State.AIRBORNE)

## Initiates a jump programmatically (used by input or scripted test adapter)
func trigger_jump():
	var on_ground = is_on_floor() if is_inside_tree() else (position.y <= 0.05)
	if on_ground and jump_timer <= 0.0:
		velocity.y = attributes.jump_impulse
		jump_timer = attributes.jump_cooldown
		has_attacked_in_current_jump = false
		_set_state(PlayerState.State.AIRBORNE)

func _handle_attack_input():
	if Input.is_action_just_pressed("attack"):
		trigger_attack()

## Initiates attack swing lifecycle (starting in WINDUP, then reaching ACTIVE_CONTACT)
func trigger_attack(aim_dir_override: Vector3 = Vector3.ZERO):
	var on_ground = is_on_floor() if is_inside_tree() else (position.y <= 0.05)
	if attack_cooldown_timer <= 0.0 and not has_attacked_in_current_jump:
		attack_cooldown_timer = 0.45
		var is_airborne = (current_state == PlayerState.State.AIRBORNE or not on_ground)
		if is_airborne:
			has_attacked_in_current_jump = true
			_set_state(PlayerState.State.ATTACKING)

		# Begin WINDUP: arm draws back for 80ms before active contact window opens
		current_swing_phase = ContactResolver.AttackSwingPhase.WINDUP
		swing_timer = 0.0
		swing_elapsed = 0.0
		has_contacted_in_current_swing = false

		if aim_dir_override != Vector3.ZERO:
			current_aim_dir = aim_dir_override
		elif follow_camera and follow_camera.has_method("get_aim_direction"):
			current_aim_dir = follow_camera.get_aim_direction()
		else:
			current_aim_dir = Vector3(0, -0.15, -1.0).normalized()

		swing_started.emit(current_swing_phase)

		# Also emit initial attack_attempted signal for tracking/legacy observers
		var facing_dir = get_player_facing_direction()
		var p_pos = global_position if is_inside_tree() else position
		attack_attempted.emit(p_pos, is_airborne, current_aim_dir, facing_dir, current_swing_phase, swing_elapsed)

func get_player_facing_direction() -> Vector3:
	if visuals:
		return -visuals.global_transform.basis.z if is_inside_tree() else -visuals.transform.basis.z
	return Vector3(0, 0, -1)

func _set_state(new_state: int):
	if current_state == new_state:
		return
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)

func register_contact_result(result: ContactResolver.ContactResult):
	if result.quality != ContactResolver.HitQuality.MISS:
		has_contacted_in_current_swing = true
	ball_hit.emit(result.quality, result.post_contact_velocity, result.message)
