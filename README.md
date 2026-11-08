# Volleyball MyCareer — Milestone 1.2 (M1.2): Foundation Stabilization

**Milestone:** M1.2 — Autonomous Foundation Stabilization
**Engine:** Godot 4.3 (Forward Plus / Compatibility), GDScript
**Target:** Windows PC, with cross-platform project compatibility
**Status:** Mechanically Verified 3D Spike-Training Prototype — Human Playtest Required

---

## 1. Summary of M1.2 Architectural & Mechanical Enhancements

Milestone 1.2 focuses on foundation stabilization, mathematical correctness, lifecycle hardening, and full scene-level automated integration testing:

1. **Physical & Trajectory Accuracy:**
   - **Net-Clearance Guarantee:** Spike trajectory assertions in `tests/test_contact.gd` rigorously verify net-plane intersection ($Z = 0$), accounting for the 0.105m ball radius over the 2.43m men's net height, as well as downstream landing within the 9×9m opponent court.
   - **Post-Contact Velocity Terminology:** Standardized post-contact physical velocities ($m/s$) across `VolleyballController` and `ContactResolver`, distinguishing physical velocities from raw impulse units ($N\cdot s$).
   - **Contact Anchor:** Evaluates contact based on the striking hand's spatial position high and forward/right of the athlete during full extension rather than the character root origin.

2. **Temporal Attack Lifecycle:**
   - Implemented explicit swing phases in `ContactResolver` and `PlayerController`:
     $$\text{READY} \rightarrow \text{WINDUP (80ms)} \rightarrow \text{ACTIVE\_CONTACT (160ms)} \rightarrow \text{FOLLOW\_THROUGH (120ms)} \rightarrow \text{RECOVERY (90ms)}$$
   - Hits initiated prematurely in windup or belatedly in follow-through are rejected as authentic temporal misses.

3. **Hardened Training State Machine:**
   - State progression: $\text{IDLE} \rightarrow \text{PREPARING} \rightarrow \text{FEEDING} \rightarrow \text{ATTACKABLE} \rightarrow \text{RESOLVING} \rightarrow \text{RESULT} \rightarrow \text{RESET}$.
   - **Unique Attempt IDs:** Every feed is assigned an incremental attempt ID. In-flight callbacks arriving from prior or cancelled feeds are rejected to prevent counter corruption.
   - **Timeout Safeguard:** Trapped or unresolvable feeds automatically resolve after a bounded timeout ($4.5s$), preventing locked states.

4. **Difficulty Presets:**
   - **Beginner (Default):** High feed arc ($5.2m$ apex), generous contact tolerance ($1.6m$), wider timing windows ($0.35s$ clean / $0.60s$ weak).
   - **Standard:** Balanced feed arc ($4.8m$ apex), authentic timing ($0.25s$ clean / $0.45s$ weak), $1.35m$ tolerance.
   - **Advanced:** Demanding set placement ($4.4m$ apex), tight timing ($0.18s$ clean / $0.35s$ weak), $1.15m$ tolerance.

5. **Automated Playtest Harness (`tests/test_playtest_harness.gd`):**
   - **Scenario A:** Full scene integration spike from feed to in-bounds opponent court landing.
   - **Scenario B:** Early swing rejection during windup.
   - **Scenario C:** Late swing rejection during follow-through.
   - **Scenario D:** Distant attack rejection beyond reach.
   - **Scenario E:** Net collision detection and net fault recording.
   - **Scenario F:** Out-of-bounds landing classification.
   - **Scenario G:** Rapid reset clearing outdated landing events.
   - **Scenario H:** Repeated feed requests without memory corruption or state stalling.
   - **Scenario I:** 100 consecutive training cycles executing cleanly without memory leaks or counter drift.
   - **Scenario J:** Camera and movement stability verifying non-divergent finite transforms.

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
│   ├── court.tscn             # 18x9m indoor court, lines, net, posts, walls, top-tape
│   ├── player.tscn            # Directional humanoid athlete placeholder with articulated arm
│   ├── volleyball.tscn        # RigidBody3D volleyball with collision and physics material
│   ├── training_launcher.tscn # Ballistic training launcher model & logic
│   └── training_hud.tscn      # CanvasLayer HUD with feedback labels & stats
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd # Movement, jump, attack lifecycle, arm swing, facing direction
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
│   │   └── contact_resolver.gd  # Attack contact anchor, swing phases, timing windows, net clearance
│   └── ui/
│       └── training_hud.gd      # HUD stats, difficulty display, readiness indicator, feedback messages
├── resources/
│   ├── player_attributes.gd     # Configurable athlete stats (power, reach, timing windows)
│   └── training_settings.gd     # Configurable difficulty presets, launcher & exercise parameters
├── tests/
│   ├── run_tests.gd             # Master headless automated test runner
│   ├── test_geometry.gd         # Unit tests for court boundaries and line rules
│   ├── test_contact.gd          # Unit tests for contact anchor, swing phases, net clearance
│   ├── test_training_reset.gd   # Unit tests for launcher arrival, contact pipeline, and 10 full cycles
│   └── test_playtest_harness.gd # Scene-level integration harness (Scenarios A through J & 100 cycles)
└── README.md
```

---

## 4. Running the Tests and Scene

### Headless Automated Test Execution
Run the complete automated test suite (including unit tests and the 100-cycle scene integration harness):
```bash
godot -s tests/run_tests.gd --headless
```
*Expected Result:* All 4 test suites pass with exit code `0`.

### Manual Playtesting Instructions
Launch the game in Godot 4.3:
```bash
godot scenes/main.tscn
```
1. **Movement & Camera:** Use WASD to navigate the player's court half. Use the mouse to orbit smoothly. Note the front-facing visor and procedural arm motion.
2. **Requesting a Set:** Press **[F]** to trigger a high set. The camera smoothly tracks the ball while maintaining player focus.
3. **Approach & Jump:** Move toward the landing shadow near the attack line. Press **[Space]** to jump.
4. **Timing the Spike:** Watch for the `>>> IN HITTING WINDOW - SPIKE NOW! <<<` prompt on the HUD. Click **[LMB]** during the jump apex.
5. **Evaluating the Outcome:** Observe the ball clear the white top tape of the net and descend onto the opponent's side of the court. The HUD registers a Clean Hit and In-Bounds Point.
6. **Cancellation & Resets:** Press **[R]** mid-feed to verify immediate cancellation without trapped state.

---

## 5. Current Limitations (Milestone 1.2 Scope)
- **Single-Athlete Focus:** Teammate AI, setter AI, and opponent blockers remain non-goals for M1.
- **Placeholder Art:** Geometric primitive meshes and untextured PBR materials.
- **Status:** Mechanically verified through automated test suites and scene integration harness. Final gameplay feel requires subjective human playtesting.
