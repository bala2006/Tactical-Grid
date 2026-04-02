#include "EnemyArchetypes.h"

namespace towerdefense {

namespace {

constexpr std::array<EnemyArchetypeSpec, 10> kEnemyArchetypes = {{
    {
        EnemyArchetypeId::Weak,
        "weak",
        "Weak",
        35.0f,
        1.0f,
        0.5f,
        1,
        1,
    },
    {
        EnemyArchetypeId::Strong,
        "strong",
        "Strong",
        75.0f,
        1.0f,
        0.6f,
        1,
        1,
    },
    {
        EnemyArchetypeId::Fast,
        "fast",
        "Fast",
        75.0f,
        2.0f,
        0.5f,
        2,
        1,
    },
    {
        EnemyArchetypeId::Medic,
        "medic",
        "Medic",
        375.0f,
        1.0f,
        0.7f,
        4,
        1,
    },
    {
        EnemyArchetypeId::StrongFast,
        "strongFast",
        "Strong Fast",
        135.0f,
        2.0f,
        0.5f,
        2,
        1,
    },
    {
        EnemyArchetypeId::Stronger,
        "stronger",
        "Stronger",
        375.0f,
        1.0f,
        0.8f,
        4,
        1,
    },
    {
        EnemyArchetypeId::Faster,
        "faster",
        "Faster",
        375.0f,
        3.0f,
        0.5f,
        4,
        1,
    },
    {
        EnemyArchetypeId::Tank,
        "tank",
        "Tank",
        750.0f,
        1.0f,
        1.0f,
        4,
        1,
    },
    {
        EnemyArchetypeId::Taunt,
        "taunt",
        "Taunt",
        1500.0f,
        1.0f,
        0.8f,
        8,
        1,
    },
    {
        EnemyArchetypeId::Spawner,
        "spawner",
        "Spawner",
        1150.0f,
        1.0f,
        0.7f,
        10,
        1,
    },
}};

}  // namespace

const std::array<EnemyArchetypeSpec, 10> &enemyArchetypes() {
    return kEnemyArchetypes;
}

const EnemyArchetypeSpec *findEnemyArchetype(std::string_view id) {
    for (const EnemyArchetypeSpec &spec : kEnemyArchetypes) {
        if (spec.id == id) {
            return &spec;
        }
    }
    return nullptr;
}

const EnemyArchetypeSpec *findEnemyArchetype(EnemyArchetypeId id) {
    for (const EnemyArchetypeSpec &spec : kEnemyArchetypes) {
        if (spec.archetype == id) {
            return &spec;
        }
    }
    return nullptr;
}

}  // namespace towerdefense
