#include "EnemySystem.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>

namespace towerdefense {

namespace {
constexpr float kDefaultTileStep = 24.0f;
constexpr float kEnemySpeedMultiplier = 1.0f;
}

EnemyRuntime makeEnemyInstance(
    int id,
    int spawnCol,
    int spawnRow,
    float boardLeft,
    float boardTop,
    float tileSize,
    const EnemyBlueprint &blueprint
) {
    EnemyRuntime enemy;
    enemy.id = id;
    enemy.archetype = blueprint.archetype;
    enemy.archetypeId = std::string(enemyArchetypeIdName(blueprint.archetype));
    enemy.x = boardLeft + (static_cast<float>(spawnCol) + 0.5f) * tileSize;
    enemy.y = boardTop + (static_cast<float>(spawnRow) + 0.5f) * tileSize;
    enemy.prevX = enemy.x;
    enemy.prevY = enemy.y;
    enemy.baseSpeed = blueprint.baseSpeed;
    enemy.speed = blueprint.baseSpeed;
    enemy.radius = blueprint.radius;
    enemy.health = blueprint.health;
    enemy.maxHealth = blueprint.health;
    enemy.cash = blueprint.cash;
    enemy.damage = blueprint.damage;
    // Seed the trail history at the spawn position.
    for (int i = 0; i < EnemyRuntime::kTrailSamples; ++i) {
        enemy.trailX[i] = enemy.x;
        enemy.trailY[i] = enemy.y;
    }
    enemy.trailHead = 0;
    enemy.trailFilled = 1;
    return enemy;
}

void spawnEnemy(
    std::vector<EnemyRuntime> &enemies,
    WaveRuntimeState &state,
    int spawnCol,
    int spawnRow,
    float boardLeft,
    float boardTop,
    float tileSize,
    const EnemyBlueprint &blueprint
) {
    enemies.push_back(makeEnemyInstance(
        state.nextEnemyId++,
        spawnCol,
        spawnRow,
        boardLeft,
        boardTop,
        tileSize,
        blueprint
    ));
}

bool tickEnemySpawnCadence(
    std::vector<EnemyRuntime> &enemies,
    WaveRuntimeState &state,
    const std::vector<int> &spawnPoints,
    float boardLeft,
    float boardTop,
    float tileSize,
    const EnemyBlueprint &blueprint
) {
    if (spawnPoints.size() < 2) {
        return false;
    }

    if (state.spawnTickCounter > 0) {
        state.spawnTickCounter--;
        return false;
    }

    const int spawnPairCount = static_cast<int>(spawnPoints.size() / 2);
    if (spawnPairCount <= 0) {
        return false;
    }

    const int spawnIndex = (state.nextSpawnIndex % spawnPairCount) * 2;
    spawnEnemy(
        enemies,
        state,
        spawnPoints[static_cast<size_t>(spawnIndex)],
        spawnPoints[static_cast<size_t>(spawnIndex + 1)],
        boardLeft,
        boardTop,
        tileSize,
        blueprint
    );
    state.nextSpawnIndex++;
    state.spawnTickCounter = state.spawnCooldownTicks;
    return true;
}

void steerEnemy(
    EnemyRuntime &enemy,
    float tileSize,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile,
    const TileCenterCheck &atTileCenter
) {
    int col = 0;
    int row = 0;
    if (!boardPointToTile(enemy.x, enemy.y, &col, &row)) {
        return;
    }

    const int direction = pathAt(col, row);
    if (direction == 0) {
        enemy.vx = 0.0f;
        enemy.vy = 0.0f;
        return;
    }
    if (!atTileCenter(enemy.x, enemy.y, col, row)) {
        return;
    }

    const float speed = enemy.speed * kEnemySpeedMultiplier * tileSize / kDefaultTileStep;
    switch (direction) {
        case 1:
            enemy.vx = -speed;
            enemy.vy = 0.0f;
            break;
        case 2:
            enemy.vx = 0.0f;
            enemy.vy = -speed;
            break;
        case 3:
            enemy.vx = speed;
            enemy.vy = 0.0f;
            break;
        case 4:
            enemy.vx = 0.0f;
            enemy.vy = speed;
            break;
        default:
            break;
    }
}

bool advanceEnemy(
    EnemyRuntime &enemy,
    float tileSize,
    int exitCol,
    int exitRow,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile,
    const TileCenterCheck &atTileCenter,
    const std::function<void(const EnemyRuntime &)> &onLeak
) {
    if (!enemy.alive) {
        return false;
    }

    if (enemy.slowTicks > 0) {
        enemy.slowTicks--;
    } else {
        enemy.slowFactor = 1.0f;
    }
    enemy.speed = enemy.baseSpeed * enemy.slowFactor;
    enemy.prevX = enemy.x;
    enemy.prevY = enemy.y;
    steerEnemy(enemy, tileSize, pathAt, boardPointToTile, atTileCenter);
    enemy.x += enemy.vx;
    enemy.y += enemy.vy;
    // Record this tick's position for multi-segment body rendering.
    enemy.trailHead = (enemy.trailHead + 1) % EnemyRuntime::kTrailSamples;
    enemy.trailX[enemy.trailHead] = enemy.x;
    enemy.trailY[enemy.trailHead] = enemy.y;
    if (enemy.trailFilled < EnemyRuntime::kTrailSamples) {
        enemy.trailFilled++;
    }
    enemy.hitFlash = std::max(0.0f, enemy.hitFlash - 0.08f);

    int col = 0;
    int row = 0;
    if (!boardPointToTile(enemy.x, enemy.y, &col, &row)) {
        enemy.alive = false;
        return false;
    }

    if (col == exitCol && row == exitRow) {
        if (onLeak) {
            onLeak(enemy);
        }
        enemy.alive = false;
        return true;
    }

    return false;
}

void updateEnemiesFixedStep(
    std::vector<EnemyRuntime> &enemies,
    float tileSize,
    int exitCol,
    int exitRow,
    const TileLookup &pathAt,
    const BoardPointToTile &boardPointToTile,
    const TileCenterCheck &atTileCenter,
    const std::function<void(const EnemyRuntime &)> &onLeak
) {
    for (EnemyRuntime &enemy : enemies) {
        advanceEnemy(
            enemy,
            tileSize,
            exitCol,
            exitRow,
            pathAt,
            boardPointToTile,
            atTileCenter,
            onLeak
        );
    }

    enemies.erase(
        std::remove_if(enemies.begin(), enemies.end(), [](const EnemyRuntime &enemy) {
            return !enemy.alive;
        }),
        enemies.end()
    );
}

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
) {
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

}  // namespace towerdefense
