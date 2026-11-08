# Volleyball MyCareer — Milestone 1.3 (M1.3): Real Gameplay Integration & Verification

**Milestone:** M1.3 — Real Gameplay Integration & Verification
**Engine:** Godot 4.3 (Forward Plus / Compatibility), GDScript
**Target:** Windows PC, with cross-platform project compatibility
**Status:** M1.3 ENGINEERING COMPLETE — HUMAN GAMEPLAY APPROVAL REQUIRED

---

## 1. Executive Summary & Audit Remediation

Milestone 1.3 proves and enhances actual gameplay behavior by eliminating artificial test shortcuts and implementing authentic engine-level physics integration:

1. **Authentic Attack Lifecycle (Windup Precedence):**
   - Corrected `PlayerController` and `ContactResolver` so an attack input initiates `WINDUP` (80ms), drawing the athlete's arm back.
   - Contact cannot occur during windup. When entering `ACTIVE_CONTACT` (160ms), contact eligibility is continuously evaluated on physics ticks against active balls in proximity.
   - Restricts contact to at most one registered hit per swing, moving naturally into `FOLLOW_THROUGH` (120ms) and `RECOVERY` (90ms).

2. **Real Physics Scene-Level Integration Harness (`tests/test_scene_physics_integration.gd`):**
   - Runs full scene instances advancing actual engine physics frames (1/60s ticks).
   - Validates live ballistic trajectories originating from the launcher, crossing the 2.43m net, and descending predictably into the player's attack zone (Z ~ 2.5m, Y ~ 2.8m–3.1m).
   - Uses deterministic athlete approach, jump initiation, windup timing, sweet spot contact, net plane clearance ($y_{net} - r_{ball} > 2.43\text{m}$), and floor landing on the opponent court.
   - Differentiates synthetic state-transition tests (retained and accurately labeled in `tests/test_playtest_harness.gd`) from live physics-driven simulation runs.

3. **Telemetry & Measurable Spike Performance:**
   - Captures feed apex, arrival time, contact distance from striking anchor, post-contact velocity, net clearance margin, and landing coordinate.
   - Separates incoming feed net collisions from attacking net faults.

4. **Difficulty Presets:**
   - **Beginner (Default):** Generous arc (5.2m apex), wider timing window (0.35s clean / 0.60s weak), 1.6m reach.
   - **Standard:** Balanced arc (4.8m apex), authentic timing (0.25s clean / 0.45s weak), 1.35m reach.
   - **Advanced:** Demanding set (4.4m apex), tight timing (0.18s clean / 0.35s weak), 1.15m reach.

---

## 2. Controls

| Input | Action | Description |
|---|---|---|
| **W, A, S, D** | Movement | Move athlete relative to camera orientation |
| **Mouse Move** | Camera Orbit | Orbit third-person camera around athlete |
| **Space** | Jump | Leap into airborne state for spike approach |
| **Left Mouse Button** | Spike Attack | Trigger attack swing (windup -> active contact -> follow-through) |
| **F** | Request Feed | Trigger training launcher to deliver a new ball |
| **R** | Reset Ball | Cancel current feed and reset ball to standby |
| **Esc** | Toggle Mouse | Release or recapture mouse cursor |

---

## 3. Project Architecture

```text
├── project.godot
├── scenes/
│   ├── main.tscn              # Root scene wiring court, player, camera, launcher, ball, HUD
│   ├── court.tscn             # 18x9m indoor court, lines, net, posts, walls, top-tape
│   ├── player.tscn            # Directional humanoid athlete with articulated arm
│   ├── volleyball.tscn        # RigidBody3D volleyball with collision and physics material
│   ├── training_launcher.tscn # Ballistic training launcher model & logic
│   └── training_hud.tscn      # CanvasLayer HUD with feedback labels & stats
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd # Movement, jump, attack lifecycle (windup -> active), arm swing
│   │   └── player_state.gd      # Explicit state definitions (GROUNDED, AIRBORNE, etc.)
│   ├── ball/
│   │   └── volleyball_controller.gd # Rigid body physics, single-hit enforcement, landing detection
│   ├── camera/
│   │   └── follow_camera.gd     # Smooth follow, mouse orbit, ball tracking assist toggle
│   ├── training/
│   │   ├── training_manager.gd  # Lifecycle state machine (IDLE -> PREPARING -> FEEDING -> ATTACKABLE -> RESOLVING -> RESULT -> RESET)
│   │   └── training_launcher.gd # Ballistic apex trajectory calculator and feed emitter
│   ├── systems/
│   │   ├── court_geometry.gd    # In/out court boundaries, line tolerance, clamping
│   │   └── contact_resolver.gd  # Contact anchor, swing phases, timing windows, net clearance
│   └── ui/
│       └── training_hud.gd      # HUD stats, difficulty display, readiness indicator, feedback messages
├── resources/
│   ├── player_attributes.gd     # Configurable athlete stats (power, reach, timing windows)
│   └── training_settings.gd     # Configurable difficulty presets, launcher & exercise parameters
├── tests/
│   ├── run_tests.gd                   # Master headless automated test runner
│   ├── test_geometry.gd               # Unit tests for court boundaries and line rules
│   ├── test_contact.gd                # Unit tests for contact anchor, swing phases, net clearance
│   ├── test_training_reset.gd         # Unit tests for launcher arrival, contact pipeline, and 10 full cycles
│   ├── test_playtest_harness.gd       # Synthetic scene state harness (Scenarios A through J & 100 cycles)
│   └── test_scene_physics_integration.gd # Live physics integration harness (engine frames, real flight & landing)
└── README.md
```

---

## 4. How to Run and Verify

### Automated Headless Test Runner
Execute all 5 test suites (geometry, contact physics, unit reset, synthetic state harness, and live scene physics integration):
```bash
godot -s tests/run_tests.gd --headless
```
*Expected Result:* All 5 test suites pass with exit code `0`.

### Manual Playtesting Instructions
Launch the game directly:
```bash
godot scenes/main.tscn
```
1. **Movement:** Move around the player's side of the court with WASD. Observe responsive directional turns and visual facing indicator.
2. **Request Set:** Press **[F]** to request a set. Watch the ball launch along a high, readable arc peaking at 5.2m (Beginner default).
3. **Approach & Jump:** Move toward the landing zone near Z = 2.5m. Press **[Space]** to jump.
4. **Time the Attack:** Press **[LMB]** slightly before the ball reaches contact height to allow the 80ms windup to complete.
5. **Observe Contact & Landing:** Upon entering active contact, the athlete strikes the ball downward over the net. The ball lands on the opponent's side, registering an In-Bounds Clean Spike on the HUD.
6. **Cancellation & Resets:** Press **[R]** at any point to verify immediate, clean cancellation.

---

## 5. Current Limitations (Milestone 1.3 Scope)
- **Single Player Vertical Slice:** No teammates, AI setters, or opponent blockers.
- **Placeholder Visuals:** Primitive meshes and clean procedural animations without high-poly skeletal rigs.
- **Human Review:** Mechanically verified through automated test suites and real engine physics integration. Subjective gameplay feel requires human gameplay approval.
