#ifndef TOWERDEFENSE_ENEMY_ARCHETYPES_H
#define TOWERDEFENSE_ENEMY_ARCHETYPES_H

#include <array>
#include <string_view>

namespace towerdefense {

struct EnemyArchetypeSpec {
    std::string_view id;
    std::string_view title;
    float health;
    float speed;
    float radius;
    int cash;
    int damage;
};

const EnemyArchetypeSpec *findEnemyArchetype(std::string_view id);
const std::array<EnemyArchetypeSpec, 10> &enemyArchetypes();

}  // namespace towerdefense

#endif
