#ifndef TOWERDEFENSE_ENEMY_BEHAVIORS_H
#define TOWERDEFENSE_ENEMY_BEHAVIORS_H

#include <string_view>
#include <vector>

#include "GameRuntimeTypes.h"

namespace towerdefense {

enum class EnemyBehaviorKind {
    None = 0,
    Medic = 1,
};

struct MedicSupportState {
    int healCooldownTicks = 0;
    int healIntervalTicks = 90;
    float healRangeTiles = 2.5f;
    float healAmount = 4.0f;
    float selfHealAmount = 0.0f;
};

struct MedicHealEvent {
    int medicId = -1;
    int targetId = -1;
    float amount = 0.0f;
};

bool isMedicBehavior(std::string_view archetypeId);
EnemyBehaviorKind behaviorKindForArchetype(std::string_view archetypeId);

MedicSupportState makeMedicSupportState(
    int healIntervalTicks = 90,
    float healRangeTiles = 2.5f,
    float healAmount = 4.0f
);

int findSupportTargetIndex(
    const EnemyRuntime &medic,
    const std::vector<EnemyRuntime> &enemies,
    float healRangeTiles,
    float tileSizePx
);

float applyHealing(EnemyRuntime &enemy, float amount);

bool tickMedicSupport(
    EnemyRuntime &medic,
    std::vector<EnemyRuntime> &allEnemies,
    MedicSupportState &state,
    float tileSizePx,
    std::vector<MedicHealEvent> *outEvents = nullptr
);

}  // namespace towerdefense

#endif
