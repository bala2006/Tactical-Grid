#ifndef TOWERDEFENSE_GAME_RUNTIME_TYPES_H
#define TOWERDEFENSE_GAME_RUNTIME_TYPES_H

#include <cstdint>
#include <string>
#include <string_view>

#include "TargetingModes.h"

namespace towerdefense {

enum class TowerKindId : std::uint8_t {
    Gun,
    MachineGun,
    Laser,
    BeamEmitter,
    Slow,
    Poison,
    Sniper,
    Railgun,
    Rocket,
    MissileSilo,
    Bomb,
    ClusterBomb,
    Tesla,
    Plasma,
    Unknown,
};

enum class EnemyArchetypeId : std::uint8_t {
    Weak,
    Strong,
    Fast,
    Medic,
    StrongFast,
    Stronger,
    Faster,
    Tank,
    Taunt,
    Spawner,
    Unknown,
};

inline constexpr std::string_view towerKindIdName(TowerKindId id) {
    switch (id) {
        case TowerKindId::Gun: return "gun";
        case TowerKindId::MachineGun: return "machineGun";
        case TowerKindId::Laser: return "laser";
        case TowerKindId::BeamEmitter: return "beamEmitter";
        case TowerKindId::Slow: return "slow";
        case TowerKindId::Poison: return "poison";
        case TowerKindId::Sniper: return "sniper";
        case TowerKindId::Railgun: return "railgun";
        case TowerKindId::Rocket: return "rocket";
        case TowerKindId::MissileSilo: return "missileSilo";
        case TowerKindId::Bomb: return "bomb";
        case TowerKindId::ClusterBomb: return "clusterBomb";
        case TowerKindId::Tesla: return "tesla";
        case TowerKindId::Plasma: return "plasma";
        default: return "gun";
    }
}

inline constexpr TowerKindId parseTowerKindId(std::string_view name) {
    return name == "gun" ? TowerKindId::Gun
        : name == "machineGun" ? TowerKindId::MachineGun
        : name == "laser" ? TowerKindId::Laser
        : name == "beamEmitter" ? TowerKindId::BeamEmitter
        : name == "slow" ? TowerKindId::Slow
        : name == "poison" ? TowerKindId::Poison
        : name == "sniper" ? TowerKindId::Sniper
        : name == "railgun" ? TowerKindId::Railgun
        : name == "rocket" ? TowerKindId::Rocket
        : name == "missileSilo" ? TowerKindId::MissileSilo
        : name == "bomb" ? TowerKindId::Bomb
        : name == "clusterBomb" ? TowerKindId::ClusterBomb
        : name == "tesla" ? TowerKindId::Tesla
        : name == "plasma" ? TowerKindId::Plasma
        : TowerKindId::Unknown;
}

inline constexpr std::string_view enemyArchetypeIdName(EnemyArchetypeId id) {
    switch (id) {
        case EnemyArchetypeId::Weak: return "weak";
        case EnemyArchetypeId::Strong: return "strong";
        case EnemyArchetypeId::Fast: return "fast";
        case EnemyArchetypeId::Medic: return "medic";
        case EnemyArchetypeId::StrongFast: return "strongFast";
        case EnemyArchetypeId::Stronger: return "stronger";
        case EnemyArchetypeId::Faster: return "faster";
        case EnemyArchetypeId::Tank: return "tank";
        case EnemyArchetypeId::Taunt: return "taunt";
        case EnemyArchetypeId::Spawner: return "spawner";
        default: return "weak";
    }
}

inline constexpr EnemyArchetypeId parseEnemyArchetypeId(std::string_view name) {
    return name == "weak" ? EnemyArchetypeId::Weak
        : name == "strong" ? EnemyArchetypeId::Strong
        : name == "fast" ? EnemyArchetypeId::Fast
        : name == "medic" ? EnemyArchetypeId::Medic
        : name == "strongFast" ? EnemyArchetypeId::StrongFast
        : name == "stronger" ? EnemyArchetypeId::Stronger
        : name == "faster" ? EnemyArchetypeId::Faster
        : name == "tank" ? EnemyArchetypeId::Tank
        : name == "taunt" ? EnemyArchetypeId::Taunt
        : name == "spawner" ? EnemyArchetypeId::Spawner
        : EnemyArchetypeId::Unknown;
}

struct EnemyRuntime {
    int id = 0;
    std::string archetypeId = "grunt";
    EnemyArchetypeId archetype = EnemyArchetypeId::Weak;
    float prevX = 0.0f;
    float prevY = 0.0f;
    float x = 0.0f;
    float y = 0.0f;
    float vx = 0.0f;
    float vy = 0.0f;
    float speed = 1.0f;
    float baseSpeed = 1.0f;
    float radius = 0.38f;
    float health = 18.0f;
    float maxHealth = 18.0f;
    float hitFlash = 0.0f;
    float slowFactor = 1.0f;
    int slowTicks = 0;
    int poisonTicks = 0;
    int regenTicks = 0;
    int cash = 5;
    int damage = 1;
    int supportCooldownTicks = 0;
    bool alive = true;
};

struct TowerRuntime {
    std::string kind = "gun";
    TowerKindId kindId = TowerKindId::Gun;
    int col = 0;
    int row = 0;
    int cooldown = 0;
    int cooldownMin = 18;
    int cooldownMax = 26;
    float range = 3.2f;
    float damageMin = 4.0f;
    float damageMax = 8.0f;
    float slowFactor = 1.0f;
    int slowTicks = 0;
    float angle = 0.0f;
    float flash = 0.0f;
    float recoil = 0.0f;
    float beamTargetX = 0.0f;
    float beamTargetY = 0.0f;
    int beamTicks = 0;
    int lastTargetEnemyId = -1;
    int beamChargeTicks = 0;
    TargetingMode targetingMode = TargetingMode::First;
    int level = 1;
    int upgradeCount = 0;
    int investedCost = 0;
    bool alive = true;
};

struct ProjectileRuntime {
    float prevX = 0.0f;
    float prevY = 0.0f;
    float x = 0.0f;
    float y = 0.0f;
    float vx = 0.0f;
    float vy = 0.0f;
    float ax = 0.0f;
    float ay = 0.0f;
    float radius = 0.18f;
    float range = 7.0f;
    float splashRadius = 1.15f;
    float damageMin = 6.0f;
    float damageMax = 10.0f;
    float accAmt = 0.6f;
    float topSpeed = 4.0f;
    int lifetime = 60;
    int trailCooldown = 0;
    int targetEnemyId = -1;
    bool alive = true;
};

struct TrailParticleRuntime {
    float x = 0.0f;
    float y = 0.0f;
    float vx = 0.0f;
    float vy = 0.0f;
    float size = 0.0f;
    float alpha = 0.0f;
    float decay = 0.0f;
    bool alive = true;
};

struct ExplosionRuntime {
    float x = 0.0f;
    float y = 0.0f;
    float radius = 0.0f;
    float age = 0.0f;
    float duration = 0.0f;
    bool alive = true;
};

struct WaveRuntimeState {
    int waveNumber = 1;
    int totalTicks = 0;
    int ticksInWave = 0;
    int ticksPerWave = 600;
    int spawnCooldownTicks = 18;
    int spawnTickCounter = 0;
    int nextSpawnIndex = 0;
    int nextEnemyId = 1;
    int activeEnemyCount = 0;
    bool waveActive = false;
    bool paused = false;
    bool defeated = false;
};

}  // namespace towerdefense

#endif
