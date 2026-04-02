#include "TowerSystem.h"

#include <algorithm>
#include <cmath>

namespace towerdefense {

namespace {

int tileDistanceToExit(int col, int row, int boardCols, const std::vector<int> &distanceField) {
    if (col < 0 || row < 0 || boardCols <= 0) {
        return 1000000;
    }
    const size_t index = static_cast<size_t>(row * boardCols + col);
    if (index >= distanceField.size()) {
        return 1000000;
    }
    return distanceField[index];
}

float enemyProgressScore(
    float xPx,
    float yPx,
    float tileSize,
    float boardLeft,
    float boardTop,
    int boardCols,
    int boardRows,
    const std::vector<int> &distanceField,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile
) {
    int col = 0;
    int row = 0;
    if (!boardPointToTile(xPx, yPx, &col, &row)) {
        return 1000000.0f;
    }
    if (col < 0 || row < 0 || col >= boardCols || row >= boardRows) {
        return 1000000.0f;
    }

    const float centerX = boardLeft + (static_cast<float>(col) + 0.5f) * tileSize;
    const float centerY = boardTop + (static_cast<float>(row) + 0.5f) * tileSize;
    const int direction = pathAt(col, row);
    float progress = 0.0f;
    switch (direction) {
        case 1:
            progress = (centerX - xPx) / tileSize;
            break;
        case 2:
            progress = (centerY - yPx) / tileSize;
            break;
        case 3:
            progress = (xPx - centerX) / tileSize;
            break;
        case 4:
            progress = (yPx - centerY) / tileSize;
            break;
        default:
            break;
    }

    return static_cast<float>(tileDistanceToExit(col, row, boardCols, distanceField)) - progress;
}

}  // namespace

TowerRuntime makeTowerRuntime(std::string_view kind, int col, int row) {
    TowerRuntime tower;
    tower.kindId = parseTowerKindId(kind);
    tower.kind = std::string(kind);
    tower.col = col;
    tower.row = row;

    if (const TowerCatalogEntry *entry = findTowerCatalogEntry(kind)) {
        tower.cooldownMin = entry->cooldownMin;
        tower.cooldownMax = entry->cooldownMax;
        tower.range = entry->range;
        tower.damageMin = entry->damageMin;
        tower.damageMax = entry->damageMax;
        tower.investedCost = entry->cost;
    }

    if (tower.kindId == TowerKindId::Slow) {
        tower.slowFactor = 0.5f;
        tower.slowTicks = 40;
    }
    tower.targetingMode = TargetingMode::First;
    tower.level = 1;
    tower.upgradeCount = 0;
    return tower;
}

void decayTowerVisuals(TowerRuntime &tower, int cooldownStep) {
    tower.cooldown = std::max(0, tower.cooldown - std::max(1, cooldownStep));
    tower.flash = std::max(0.0f, tower.flash - 0.16f);
    tower.recoil = std::max(0.0f, tower.recoil - 0.18f);
    tower.beamTicks = std::max(0, tower.beamTicks - 1);
}

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
) {
    const float centerX = boardLeft + (static_cast<float>(tower.col) + 0.5f) * tileSize;
    const float centerY = boardTop + (static_cast<float>(tower.row) + 0.5f) * tileSize;
    const float rangePx = tower.range * tileSize;
    const float rangeSquared = rangePx * rangePx;

    int bestIndex = -1;
    float bestMetric = 1e9f;
    for (size_t index = 0; index < enemies.size(); ++index) {
        const EnemyRuntime &enemy = enemies[index];
        if (!enemy.alive) {
            continue;
        }
        const float dx = enemy.x - centerX;
        const float dy = enemy.y - centerY;
        if (dx * dx + dy * dy > rangeSquared) {
            continue;
        }

        const float metric = enemyProgressScore(
            enemy.x,
            enemy.y,
            tileSize,
            boardLeft,
            boardTop,
            boardCols,
            boardRows,
            distanceField,
            pathAt,
            boardPointToTile
        );
        if (metric < bestMetric) {
            bestMetric = metric;
            bestIndex = static_cast<int>(index);
        }
    }

    return bestIndex;
}

void prepareTowerFireState(
    TowerRuntime &tower,
    const EnemyRuntime &target,
    float boardLeft,
    float boardTop,
    float tileSize,
    int cooldownTicksOverride,
    int beamTicks
) {
    const float centerX = boardLeft + (static_cast<float>(tower.col) + 0.5f) * tileSize;
    const float centerY = boardTop + (static_cast<float>(tower.row) + 0.5f) * tileSize;
    tower.angle = std::atan2(target.y - centerY, target.x - centerX);
    tower.beamTargetX = target.x;
    tower.beamTargetY = target.y;
    tower.flash = 1.0f;
    tower.recoil = 1.0f;
    tower.cooldown = cooldownTicksOverride >= 0 ? cooldownTicksOverride : (tower.cooldownMin + tower.cooldownMax) / 2;
    if (tower.kindId == TowerKindId::Laser || tower.kindId == TowerKindId::BeamEmitter) {
        tower.beamTicks = std::max(1, beamTicks);
    } else {
        tower.beamTicks = 0;
    }
}

}  // namespace towerdefense
