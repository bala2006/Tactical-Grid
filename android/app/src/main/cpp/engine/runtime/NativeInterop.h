#ifndef TOWERDEFENSE_NATIVE_INTEROP_H
#define TOWERDEFENSE_NATIVE_INTEROP_H

#include <cstdint>

namespace towerdefense {

enum class SoundType : std::uint8_t {
    None = 0,
    Boom = 1,
    Missile = 2,
    Pop = 3,
    Railgun = 4,
    Sniper = 5,
    Spark = 6,
    Taunt = 7,
};

constexpr int kMapIdCapacity = 32;
constexpr int kWaveStateCapacity = 32;
constexpr int kDefeatSummaryCapacity = 160;
constexpr int kSelectionStatusCapacity = 64;
constexpr int kSelectionTitleCapacity = 48;
constexpr int kUpgradeDeltaCapacity = 96;
constexpr int kDamageTextCapacity = 24;
constexpr int kDamageTypeCapacity = 24;
constexpr int kTargetingCapacity = 32;
constexpr int kEffectCapacity = 48;
constexpr int kPlacementReasonCapacity = 96;
constexpr int kPendingPlacementIdCapacity = 48;
constexpr int kPendingPlacementTitleCapacity = 48;
constexpr int kPendingPlacementStatusCapacity = 96;

#pragma pack(push, 1)

struct NativeAudioEvent {
    std::uint8_t soundId = 0;
    float volume = 1.0f;
};

struct NativeHudSnapshot {
    std::int32_t health = 0;
    std::int32_t maxHealth = 0;
    std::int32_t cash = 0;
    std::int32_t wave = 0;
    std::int32_t kills = 0;
    char waveState[kWaveStateCapacity] = {};
    std::uint8_t paused = 0;
};

struct NativePerfSnapshot {
    std::uint8_t show = 0;
    float fps = 0.0f;
    float frameTimeMs = 0.0f;
    std::int32_t quality = 0;
};

struct NativeRunStatsSnapshot {
    std::int32_t built = 0;
    std::int32_t kills = 0;
    std::int32_t leaks = 0;
    float totalDamage = 0.0f;
};

struct NativeConfigSnapshot {
    std::int32_t difficulty = 0;
    std::int32_t waveMode = 0;
    std::int32_t quality = 0;
    std::uint8_t effects = 0;
    std::uint8_t healthBars = 0;
    std::uint8_t muted = 0;
    std::uint8_t autoSend = 0;
    std::uint8_t adaptiveQuality = 0;
    std::uint8_t showFps = 0;
    std::uint8_t godMode = 0;
    std::uint8_t firingDisabled = 0;
    std::int32_t zoom = 0;
    char mapId[kMapIdCapacity] = {};
};

struct NativeSelectionSnapshot {
    std::uint8_t present = 0;
    char status[kSelectionStatusCapacity] = {};
    char title[kSelectionTitleCapacity] = {};
    std::uint32_t titleColor = 0;
    float cost = 0.0f;
    float sellPrice = 0.0f;
    std::uint8_t hasUpgradePrice = 0;
    float upgradePrice = 0.0f;
    char upgradeDelta[kUpgradeDeltaCapacity] = {};
    char damage[kDamageTextCapacity] = {};
    float dps = 0.0f;
    char damageTypeLabel[kDamageTypeCapacity] = {};
    float range = 0.0f;
    float cooldownSeconds = 0.0f;
    char targeting[kTargetingCapacity] = {};
    char effect[kEffectCapacity] = {};
    char placementReason[kPlacementReasonCapacity] = {};
    std::uint8_t canSell = 0;
    std::uint8_t canUpgrade = 0;
};

struct NativePendingPlacementSnapshot {
    std::uint8_t present = 0;
    char id[kPendingPlacementIdCapacity] = {};
    char title[kPendingPlacementTitleCapacity] = {};
    float cost = 0.0f;
    float anchorX = 0.0f;
    float anchorY = 0.0f;
    std::uint8_t placementAllowed = 0;
    std::uint8_t placementAffordable = 0;
    std::uint8_t showPlaceAction = 0;
    std::int32_t remainingTicks = 0;
    char statusText[kPendingPlacementStatusCapacity] = {};
};

struct NativeGameSnapshot {
    std::int32_t runId = 0;
    std::int32_t tick = 0;
    std::int64_t simTimeMs = 0;
    std::int32_t activeScreen = 0;
    NativeHudSnapshot hud;
    NativePerfSnapshot perf;
    std::uint8_t defeatVisible = 0;
    char defeatSummary[kDefeatSummaryCapacity] = {};
    NativeConfigSnapshot config;
    NativeRunStatsSnapshot runStats;
    NativeSelectionSnapshot selection;
    NativePendingPlacementSnapshot pendingPlacement;
    char exportMap[kMapIdCapacity] = {};
    // Remaster (appended to preserve existing byte offsets):
    std::uint8_t victoryVisible = 0;  // finite level cleared
    std::int32_t stars = 0;           // 1-3 stars earned at victory
    std::int32_t totalWaves = 0;      // 0 = endless, >0 = finite campaign level
};

#pragma pack(pop)

}  // namespace towerdefense

#endif
