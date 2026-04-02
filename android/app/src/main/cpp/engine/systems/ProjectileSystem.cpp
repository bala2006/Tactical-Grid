#include "ProjectileSystem.h"

#include <algorithm>
#include <cmath>

namespace towerdefense {

namespace {

int findEnemyIndexById(const std::vector<EnemyRuntime> &enemies, int enemyId) {
    if (enemyId < 0) {
        return -1;
    }
    for (size_t index = 0; index < enemies.size(); ++index) {
        if (enemies[index].id == enemyId) {
            return static_cast<int>(index);
        }
    }
    return -1;
}

int findNearestEnemyIndex(
    const std::vector<EnemyRuntime> &enemies,
    float xPx,
    float yPx,
    float rangePx,
    int excludeEnemyId
) {
    int bestIndex = -1;
    float bestDistanceSquared = 1e30f;
    std::vector<int> taunts;
    for (size_t index = 0; index < enemies.size(); ++index) {
        const EnemyRuntime &enemy = enemies[index];
        if (!enemy.alive || enemy.id == excludeEnemyId) {
            continue;
        }
        const float dx = enemy.x - xPx;
        const float dy = enemy.y - yPx;
        const float distanceSquared = dx * dx + dy * dy;
        if (distanceSquared > rangePx * rangePx) {
            continue;
        }
        if (enemy.archetype == EnemyArchetypeId::Taunt) {
            taunts.push_back(static_cast<int>(index));
        }
    }

    const auto chooseNearest = [&](const std::vector<int> &indices) {
        for (int rawIndex : indices) {
            const EnemyRuntime &enemy = enemies[static_cast<size_t>(rawIndex)];
            const float dx = enemy.x - xPx;
            const float dy = enemy.y - yPx;
            const float distanceSquared = dx * dx + dy * dy;
            if (distanceSquared < bestDistanceSquared) {
                bestDistanceSquared = distanceSquared;
                bestIndex = rawIndex;
            }
        }
    };

    if (!taunts.empty()) {
        chooseNearest(taunts);
        return bestIndex;
    }

    for (size_t index = 0; index < enemies.size(); ++index) {
        const EnemyRuntime &enemy = enemies[index];
        if (!enemy.alive || enemy.id == excludeEnemyId) {
            continue;
        }
        const float dx = enemy.x - xPx;
        const float dy = enemy.y - yPx;
        const float distanceSquared = dx * dx + dy * dy;
        if (distanceSquared > rangePx * rangePx) {
            continue;
        }
        if (distanceSquared < bestDistanceSquared) {
            bestDistanceSquared = distanceSquared;
            bestIndex = static_cast<int>(index);
        }
    }
    return bestIndex;
}

}  // namespace

int retargetRocketByEnemyId(
    ProjectileRuntime &projectile,
    const std::vector<EnemyRuntime> &enemies,
    float fallbackX,
    float fallbackY,
    float tileSizePx,
    int excludeEnemyId
) {
    int targetIndex = findEnemyIndexById(enemies, projectile.targetEnemyId);
    if (targetIndex >= 0 && enemies[static_cast<size_t>(targetIndex)].alive) {
        return projectile.targetEnemyId;
    }

    targetIndex = findNearestEnemyIndex(
        enemies,
        fallbackX,
        fallbackY,
        (projectile.range + 1.0f) * tileSizePx,
        excludeEnemyId
    );
    if (targetIndex < 0) {
        projectile.targetEnemyId = -1;
        return -1;
    }

    projectile.targetEnemyId = enemies[static_cast<size_t>(targetIndex)].id;
    return projectile.targetEnemyId;
}

std::vector<ProjectileImpact> advanceProjectiles(
    std::vector<ProjectileRuntime> &projectiles,
    const std::vector<EnemyRuntime> &enemies,
    float hitDistancePx,
    float tileSizePx
) {
    std::vector<ProjectileImpact> impacts;
    const float hitDistanceSquared = hitDistancePx * hitDistancePx;

    for (size_t index = 0; index < projectiles.size(); ++index) {
        ProjectileRuntime &projectile = projectiles[index];
        if (!projectile.alive) {
            continue;
        }
        projectile.prevX = projectile.x;
        projectile.prevY = projectile.y;

        const int retargetedId = retargetRocketByEnemyId(
            projectile,
            enemies,
            projectile.x,
            projectile.y,
            tileSizePx,
            projectile.targetEnemyId
        );
        if (retargetedId < 0) {
            projectile.alive = false;
            continue;
        }

        const int targetIndex = findEnemyIndexById(enemies, projectile.targetEnemyId);
        if (targetIndex < 0 || !enemies[static_cast<size_t>(targetIndex)].alive) {
            projectile.alive = false;
            continue;
        }

        const EnemyRuntime &target = enemies[static_cast<size_t>(targetIndex)];
        const float dx = target.x - projectile.x;
        const float dy = target.y - projectile.y;
        const float distanceSquared = dx * dx + dy * dy;

        if (projectile.lifetime <= 0) {
            impacts.push_back(ProjectileImpact{
                projectile.prevX,
                projectile.prevY,
                projectile.splashRadius,
                projectile.damageMin,
                projectile.damageMax,
                static_cast<int>(index),
                projectile.targetEnemyId,
            });
            projectile.alive = false;
            continue;
        }

        if (distanceSquared <= hitDistanceSquared) {
            impacts.push_back(ProjectileImpact{
                projectile.prevX,
                projectile.prevY,
                projectile.splashRadius,
                projectile.damageMin,
                projectile.damageMax,
                static_cast<int>(index),
                projectile.targetEnemyId,
            });
            projectile.alive = false;
            continue;
        }

        const float distance = std::sqrt(distanceSquared);
        if (distance > 0.0001f) {
            const float desiredX = (dx / distance) * projectile.topSpeed;
            const float desiredY = (dy / distance) * projectile.topSpeed;
            float steerX = desiredX - projectile.vx;
            float steerY = desiredY - projectile.vy;
            const float steerLength = std::sqrt(steerX * steerX + steerY * steerY);
            if (steerLength > projectile.accAmt && steerLength > 0.0001f) {
                const float scale = projectile.accAmt / steerLength;
                steerX *= scale;
                steerY *= scale;
            }
            projectile.ax += steerX;
            projectile.ay += steerY;
        }

        projectile.vx += projectile.ax;
        projectile.vy += projectile.ay;
        const float velocityLength = std::sqrt(projectile.vx * projectile.vx + projectile.vy * projectile.vy);
        if (velocityLength > projectile.topSpeed && velocityLength > 0.0001f) {
            const float scale = projectile.topSpeed / velocityLength;
            projectile.vx *= scale;
            projectile.vy *= scale;
        }
        projectile.x += projectile.vx;
        projectile.y += projectile.vy;
        projectile.ax = 0.0f;
        projectile.ay = 0.0f;
        projectile.lifetime--;
    }

    projectiles.erase(
        std::remove_if(
            projectiles.begin(),
            projectiles.end(),
            [](const ProjectileRuntime &projectile) { return !projectile.alive; }
        ),
        projectiles.end()
    );

    return impacts;
}

int applySplashImpact(
    const ProjectileImpact &impact,
    std::vector<EnemyRuntime> &enemies,
    float tileSizePx
) {
    const float splashRadiusPx = impact.splashRadius * tileSizePx;
    const float splashRadiusSquared = splashRadiusPx * splashRadiusPx;
    int affectedCount = 0;

    for (EnemyRuntime &enemy : enemies) {
        if (!enemy.alive) {
            continue;
        }
        const float dx = enemy.x - impact.x;
        const float dy = enemy.y - impact.y;
        const float distanceSquared = dx * dx + dy * dy;
        if (distanceSquared > splashRadiusSquared) {
            continue;
        }

        const float damage = (impact.damageMin + impact.damageMax) * 0.5f;
        enemy.hitFlash = std::min(1.0f, enemy.hitFlash + 0.65f);
        enemy.health -= damage;
        if (enemy.health <= 0.0f) {
            enemy.alive = false;
        }
        affectedCount++;
    }

    return affectedCount;
}

ExplosionRuntime spawnExplosion(float xPx, float yPx, float radiusTiles, float durationFrames) {
    ExplosionRuntime explosion;
    explosion.x = xPx;
    explosion.y = yPx;
    explosion.radius = std::max(0.8f, radiusTiles);
    explosion.age = 0.0f;
    explosion.duration = std::max(1.0f, durationFrames);
    explosion.alive = true;
    return explosion;
}

void ageExplosions(std::vector<ExplosionRuntime> &explosions, float deltaFrames) {
    for (ExplosionRuntime &explosion : explosions) {
        if (!explosion.alive) {
            continue;
        }
        explosion.age += std::max(0.0f, deltaFrames);
        if (explosion.age >= explosion.duration) {
            explosion.alive = false;
        }
    }

    explosions.erase(
        std::remove_if(
            explosions.begin(),
            explosions.end(),
            [](const ExplosionRuntime &explosion) { return !explosion.alive; }
        ),
        explosions.end()
    );
}

}  // namespace towerdefense
