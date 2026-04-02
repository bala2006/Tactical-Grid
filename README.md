# Tactical Grid Tower Defense

## Current Status

The project is no longer using the original JSON-based UI snapshot bridge for the native Android board. The main gameplay loop now runs through a packed native FFI snapshot/audio bridge, while Kotlin remains as a thin Android host for the `GLSurfaceView` and JNI render/input lifecycle calls.

The latest visible changes include:

| Area | Change |
| :--- | :--- |
| Native state sync | Replaced JSON/EventChannel polling with packed FFI snapshot reads |
| Native audio | Replaced JSON sound nonce flow and Android `SoundPool` path with FFI audio events consumed in Flutter |
| Android bridge | Removed `NativeStateStream.kt`, `NativeControlChannelHandler.kt`, and `NativeSoundPlayer.kt` |
| Runtime hot paths | Migrated major tower/enemy hot-path checks to enum-based IDs |
| Renderer | Packed vertex colors and added cached unit-circle meshes in `GlRenderer2D` |
| Placement UI | Moved inline placement popup into Flutter overlay and fixed anchor alignment to the actual build tile |
| Gameplay VFX | Added native enemy death box-shutter animation on kill |
| Map picker | Removed the visible `Custom` map option from the selector |
| Dev controls | Reduced developer toggle text and switch sizing |

## Before / After

These metrics are limited to changes that were actually implemented and verified in the codebase. They are not synthetic performance claims.

| Metric | Before | After | Accuracy |
| :--- | :--- | :--- | :--- |
| UI state transport | JSON string snapshot over JNI/Kotlin/EventChannel | Packed native snapshot read over FFI | Verified in code |
| Audio trigger path | JSON nonce + Kotlin `SoundPool` bridge | Native audio event queue + Flutter audio consumption | Verified in code |
| Kotlin state/audio bridge files | 3 files | 0 files | Verified in repo |
| Renderer circle/ellipse mesh generation | Recomputed trig data during draws | Cached unit-circle meshes reused by segment count | Verified in code |
| Vertex color storage | Per-channel float-style expansion in vertex build path | Packed `uint32_t` color | Verified in code |
| Placement popup anchoring | Offset/mismatched due to physical-vs-logical pixel mismatch | Anchored to tile center in Flutter logical coordinates | Verified in code |
| Enemy death feedback | Enemy disappears immediately on kill | Box-shutter death effect plays at kill position | Verified in code |

## Performance Metrics

Real frame-time, GC churn, and state-sync latency benchmarks have not been instrumented yet in this repository. The table below is intentionally limited to what has actually been measured during recent work.

| Measurement | Before | After | Status |
| :--- | :--- | :--- | :--- |
| `flutter analyze` | Not recorded historically | Pass | Verified |
| Android debug build | Not recorded historically | Pass | Verified |
| APK output | Not recorded historically | `build/app/outputs/flutter-apk/app-debug.apk` | Verified |
| State-sync latency in ms | Not benchmarked | Not benchmarked | Not yet measured |
| GC churn / alloc pauses | Not benchmarked | Not benchmarked | Not yet measured |
| Frame time / FPS under load | Not benchmarked | Not benchmarked | Not yet measured |

If you need true performance numbers, the remaining step is instrumentation on device for:

| Pending benchmark | Suggested method |
| :--- | :--- |
| Frame time / FPS | Android GPU profiler + in-game fixed-wave stress scenario |
| GC churn | Android Studio profiler / `logcat` GC events during heavy waves |
| State-sync latency | Timestamped native write vs Dart read sampling around snapshot polling |

## What Was Finished From The Migration Plan

| Plan item | Status | Notes |
| :--- | :--- | :--- |
| Replace JSON snapshot bridge | Done | FFI snapshot path is live |
| Move audio triggers off JSON path | Done | Audio events are queued natively and consumed from Flutter |
| Remove Kotlin JSON/audio intermediary | Done | State/audio broker files were removed |
| Enum-based hot-path migration | Partially done | Major tower/enemy runtime checks use enums now |
| Packed renderer colors | Done | Implemented in native renderer |
| Circle mesh caching | Done | Cached circle meshes are now reused |
| Placement popup overlay migration | Done | Popup is in Flutter and tied to build-mode state |

## Remaining Work

The plan is still not fully complete. The remaining items below are the important ones that are still open or only partially complete.

| Remaining area | Current state |
| :--- | :--- |
| Full removal of JNI intermediary layers | Not complete. Android still uses JNI for `GLSurfaceView`, rendering, touch forwarding, and lifecycle hooks |
| Full zero-copy world-state access | Not complete. The packed snapshot covers UI and placement state, not full large-array world exposure |
| Full handle/enum migration across all systems | Partial. Some string-based identifiers and content plumbing still exist |
| True performance benchmarking | Not done yet. No instrumented before/after timing dataset exists in the repo |
| Custom map support cleanup | Visible map selector entry was removed, but internal custom-map code paths still exist |

## Project Overview

Tactical Grid is a hybrid Flutter + native Android tower defense game with:

| Layer | Responsibility |
| :--- | :--- |
| Flutter / Dart | Shell UI, overlays, menus, state presentation, audio consumption |
| Kotlin / Android | Platform view host, JNI entry points, Android lifecycle integration |
| C++ / NDK | Core gameplay simulation, rendering, pathing, projectiles, enemy/tower runtime |
| OpenGL ES | Native board rendering via custom `GlRenderer2D` batching |

## Key Project Areas

| Path | Purpose |
| :--- | :--- |
| `lib/src/features/game/` | Game controller, models, bridge bindings, fallback simulation code |
| `lib/src/features/shell/` | Home screen, shell UI, overlays, settings and game screen layout |
| `android/app/src/main/cpp/engine/runtime/` | Native engine runtime, JNI/FFI bridge, snapshot/audio flow |
| `android/app/src/main/cpp/engine/rendering/` | OpenGL renderer and batching logic |
| `android/app/src/main/cpp/engine/content/` | Native tower/enemy catalog and balance data |
| `android/app/src/main/kotlin/com/sekhar/towerdefense/bridge/` | Android host integration for the native board |

## Gameplay Notes

Recent gameplay/UI behavior now includes:

| Feature | Current behavior |
| :--- | :--- |
| Inline placement popup | Appears above the build tile when space allows, otherwise below |
| Popup anchor | Uses the actual selected build tile center |
| Enemy death effect | A short box-shutter animation plays at the kill position |
| Map selector | `Custom` is hidden from the visible map selection UI |

## Verification

Recent verified checks:

| Command / Output | Result |
| :--- | :--- |
| `flutter analyze` | Passed |
| `flutter build apk --debug` | Passed |
| `build/app/outputs/flutter-apk/app-debug.apk` | Produced successfully |

## Running The Project

### Flutter tooling

| Command | Purpose |
| :--- | :--- |
| `flutter pub get` | Install Dart and Flutter dependencies |
| `flutter analyze` | Run static analysis |
| `flutter run` | Launch the app on a connected device/emulator |
| `flutter build apk --debug` | Build Android debug APK |

### Git basics

| Command | Purpose |
| :--- | :--- |
| `git status` | Show changed, staged, and untracked files |
| `git add .` | Stage changes from the current directory downward |
| `git commit -m "message"` | Create a commit from staged changes |
| `git pull --rebase` | Update local branch from remote while keeping history linear |
| `git push` | Push local commits to the remote repository |

## Notes

- `plan.md` is the migration/design plan, not a source-of-truth record of completed benchmarks.
- The repository still contains both the native engine path and a broader Dart-side gameplay model/simulation surface.
- Performance ROI numbers in `plan.md` are targets, not validated measured results for the current branch.
