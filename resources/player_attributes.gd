class_name PlayerAttributes
extends Resource

## Physical & athletic attributes for the player character
@export_group("Athleticism")
@export var move_speed: float = 6.0
@export var acceleration: float = 24.0
@export var deceleration: float = 20.0
@export var jump_impulse: float = 7.2
@export var jump_cooldown: float = 0.15

@export_group("Attack Attributes")
@export var hitting_power: float = 16.0
@export var hit_assist_tolerance: float = 1.35
@export var vertical_reach: float = 2.9
@export var timing_window_clean: float = 0.25
@export var timing_window_weak: float = 0.45
