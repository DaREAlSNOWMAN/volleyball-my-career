class_name PlayerState
extends RefCounted

## Explicit state enumeration for player athlete
enum State {
	GROUNDED = 0,
	AIRBORNE = 1,
	ATTACKING = 2,
	LANDING = 3
}

static func state_name(state: State) -> String:
	match state:
		State.GROUNDED:
			return "Grounded"
		State.AIRBORNE:
			return "Airborne"
		State.ATTACKING:
			return "Attacking"
		State.LANDING:
			return "Landing"
		_:
			return "Unknown"
