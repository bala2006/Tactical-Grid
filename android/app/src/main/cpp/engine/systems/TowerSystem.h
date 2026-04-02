#ifndef TOWERDEFENSE_TOWER_SYSTEM_H
#define TOWERDEFENSE_TOWER_SYSTEM_H

#include <functional>
#include <string_view>
#include <vector>

#include "GameRuntimeTypes.h"
#include "TowerCatalog.h"

namespace towerdefense {

using TileLookup = std::function<int(int, int)>;
using BoardPointToTile = std::function<bool(float, float, int *, int *)>;

TowerRuntime makeTowerRuntime(std::string_view kind, int col, int row);

void decayTowerVisuals(TowerRuntime &tower, int cooldownStep = 1);

int findLeadingEnemyIndexInRange(
    const std::vector<EnemyRuntime> &enemies,
    const TowerRuntime &tower,
    float boardLeft,
    float boardTop,
    float tileSize,
    int boardCols,
    int boardRows,
    const std::vector<int> &distanceField,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile
);

void prepareTowerFireState(
    TowerRuntime &tower,
    const EnemyRuntime &target,
    float boardLeft,
    float boardTop,
    float tileSize,
    int cooldownTicksOverride = -1,
    int beamTicks = 6
);

}  // namespace towerdefense

#endif
