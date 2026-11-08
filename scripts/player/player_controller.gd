class_name PlayerController
extends CharacterBody3D

const PlayerState = preload("res://scripts/player/player_state.gd")
const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")
const ContactResolver = preload("res://scripts/systems/contact_resolver.gd")
const PlayerAttributes = preload("res://resources/player_attributes.gd")
const FollowCamera = preload("res://scripts/camera/follow_camera.gd")

signal state_changed(old_state: int, new_state: int)
signal attack_attempted(player_pos: Vector3, is_airborne: bool, aim_direction: Vector3)
signal ball_hit(quality: int, impulse: Vector3, message: String)

@export var attributes: Resource # PlayerAttributes
@export var follow_camera: Node3D # FollowCamera

var current_state: int = PlayerState.State.GROUNDED
var attack_cooldown_timer: float = 0.0
var jump_timer: float = 0.0
var has_attacked_in_current_jump: bool = false

@onready var visuals: Node3D = $Visuals

func _ready():
	if not attributes:
		attributes = PlayerAttributes.new()

func _physics_process(delta: float):
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if jump_timer > 0.0:
		jump_timer -= delta

	_handle_gravity_and_grounding(delta)
	_handle_input_movement(delta)
	_handle_jump()
	_handle_attack_input()

	move_and_slide()

	# Boundary constraint: athlete remains on their court half
	var clamped_pos = CourtGeometry.clamp_player_to_training_area(global_position)
	global_position.x = clamped_pos.x
	global_position.z = clamped_pos.z

func _handle_gravity_and_grounding(delta: float):
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.81)

	if not is_on_floor():
		velocity.y -= gravity * delta
		if current_state == PlayerState.State.GROUNDED:
			_set_state(PlayerState.State.AIRBORNE)
	else:
		if current_state == PlayerState.State.AIRBORNE or current_state == PlayerState.State.ATTACKING:
			_set_state(PlayerState.State.GROUNDED)
			has_attacked_in_current_jump = false

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

	# Face towards movement direction or towards opponent court
	if move_direction.length_squared() > 0.01 and visuals:
		var target_angle = atan2(-move_direction.x, -move_direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 12.0 * delta)
	elif visuals and current_state == PlayerState.State.AIRBORNE:
		# When airborne, athlete naturally faces the net (negative Z direction)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, 0.0, 8.0 * delta)

func _handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor() and jump_timer <= 0.0:
		velocity.y = attributes.jump_impulse
		jump_timer = attributes.jump_cooldown
		has_attacked_in_current_jump = false
		_set_state(PlayerState.State.AIRBORNE)

func _handle_attack_input():
	if Input.is_action_just_pressed("attack"):
		if attack_cooldown_timer <= 0.0 and not has_attacked_in_current_jump:
			attack_cooldown_timer = 0.3
			var is_airborne = (current_state == PlayerState.State.AIRBORNE or not is_on_floor())
			if is_airborne:
				has_attacked_in_current_jump = true
				_set_state(PlayerState.State.ATTACKING)

			var aim_dir = Vector3(0, -0.25, -1.0).normalized()
			if follow_camera and follow_camera.has_method("get_aim_direction"):
				aim_dir = follow_camera.get_aim_direction()

			attack_attempted.emit(global_position, is_airborne, aim_dir)

func _set_state(new_state: int):
	if current_state == new_state:
		return
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)

## Called when ContactResolver finishes evaluating the hit
func register_contact_result(result: ContactResolver.ContactResult):
	ball_hit.emit(result.quality, result.impulse, result.message)
