# Tower Defense Project Structure

## Intent

This document defines a scalable project structure for the current Tower Defense app.

The goal is not a cosmetic folder shuffle. The goal is to make the project easier to scale, debug, test, and evolve while keeping one shared mental model across:

- Flutter shell and UI
- Dart gameplay logic and Flame rendering
- Android Kotlin bridge code
- Native C++ runtime and renderer

The current codebase already works, but several responsibilities are still concentrated in a few large files and are split differently across Dart and native code. This document describes:

- the current live structure
- the main problems in that structure
- the target scalable structure
- the dependency rules that keep the structure clean
- a phased migration plan from the current codebase

This is an architecture and refactor guide, not just a folder list.

## Current Architecture Snapshot

### Live repository shape

The current repository is effectively organized into four layers:

- `lib/main.dart` boots Flutter and app orientation
- `lib/src/features/shell/` owns shell navigation, theme, and high-level screens
- `lib/src/features/game/` owns Dart gameplay logic, rendering, maps, state, worker code, and native integration
- `android/app/src/main/` contains the Android platform bridge and the native C++ engine

### Current Dart structure

Current Dart code is split into:

- `lib/src/features/shell/`
  - `presentation/tower_defense_app.dart` creates the app and controller
  - `application/game_shell.dart` owns screen switching and modal/dialog orchestration
  - `presentation/screens/` contains home, map, settings, leaderboard, and game UI
- `lib/src/features/game/`
  - `application/controller.dart` is the main coordinator
  - `application/controller_render.dart` contains Dart-side board rendering and sound triggers
  - `application/controller_simulation.dart` contains gameplay simulation
  - `application/controller_ui.dart` contains UI state publishing
  - `domain/models.dart` contains gameplay enums, entities, config, UI DTOs, map definitions, and snapshot-like data
  - `domain/content.dart` contains authored content and blueprint data
  - `infrastructure/maps.dart` loads and decodes authored maps
  - `infrastructure/simulation_worker.dart` handles procedural generation and path recalculation
  - `infrastructure/native_game_bridge.dart` and `presentation/native_game_board.dart` connect Flutter to the Android native board
  - `rendering/tower_defense_flame_game.dart` hosts the Flame integration

### Current Android and native structure

Current Android runtime code is split into:

- Kotlin bridge layer
  - `bridge/MainActivity.kt`
  - `bridge/NativeControlChannelHandler.kt`
  - `bridge/NativeStateStream.kt`
  - `bridge/NativeBridge.kt`
  - `bridge/platform_view/GameBoardPlatformView.kt`
  - `bridge/platform_view/GameBoardPlatformViewFactory.kt`
  - `bridge/audio/NativeSoundPlayer.kt`
- Native C++ layer
  - `engine/runtime/NativeEngine.*`
  - `engine/systems/EnemySystem.*`
  - `engine/systems/TowerSystem.*`
  - `engine/systems/ProjectileSystem.*`
  - `engine/systems/WaveRuntime.*`
  - `engine/content/TowerCatalog.*`
  - `engine/content/EnemyArchetypes.*`
  - `engine/content/GeneratedMaps.h`
  - `engine/rendering/GlRenderer2D.*`

### Main pain points

The current structure has four main issues:

1. `GameController` is still a god object.
   It owns run lifecycle, UI publishing, pathing, map selection, simulation, rendering coordination, sound triggering, and native synchronization.

2. `models.dart` mixes multiple layers.
   It contains gameplay domain types, mutable runtime entities, app config, UI DTOs, and data contracts that should not live together long term.

3. Dart and native are organized around different concepts.
   Dart is mostly split by one large controller plus support files, while native already has partial systems. This makes cross-platform debugging slower because the same gameplay concept lives in different places with different boundaries.

4. Infrastructure concerns leak into gameplay layers.
   Asset loading, isolate worker orchestration, Flame integration, native bridge payloads, and audio access are too close to game rules.

## Anti-Patterns To Remove

The refactor should explicitly remove these anti-patterns:

- God-object ownership in `GameController`
- Different architectural shapes for Dart and native implementations of the same gameplay concepts
- Domain entities, UI DTOs, and native payload contracts in the same file
- Asset loading, game rules, simulation, rendering, and side effects in the same layer
- UI reading or mutating raw gameplay internals directly
- Platform bridges acting as informal service layers without explicit boundaries

## Target Structure

The target structure is a hybrid feature/domain architecture.

It is not pure layer-first, and it is not pure screen-first. The structure should group by product area first, then by responsibility inside that area.

### Target Dart tree

```text
lib/
  main.dart
  src/
    core/
      errors/
      logging/
      platform/
      types/
      utils/

    features/
      shell/
        application/
        presentation/
          screens/
          widgets/

      game/
        domain/
          config/
          entities/
          enums/
          value_objects/
          blueprints/
          rules/

        application/
          session/
          placement/
          combat/
          waves/
          selection/
          settings/
          import_export/

        infrastructure/
          maps/
          content/
          audio/
          workers/
          native_bridge/
          repositories/

        presentation/
          view_models/
          screens/
          widgets/
          overlays/
          dialogs/
          devtools/

        rendering/
          flame/
          board/
          effects/
          painters/
```

### What each Dart area owns

#### `lib/src/core/`

Owns app-wide technical primitives only.

Examples:

- utility helpers
- generic result and error types
- debug logging
- platform capability checks
- shared abstractions that are not game-specific

Do not put gameplay entities here.

#### `lib/src/features/shell/`

Owns app navigation and non-game shell behavior.

Examples:

- app startup shell state
- screen routing between home, map, settings, leaderboard, and game
- shell-level dialogs that are not board-runtime logic
- shell widgets and layout chrome

Current code already placed here:

- `lib/src/features/shell/presentation/tower_defense_app.dart`
- `lib/src/features/shell/application/game_shell.dart`
- `lib/src/features/shell/presentation/screens/home_screen.dart`
- `lib/src/features/shell/presentation/screens/map_selector_screen.dart`
- `lib/src/features/shell/presentation/screens/settings_screen.dart`
- `lib/src/features/shell/presentation/screens/leaderboard_screen.dart`

#### `lib/src/features/game/domain/`

Owns runtime-independent game meaning.

Examples:

- tower kinds, enemy kinds, damage types, targeting modes
- immutable config models
- gameplay entities and value objects
- authored blueprints and catalog definitions
- rule contracts and balancing definitions
- map definition data model

This layer must not know about:

- Flutter widgets
- Flame
- isolates
- Android bridge channels
- audio playback APIs

Current code that would be split into this area:

- domain enums and config from `models.dart`
- blueprints from `content.dart`
- map definition types from `models.dart`

#### `lib/src/features/game/application/`

Owns game use cases and orchestration.

This is where the future replacement for the current god-controller should be composed.

Examples:

- run/session coordinator
- restart run flow
- map switching flow
- wave progression orchestration
- selection and placement actions
- combat tick coordination
- settings mutation flows
- import/export flows

This layer may call domain logic and infrastructure adapters, but should not render UI directly.

Target services in this area:

- `GameSessionCoordinator`
- `PlacementService`
- `CombatService`
- `WaveService`
- `SelectionService`
- `SettingsSyncService`
- `MapImportExportService`

#### `lib/src/features/game/infrastructure/`

Owns concrete I/O and side-effect integrations.

Examples:

- authored map asset loading
- content repositories
- isolate worker wrapper
- audio adapter
- native bridge adapter
- snapshot serializers
- platform-specific repository implementations

Current code that would move here:

- `maps.dart`
- `simulation_worker.dart`
- `native_game_bridge.dart`
- audio-loading parts of `controller.dart`

#### `lib/src/features/game/presentation/`

Owns Flutter-side board UI and view models.

Examples:

- `GameScreen`
- HUD widgets
- overlays
- selection cards
- defeat cards
- dev panel widgets
- dialog models
- board-facing view state

This layer should only depend on application contracts and immutable state objects.

It should not run game rules directly.

#### `lib/src/features/game/rendering/`

Owns visual-only board rendering for the Dart path.

Examples:

- Flame integration
- board painters
- visual effects
- particle drawing
- board render helpers

Current code that would move here:

- `tower_defense_flame_game.dart`
- rendering parts from `controller_render.dart`

This layer reads immutable state and render snapshots. It should not own authoritative gameplay state.

## Target Native Structure

The native side should mirror the same concepts as Dart so the same gameplay concern has the same home on both sides.

### Target Android and C++ tree

```text
android/app/src/main/
  kotlin/com/example/towerdefense/
    bridge/
      MainActivity.kt
      NativeControlChannelHandler.kt
      NativeStateStream.kt
      NativeBridge.kt
      platform_view/
        GameBoardPlatformView.kt
        GameBoardPlatformViewFactory.kt
      audio/
        NativeSoundPlayer.kt

  cpp/
    engine/
      runtime/
        NativeEngine.*
        RunState.*
        BoardState.*
        WaveState.*

      domain/
        GameRuntimeTypes.h
        GameConfigState.h
        TargetingModes.h

      systems/
        EnemySystem.*
        TowerSystem.*
        ProjectileSystem.*
        WaveRuntime.*
        SelectionSystem.*
        PlacementSystem.*
        PathingSystem.*

      rendering/
        GlRenderer2D.*

      content/
        TowerCatalog.*
        TowerUpgrades.*
        EnemyArchetypes.*
        EnemyBehaviors.*
        GeneratedMaps.h
        WaveSpec.*

      support/
        main.cpp
```

### What each native area owns

#### `bridge/`

Owns Kotlin-to-Flutter and Kotlin-to-native glue only.

Responsibilities:

- platform view registration
- method/event channel wiring
- sound integration
- screen and lifecycle propagation

This layer should not contain gameplay rules.

#### `engine/runtime/`

Owns authoritative runtime state and frame lifecycle.

Responsibilities:

- simulation loop
- run lifecycle
- board lifecycle
- snapshot refresh
- active session orchestration

`NativeEngine` should become thinner over time by delegating to systems and runtime state holders.

#### `engine/domain/`

Owns shared native gameplay data types and config shapes.

Responsibilities:

- runtime structs
- configuration state
- type definitions shared by systems

#### `engine/systems/`

Owns focused gameplay systems.

Responsibilities:

- enemy logic
- tower logic
- projectile logic
- wave progression
- selection
- placement
- pathing

Each system should be individually testable or at least individually debuggable.

#### `engine/rendering/`

Owns GL and draw mechanics only.

Responsibilities:

- shader setup
- texture handling
- board draw helpers
- low-level renderer primitives

This layer must not decide gameplay outcomes.

#### `engine/content/`

Owns static authored content.

Responsibilities:

- map content
- tower catalog
- enemy archetypes
- upgrade rules
- wave specs

## Module Responsibilities

The following ownership rules are required in the target structure.

### Domain

Put something in `domain` only if it still makes sense without Flutter, Flame, Android, or file I/O.

Examples:

- `TowerBlueprint`
- `EnemyBlueprint`
- `DamageType`
- `MapDefinition`
- `GameConfig`

### Application

Put something in `application` if it coordinates actions or business flows across multiple domain concepts.

Examples:

- restarting a run
- applying a tower placement
- publishing selected state
- synchronizing config to native
- starting the next wave

### Infrastructure

Put something in `infrastructure` if it touches assets, workers, audio, platform channels, or serialization.

Examples:

- loading `assets/data/maps.js`
- sending commands over the method channel
- preloading sound assets
- running isolate pathing jobs

### Presentation

Put something in `presentation` if it exists to show state, collect UI input, or transform app state into display models.

Examples:

- HUD widgets
- settings toggles
- board overlays
- dialogs
- game screen-specific view models

### Rendering

Put something in `rendering` if it draws, animates, or converts render state into pixels.

Examples:

- Flame game host
- particle painters
- tower beam effects
- board picture cache

### DTO separation rule

These categories must not share the same file long term:

- gameplay entities
- UI view state
- native snapshot payload contracts
- repository serialization contracts

Concrete target split:

- domain entities live under `domain/`
- Flutter-facing UI state lives under `presentation/view_models/`
- native snapshot contracts live under `infrastructure/native_bridge/`
- asset and import/export serialization lives under `infrastructure/`

## Dependency Rules

These rules are the core of the structure.

### Dart dependency rules

- `presentation -> application -> domain`
- `infrastructure -> domain`
- `infrastructure -> application` only through defined interfaces or adapters
- `rendering -> domain`
- `rendering -> presentation view state`
- `shell -> game application/presentation` through clear entry contracts

Disallowed:

- `domain -> Flutter`
- `domain -> Flame`
- `domain -> method channel`
- `presentation -> raw infrastructure repositories`
- `rendering -> mutate authoritative simulation state directly`

### Native dependency rules

- `bridge -> engine/runtime`
- `runtime -> domain`
- `runtime -> systems`
- `systems -> domain`
- `rendering -> domain`
- `content -> domain`

Disallowed:

- `rendering -> gameplay decisions`
- `bridge -> gameplay rules`
- `content -> runtime mutation`

### Public boundaries that must be preserved

- Flutter UI talks to application or view-model APIs, not raw simulation internals
- Rendering reads immutable snapshots or read-only state
- Native bridge exposes a small command and snapshot contract
- Map/content loading goes through repositories or loaders, not direct ad hoc asset path calls across the codebase

## Current File Mapping To Target Structure

This section maps the current live file categories into the target structure so migration is decision-complete.

### Flutter shell mapping

- `lib/src/features/shell/presentation/tower_defense_app.dart`
- `lib/src/features/shell/application/game_shell.dart`
- `lib/src/features/shell/presentation/screens/home_screen.dart`
- `lib/src/features/shell/presentation/screens/map_selector_screen.dart`
- `lib/src/features/shell/presentation/screens/settings_screen.dart`
- `lib/src/features/shell/presentation/screens/leaderboard_screen.dart`

### Dart gameplay mapping

- `lib/src/features/game/domain/models.dart`
  - split across `domain/`, `presentation/view_models/`, and `infrastructure/native_bridge/contracts/`
- `lib/src/features/game/domain/content.dart`
  - split across `domain/blueprints/` and `infrastructure/content/`
- `lib/src/features/game/infrastructure/maps.dart`
  - `infrastructure/maps/`
- `lib/src/features/game/infrastructure/simulation_worker.dart`
  - `infrastructure/workers/`
- `lib/src/features/game/infrastructure/native_game_bridge.dart`
  - `infrastructure/native_bridge/`
- `lib/src/features/game/presentation/native_game_board.dart`
  - `presentation/widgets/` or `rendering/board/` depending on final API
- `lib/src/features/game/rendering/tower_defense_flame_game.dart`
  - `rendering/flame/`
- `lib/src/features/game/application/controller.dart`
  - broken into `application/session/`, `application/combat/`, `application/placement/`, `application/waves/`, and presentation-facing coordinators
- `lib/src/features/game/application/controller_render.dart`
  - split between `rendering/` and `infrastructure/audio/`
- `lib/src/features/game/application/controller_simulation.dart`
  - split into `application/combat/`, `application/waves/`, and extracted domain rule helpers
- `lib/src/features/game/application/controller_ui.dart`
  - `presentation/view_models/` plus an application-facing publisher

### Kotlin mapping

- `android/app/src/main/kotlin/com/example/towerdefense/bridge/MainActivity.kt`
- `android/app/src/main/kotlin/com/example/towerdefense/bridge/NativeControlChannelHandler.kt`
- `android/app/src/main/kotlin/com/example/towerdefense/bridge/NativeStateStream.kt`
- `android/app/src/main/kotlin/com/example/towerdefense/bridge/NativeBridge.kt`
- `android/app/src/main/kotlin/com/example/towerdefense/bridge/platform_view/GameBoardPlatformView.kt`
- `android/app/src/main/kotlin/com/example/towerdefense/bridge/platform_view/GameBoardPlatformViewFactory.kt`
- `android/app/src/main/kotlin/com/example/towerdefense/bridge/audio/NativeSoundPlayer.kt`

### C++ mapping

- `android/app/src/main/cpp/engine/runtime/NativeEngine.*`
- `android/app/src/main/cpp/engine/domain/GameRuntimeTypes.h`, `android/app/src/main/cpp/engine/domain/GameConfigState.h`, `android/app/src/main/cpp/engine/domain/TargetingModes.h`
- `android/app/src/main/cpp/engine/systems/EnemySystem.*`, `android/app/src/main/cpp/engine/systems/TowerSystem.*`, `android/app/src/main/cpp/engine/systems/ProjectileSystem.*`, `android/app/src/main/cpp/engine/systems/WaveRuntime.*`
- `android/app/src/main/cpp/engine/rendering/GlRenderer2D.*`
- `android/app/src/main/cpp/engine/content/TowerCatalog.*`, `android/app/src/main/cpp/engine/content/TowerUpgrades.*`, `android/app/src/main/cpp/engine/content/EnemyArchetypes.*`, `android/app/src/main/cpp/engine/content/EnemyBehaviors.*`, `android/app/src/main/cpp/engine/content/GeneratedMaps.h`, `android/app/src/main/cpp/engine/content/WaveSpec.*`

## Debugging Guide Under The Target Structure

The structure should make debugging location obvious.

### If the bug is gameplay logic

Look in:

- `lib/src/features/game/domain/`
- `lib/src/features/game/application/`
- `android/app/src/main/cpp/engine/runtime/`
- `android/app/src/main/cpp/engine/systems/`

Examples:

- tower targeting
- splash damage
- wave progression
- placement rules
- path recalculation

### If the bug is Flutter UI or shell flow

Look in:

- `lib/src/features/shell/`
- `lib/src/features/game/presentation/`

Examples:

- wrong button state
- missing dialog
- incorrect HUD labels
- wrong screen transition

### If the bug is Dart rendering only

Look in:

- `lib/src/features/game/rendering/`

Examples:

- particle visuals
- Flame drawing issues
- board picture invalidation
- beam and pulse visuals

### If the bug is native board integration

Look in:

- `android/.../bridge/`
- `lib/src/features/game/infrastructure/native_bridge/`

Examples:

- wrong command payload
- screen sync mismatch
- snapshot parsing issue
- platform view lifecycle bug

### If the bug is native rendering or simulation

Look in:

- `android/.../engine/runtime/`
- `android/.../engine/systems/`
- `android/.../engine/rendering/`

Examples:

- native board hit test errors
- simulation drift
- frame pacing problems
- GL draw regressions

### If the bug is authored content or maps

Look in:

- `lib/src/features/game/infrastructure/maps/`
- `lib/src/features/game/infrastructure/content/`
- `android/.../engine/content/`

Examples:

- wrong map decode
- incorrect blueprint values
- missing sound asset
- authored content mismatch between Dart and native

## Ownership Conventions

These rules should be enforced during migration.

### One module owns one responsibility

Do not let one class own:

- game rules
- UI state publishing
- rendering coordination
- platform bridge communication
- asset loading

at the same time.

### Cross-layer movement happens through explicit contracts

Examples:

- application services expose immutable view state or session state
- rendering consumes snapshots, not mutable controller internals
- native bridge consumes command DTOs and produces snapshot DTOs
- repositories return domain objects, not widget-ready strings

### Shared concepts keep the same names across Dart and native

If a concept exists in both environments, prefer the same naming.

Examples:

- `WaveRuntime`
- `TowerBlueprint`
- `EnemyArchetype`
- `PlacementReason`
- `BoardState`

This reduces translation overhead during debugging.

### Asset paths are centralized

Do not hardcode asset paths across unrelated files.

Use one content or asset access layer per concern:

- maps loader
- sound catalog
- content repository

### UI state is not domain state

UI-only strings such as:

- status labels
- button enablement
- formatted cooldown text
- selection banners

must live in presentation-facing models, not domain entities.

## Migration Plan

The migration should be phased so behavior stays stable while structure improves.

### Phase 1: Split mixed models

Goal:
Separate domain types from presentation and transport types.

Changes:

- break `models.dart` into:
  - domain enums and entities
  - config models
  - presentation view models
  - native bridge payload contracts
- move blueprint and content definitions toward `domain/blueprints/`

Success criteria:

- gameplay entities are no longer mixed with Flutter UI DTOs
- native snapshot models no longer depend on broad gameplay model files

### Phase 2: Extract infrastructure

Goal:
Move side-effectful concerns out of the gameplay core.

Changes:

- move map asset loading into `infrastructure/maps/`
- move content loading and path constants into `infrastructure/content/`
- move isolate worker code into `infrastructure/workers/`
- move audio access behind `infrastructure/audio/`
- move native channel code behind `infrastructure/native_bridge/`

Success criteria:

- application and domain layers do not directly touch assets, channels, or audio APIs

### Phase 3: Decompose `GameController`

Goal:
Replace the god object with a smaller coordination model.

Changes:

- keep one top-level session coordinator if needed
- extract focused services for:
  - session lifecycle
  - combat and simulation
  - placement and selection
  - wave progression
  - UI state projection
  - config synchronization
- make rendering depend on read-only session state

Success criteria:

- no single file owns all gameplay, rendering, UI projection, and bridge logic
- each gameplay behavior has a clear home

### Phase 4: Align native structure

Goal:
Make native folders and file ownership mirror Dart concepts.

Changes:

- reorganize Kotlin under `bridge/`
- reorganize C++ under `engine/runtime`, `engine/domain`, `engine/systems`, `engine/rendering`, and `engine/content`
- isolate selection, placement, and pathing logic into clearer native system boundaries over time

Success criteria:

- a gameplay concept has a corresponding location on both Dart and native sides
- bridge, runtime, and rendering are visually distinct in the native tree

### Phase 5: Add tests before deleting legacy seams

Goal:
Protect behavior while removing transitional code.

Changes:

- add unit coverage for extracted rule logic
- add regression tests for map decode and path recalculation
- add focused tests around config and snapshot translation
- remove legacy wrappers only after new module seams are exercised

Success criteria:

- refactor safety does not depend on manual playtesting alone

## Validation Checklist

The target structure is only acceptable if all of the following are true.

- Every current file category maps to exactly one target module area
- `GameController` responsibilities are fully redistributed with no ambiguous leftovers
- Kotlin bridge code and native C++ runtime map cleanly to the same conceptual structure as Dart
- A new engineer can answer these questions from this document alone:
  - where do I add a tower rule?
  - where do I add a HUD widget?
  - where do I debug placement?
  - where does map loading live?
- Each migration phase can be executed independently
- No phase requires architecture refactor and gameplay redesign in the same step without validation

## Practical Answers Under The Target Structure

To make the structure operational, these should be the default answers:

- Add a tower rule:
  - `lib/src/features/game/domain/` if it is a pure rule
  - `lib/src/features/game/application/combat/` if it coordinates runtime effects
  - native equivalent in `android/.../engine/systems/`

- Add a HUD widget:
  - `lib/src/features/game/presentation/widgets/`

- Debug placement:
  - `lib/src/features/game/application/placement/`
  - `lib/src/features/game/presentation/` for placement UX
  - `android/.../engine/systems/PlacementSystem.*` on native

- Map loading lives:
  - `lib/src/features/game/infrastructure/maps/`
  - native authored content in `android/.../engine/content/`

## Final Notes

This structure is intentionally conservative.

It keeps the current product shape:

- Flutter shell
- optional Dart-rendered path
- optional native-rendered path
- shared authored content model

But it changes the ownership model so that the project can scale without making every new feature depend on a larger `GameController`, a larger `models.dart`, or a larger native engine façade.

The main rule is simple:

authoritative gameplay meaning belongs in domain and application modules, side effects belong in infrastructure, pixels belong in rendering, and widgets belong in presentation.
