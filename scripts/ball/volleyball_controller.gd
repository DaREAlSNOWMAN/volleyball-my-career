class_name VolleyballController
extends RigidBody3D

const CourtGeometry = preload("res://scripts/systems/court_geometry.gd")
const ContactResolver = preload("res://scripts/systems/contact_resolver.gd")

signal ball_hit_registered(quality: int, velocity: Vector3)
signal ball_landed(landing_zone: int, position: Vector3)
signal ball_net_hit()

enum BallState {
	INACTIVE = 0,
	IN_FLIGHT = 1,
	SPIKED = 2,
	LANDED = 3
}

var current_state: BallState = BallState.INACTIVE
var has_landed: bool = false
var has_been_hit: bool = false
var last_hit_quality: int = ContactResolver.HitQuality.MISS

# Standard volleyball radius: circumference 65-67cm => r = 0.105m
const BALL_RADIUS: float = 0.105
const FLOOR_Y_THRESHOLD: float = 0.12

func _ready():
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float):
	if current_state == BallState.INACTIVE or has_landed:
		return

	# Landing check against floor
	if get_ball_position().y <= FLOOR_Y_THRESHOLD:
		_process_landing(get_ball_position())

func _on_body_entered(body: Node):
	if has_landed:
		return

	if body.name == "GymFloor" or body.name == "CourtSurface":
		_process_landing(get_ball_position())
	elif body.name == "NetStructure" or body.name.begins_with("Post"):
		ball_net_hit.emit()

func _process_landing(contact_point: Vector3):
	has_landed = true
	var landing_zone = CourtGeometry.evaluate_landing(contact_point)
	current_state = BallState.LANDED
	ball_landed.emit(landing_zone, contact_point)

func get_ball_position() -> Vector3:
	return global_position if is_inside_tree() else position

## Launch ball from position with initial linear velocity
func launch(start_pos: Vector3, initial_velocity: Vector3):
	reset(start_pos)
	current_state = BallState.IN_FLIGHT
	has_been_hit = false
	linear_velocity = initial_velocity
	angular_velocity = Vector3(randf_range(-2, 2), randf_range(-1, 1), randf_range(-2, 2))

## Apply post-contact velocity (in m/s) to the ball (enforcing one hit per feed)
func apply_spike(post_contact_vel: Vector3, quality: int) -> bool:
	if has_been_hit:
		return false
	has_been_hit = true
	last_hit_quality = quality
	current_state = BallState.SPIKED
	linear_velocity = post_contact_vel
	# Add slight authentic topspin when spiked
	angular_velocity = Vector3(-post_contact_vel.length() * 0.8, 0, 0)
	ball_hit_registered.emit(quality, post_contact_vel)
	return true

## Reset the ball physics state completely
func reset(new_pos: Vector3 = Vector3(0, -10, 0)):
	has_landed = false
	has_been_hit = false
	last_hit_quality = ContactResolver.HitQuality.MISS
	current_state = BallState.INACTIVE
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if is_inside_tree():
		global_position = new_pos
	else:
		position = new_pos
