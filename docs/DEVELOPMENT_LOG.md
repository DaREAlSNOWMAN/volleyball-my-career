# Volleyball MyCareer — Development Log

## Mission M1.1 — Gameplay Rescue
- Identified missing timing window evaluation, capsule readability, and fixed launcher trajectories.
- Implemented `get_attack_sweet_spot` based on athlete height and facing direction.
- Implemented configurable timing windows (`timing_window_clean`, `timing_window_weak`).
- Added directional humanoid placeholder with visible facing visor and right arm pivot.
- Added 5-phase training state machine and live HUD indicators.

## Mission M1.2 — Foundation Stabilization
- Fixed net clearance assertions to account for ball radius (0.105m) and men's net height (2.43m) at Z=0.
- Implemented explicit swing phases (`READY`, `WINDUP`, `ACTIVE_CONTACT`, `FOLLOW_THROUGH`, `RECOVERY`).
- Standardized post-contact velocity naming in m/s.
- Created synthetic playtest harness verifying Scenarios A through J and 100 cycles.
- Added Beginner, Standard, and Advanced difficulty presets.

## Mission M1.3 — Real Gameplay Integration & Verification
- Corrected attack lifecycle: attack input initiates 80ms WINDUP before entering 160ms ACTIVE_CONTACT.
- Contact checks evaluate on physics ticks during active contact window; allows at most 1 hit per swing.
- Built live engine physics playtest harness (`tests/test_scene_physics_integration.gd`) simulating approach, jump, windup, contact, net clearance, and floor landing.
- All 5 test suites pass headless Godot verification with zero errors.
