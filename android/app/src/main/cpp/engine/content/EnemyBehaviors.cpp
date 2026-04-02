#include "EnemyBehaviors.h"

#include <algorithm>
#include <cmath>

namespace towerdefense {

namespace {

float distanceSquared(float ax, float ay, float bx, float by) {
    const float dx = ax - bx;
    const float dy = ay - by;
    return dx * dx + dy * dy;
}

}  // namespace

bool isMedicBehavior(EnemyArchetypeId archetypeId) {
    return archetypeId == EnemyArchetypeId::Medic;
}

EnemyBehaviorKind behaviorKindForArchetype(EnemyArchetypeId archetypeId) {
    return isMedicBehavior(archetypeId) ? EnemyBehaviorKind::Medic : EnemyBehaviorKind::None;
}

MedicSupportState makeMedicSupportState(int healIntervalTicks, float healRangeTiles, float healAmount) {
    MedicSupportState state;
    state.healIntervalTicks = std::max(1, healIntervalTicks);
    state.healRangeTiles = std::max(0.5f, healRangeTiles);
    state.healAmount = std::max(0.0f, healAmount);
    state.healCooldownTicks = 0;
    state.selfHealAmount = 0.0f;
    return state;
}

int findSupportTargetIndex(
    const EnemyRuntime &medic,
    const std::vector<EnemyRuntime> &enemies,
    float healRangeTiles,
    float tileSizePx
) {
    const float rangePx = std::max(0.0f, healRangeTiles) * tileSizePx;
    const float rangeSquared = rangePx * rangePx;
    int bestIndex = -1;
    float bestHealthRatio = 1e9f;
    float bestDistanceSquared = 1e9f;

    for (size_t index = 0; index < enemies.size(); ++index) {
        const EnemyRuntime &candidate = enemies[index];
        if (!candidate.alive || candidate.id == medic.id) {
            continue;
        }

        const float distSquared = distanceSquared(medic.x, medic.y, candidate.x, candidate.y);
        if (distSquared > rangeSquared) {
            continue;
        }

        if (candidate.maxHealth <= 0.0f) {
            continue;
        }

        const float healthRatio = candidate.health / candidate.maxHealth;
        if (healthRatio < bestHealthRatio ||
            (healthRatio == bestHealthRatio && distSquared < bestDistanceSquared)) {
            bestHealthRatio = healthRatio;
            bestDistanceSquared = distSquared;
            bestIndex = static_cast<int>(index);
        }
    }

    return bestIndex;
}

float applyHealing(EnemyRuntime &enemy, float amount) {
    if (!enemy.alive || amount <= 0.0f || enemy.maxHealth <= 0.0f) {
        return 0.0f;
    }

    const float before = enemy.health;
    enemy.health = std::min(enemy.maxHealth, enemy.health + amount);
    return enemy.health - before;
}

bool tickMedicSupport(
    EnemyRuntime &medic,
    std::vector<EnemyRuntime> &allEnemies,
    MedicSupportState &state,
    float tileSizePx,
    std::vector<MedicHealEvent> *outEvents
) {
    if (!medic.alive) {
        return false;
    }

    if (state.healCooldownTicks > 0) {
        state.healCooldownTicks--;
        return false;
    }

    const int targetIndex = findSupportTargetIndex(medic, allEnemies, state.healRangeTiles, tileSizePx);
    if (targetIndex < 0) {
        return false;
    }

    EnemyRuntime &target = allEnemies[static_cast<size_t>(targetIndex)];
    const float healedAmount = applyHealing(target, state.healAmount);
    if (healedAmount <= 0.0f) {
        state.healCooldownTicks = std::max(1, state.healIntervalTicks / 2);
        return false;
    }

    if (outEvents != nullptr) {
        outEvents->push_back(MedicHealEvent{
            medic.id,
            target.id,
            healedAmount,
        });
    }

    state.healCooldownTicks = state.healIntervalTicks;
    return true;
}

}  // namespace towerdefense
