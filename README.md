# Volleyball MyCareer — Milestone 1 (M1): First Contact

**Milestone:** M1 — First Contact
**Engine:** Godot 4.3 (Forward Plus / Compatibility), GDScript
**Target:** Windows PC, with cross-platform project compatibility
**Status:** Complete playable 3D training prototype

---

## 1. Project Overview

Volleyball MyCareer is a single-player 3D volleyball career simulation. Milestone 1 establishes the playable core vertical slice: an athlete training on an indoor volleyball court with responsive movement, jumping, assisted spike mechanics, camera controls, automated feeds, and real-time in/out court scoring.

### Completed Milestone 1 Features:
- **Indoor Volleyball Court:** FIVB standard dimensions (18m × 9m, net height 2.43m, attack lines at 3m, 5cm line width in-bounds rules, net collision).
- **Third-Person Athlete Controller:** CharacterBody3D with camera-relative movement, responsive acceleration/deceleration, jump impulse, airborne/attacking states, and court boundary constraints.
- **Third-Person Follow Camera:** Smooth follow target, mouse-driven pitch and yaw orbiting, pitch clamping, and customizable distance/height/sensitivity.
- **Volleyball Physics:** 3D rigid body matching standard scale (~65cm circumference, 0.27kg mass) with gravity, bounce restitution, net collision, and floor impact detection.
- **Assisted Spike Mechanic:** Deterministic `ContactResolver` evaluating 3D distance, relative height, airborne status, aiming vector, and tolerances to yield Clean hits, Weak hits, or Misses without teleportation.
- **Training Launcher:** Feeds predictable, reproducible sets/arcs to the player's attack zone upon trigger.
- **Training HUD:** Non-intrusive gameplay interface showing exercise title, reps, hits, misses, in-bounds/out-of-bounds score, hit quality feedback, and key bindings.
- **Repeatable Training Loop:** Seamless retry loop without scene reloading or object leaking (verified over 10+ successive reps).

---

## 2. Controls

| Input | Action | Description |
|---|---|---|
| **W, A, S, D** | Movement | Move athlete relative to camera orientation |
| **Mouse Move** | Camera Orbit | Orbit third-person camera around athlete |
| **Space** | Jump | Leap into airborne state for spike approach |
| **Left Mouse Button** | Spike Attack | Strike ball when airborne within reach; direction driven by camera aim |
| **F** | Request Feed | Trigger training launcher to deliver a new ball |
| **R** | Reset Ball | Cancel current feed and reset ball to standby |
| **Esc** | Toggle Mouse | Release or recapture mouse cursor |

---

## 3. Project Architecture & Directory Structure

```text
├── project.godot
├── scenes/
│   ├── main.tscn              # Root scene wiring court, player, camera, launcher, ball, HUD
│   ├── court.tscn             # 18x9m indoor court, lines, net, posts, walls
│   ├── player.tscn            # CharacterBody3D athlete with placeholder meshes
│   ├── volleyball.tscn        # RigidBody3D volleyball with collision and physics material
│   ├── training_launcher.tscn # Training launcher model & logic
│   └── training_hud.tscn      # CanvasLayer HUD with feedback labels & stats
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd # Movement, jump, attack trigger, boundary clamping
│   │   └── player_state.gd      # Explicit state definitions (GROUNDED, AIRBORNE, etc.)
│   ├── ball/
│   │   └── volleyball_controller.gd # Rigid body physics, launch, spike, landing detection
│   ├── camera/
│   │   └── follow_camera.gd     # Smooth follow and mouse orbit camera
│   ├── training/
│   │   ├── training_manager.gd  # Loop orchestrator, scoring, hit verification
│   │   └── training_launcher.gd # Ballistic trajectory calculator and feed emitter
│   ├── systems/
│   │   ├── court_geometry.gd    # In/out court boundaries, line tolerance, clamping
│   │   └── contact_resolver.gd  # Assisted hit detection, timing, impulse math
│   └── ui/
│       └── training_hud.gd      # HUD stats and feedback messages
├── resources/
│   ├── player_attributes.gd     # Configurable athlete stats (power, reach, speed)
│   └── training_settings.gd     # Configurable launcher & exercise parameters
├── tests/
│   ├── run_tests.gd             # Master headless automated test runner
│   ├── test_geometry.gd         # Unit tests for court boundaries and line rules
│   ├── test_contact.gd          # Unit tests for spike reach, timing, hit qualities
│   └── test_training_reset.gd   # 10-rep repeatable training feed and reset tests
└── README.md
```

---

## 4. How to Run and Test

### Prerequisites
- Godot Engine 4.3 (or 4.x compatible standard binary).

### Running the Game
Open the project folder in Godot 4.3 and press **Run Project** (F5), or launch directly via terminal:
```bash
godot scenes/main.tscn
```

### Running Automated Smoke & Unit Tests
Run the automated test runner in headless mode:
```bash
godot -s tests/run_tests.gd --headless
```
The test runner executes 3 test suites:
1. `TestGeometry`: Validates FIVB court boundary logic, lines included in bounds, opponent vs player zones, and player boundary clamping.
2. `TestContact`: Validates airborne requirements, reach limitations, mistimed height misses, clean spike impulse, and weak off-center hits.
3. `TestTrainingReset`: Validates 10 full cycles of feeding, spiking, landing, and resetting without scene reload or state corruption.

All automated tests exit with exit code `0` on success and `1` on failure.

---

## 5. Current Limitations & M2 Roadmap

### Limitations (Milestone 1 Scope):
- **Single athlete solo training:** No teammates, AI setters, or blockers.
- **Placeholder graphics:** Geometric capsule athlete, cylinder posts, and basic shaded surfaces.
- **Simplified aerodynamics:** Standard gravity, bounce, and topspin impulse without full Magnus effect aerodynamic spin equations.
- **Manual feed requests:** Uses automated launcher feeds rather than human set passes.

### Milestone 2 (M2) Roadmap:
- AI Setter teammate capable of setting balls from player passes.
- Expanded contact repertoire: bumping (pass), setting, and blocking.
- Basic opponent blocker AI on the opposite side of the net.
- Character animation tree blending (run cycle, jump approach, spike swing, landing).
