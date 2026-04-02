# Native Runtime Bug Audit

## 1. Codebase Understanding Summary

### Active Android runtime path

`lib/main.dart` -> `TowerDefenseApp` -> `GameController.initialize()` -> Android-only `NativeGameBridge` path (`lib/src/features/game/application/controller.dart:191-207`) -> Kotlin channels/platform view -> C++ `NativeEngine`.

- Flutter owns shell navigation and HUD binding.
- Kotlin owns method/event bridging and the Android `GLSurfaceView` wrapper.
- C++ owns authoritative gameplay state: wave timing, pause flags, placement, upgrades, enemy movement, projectiles, and path rebuilding.

### Runtime ownership

- `GameController` is only a native snapshot consumer on Android. The Dart simulation path is fallback-only on non-Android (`controller.dart:198-206`).
- `MainActivity` forwards lifecycle directly into native code (`MainActivity.kt:38-46`).
- `NativeStateStream` polls snapshots every `33ms` on the game screen regardless of gameplay pause (`NativeStateStream.kt:24-35`).
- `GameBoardPlatformView` handles touch, placement popup display, and a wall-clock placement timeout (`GameBoardPlatformView.kt:143-176`, `218-235`).
- `NativeEngine` owns the real game loop: `onDrawFrame()` -> `updateSimulation()` -> `updateEnemies()` -> `updateTowers()` -> `updateProjectiles()` (`NativeEngine.cpp:558-565`, `1123-1167`).

### Entity lifecycle

- Towers are created in `NativeEngine::invokeAction("confirmPlacement")`, stored in `towers_`, and removed by marking `alive = false` in `"sellTower"` (`NativeEngine.cpp:753-844`).
- Enemies are spawned from `pendingEnemyQueue_`, moved by a cached direction field (`paths_`), then removed on leak or death (`NativeEngine.cpp:2010-2099`).
- Projectiles are advanced separately and apply splash damage on impact (`NativeEngine.cpp:2635-2703`).

### Data flow

- Input: Flutter button tap -> Kotlin `NativeControlChannelHandler` -> `NativeBridge.nativeInvokeAction(...)`.
- Simulation: C++ mutates authoritative state.
- Output: `NativeEngine::consumeUiSnapshot()` serializes HUD/selection/placement state back to Flutter.

## 2. Bug-by-Bug Analysis Table

| Bug | File / Function | Root Cause | Fix |
| --- | --- | --- | --- |
| 1. Tower placement fails silently when money is insufficient | `android/app/src/main/cpp/engine/runtime/NativeEngine.cpp` in `invokeAction()` (`724-792`) and `consumeUiSnapshot()` (`976-1096`); `android/app/src/main/kotlin/com/example/towerdefense/bridge/NativeControlChannelHandler.kt` (`77-99`) | Confirmed. Native code does set `placementMessage_ = "Not enough cash."` on `selectTower` and `confirmPlacement`, but the snapshot path overwrites the visible reason with `describePlacement(...)` whenever a tile is hovered, so the UI falls back to `"Valid placement."`. Kotlin then returns `result.success(null)` for placement actions, swallowing success/failure entirely. Type: logic + architecture. | Minimal: make `consumeUiSnapshot()` prefer `placementMessage_` over `describePlacement(...)` when build mode is active. Proper: return structured action results from native control calls instead of void/null. |
| 2. Pause state not preserved across app lifecycle | `android/app/src/main/kotlin/com/example/towerdefense/bridge/MainActivity.kt` (`38-46`); `android/app/src/main/cpp/engine/runtime/NativeEngine.cpp` in `onPause()` / `onResume()` (`571-585`) | Confirmed. `onPause()` forces `paused_ = true`, but `onResume()` always forces `paused_ = false`, so any pre-background pause intent is lost. There is no persisted pause reason or previous pause snapshot. Type: state bug. | Minimal: stop unconditionally clearing `paused_` in `onResume()`. Proper: track pause reasons separately (`userPaused`, `lifecyclePaused`, `defeatPaused`) and derive the effective paused state from them. |
| 3. Game auto-starts when app resumes | `MainActivity.kt` (`38-41`); `NativeEngine.cpp` `onResume()` (`577-585`) | Confirmed. Foregrounding always calls `NativeBridge.nativeOnResume()`, and native resume always clears pause. That restarts simulation without an explicit player action. Type: state bug. | Minimal: keep the game paused after resume. Proper: add a lifecycle-safe waiting state so foregrounding restores the board but requires explicit resume/play input. |
| 4. Timer / game progression continues in background | `android/app/src/main/kotlin/com/example/towerdefense/bridge/platform_view/GameBoardPlatformView.kt` (`143-176`); `android/app/src/main/kotlin/com/example/towerdefense/bridge/NativeStateStream.kt` (`24-35`); `NativeEngine.cpp` `updateSimulation()` (`1123-1167`) | Partially confirmed. Core simulation is halted while `paused_` is true, but non-simulation timers continue on wall clock: the placement popup timeout uses `System.currentTimeMillis()` and can cancel placement in the background, and the snapshot poller keeps running on a `Handler`. This is real progression of gameplay-affecting state outside the fixed-step sim. Type: architecture flaw. | Minimal: stop using wall-clock timeout to cancel placement. Proper: move placement deadline into native simulation ticks and expose remaining time through snapshots. |
| 5. Damage upgrade results in 0 damage | `android/app/src/main/cpp/engine/content/TowerCatalog.cpp` (`25-33`, `41-49`, `57-64`); `android/app/src/main/cpp/engine/content/TowerUpgrades.cpp` (`20-32`); `android/app/src/main/cpp/engine/runtime/NativeEngine.cpp` `updateTowers()` (`2352-2618`) | Confirmed. Multiple upgrade/content paths allow zero or near-zero effective damage: `machineGun` upgrades to `0..10`, `laser` starts at `0..3`, and `beamEmitter` upgrades to `0.001..0.1`. `rollDamage()` rounds these values, and the beam path multiplies by `beamChargeTicks * beamChargeTicks`; on a new target `beamChargeTicks == 0`, so the first upgraded beam hit is guaranteed `0`. Type: logic + content bug. | Minimal: clamp post-upgrade direct/beam damage to a positive minimum. Proper: fix both content values and firing formulas so upgrades never regress to zero-damage states unless explicitly designed as status-only towers. |
| 6. Enemy bypassing walls | `android/app/src/main/cpp/engine/runtime/NativeEngine.cpp` `rebuildDynamicPaths()` (`1862-1877`), `updateEnemies()` (`2010-2099`), `placeable()` (`2191-2233`); `android/app/src/main/cpp/engine/systems/EnemySystem.cpp` steering/movement | Confirmed as a movement/pathing architecture flaw. Enemy movement follows cached direction fields only; there is no collision resolution against dynamic blockers. If an enemy reaches a tile where `pathAt(...) == 0`, steering returns early and the previous velocity is preserved, so the enemy can drift through spaces that should behave as blocked after topology changes or stale path state. Type: architecture flaw. | Minimal: zero enemy velocity when direction data is invalid and rebuild paths on every occupancy change. Proper: couple occupancy/path invalidation to placement/sell events and reject/repair any enemy that enters a non-walkable tile. |
| 7. Inconsistent tower placement tiles | `NativeEngine.cpp` `loadMapById()` (`1826-1859`), `canPlace()` (`2236-2247`), `describePlacement()` (`2250-2275`); Dart parser `lib/src/features/game/infrastructure/maps.dart` (`50-87`) | Confirmed as a cross-runtime data-model mismatch. The active native runtime only uses compiled `grid_` integers and hardcoded tile semantics, while the Dart/editor path preserves `display`, `displayDirection`, `metadata`, and `paths`. Native Android ignores metadata entirely, so placement truth is not normalized across systems. Type: architecture flaw. | Minimal: centralize native tile classification helpers instead of duplicating raw `gridValue` checks. Proper: define one buildability model from imported/generated map data and feed the same flags into placement, pathing, and UI reason strings. |

## 3. Code Fix Snippets

### Bug 1: Preserve the real failure reason and stop swallowing action failures

```cpp
// NativeEngine::consumeUiSnapshot
std::string placementReason = "No tower selected. Tap a placed tower or choose one from the dock.";
if (buildMode_) {
    if (!placementMessage_.empty()) {
        placementReason = placementMessage_;
    } else if (hoveredCol_ >= 0 && hoveredRow_ >= 0) {
        placementReason = describePlacement(hoveredCol_, hoveredRow_);
    } else {
        placementReason = "Choose a tile.";
    }
}
```

```kotlin
// NativeControlChannelHandler.kt
private fun invokeBooleanAction(actionId: String, result: MethodChannel.Result) {
    val before = NativeBridge.nativeConsumeUiSnapshot()
    NativeBridge.nativeInvokeAction(actionId)
    val after = NativeBridge.nativeConsumeUiSnapshot()
    stateStream.emitNow()
    result.success(before != after)
}
```

### Bug 2 and Bug 3: Preserve pause state and do not auto-resume on foreground

```cpp
// NativeEngine.h
bool lifecyclePaused_ = false;
bool userPaused_ = false;

// NativeEngine.cpp
void NativeEngine::onPause() {
    std::scoped_lock lock(mutex_);
    lifecyclePaused_ = true;
    paused_ = true;
    waveRuntime_.paused = true;
}

void NativeEngine::onResume() {
    std::scoped_lock lock(mutex_);
    lifecyclePaused_ = false;
    paused_ = true;              // stay paused until explicit user resume
    waveRuntime_.paused = true;
    lastFrameAt_ = std::chrono::steady_clock::now();
    simAccumulatorSeconds_ = 0.0;
    renderAlpha_ = 0.0f;
    smoothedFrameTimeMs_ = std::max(1.0f, lastFrameTimeMs_);
}

// togglePause action
userPaused_ = !userPaused_;
paused_ = lifecyclePaused_ || userPaused_;
waveRuntime_.paused = paused_;
```

### Bug 4: Move placement timeout into simulation time

```cpp
// NativeEngine.h
int pendingPlacementExpiryTick_ = -1;

// when placement becomes confirmable
pendingPlacementExpiryTick_ = tickCount_ + (7 * 60);

// NativeEngine::updateSimulation
if (buildMode_ && pendingPlacementExpiryTick_ >= 0 && tickCount_ >= pendingPlacementExpiryTick_) {
    pendingPlacementCol_ = -1;
    pendingPlacementRow_ = -1;
    pendingPlacementExpiryTick_ = -1;
    placementMessage_ = "Placement timed out.";
}
```

```kotlin
// GameBoardPlatformView.kt
// Render remaining time from snapshot data only. Do not cancel using System.currentTimeMillis().
val remainingTicks = pending.remainingTicks
val countdown = max(1, (remainingTicks + 59) / 60)
countdownLabel.text = "${countdown}s"
```

### Bug 5: Prevent zero-damage upgrades

```cpp
// NativeEngine::updateTowers
const auto rollDamage = [this](const TowerInstance &tower) -> float {
    const float rolled = randomRange(tower.damageMin, tower.damageMax);
    if (tower.kind == "machineGun" || tower.kind == "laser") {
        return std::max(1.0f, std::round(rolled));
    }
    return std::max(0.0f, std::round(rolled));
};

if (tower.kind == "beamEmitter") {
    const float baseDamage = std::max(1.0f, randomRange(tower.damageMin, tower.damageMax));
    const float charge = static_cast<float>(std::max(1, tower.beamChargeTicks));
    dealDamage(enemy, baseDamage * charge * charge, damageType);
    continue;
}
```

```cpp
// TowerCatalog.cpp: content-level correction
// Avoid upgrade entries whose post-rounding minimum damage is zero unless the tower is explicitly status-only.
{ "machineGun", "Machine Gun", 75, 1.0f, 10.0f, 3.0f, 0, 5, ... }
{ "laser", "Laser Tower", 75, 1.0f, 3.0f, 2.0f, 0, 1, ... }
{ "beamEmitter", "Beam Emitter", 200, 1.0f, 4.0f, 3.0f, 0, 0, ... }
```

### Bug 6: Stop drift on invalid path data and rebuild on every occupancy change

```cpp
// EnemySystem.cpp or NativeEngine::steerEnemy
const int direction = pathAt(col, row);
if (direction == 0) {
    enemy.vx = 0.0f;
    enemy.vy = 0.0f;
    return;
}
if (!atTileCenter(enemy.x, enemy.y, col, row)) {
    return;
}
```

```cpp
// after any successful placement or sell
rebuildDynamicPaths();
```

### Bug 7: Unify tile semantics behind one helper

```cpp
enum class TileKind {
    Buildable,
    Blocked,
    Path,
    Socket,
};

TileKind classifyTile(int gridValue) {
    switch (gridValue) {
        case 1: return TileKind::Blocked;
        case 2:
        case 4: return TileKind::Path;
        case 3: return TileKind::Socket;
        default: return TileKind::Buildable;
    }
}

bool NativeEngine::canPlace(int col, int row) const {
    switch (classifyTile(tileAt(col, row))) {
        case TileKind::Blocked:
        case TileKind::Path:
            return false;
        case TileKind::Socket:
            return !towerAt(col, row);
        case TileKind::Buildable:
            return emptyTile(col, row) && placeable(col, row);
    }
    return false;
}
```

## 4. Architecture Improvements

### State machine

Use an explicit native game state:

`INIT -> PREPARE -> RUNNING -> PAUSED -> GAME_OVER`

- `INIT`: engine/bootstrap only.
- `PREPARE`: map loaded, board visible, waiting for explicit start/resume.
- `RUNNING`: fixed-step simulation active.
- `PAUSED`: user pause, lifecycle pause, or modal pause.
- `GAME_OVER`: defeat frozen until restart.

Do not encode pause intent in one boolean. Track pause reasons separately and derive the effective state.

### Lifecycle-safe game loop

- `onPause()` should add a lifecycle pause reason, not destroy player intent.
- `onResume()` should restore rendering clocks only and keep simulation paused until the state machine allows `RUNNING`.
- Any countdown that changes gameplay state must be driven by simulation ticks, not Android wall clock.

### Grid system redesign

- Replace raw `gridValue` checks with a typed tile model used by placement, UI reason strings, and path rebuilding.
- Normalize authored/imported map data once at load time.
- Ensure custom/imported maps and bundled generated maps produce the same native buildability rules.

### Pathfinding recalculation strategy

- Rebuild path data on every occupancy change, not only some tile classes.
- Track a path-version counter and invalidate enemy steering when topology changes.
- If an enemy lands on a tile with no valid direction, snap it to the nearest valid tile center or zero velocity and request path recovery.

### Upgrade system design

- Separate content balance from upgrade application logic.
- Use immutable catalog stats for each tower tier and validate them at startup.
- Add invariant checks: upgraded towers must not reduce effective damage below a configured floor unless marked `status_only`.

## 5. Risk Notes

- Bug 2 and Bug 3 share the same core defect. Fix them together to avoid trading one lifecycle regression for another.
- Bug 4 is not a full “simulation keeps running” issue on the active path; it is a gameplay-affecting timer leak outside the simulation clock. The report should keep that distinction explicit.
- Bug 6 needs care around path rebuild frequency. Rebuilding on every occupancy change is correct; rebuilding every frame is not.
- Bug 7 is partly architectural debt. A quick helper-based cleanup reduces inconsistency, but full parity requires unifying native map ingestion with editor/import semantics.
- `flutter analyze` was intentionally skipped per user request, so this report is based on source-trace evidence rather than analyzer output.
