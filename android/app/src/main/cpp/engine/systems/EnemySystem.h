#ifndef TOWERDEFENSE_ENEMY_SYSTEM_H
#define TOWERDEFENSE_ENEMY_SYSTEM_H

#include <functional>
#include <vector>

#include "GameRuntimeTypes.h"

namespace towerdefense {

struct EnemyBlueprint {
    float baseSpeed = 1.0f;
    float radius = 0.38f;
    float health = 18.0f;
    int cash = 5;
    int damage = 1;
};

using TileLookup = std::function<int(int, int)>;
using BoardPointToTile = std::function<bool(float, float, int *, int *)>;
using TileCenterCheck = std::function<bool(float, float, int, int)>;

EnemyRuntime makeEnemyInstance(
    int id,
    int spawnCol,
    int spawnRow,
    float boardLeft,
    float boardTop,
    float tileSize,
    const EnemyBlueprint &blueprint
);

void spawnEnemy(
    std::vector<EnemyRuntime> &enemies,
    WaveRuntimeState &state,
    int spawnCol,
    int spawnRow,
    float boardLeft,
    float boardTop,
    float tileSize,
    const EnemyBlueprint &blueprint
);

bool tickEnemySpawnCadence(
    std::vector<EnemyRuntime> &enemies,
    WaveRuntimeState &state,
    const std::vector<int> &spawnPoints,
    float boardLeft,
    float boardTop,
    float tileSize,
    const EnemyBlueprint &blueprint
);

void steerEnemy(
    EnemyRuntime &enemy,
    float tileSize,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile,
    const TileCenterCheck &atTileCenter
);

bool advanceEnemy(
    EnemyRuntime &enemy,
    float tileSize,
    int exitCol,
    int exitRow,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile,
    const TileCenterCheck &atTileCenter,
    const std::function<void(const EnemyRuntime &)> &onLeak
);

void updateEnemiesFixedStep(
    std::vector<EnemyRuntime> &enemies,
    float tileSize,
    int exitCol,
    int exitRow,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile,
    const TileCenterCheck &atTileCenter,
    const std::function<void(const EnemyRuntime &)> &onLeak
);

int tileDistanceToExit(int col, int row, int boardCols, const std::vector<int> &distanceField);

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
);

int findLeadingEnemyIndex(
    const std::vector<EnemyRuntime> &enemies,
    float centerX,
    float centerY,
    float rangePx,
    float tileSize,
    float boardLeft,
    float boardTop,
    int boardCols,
    int boardRows,
    const std::vector<int> &distanceField,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile
);

}  // namespace towerdefense

#endif
