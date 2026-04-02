#ifndef TOWERDEFENSE_ENEMY_ARCHETYPES_H
#define TOWERDEFENSE_ENEMY_ARCHETYPES_H

#include <array>
#include <string_view>

#include "GameRuntimeTypes.h"

namespace towerdefense {

struct EnemyArchetypeSpec {
    EnemyArchetypeId archetype;
    std::string_view id;
    std::string_view title;
    float health;
    float speed;
    float radius;
    int cash;
    int damage;
};

const EnemyArchetypeSpec *findEnemyArchetype(std::string_view id);
const EnemyArchetypeSpec *findEnemyArchetype(EnemyArchetypeId id);
const std::array<EnemyArchetypeSpec, 10> &enemyArchetypes();

}  // namespace towerdefense

#endif
