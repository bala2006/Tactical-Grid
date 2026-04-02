# Unused / Dead Code / Duplicate Files

This document lists files that are currently not used by the live project, are dead code, or are duplicate legacy implementations.

The list is based on the current repository state after removal of the old reference folders, with reachability checked from:

- `lib/main.dart`
- `lib/src/features/shell/presentation/tower_defense_app.dart`
- `android/app/src/main/kotlin/com/example/towerdefense/bridge/MainActivity.kt`
- `android/app/src/main/cpp/CMakeLists.txt`

## Summary

There was one high-confidence dead native stack in the repo:

- the legacy `GameApp` Android-native app path
- its older renderer stack and support files

That legacy stack has now been removed.

The current live native path uses:

- `engine/runtime/NativeEngine.cpp`
- `engine/runtime/NativeBridge.cpp`
- subsystem files listed in `android/app/src/main/cpp/CMakeLists.txt`
- Kotlin bridge files under `android/app/src/main/kotlin/com/example/towerdefense/bridge/`

Anything not compiled into `CMakeLists.txt` and not referenced by the Flutter Android entry path is dead or legacy unless otherwise noted.

## Removed Legacy Files

The following legacy native files were removed because they were not part of the live build graph:

- `android/app/src/main/cpp/GameApp.cpp`
- `android/app/src/main/cpp/GameApp.h`
- `android/app/src/main/cpp/main.cpp`
- `android/app/src/main/cpp/Renderer.cpp`
- `android/app/src/main/cpp/Renderer.h`
- `android/app/src/main/cpp/Shader.cpp`
- `android/app/src/main/cpp/Shader.h`
- `android/app/src/main/cpp/TextureAsset.cpp`
- `android/app/src/main/cpp/TextureAsset.h`
- `android/app/src/main/cpp/Model.h`
- `android/app/src/main/cpp/Utility.cpp`
- `android/app/src/main/cpp/Utility.h`
- `android/app/src/main/cpp/AndroidOut.cpp`
- `android/app/src/main/cpp/AndroidOut.h`

They were previously unused because:

- `android/app/src/main/cpp/CMakeLists.txt` did not compile them
- the live JNI path is `NativeBridge.cpp -> NativeEngine.cpp`
- the legacy renderer stack was only tied to the removed `GameApp` path

## Files That Look Suspicious But Are Still Used

These should **not** be listed as dead code right now.

### Native subsystem files compiled through CMake

The following are live because they are explicitly compiled in `CMakeLists.txt` or referenced by compiled files:

- `NativeEngine.cpp`
- `NativeEngine.h`
- `NativeBridge.cpp`
- `EnemyArchetypes.*`
- `EnemyBehaviors.*`
- `EnemySystem.*`
- `ProjectileSystem.*`
- `TowerSystem.*`
- `TowerCatalog.*`
- `TowerUpgrades.*`
- `WaveRuntime.*`
- `WaveSpec.*`
- `GlRenderer2D.*`
- `GeneratedMaps.h`
- `GameRuntimeTypes.h`
- `GameConfigState.h`
- `TargetingModes.h`

### Dart files under `lib/src/features/game/`

All current Dart files under `lib/src/features/game/` are reachable from the live app path, either directly or through `controller.dart`.

Not dead:

- `application/controller.dart`
- `application/controller_render.dart`
- `application/controller_simulation.dart`
- `application/controller_ui.dart`
- `domain/models.dart`
- `domain/content.dart`
- `infrastructure/maps.dart`
- `infrastructure/simulation_worker.dart`
- `infrastructure/native_game_bridge.dart`
- `infrastructure/lz_string.dart`
- `presentation/native_game_board.dart`
- `rendering/tower_defense_flame_game.dart`

### Assets

Current project-owned assets are live:

- `assets/data/maps.js`
- `assets/audio/*.wav`
- `assets/fonts/SourceCodePro-Regular.ttf`

They are referenced by:

- `pubspec.yaml`
- Dart map/audio loading
- Android native sound loading

### Test file

`test/widget_test.dart` is not dead code.

It is not part of the runtime app, but it is a live test target.

## Duplicate / Legacy Architecture Notes

The biggest duplication in the repo is architectural, not just file-level:

### Removed: `GameApp` vs `NativeEngine`

There were two native runtime architectures present:

- current live path: `NativeEngine`
- removed legacy path: `GameApp`

These are not complementary. They are competing implementations of the same responsibility.

The live project uses `NativeEngine`.

### Removed: `Renderer` vs `GlRenderer2D`

There were two native rendering approaches present:

- current live path: `GlRenderer2D`
- removed legacy path: `Renderer` + `Shader` + `TextureAsset` + `Model`

The live project uses `GlRenderer2D`.

## Not Included In This List

The following are intentionally not marked unused:

- generated Flutter/Android files required by the build, such as `GeneratedPluginRegistrant.java`
- Android resource files such as launch backgrounds, mipmaps, and style XML
- generic documentation files like `README.md`, even if they are outdated
- build output, cache, and IDE files, since they are not source-level dead code

## Final Verdict

The previously identified high-confidence dead native files have been removed.

Everything remaining in the current source tree appears to be live, build-relevant, test-relevant, or asset-relevant.
