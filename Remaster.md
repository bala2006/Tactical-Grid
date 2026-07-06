# Forward Defense Grid — Remaster Plan

> Goal: turn the current *endless, single-map, no-reward* sandbox into an engaging
> journey with **progression, varied levels, meaningful choices, and reasons to come back**.
> Every idea below is grounded in proven tower-defense design principles (Bloons TD,
> Kingdom Rush, Plants vs Zombies, Defense Grid) and fits the existing
> Flutter HUD + C++ `NativeEngine` (FFI) architecture.

---

## 0. Implementation progress tracker

> Updated as work lands. Legend: ✅ done · 🚧 in progress · ⬜ not started.
> Note: the C++ `NativeEngine` is Android-only and is built by CI / on-device; Dart
> changes are verified locally with `flutter analyze`. FFI struct fields are **appended**
> to keep existing byte offsets stable.

### Phase P0 — Win condition + Stars + Persistence + Victory (biggest boredom fix)
| # | Step | Files | Status |
|---|---|---|---|
| 0.1 | Campaign data: 4 worlds × 4 levels from existing maps | `progression/domain/campaign.dart` | ✅ |
| 0.2 | Player profile + JSON persistence (stars, crystals, unlocks, records) | `progression/domain/profile.dart`, `progression/infrastructure/profile_store*.dart`, `progression/application/progression_controller.dart` | ✅ |
| 0.3 | C++ engine: finite `totalWaves`, `victory`, `stars`, `setLevel` action | `GameConfigState.h`, `NativeEngine.{h,cpp}` | ✅ |
| 0.4 | FFI parity: append victory/stars/totalWaves to snapshot (C++ + Dart) | `NativeInterop.h`, `native_ffi_bindings.dart`, `native_game_bridge.dart` | ✅ |
| 0.5 | Dart fallback engine: finite-wave win condition | `controller_simulation.dart`, `controller_ui.dart`, `models.dart` | ✅ |
| 0.6 | Controller: load level, detect victory, record result to profile | `controller.dart` | ✅ |
| 0.7 | Victory overlay UI (stars + crystals + Next/Replay/World Map) | `game_screen.dart` | ✅ |
| 0.8 | World Map screen (nodes, locks, stars) as the Play entry point | `screens/world_map_screen.dart`, `game_shell.dart` | ✅ |
| 0.9 | Wire Leaderboard stub to persisted records | `leaderboard_screen.dart` | ✅ |
| 0.10 | `flutter analyze` clean + format + dead-code review | — | ✅ |

> **P0 status:** complete. `flutter analyze` is clean across the project; Dart files
> formatted. The Dart fallback engine + all UI/persistence are runtime-verifiable on
> desktop/web. The C++ `NativeEngine` changes are brace-balanced and follow existing
> patterns; they are compiled by CI / on-device (no local Android NDK build here).
>
> **Flow after P0:** Home → **World Map** (campaign) → tap unlocked level →
> finite waves → **Victory** (1–3 stars + crystals) → Next level / World Map.
> "Endless" (old map selector) is still reachable from the World Map for sandbox play.
>
> **Dead-code review:** no code removed in P0 — the old map selector was *repurposed*
> as Endless mode rather than deleted, and all existing helpers (`selectableMapNames`,
> `mapLabels`, difficulty handling) remain in use. The leaderboard placeholder text was
> replaced with live records. Cleanup of now-redundant paths (e.g. global difficulty in
> Settings vs per-level difficulty) is tracked for P1.

### Phase P1 — Campaign polish (boss banner, wave counter, per-level difficulty)
| # | Step | Files | Status |
|---|---|---|---|
| 1.1 | In-game `Wave N / Total` progress counter (campaign) | `game_screen.dart` | ✅ |
| 1.2 | Final/boss wave banner overlay | `game_screen.dart` | ✅ |
| 1.3 | Settings: difficulty applies to Endless; campaign uses per-level | `settings_screen.dart` | ✅ |
| 1.4 | `flutter analyze` clean + format | — | ✅ |

> P1 is intentionally UI-only: the boss/progress cues are derived from the
> `wave` / `totalWaves` already in `AppUiState`, so no FFI/native rebuild is needed.
> Also hardened the Endless entry (`startEndlessRun`) so a sandbox run can never
> inherit a stale campaign win condition.
### Phase P2 — Meta & Shop (crystals → tower unlocks)
| # | Step | Files | Status |
|---|---|---|---|
| 2.1 | Shop data: starter towers + crystal unlock costs | `progression/domain/shop.dart` | ✅ |
| 2.2 | Profile: `unlockedTowers` set + persistence | `progression/domain/profile.dart` | ✅ |
| 2.3 | Progression controller: `isTowerUnlocked` + `unlockTower` | `progression_controller.dart` | ✅ |
| 2.4 | Gate the tower dock via `storeBlueprints` | `controller.dart` | ✅ |
| 2.5 | Shop screen (spend crystals to unlock towers) | `screens/shop_screen.dart`, `game_shell.dart`, `world_map_screen.dart` | ✅ |
| 2.6 | `flutter analyze` clean + format | — | ✅ |

> P2 status: complete. Starter dock is Gun + Slow; Laser/Sniper/Rocket/Bomb/Tesla
> are unlocked with crystals in the new Armory (reached from the World Map). Gating is
> Dart-only (dock reads `storeBlueprints`), so no native/FFI change or rebuild.
> Commanders and stat perks (which require engine support + a native build) are
> intentionally deferred.
### Phase P3 — Content & spice (bonus objectives now; bosses/events need native)
| # | Step | Files | Status |
|---|---|---|---|
| 3.1 | Bonus objective definitions (efficient build, no sales) | `progression/domain/objectives.dart` | ✅ |
| 3.2 | Profile: `claimedObjectives` set (award once per level) | `profile.dart` | ✅ |
| 3.3 | Award objectives at victory; surface in `LevelResult` | `progression_controller.dart` | ✅ |
| 3.4 | Track towers-built / sold-this-run in controller | `controller.dart`, `controller_simulation.dart` | ✅ |
| 3.5 | Show achieved objectives on the victory card | `game_screen.dart` | ✅ |
| 3.6 | `flutter analyze` clean + format | — | ✅ |
| 3.7 | Boss enemies, multi-segment bosses, mid-wave events | C++ `NativeEngine` + FFI | ⬜ (needs native build) |

> Bonus objectives shipped (Dart-only, verified). The boss/wave-event content (3.7)
> needs new C++ archetypes/behaviors + FFI fields + an on-device/CI build to verify,
> so it is left as the next native-capable task rather than shipped unverified.
### Phase P4 — Modes & social (endless, daily, real leaderboards) — ⬜

### UX pass — compact layouts + remove cheat/clutter controls
| # | Step | Files | Status |
|---|---|---|---|
| U.1 | Compact World Map / Settings / Leaderboard / Shop (smaller fonts, paddings, tiles; two-row toolbar) | screens | ✅ |
| U.2 | Compact in-game HUD (smaller action buttons, icons) and store dock | `game_screen.dart` | ✅ |
| U.3 | Remove Developer Controls (God Mode / Disable Fire / Show FPS) + the FPS overlay | `game_screen.dart`, `game_shell.dart`, `controller.dart` | ✅ |
| U.4 | Remove the redundant in-game Restart button (Retry still on the defeat card) | `game_screen.dart` | ✅ |
| U.5 | Fix Victory card 132px overflow → scrollable + compact | `game_screen.dart` | ✅ |

> Removing God Mode and the dev panel makes runs honest — no infinite cash / no
> damage-immunity / no sabotage toggles. Kept Play/Pause (it's how a wave is
> started/resumed). The cheat *flags* still exist in code but default off and have no
> UI, so they can't be enabled. All 35 tests pass; analyzer clean.

---

## 0b. Test coverage (regression guard for the meta layer)

`test/progression_test.dart` — 24 pure-Dart tests, all green, run with `flutter test`:
- `computeStars` tiers + degenerate input
- `crystalRewardForImprovement` incremental payout
- `Campaign` 16-level chain, `nextLevel`, `worldOf`, map/wave validity
- `PlayerProfile` unlock chain, totals, JSON round-trip + garbage tolerance
- `Objectives.evaluate`
- `ProgressionController` victory rewards, replay no-double-pay, lifetime totals,
  tower unlock affordability/dedup

> Writing these caught and fixed a real bug: `PlayerProfile.fromJson` threw on a
> wrong-typed field instead of tolerating it (now hardened via `_asInt`). Full suite
> (35 tests incl. existing catalog/content/boot) passes.

---

---

## 1. Why the game feels boring today (diagnosis)

| Symptom | Root cause in current build |
|---|---|
| Every session feels the same | One map per run, endless waves, no campaign arc |
| No sense of achievement | **No win condition** — you can only lose |
| No reason to improve | No score persistence, no stars, no leaderboard (UI is a stub) |
| No reason to come back | No meta-progression, no unlocks, settings reset on restart |
| Choices don't matter long-term | Towers/maps all available immediately; no build identity |
| Difficulty feels flat | Only per-wave HP scaling; no surprises, no bosses, no events |

**Design principle:** engagement = *clear goals* + *steady reward* + *meaningful choice* + *escalating novelty*. The current build has the simulation but none of the four loops.

---

## 2. The four engagement loops we are adding

```
   ┌─────────────────────────────────────────────────────────────┐
   │                     SESSION LOOP (minutes)                    │
   │   place towers → survive wave → earn cash → upgrade → repeat  │
   │                     (exists today, keep it)                   │
   └───────────────────────────┬─────────────────────────────────┘
                               │ win a level
   ┌───────────────────────────▼─────────────────────────────────┐
   │                    LEVEL LOOP (per stage)                     │
   │   finite waves → BOSS → victory → earn STARS (1-3) + crystals │
   └───────────────────────────┬─────────────────────────────────┘
                               │ stars unlock the path
   ┌───────────────────────────▼─────────────────────────────────┐
   │                  CAMPAIGN LOOP (per world)                    │
   │   world map of nodes → unlock next level → boss world finale  │
   └───────────────────────────┬─────────────────────────────────┘
                               │ crystals spent between runs
   ┌───────────────────────────▼─────────────────────────────────┐
   │                  META LOOP (account-wide)                     │
   │   spend crystals → permanent upgrades, new towers, commanders │
   │   + leaderboards, daily challenge, endless survival mode      │
   └──────────────────────────────────────────────────────────────┘
```

---

## 3. Master player flow (linear flow chart)

```
 APP LAUNCH
    │
    ▼
 ┌──────────┐   first run?   ┌──────────────────┐
 │  SPLASH  │───────yes──────▶│  TUTORIAL LEVEL  │
 └────┬─────┘                └─────────┬────────┘
      │ no                             │
      ▼                                ▼
 ┌─────────────────────────────────────────────┐
 │                 HOME / HUB                    │
 │  [Campaign] [Endless] [Daily] [Shop] [Ranks]  │
 └───┬───────────┬─────────┬────────┬────────┬──┘
     │           │         │        │        │
     ▼           │         │        │        ▼
 ┌─────────┐     │         │        │   ┌──────────┐
 │ WORLD   │     │         │        │   │LEADERBOARD│
 │  MAP    │     │         │        │   └──────────┘
 │ (nodes) │     │         │        ▼
 └────┬────┘     │         │   ┌──────────┐
      │ pick node│         │   │   SHOP   │ (spend crystals)
      ▼          │         │   └──────────┘
 ┌─────────────┐ │         ▼
 │ LOADOUT     │ │   ┌────────────┐
 │ pick towers │ │   │   DAILY    │ (fixed seed)
 │ + commander │ │   └─────┬──────┘
 └──────┬──────┘ │         │
        │        ▼         │
        │   ┌─────────┐    │
        └──▶│  BATTLE  │◀───┘   (the existing C++ engine)
            └────┬────┘
                 │
        ┌────────┴─────────┐
        ▼                  ▼
   ┌─────────┐       ┌──────────┐
   │ DEFEAT  │       │ VICTORY  │  ← NEW win condition
   │ retry / │       │ stars +  │
   │ go home │       │ crystals │
   └────┬────┘       └────┬─────┘
        │                 │
        ▼                 ▼
   back to WORLD MAP / HOME  → unlock next node
```

---

## 4. Campaign structure — "worlds" built from existing maps

We already have **16 maps**. Group them into **4 themed worlds** of 4 levels each, plus a boss finale. Reskin via color palette + named lore, no new map geometry required for v1.

| World | Theme | Maps used (existing) | Gimmick introduced | Boss |
|---|---|---|---|---|
| 1 — **Green Valley** | training fields | empty2, sparse2, loops, spiral | basics, fast enemies | Brute (giant tank) |
| 2 — **Iron Foundry** | industrial | dense2, branch, city, walls | armor / medics | The Forgemaster (spawner) |
| 3 — **Frost Reach** | tundra | solid2, freeway, fork, branchAlt | swarms / taunts | Glacier Wyrm |
| 4 — **Void Citadel** | endgame | empty3, dense3, solid3, sparse3 | combined pressure | The Overmind |

**Level = finite wave count (10–20) ending in a guaranteed boss wave, then VICTORY.** This is the single biggest change: a clear finish line.

```
World 1 ──▶ World 2 ──▶ World 3 ──▶ World 4
  L1 L2 L3 L4 (★)        (locked until prev world ★ threshold met)
   └─ each level: waves 1..N → BOSS → VICTORY → stars
```

---

## 5. Star rating & rewards (the "reason to replay")

Award 1–3 stars per level. Stars are the currency that unlocks the next world and the campaign's completion meter.

| Stars | Earned when | Reward (crystals) |
|---|---|---|
| ★ | Level cleared (any health left) | 10 |
| ★★ | Cleared with ≥ 50% base health | 20 |
| ★★★ | Cleared with 100% health (no leaks) | 35 |

| Bonus objective (optional, per level) | Reward |
|---|---|
| Win using ≤ 8 towers | +15 crystals |
| Win without selling | +10 crystals |
| Win under a time/wave-speed target | +15 crystals |

> Replay value: players grind ★★★ + bonus objectives → steady crystal income → meta upgrades.

---

## 6. Meta-progression & shop (the "reason to come back")

Spend **crystals** (earned from stars/bosses/daily) on permanent account upgrades. This is brand-new state that must be **persisted to disk** (see §9).

| Shop category | Examples | Effect |
|---|---|---|
| **Tower unlocks** | Unlock Tesla, Rocket, Sniper one at a time | Gated towers create build identity |
| **Commanders** | "Engineer" (cheaper towers), "Tactician" (+range), "Banker" (+income) | Pick 1 per battle = a strategic meta-choice |
| **Permanent perks** | +5% starting cash, +1 sell %, +10 base health | Small, stacking power |
| **Cosmetics** | Tower skins, board palettes | Pure flavor, optional monetization hook |

```
 EARN crystals ──▶ SHOP ──▶ unlock tower / perk / commander
       ▲                              │
       └──────── stronger runs ◀──────┘   (virtuous loop)
```

---

## 7. New content to fight boredom (creative, grounded)

### 7a. Boss enemies (new archetypes)
Bosses are the climax of every level. Build them by extending `EnemyArchetypeId` + behaviors.

| Boss | Mechanic (extends existing systems) |
|---|---|
| **Brute** | huge HP tank, periodically *enrages* (speed burst) at HP thresholds |
| **Forgemaster** | reuses `spawner` behavior — continuously spits minions |
| **Glacier Wyrm** | multi-segment (we already render trail bodies) — damage only the head |
| **Overmind** | phases: shields up → must kill medics first → splits on death |

### 7b. Mid-level events / modifiers (novelty per wave)
Inject surprise without new maps. Show a banner before the wave.

| Event | Effect |
|---|---|
| **Fog** | tower range temporarily reduced |
| **Overcharge** | all towers +fire rate for one wave |
| **Cash rain** | extra cash for fast kills this wave |
| **Speed surge** | enemies move faster, pay more |

### 7c. Difficulty as a *choice*, not a setting
Offer **Normal / Hard / Heroic** per level with rising star/crystal multipliers, instead of a global toggle.

---

## 8. UI / screens — what to build or change

| Screen | Status today | Remaster action |
|---|---|---|
| Home | exists | Reframe as Hub: Campaign / Endless / Daily / Shop / Ranks |
| **World Map** | ❌ none | NEW — node graph, locked/unlocked nodes, star totals |
| **Loadout** | ❌ none | NEW — pick allowed towers + commander before battle |
| Map selector | exists | Repurpose into Endless-mode map picker |
| Game/Battle | exists | Add: wave counter `N/Total`, boss banner, event banner |
| **Victory** | ❌ none | NEW — stars earned, crystals, bonus objectives, Next button |
| Defeat | exists | Add Retry + return-to-map; show progress kept |
| **Shop** | ❌ none | NEW — spend crystals |
| Leaderboard | stub | Wire to real persisted scores (§9) |
| Settings | exists | Keep; move global difficulty out (now per-level) |

---

## 9. Architecture changes (fits current FFI design)

### 9a. New native state in `NativeEngine` / `GameConfigState`
```
+ levelId            (string)   which campaign level is loaded
+ totalWaves         (int)      finite wave count for this level
+ isBossWave         (bool)     surfaced in snapshot for the banner
+ victory            (bool)     NEW: health survived to end of last wave
+ activeEvent        (int)      current wave modifier id
+ commanderId        (int)      selected commander perk set
+ allowedTowers      (mask)     loadout restriction
```

### 9b. New FFI actions (string-action pattern already in use)
```
setLevel <levelId>        loadCampaignLevel(levelId) → sets totalWaves, theme, boss
setCommander <id>         apply commander modifiers at run start
setLoadout <mask>         restrict store towers
(snapshot gains: waveNumber/totalWaves, isBossWave, victory, stars, activeEvent)
```

### 9c. Win condition (core engine change)
```
in updateSimulation, after a wave clears:
    if (waveRuntime_.waveNumber >= totalWaves && enemies_.empty()):
        victory_ = true
        compute stars from health_ / maxHealth_
        pause sim, publish victory in snapshot
```

### 9d. Persistence layer (brand new — has no home today)
Native state is ephemeral, so progression must live on the **Dart side**.

```
lib/src/features/progression/
  ├─ domain/        profile.dart  (stars, crystals, unlocks, level records)
  ├─ infrastructure/ profile_store.dart  (shared_preferences / JSON file)
  └─ application/   progression_controller.dart
```
- Save on every victory/purchase; load on launch.
- Leaderboard (local first) reads from the same store: best wave, fastest clear, total kills.

```
 BATTLE (C++ snapshot: victory, stars) ──▶ Dart GameController
        │
        ▼
 ProgressionController.recordResult(levelId, stars, crystals)
        │
        ▼
 ProfileStore.save()  ──▶  disk (JSON / shared_preferences)
        │
        ▼
 World Map + Shop + Leaderboard read updated profile
```

> Keep the C++/Dart engine sync rule in mind: any *gameplay* change (win condition,
> bosses, events) must be mirrored in the Dart fallback engine (`controller_simulation.dart`)
> or the fallback path is explicitly marked dev-only.

---

## 10. Phased delivery (ship value early)

| Phase | Scope | Player-visible win |
|---|---|---|
| **P0 — Win + Stars** | finite waves, victory screen, stars, local persistence | Levels now *end* and *reward* — biggest boredom fix |
| **P1 — Campaign map** | 4 worlds from existing maps, World Map UI, unlock gating | A journey with locked content |
| **P2 — Meta & Shop** | crystals, tower/commander unlocks, perks | Reason to come back between runs |
| **P3 — Content & spice** | bosses, wave events, per-level difficulty, bonus objectives | Novelty + mastery depth |
| **P4 — Modes & social** | Endless survival, Daily challenge (seeded), real leaderboards | Long-tail retention |

```
 P0 ─▶ P1 ─▶ P2 ─▶ P3 ─▶ P4
 (each phase is independently shippable and improves engagement)
```

---

## 11. Quick-win checklist (start here)

- [ ] Add `totalWaves` + `victory` + star calc to `NativeEngine` (and Dart fallback)
- [ ] Build Victory screen (stars, crystals, Next/Retry)
- [ ] Add `progression` module with `ProfileStore` (shared_preferences)
- [ ] Define the 4-world / 16-level table in a `campaign.dart` data file
- [ ] Build World Map screen reading unlock state from the profile
- [ ] Wire the Leaderboard stub to persisted best-wave / fastest-clear / total-kills

---

### Design references (principles, paraphrased — content rephrased for compliance)
- Finite levels + star ratings drive replay (Bloons TD, Kingdom Rush model).
- Pre-battle loadout/commander choice creates strategic identity (Kingdom Rush heroes).
- Boss waves as level climax give a memorable goal (Defense Grid, PvZ).
- Meta-currency spent between runs builds a long-term loop (roguelite progression).
