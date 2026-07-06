# Tactical Grid — Production, Balancing & Visual Improvement Plan

This document is a concrete, prioritized plan to take the current Tower Defense
build from "works" to "production-grade, well-balanced, and visually appealing".

It is based on a full read of the live codebase:

- Flutter shell + Dart gameplay (fallback only on non-Android)
- Authoritative native C++ engine on Android (`android/app/src/main/cpp/engine/`)
- OpenGL ES renderer drawing flat primitive shapes (`rendering/GlRenderer2D.*`)
- Authored content in `engine/content/` (towers, enemies, waves)

The plan is split into three pillars the request asked for:

1. **Balancing & progression** — make it simpler, fair, and satisfying to climb.
2. **Production-grade engineering** — correctness, validation, and maintainability.
3. **Graphics & design** — enemies, towers, spawn points, and board readability.

---

## 1. Current State Assessment

### 1.1 What works today

- Hybrid architecture is functional: native sim is authoritative, Flutter renders HUD.
- 7 base towers, each with a single upgrade (14 catalog entries total).
- 10 enemy archetypes with damage-type interactions (tank/taunt immunities, etc.).
- Two wave modes: procedural (`randomWavePattern`) and preset (`choosePresetWave`).
- Renderer supports rects, triangles, quads, circles, ellipses, shadows, particles.

### 1.2 Core problems found

**Balancing**

- **Broken damage values** (also flagged in `check.md`):
  - `machineGun` damage `0.0..10.0` → rounds to 0 sometimes (zero-damage hits).
  - `laser` `1..3`, `beamEmitter` `1..4` with a `beamChargeTicks²` multiplier, so the
    first hit on a new target deals 0.
  - `tesla` `256..512` jumping to `plasma` `1024..2048` trivializes the late game.
- **Non-monotonic / flat costs**: `plasma` upgrade costs 250 but base `tesla` is 350;
  `missileSilo`/`clusterBomb` upgrades cost the same as their base. Many towers are a
  flat 250, so cost no longer signals power.
- **Shallow progression**: every tower caps at level 2 (one upgrade). No long-term
  investment curve.
- **No enemy HP scaling by wave**: `enemy.health = blueprint.health` is fixed per
  archetype (`EnemySystem.cpp`). Difficulty only changes *which* archetype spawns and
  *how many*, producing choppy spikes instead of a smooth curve.
- **Dead/confusing content**: `WaveSpec.cpp` uses archetype ids `grunt`/`runner`/`brute`
  that do **not** exist in `EnemyArchetypes` and are never used by the runtime wave
  path. This is misleading dead code.
- **Preset waves clamp at 9** (`kPresetWaves`), custom at 5 — endless mode reuses the
  last entry, so there is no authored end-game arc or "victory".

**Engineering** (cross-referenced with `check.md`)

- Placement failure reasons swallowed; lifecycle pause/auto-resume bugs; wall-clock
  placement timeout; enemies can drift through blocked tiles on stale paths; tile
  semantics duplicated instead of centralized.
- No startup validation of content (a 0-damage tower ships silently).
- `NativeEngine` is a god object mixing sim, rendering, and content lookups.

**Graphics**

- Enemies are mostly flat squares; only fast/tank/taunt have distinct silhouettes.
  Hard to read type and threat at a glance.
- Towers share a square base + barrel language; tiers look almost identical.
- Spawn points and the exit are near-identical nested squares (green vs red) with no
  animation or directional cue — players can't quickly find where enemies enter/leave.
- Palette is uniformly muted olive/grey; low contrast between path, buildable, and
  blocked tiles.

---

## 2. Design Pillars (target experience)

- **Readable in 2 seconds**: a new player can identify path, spawn, exit, threat type,
  and what each tower does without a tutorial.
- **Smooth difficulty ramp**: every wave is a little harder than the last; spikes are
  intentional "boss" beats, not accidents.
- **Meaningful economy**: cost scales with power; every purchase and upgrade is a clear
  trade-off.
- **Simple core, deep mastery**: fewer special-case rules, but towers/enemies that
  combine in interesting ways (damage types, immunities, support enemies).
- **Polished feel**: consistent visual language, juicy hits, clear feedback.

---

## 3. Balancing & Progression Redesign

### 3.1 Economy baseline

Keep the difficulty split but make values intentional and documented:

| Difficulty | Start HP | Start Cash | Wave cash bonus | Sell refund |
|-----------|----------|-----------|-----------------|-------------|
| Easy      | 60       | 80        | +25/wave        | 80%         |
| Normal    | 40       | 60        | +20/wave        | 75%         |
| Hard      | 25       | 45        | +15/wave        | 70%         |

- Add an explicit **end-of-wave cash bonus** so passive economy grows with progress
  (currently cash only comes from kills). This rewards survival and funds the power curve.

### 3.2 Tower power & cost curve

Replace ad-hoc values with a documented curve. Define a single source-of-truth table in
`TowerCatalog.cpp` and validate it at startup (see §4.3).

Principles:

- **Cost roughly tracks DPS-per-tile-of-range.** No tower should be a flat 250 by accident.
- **Upgrades cost ~1.5–2× the base** and deliver a clear, non-regressive power increase.
- **No upgrade may reduce effective damage** below a positive floor (fixes the 0-damage bug).
- **Smooth the Tesla→Plasma spike**: cap chain/AoE growth so a single late tower can't
  delete whole waves.

Proposed corrected baseline (illustrative starting numbers to tune in playtest):

| Tower         | Cost | Dmg (min–max) | Range | Cooldown | Role |
|---------------|------|---------------|-------|----------|------|
| Gun           | 25   | 8–18          | 3.0   | 8–18     | Reliable starter |
| Machine Gun   | 60   | 4–10          | 3.0   | 3–5      | Sustained DPS (min ≥ 4, never 0) |
| Laser         | 75   | 6–10          | 2.5   | 2–3      | Fast single-target energy |
| Beam Emitter  | 180  | 8–14 (+dwell) | 3.0   | 1–2      | Ramps on a held target, capped |
| Slow          | 100  | 0 (utility)   | 2.5   | —        | Status-only (explicitly tagged) |
| Poison        | 150  | DoT           | 2.5   | —        | Status DoT, ignores armor |
| Sniper        | 150  | 90–110        | 9.0   | 60–100   | Anti-tank single shot |
| Railgun       | 300  | 180–220       | 11.0  | 100–120  | Piercing line/anti-armor |
| Rocket        | 200  | 40–60 AoE     | 7.0   | 60–80    | Splash crowd control |
| Missile Silo  | 380  | 90–120 AoE    | 9.0   | 60–80    | Heavy splash |
| Bomb          | 175  | 20–60 AoE     | 2.0   | 40–60    | Cheap close-range AoE |
| Cluster Bomb  | 320  | 70–110 AoE    | 2.5   | 40–80    | Multi-blast AoE |
| Tesla         | 350  | 200–320 chain | 4.0   | 60–80    | Chain lightning |
| Plasma        | 600  | 400–600 chain | 4.5   | 40–60    | Stronger chain, **capped chain count** |

> All numbers are starting points; the deliverable is a tuned table plus the validation
> rule that no tier ever regresses.

### 3.3 Add a second upgrade tier (depth without complexity)

- Extend each tower line to **3 tiers** (e.g. Gun → Machine Gun → Auto-Cannon).
- Tier 3 is optional and expensive; it gives players a long-term money sink and a reason
  to defend high-value tiles. Reuse the existing `nextUpgradeKindId` chain — just add the
  third entry, so no engine change is required, only content.

### 3.4 Enemy HP scaling (the key progression fix)

Introduce a per-wave health multiplier applied at spawn time in `EnemySystem.cpp`:

```text
effectiveHealth = blueprint.health * waveHealthMultiplier(waveNumber, difficulty)
```

Suggested curve (smooth, compounding ~8%/wave with difficulty bias):

```text
waveHealthMultiplier(w, d) = (1.0 + 0.08 * (w - 1)) * difficultyFactor(d)
difficultyFactor: Easy 0.85, Normal 1.0, Hard 1.2
```

- Also scale kill cash modestly with the multiplier so the economy keeps pace.
- This converts the current "archetype swap" difficulty into a true smooth ramp, and lets
  archetype changes act as *texture* (new threats) rather than the only difficulty lever.

### 3.5 Wave & progression structure

- **Define a finite campaign arc** (e.g. 20–30 authored waves) with a clear **victory**
  state, plus an optional **endless mode** after the final authored wave.
- Replace the 9-entry preset clamp with a proper authored sequence that introduces one
  new mechanic at a time:
  - Waves 1–3: `weak` only (learn placement).
  - Waves 4–6: introduce `fast` (learn target priority).
  - Waves 7–9: introduce `strong` + first `medic` (learn focus fire).
  - Waves 10–12: `tank` (learn armor/AoE).
  - Waves 13–15: `taunt`/`spawner` mini-boss beats.
  - Waves 16+: combined pressure, scaling HP.
- **Delete the dead `WaveSpec.cpp` grunt/runner/brute path** or rewire it to real
  archetype ids. Keep exactly one wave-authoring source of truth.
- Add a visible **"Wave X / N"** and **next-wave preview** in the HUD so players can plan.

### 3.6 Damage-type clarity

Keep the existing interactions but document and surface them:

- Tank: immune to poison/slow, +50% from explosion.
- Taunt: immune to poison/slow, −50% from most, forces targeting.
- Faster: −50% from explosion.
- Surface these as small icons on the enemy info / selection card so the player learns
  counters instead of guessing.

---

## 4. Production-Grade Engineering Improvements

### 4.1 Fix the confirmed runtime bugs (from `check.md`)

Bundle these as the first hardening pass (they directly hurt balance perception):

1. Stop swallowing placement failure reasons; prefer `placementMessage_` in the snapshot.
2. Separate pause reasons (`userPaused_`, `lifecyclePaused_`); don't auto-resume on foreground.
3. Move the placement timeout into **simulation ticks**, not wall clock.
4. Clamp all post-upgrade damage to a positive floor; fix the beam charge² first-hit-0 case.
5. Zero enemy velocity on invalid path data and rebuild paths on every occupancy change.
6. Centralize tile classification (`classifyTile`) for placement, pathing, and UI.

### 4.2 Single source of truth for content

- One authored table each for towers, enemies, waves — Dart and native must read the
  **same** semantics (the architecture in `Project.md` already calls for this).
- Remove duplicate/contradicting content paths (e.g. unused `WaveSpec.cpp`).

### 4.3 Startup content validation

Add a `validateContent()` invoked once at engine init that asserts invariants:

- No tower deals < 1 effective damage unless tagged `statusOnly`.
- Each upgrade tier is ≥ previous tier in cost and in DPS.
- Every wave references a real archetype id.
- Every map has ≥1 spawn, exactly one exit, and a reachable path.

Fail loudly in debug builds; clamp + log in release.

### 4.4 Decompose the engine (incremental, low risk)

Following `Project.md`'s phased plan, move content lookups and validation out of
`NativeEngine.cpp` into the `content/` and `systems/` modules already present, so
balancing changes happen in data, not in the 2000-line god file.

### 4.5 Tuning workflow

- Expose balance constants (HP curve, cash bonus, cost table) as data, not hardcoded
  literals scattered through the engine, so designers can tune without a full rebuild.
- Add a lightweight **dev overlay** (already partly present) showing DPS, wave HP
  multiplier, and economy rate for live balance checks.

---

## 5. Graphics & Design Improvements

The renderer (`GlRenderer2D`) supports rects, triangles, quads, circles, ellipses, lines,
shadows, and particles. We don't need new GL features — we need a stronger, consistent
**visual language** built from these primitives.

### 5.1 Board & palette readability

- Establish a 3-tier tile palette with strong contrast:
  - **Buildable**: cool dark slate with a subtle inner highlight.
  - **Path/road**: lighter warm track with clear directional chevrons (extend the existing
    `drawRoadTile` arrow into repeating chevrons so flow direction is obvious).
  - **Blocked/wall**: distinctly darker with a beveled edge (top-light/bottom-shadow rects).
- Reduce grid-line opacity on buildable tiles, increase it subtly along the path edges so
  the lane reads as a corridor.

### 5.2 Spawn points & exit (high priority — currently weakest)

Make entrances and the objective unmistakable and alive:

- **Spawn portal**: animated concentric rings (pulsing `drawCircleRing`) in a cool color,
  plus an inward-pointing chevron showing the first move direction. A slow rotating outer
  ring sells "enemies emerge here". Add a brief spawn flash + particle burst when an enemy
  appears.
- **Exit / objective (the base you defend)**: a warm, layered structure (stacked rects +
  a pulsing core circle) with a damage-reactive pulse that intensifies as HP drops. When an
  enemy leaks, flash the objective and emit a shockwave ring.
- Give spawn and exit clearly **different shapes** (portal vs. fortress), not just colors,
  so colorblind players can distinguish them.

### 5.3 Enemy redesign (silhouette = role)

Give each archetype a distinct silhouette and a small "tell" so threat reads instantly:

| Archetype  | Silhouette idea | Visual tell |
|-----------|------------------|-------------|
| Weak      | small soft square | flat color, low contrast |
| Strong    | square + thicker dark border | armored rim |
| Fast      | sleek arrow/chevron (already) | motion streak trail |
| Faster    | thinner, longer arrow | double streak + glow |
| StrongFast| broad arrow + rim | armored arrow |
| Stronger  | bold square + plating lines | rivet dots |
| Tank      | wide hull + turret (already) | tracks + heavier shadow |
| Medic     | rounded body + cross emblem | healing pulse ring on heal |
| Taunt     | spiky/star outline | aggressive aura ring |
| Spawner   | segmented/hex body | periodic "split" flash before spawning |

- Standardize **health bars**: thin, rounded, color-graded (green→amber→red), only shown
  when damaged (already conditional) and slightly above the unit.
- Add **hit feedback**: brief white flash (partially present via `hitFlash`) + a small
  spark particle, and a knockback-ish squash on heavy hits for "juice".
- Slowed enemies get a cool blue tint + frost particles; poisoned get a green drip tint.

### 5.4 Tower redesign (tier = visual upgrade)

- Keep the base + oriented-barrel language but make **each tier visibly stronger**:
  - Tier 1: single barrel, plain base.
  - Tier 2: heavier/twin barrel, added plating, accent color.
  - Tier 3: distinct turret crown / glowing core.
- Add a **subtle idle animation** (slow rotation toward nearest target, gentle breathing
  scale) so the board feels alive even between shots.
- Stronger **muzzle feedback**: keep the flash triangle, add a recoil kick (already has
  `recoil`), a short tracer line for hitscan towers, and shell-casing particles for kinetic.
- **Range preview** on selection: filled translucent disc + animated ring (already present)
  — make it color-coded valid/invalid (green/red) for placement clarity.
- Energy towers (laser/beam/tesla/plasma) get a glowing core + chained/beam line effects;
  cap visual chain length to match the balance cap.

### 5.5 Effects & feedback

- Unify explosions: expanding ring + flash core + debris particles, scaled by AoE radius
  (currently expanding rects). Bombs vs missiles vs cluster should read differently.
- Add floating cash text on kill ("+12") and a brief screen-edge flash when the base is hit.
- Wave-start banner and countdown so the rhythm of build → defend → reward is clear.

### 5.6 Consistency rules

- One accent color per damage type (physical/energy/explosion/poison/slow) reused across
  towers, projectiles, and impact effects so players learn the system by color.
- Consistent shadow direction and intensity for all entities.
- Keep everything built from existing primitives — no new asset pipeline required.

---

## 6. Phased Roadmap

**Phase 0 — Stabilize (1 pass)** — DONE
- Fix the confirmed runtime bugs (§4.1). Add damage floor + beam first-hit fix.
- Remove/rewire dead `WaveSpec.cpp`. No behavior should regress.

**Phase 1 — Balance foundation** — DONE
- Implement per-wave enemy HP scaling (§3.4) and end-of-wave cash bonus (§3.1).
- Apply corrected tower cost/damage table (§3.2) + startup validation (§4.3).

**Phase 2 — Progression** — PARTIAL
- Author the finite campaign arc + victory state + endless mode (§3.5).
- Add HUD "Wave X/N" and next-wave preview.

**Phase 3 — Depth** — TODO
- Add optional tier-3 tower upgrades via the existing upgrade chain (§3.3).
- Surface damage-type interactions in the UI (§3.6).

**Phase 4 — Visual overhaul** — PARTIAL
- Spawn/exit redesign (§5.2) → enemy silhouettes (§5.3) → tower tiers (§5.4) →
  effects & palette (§5.1, §5.5).

**Phase 5 — Polish & validation** — TODO
- Playtest tuning pass against the curve; add tests for content invariants and path/HP
  scaling; profile renderer batching.

---

## Implementation Log

What has been built and verified to compile (debug APK builds; `flutter analyze` clean):

**Balance (native `engine/` + Dart `content.dart` kept in sync)**
- Rewrote `TowerCatalog.cpp` with the corrected, documented cost/damage/range/cooldown
  table from §3.2. Added a `statusOnly` flag to `TowerCatalogEntry` (slow/poison).
- `rollDamage` now floors damage-dealing towers at 1 (no more 0-damage hits) and returns
  0 only for status-only towers. Beam charge multiplier is capped (`kMaxBeamCharge = 3`)
  so a single beam can't delete waves.
- Per-wave enemy HP scaling in `spawnEnemyAt`:
  `health *= (1 + 0.08*(wave-1)) * difficultyFactor` (Easy 0.85 / Normal 1.0 / Hard 1.2),
  with a gentler kill-cash multiplier so the economy keeps pace.
- End-of-wave cash bonus on wave clear (Easy 25 / Normal 20 / Hard 15, + wave number).
- Starting economy updated per §3.1 (Easy 60/80, Normal 40/60, Hard 25/45).
- Synced `lib/.../domain/content.dart` tower table to the native values so the store/dock
  and placement UI show the real costs/stats.

**Engineering**
- `validateContentOnce()` runs at surface creation and logs (via `android/log.h`) any
  zero-damage non-status tower, inverted damage range, missing/regressing upgrade, or
  unknown wave archetype id.
- Deleted the dead, misleading `WaveSpec.cpp/.h` (grunt/runner/brute ids that never
  existed) and removed it from `CMakeLists.txt`. Fixed the stale `"grunt"` runtime default.

**Progression**
- Replaced the 9-wave preset clamp with a 20-wave authored campaign that introduces one
  mechanic at a time (weak → fast → strong/medic → tank/strongFast → taunt/spawner →
  combined pressure). The last wave is reused for endless play beyond the arc.

**Visuals**
- Animated spawn portals: pulsing energy rings, glowing well, rotating spokes, and a
  chevron pointing the first travel direction.
- Objective fortress: layered keep with corner bastions and a reactor core that pulses
  hotter/redder as base HP falls. Distinct shape from spawns (colorblind-friendly).
- Enemy archetype "tells": medic cross + heal pulse ring, spawner rotating hex core,
  stronger corner rivets, strong armored rim.
- Path tiles now show directional travel chevrons.

**Audio crash fix + low-latency optimization (post-playtest)**
- Root cause of the fatal crash: `AudioPool` used Android `MediaPlayer` (one per voice ×
  7 sounds ≈ 28 players + DRM sessions), exhausting codec resources (`error -19`); a
  failed player's `onCompletion` then called `prepareAsync` in an invalid state and threw
  an uncaught `IllegalStateException` that killed the app.
- Replaced it with a new low-latency SFX manager (`infrastructure/audio/sfx_player.dart`,
  `SfxVoice`) backed by Android **SoundPool** (`PlayerMode.lowLatency`): clips are decoded
  once and reused, with a small ring of voices per sound for overlap. This removes the
  crash path entirely, gives near-zero playback latency, and eliminates the per-shot
  MediaPlayer/DRM allocation churn that was driving the native GC. All plays are wrapped
  so audio can never be fatal again. Voices are disposed with the controller.
- Added `audioplayers` as a direct dependency.

**Richer entity art (post-playtest "don't keep simple shapes")**
- Towers now sit on an octagonal armored plate with a recessed hub, corner rivets, and a
  top-light highlight instead of a flat square.
- Generic enemies are now beveled hex mech bodies with a recessed core and a directional
  sensor, replacing the flat square, while keeping the archetype tells on top.

**Still outstanding (larger features, flagged not rushed)**
- Tier-3 tower upgrades (new enum kinds, parse, visuals) — §3.3.
- Damage-type interaction icons in the selection card — §3.6.
- Tower tier visual differentiation, unified explosion FX, floating cash text, wave banner.
- Tuning playtest pass and automated content/HP-scaling tests.

**Round 3 — placement, sound regression, full art redesign**
- Placement: `confirmPlacement` no longer auto-selects the just-placed tower (which hid
  the dock and forced a tap on empty ground before placing another). Selection is cleared.
- Sound regression fixed: `SfxVoice.play` had `setVolume`/`seek`/`resume` in one try-block;
  `seek` throws on SoundPool (low-latency), aborting `resume` before any audio played. Each
  call is now guarded independently so playback always runs.
- Tower redesigns from layered primitives (base + upgrade): Sniper (hex nest, long barrel,
  scope, muzzle brake) / Railgun (twin rails + pulsing charge core + octagon breech);
  Rocket (twin-tube launcher + warheads) / Missile Silo (octagon bunker, four staggered
  tubes, rotating radar fin); Tesla (rotating electrode prongs + sparking core) / Plasma
  (glowing orb + containment ring + six prongs). Tower base is now an octagonal plate.
- Enemy redesigns + multi-segment movement: added a per-enemy position-history trail so
  bodies bend around corners. Spawner is a 3-segment glowing centipede, Stronger a
  2-segment crawler. Taunt is a rotating spiky six-point star with a pulsing aura. Generic
  enemies use beveled hex bodies with a directional sensor.



---

## 7. Success Criteria

- No tower can ever deal 0 effective damage; every upgrade is a strict improvement.
- Difficulty rises smoothly wave-to-wave; intentional spikes only at boss beats.
- A new player can identify spawn, exit, threat type, and tower role without a tutorial.
- There is a clear win condition and an optional endless mode.
- Content lives in validated data tables, tunable without engine surgery.
- Frame time stays stable on target devices with the added effects (batched draws).

---

## 8. Open Questions to Confirm Before Implementation

1. Target campaign length — 20 waves? 30? Endless after?
2. Should tier-3 upgrades ship now or after the visual overhaul?
3. Keep all 14 towers, or trim to a tighter, easier-to-balance set first?
4. Any device performance ceiling we must respect for the richer effects?
