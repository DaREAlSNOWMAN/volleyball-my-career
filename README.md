# Volleyball MyCareer — Milestone 1.1 (M1.1): Gameplay Rescue

**Milestone:** M1.1 — Gameplay Rescue
**Engine:** Godot 4.3 (Forward Plus / Compatibility), GDScript
**Target:** Windows PC, with cross-platform project compatibility
**Status:** Complete playable 3D training prototype

---

## 1. Summary of M1.1 Gameplay Improvements

Milestone 1.1 focuses on usability, training feedback, and mechanical polish based on playtesting feedback:

1. **Playable Spike Mechanics:**
   - **Attack Sweet Spot Region:** Replaced player-origin distance checking with an authentic attack contact region relative to athlete height, reach, and facing direction (`ContactResolver.get_attack_sweet_spot`).
   - **Timing Windows:** Implemented configurable clean vs weak spike timing windows (`timing_window_clean`, `timing_window_weak`).
   - **Ballistic Apex Feeds:** `TrainingLauncher` computes launch velocity using `feed_arc_height` (apex physics), delivering high, readable arcs into the player's attack zone.
   - **Single-Hit Enforcement:** `VolleyballController.apply_spike()` prevents multiple hits on the same ball from one swing or during a single feed.
   - **Clearance & Trajectory:** Spikes feature authentic downward depression angles that guarantee clearance over the 2.43m net and landing within the opponent's 9x9m half.

2. **Player Readability & Movement Feel:**
   - Replaced plain capsule with a directional humanoid placeholder (torso, articulated limbs, directional facing visor, and right hitting arm).
   - Visual arm swing indicator rotates forward and down upon attack triggering.
   - Athlete smoothly turns to face camera aim or net when airborne.

3. **Camera & Framing:**
   - Improved third-person follow camera with gentle, subtle ball-in-flight tracking assist (`enable_ball_tracking_assist`) keeping the incoming set and net clearly visible without snapping.
   - Distance, height, smoothing, and pitch limits configured for optimal court framing.

4. **Training State Sequence & HUD:**
   - Explicit training lifecycle: `IDLE` -> `FEEDING` -> `ATTACK_WINDOW` -> `RESULT` -> `RESET`.
   - Contact readiness prompt: Displays `>>> IN HITTING WINDOW - SPIKE NOW! <<<` when the ball enters the attackable zone.
   - Granular statistics: Feeds, Completed Attempts, Clean Hits, Weak Hits, Missed Swings, Untouched Feeds, In-Bounds, and Out-of-Bounds.

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

## 3. Project Architecture

```text
├── project.godot
├── scenes/
│   ├── main.tscn              # Root scene wiring court, player, camera, launcher, ball, HUD
│   ├── court.tscn             # 18x9m indoor court, lines, net, posts, walls
│   ├── player.tscn            # Directional humanoid athlete placeholder
│   ├── volleyball.tscn        # RigidBody3D volleyball with collision and physics material
│   ├── training_launcher.tscn # Ballistic training launcher model & logic
│   └── training_hud.tscn      # CanvasLayer HUD with feedback labels & stats
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd # Movement, jump, attack trigger, arm swing, facing direction
│   │   └── player_state.gd      # Explicit state definitions (GROUNDED, AIRBORNE, etc.)
│   ├── ball/
│   │   └── volleyball_controller.gd # Rigid body physics, single-hit enforcement, landing detection
│   ├── camera/
│   │   └── follow_camera.gd     # Smooth follow, mouse orbit, ball tracking assist
│   ├── training/
│   │   ├── training_manager.gd  # Lifecycle state machine (IDLE -> FEEDING -> ATTACK_WINDOW -> RESULT -> RESET)
│   │   └── training_launcher.gd # Ballistic apex trajectory calculator and feed emitter
│   ├── systems/
│   │   ├── court_geometry.gd    # In/out court boundaries, line tolerance, clamping
│   │   └── contact_resolver.gd  # Attack sweet spot, timing windows, impulse calculations
│   └── ui/
│       └── training_hud.gd      # HUD stats, state display, readiness indicator, feedback messages
├── resources/
│   ├── player_attributes.gd     # Configurable athlete stats (power, reach, timing windows)
│   └── training_settings.gd     # Configurable launcher & exercise parameters
├── tests/
│   ├── run_tests.gd             # Master headless automated test runner
│   ├── test_geometry.gd         # Unit tests for court boundaries and line rules
│   ├── test_contact.gd          # Unit tests for sweet spot, timing windows, net clearance
│   └── test_training_reset.gd   # Integration tests for launcher arrival, contact pipeline, and 10 full cycles
└── README.md
```

---

## 4. How to Run and Test

### Running the Game (Visual / Manual Validation)
Launch directly in Godot 4.3:
```bash
godot scenes/main.tscn
```
**Manual Playtesting Verification Steps:**
1. Observe athlete: Directional head visor and arm positions show facing direction clearly.
2. Move with WASD; verify smooth turning and camera-relative motion.
3. Press **[F]** to request a high set: Watch ball launch along a readable high arc peaking at ~4.8m.
4. Camera subtly tilts/blends to keep both athlete and the incoming set in view.
5. Time your approach: Watch the HUD display `>>> IN HITTING WINDOW - SPIKE NOW! <<<`.
6. Press **[Space]** to jump, aim at opponent court with mouse, and press **[LMB]** to spike.
7. Observe clean hit feedback: Ball crosses net and lands in bounds on the opponent's side.
8. HUD updates statistics cleanly. Repeat 10 times without restart.

### Running Headless Automated Test Suite
```bash
godot -s tests/run_tests.gd --headless
```
The suite executes:
- `TestGeometry`: Court bounds, lines included in bounds, opponent vs player zones.
- `TestContact`: Sweet spot calculation, grounded miss, distant miss, mistimed height miss, clean hit, weak hit, net clearance.
- `TestTrainingReset`: Ballistic apex trajectory arrival, ContactResolver-to-Volleyball pipeline, single-hit enforcement, 10 clean full cycles, and reset invariants.

---

## 5. Current Limitations (Milestone 1.1 Scope)
- **Single athlete solo training:** No teammates, AI setters, or opponent blockers.
- **Placeholder art:** Primitive meshes used for player and equipment.
- **Physics aerodynamics:** Standard gravity and topspin impulse without full Magnus aerodynamic fluid calculations.
