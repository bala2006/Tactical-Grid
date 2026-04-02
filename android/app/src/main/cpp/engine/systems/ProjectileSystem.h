#ifndef TOWERDEFENSE_PROJECTILE_SYSTEM_H
#define TOWERDEFENSE_PROJECTILE_SYSTEM_H

#include <vector>

#include "GameRuntimeTypes.h"

namespace towerdefense {

struct ProjectileImpact {
    float x = 0.0f;
    float y = 0.0f;
    float splashRadius = 0.0f;
    float damageMin = 0.0f;
    float damageMax = 0.0f;
    int projectileIndex = -1;
    int targetEnemyId = -1;
};

int retargetRocketByEnemyId(
    ProjectileRuntime &projectile,
    const std::vector<EnemyRuntime> &enemies,
    float fallbackX,
    float fallbackY,
    float tileSizePx,
    int excludeEnemyId = -1
);

std::vector<ProjectileImpact> advanceProjectiles(
    std::vector<ProjectileRuntime> &projectiles,
    const std::vector<EnemyRuntime> &enemies,
    float hitDistancePx,
    float tileSizePx
);

int applySplashImpact(
    const ProjectileImpact &impact,
    std::vector<EnemyRuntime> &enemies,
    float tileSizePx
);

ExplosionRuntime spawnExplosion(float xPx, float yPx, float radiusTiles, float durationFrames = 14.0f);

void ageExplosions(std::vector<ExplosionRuntime> &explosions, float deltaFrames = 1.0f);

}  // namespace towerdefense

#endif
