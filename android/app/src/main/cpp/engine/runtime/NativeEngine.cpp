#include "NativeEngine.h"

#include "GeneratedMaps.h"
#include "EnemyArchetypes.h"
#include "EnemyBehaviors.h"
#include "EnemySystem.h"
#include "ProjectileSystem.h"
#include "TowerSystem.h"
#include "TowerUpgrades.h"
#include "WaveSpec.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <queue>
#include <random>
#include <sstream>
#include <stdexcept>

using towerdefense::TowerCatalogEntry;
using towerdefense::EnemyBlueprint;
using towerdefense::EnemyArchetypeSpec;
using towerdefense::MedicSupportState;
using towerdefense::advanceProjectiles;
using towerdefense::ageExplosions;
using towerdefense::applySplashImpact;
using towerdefense::applyTowerUpgrade;
using towerdefense::computeSellPrice;
using towerdefense::computeUpgradePrice;
using towerdefense::nextTowerUpgrade;
using towerdefense::makeMedicSupportState;
using towerdefense::findTowerCatalogEntry;
using towerdefense::findEnemyArchetype;
using towerdefense::makeEnemyInstance;
using towerdefense::makeTowerRuntime;
using towerdefense::makeWaveSpec;
using towerdefense::prepareTowerFireState;
using towerdefense::towerCatalogEntries;
using towerdefense::advanceWaveByTicks;
using towerdefense::decayTowerVisuals;
using towerdefense::findLeadingEnemyIndexInRange;
using towerdefense::TargetingMode;
using towerdefense::isValidTargetingModeId;
using towerdefense::parseTargetingMode;
using towerdefense::targetingModeLabel;
using towerdefense::resetWaveRuntime;
using towerdefense::tickEnemySpawnCadence;
using towerdefense::tickMedicSupport;
using towerdefense::updateEnemiesFixedStep;
using towerdefense::waveStateLabel;
using towerdefense::NativeAudioEvent;
using towerdefense::NativeGameSnapshot;
using towerdefense::SoundType;
using towerdefense::EnemyArchetypeId;
using towerdefense::TowerKindId;
using towerdefense::parseTowerKindId;

namespace {
constexpr double kFixedStepSeconds = 1.0 / 60.0;
constexpr int kMaxSimulationStepsPerFrame = 8;
constexpr int kDefaultWaveCooldown = 120;
constexpr float kTowerCooldownScale = 0.90f;
constexpr float kReferenceProceduralSpawnDistanceTiles = 24.0f;
constexpr float kMinimumProceduralEnemySpeedScale = 0.65f;

struct WaveGroupDef {
    std::vector<std::string> sequence;
    int count;
};

struct WavePatternDef {
    int spawnCooldownTicks;
    std::vector<WaveGroupDef> groups;
};

struct RgbColor {
    int r;
    int g;
    int b;
};

struct Point2D {
    float x;
    float y;
};

struct EnemyPalette {
    RgbColor primary;
    RgbColor secondary;
};

template <size_t N>
void copyCString(char (&destination)[N], std::string_view source) {
    static_assert(N > 0);
    const size_t count = std::min(source.size(), N - 1);
    if (count > 0) {
        std::memcpy(destination, source.data(), count);
    }
    destination[count] = '\0';
    if (count + 1 < N) {
        std::memset(destination + count + 1, 0, N - count - 1);
    }
}

unsigned int rgba(int r, int g, int b, int a = 255) {
    return (static_cast<unsigned int>(a) << 24) |
           (static_cast<unsigned int>(b) << 16) |
           (static_cast<unsigned int>(g) << 8) |
           static_cast<unsigned int>(r);
}

Point2D rotatePoint(float centerX, float centerY, float angle, float localX, float localY) {
    const float c = std::cos(angle);
    const float s = std::sin(angle);
    return Point2D{
        centerX + localX * c - localY * s,
        centerY + localX * s + localY * c,
    };
}

void drawShadow(GlRenderer2D &renderer, float x, float y, float width, float height, int alpha) {
    renderer.drawEllipse(x, y, width * 0.5f, height * 0.5f, rgba(0, 0, 0, alpha), 28);
}

EnemyPalette enemyPaletteFor(EnemyArchetypeId archetype, bool slowed) {
    EnemyPalette palette{
        {146, 152, 145},
        {190, 194, 184},
    };
    if (archetype == EnemyArchetypeId::Fast) {
        palette = {{118, 132, 138}, {190, 198, 196}};
    } else if (archetype == EnemyArchetypeId::StrongFast) {
        palette = {{86, 106, 116}, {170, 180, 178}};
    } else if (archetype == EnemyArchetypeId::Strong) {
        palette = {{96, 103, 106}, {145, 150, 147}};
    } else if (archetype == EnemyArchetypeId::Stronger) {
        palette = {{86, 90, 88}, {132, 138, 134}};
    } else if (archetype == EnemyArchetypeId::Faster) {
        palette = {{122, 116, 92}, {214, 168, 92}};
    } else if (archetype == EnemyArchetypeId::Medic) {
        palette = {{127, 116, 102}, {193, 74, 58}};
    } else if (archetype == EnemyArchetypeId::Tank) {
        palette = {{92, 108, 82}, {146, 152, 134}};
    } else if (archetype == EnemyArchetypeId::Taunt) {
        palette = {{96, 86, 112}, {200, 156, 84}};
    } else if (archetype == EnemyArchetypeId::Spawner) {
        palette = {{136, 128, 86}, {214, 188, 102}};
    }
    if (slowed) {
        palette = {{114, 170, 196}, {196, 224, 236}};
    }
    return palette;
}

void drawCircleRing(GlRenderer2D &renderer, float x, float y, float radius, float weight, RgbColor color, int alpha) {
    constexpr float kTau = 6.28318530718f;
    constexpr int kSegments = 48;
    for (int index = 0; index < kSegments; ++index) {
        const float angleA = (static_cast<float>(index) / static_cast<float>(kSegments)) * kTau;
        const float angleB = (static_cast<float>(index + 1) / static_cast<float>(kSegments)) * kTau;
        renderer.drawLine(
            x + std::cos(angleA) * radius,
            y + std::sin(angleA) * radius,
            x + std::cos(angleB) * radius,
            y + std::sin(angleB) * radius,
            weight,
            rgba(color.r, color.g, color.b, alpha)
        );
    }
}

void drawAxisAlignedRectOutline(
    GlRenderer2D &renderer,
    float left,
    float top,
    float width,
    float height,
    float thickness,
    unsigned int color
) {
    renderer.drawLine(left, top, left + width, top, thickness, color);
    renderer.drawLine(left + width, top, left + width, top + height, thickness, color);
    renderer.drawLine(left + width, top + height, left, top + height, thickness, color);
    renderer.drawLine(left, top + height, left, top, thickness, color);
}

void drawOrientedRect(
    GlRenderer2D &renderer,
    float centerX,
    float centerY,
    float angle,
    float left,
    float top,
    float width,
    float height,
    unsigned int color
) {
    const Point2D a = rotatePoint(centerX, centerY, angle, left, top);
    const Point2D b = rotatePoint(centerX, centerY, angle, left + width, top);
    const Point2D c = rotatePoint(centerX, centerY, angle, left + width, top + height);
    const Point2D d = rotatePoint(centerX, centerY, angle, left, top + height);
    renderer.drawQuad(a.x, a.y, b.x, b.y, c.x, c.y, d.x, d.y, color);
}

void drawOrientedQuad(
    GlRenderer2D &renderer,
    float centerX,
    float centerY,
    float angle,
    Point2D a,
    Point2D b,
    Point2D c,
    Point2D d,
    unsigned int color
) {
    const Point2D wa = rotatePoint(centerX, centerY, angle, a.x, a.y);
    const Point2D wb = rotatePoint(centerX, centerY, angle, b.x, b.y);
    const Point2D wc = rotatePoint(centerX, centerY, angle, c.x, c.y);
    const Point2D wd = rotatePoint(centerX, centerY, angle, d.x, d.y);
    renderer.drawQuad(wa.x, wa.y, wb.x, wb.y, wc.x, wc.y, wd.x, wd.y, color);
}

void drawOrientedTriangle(
    GlRenderer2D &renderer,
    float centerX,
    float centerY,
    float angle,
    Point2D a,
    Point2D b,
    Point2D c,
    unsigned int color
) {
    const Point2D wa = rotatePoint(centerX, centerY, angle, a.x, a.y);
    const Point2D wb = rotatePoint(centerX, centerY, angle, b.x, b.y);
    const Point2D wc = rotatePoint(centerX, centerY, angle, c.x, c.y);
    renderer.drawTriangle(wa.x, wa.y, wb.x, wb.y, wc.x, wc.y, color);
}

void drawRegularPolygon(
    GlRenderer2D &renderer,
    float centerX,
    float centerY,
    float radius,
    int sides,
    float rotation,
    unsigned int color
) {
    if (sides < 3 || radius <= 0.0f) {
        return;
    }
    constexpr float kTau = 6.28318530718f;
    for (int index = 0; index < sides; ++index) {
        const float angleA = rotation + (static_cast<float>(index) / static_cast<float>(sides)) * kTau;
        const float angleB = rotation + (static_cast<float>(index + 1) / static_cast<float>(sides)) * kTau;
        renderer.drawTriangle(
            centerX,
            centerY,
            centerX + std::cos(angleA) * radius,
            centerY + std::sin(angleA) * radius,
            centerX + std::cos(angleB) * radius,
            centerY + std::sin(angleB) * radius,
            color
        );
    }
}

std::vector<std::string> expandWavePattern(const WavePatternDef &pattern) {
    std::vector<std::string> queue;
    for (const WaveGroupDef &group : pattern.groups) {
        for (int iteration = 0; iteration < group.count; ++iteration) {
            queue.insert(queue.end(), group.sequence.begin(), group.sequence.end());
        }
    }
    return queue;
}

WavePatternDef choosePresetWave(int waveNumber, int waveMode) {
    static const std::array<WavePatternDef, 9> kPresetWaves = {{
        {40, {{{"weak"}, 20}}},
        {30, {{{"weak"}, 10}, {{"fast"}, 10}}},
        {20, {{{"strong"}, 15}, {{"fast"}, 10}}},
        {20, {{{"medic", "strong", "strong"}, 10}}},
        {15, {{{"strongFast"}, 20}}},
        {15, {{{"tank"}, 8}, {{"fast"}, 16}}},
        {10, {{{"spawner"}, 2}, {{"stronger"}, 18}}},
        {10, {{{"taunt", "tank", "tank", "stronger"}, 10}}},
        {5, {{{"taunt", "medic", "tank"}, 16}, {{"faster"}, 24}}},
    }};
    static const std::array<WavePatternDef, 5> kCustomWaves = {{
        {30, {{{"weak"}, 12}, {{"strong"}, 6}}},
        {20, {{{"fast"}, 14}, {{"strong"}, 8}}},
        {20, {{{"medic", "strong"}, 10}, {{"strongFast"}, 8}}},
        {15, {{{"spawner"}, 1}, {{"tank"}, 8}, {{"faster"}, 10}}},
        {10, {{{"taunt", "medic", "tank"}, 12}, {{"spawner"}, 2}}},
    }};

    const int safeWave = std::max(1, waveNumber);
    if (waveMode == 2) {
        return kCustomWaves[static_cast<size_t>(std::min(safeWave - 1, static_cast<int>(kCustomWaves.size()) - 1))];
    }
    return kPresetWaves[static_cast<size_t>(std::min(safeWave - 1, static_cast<int>(kPresetWaves.size()) - 1))];
}

bool isWaveInRange(int waveNumber, int minInclusive, int maxExclusive = -1) {
    return maxExclusive < 0 ? waveNumber >= minInclusive : (waveNumber >= minInclusive && waveNumber < maxExclusive);
}

WavePatternDef randomWavePattern(int waveNumber, int difficulty) {
    std::vector<WavePatternDef> candidates;
    if (isWaveInRange(waveNumber, 0, 3)) candidates.push_back({40, {{{"weak"}, 50}}});
    if (isWaveInRange(waveNumber, 2, 4)) candidates.push_back({20, {{{"weak"}, 25}}});
    if (isWaveInRange(waveNumber, 2, 7)) {
        candidates.push_back({30, {{{"weak"}, 25}, {{"strong"}, 25}}});
        candidates.push_back({20, {{{"strong"}, 25}}});
    }
    if (isWaveInRange(waveNumber, 3, 7)) candidates.push_back({40, {{{"fast"}, 25}}});
    if (isWaveInRange(waveNumber, 4, 14)) candidates.push_back({20, {{{"fast"}, 50}}});
    if (isWaveInRange(waveNumber, 5, 6)) candidates.push_back({20, {{{"strong"}, 50}, {{"fast"}, 25}}});
    if (isWaveInRange(waveNumber, 8, 12)) candidates.push_back({20, {{{"medic", "strong", "strong"}, 25}}});
    if (isWaveInRange(waveNumber, 10, 13)) {
        candidates.push_back({20, {{{"medic", "strong", "strong"}, 50}}});
        candidates.push_back({30, {{{"medic", "strong", "strong"}, 50}, {{"fast"}, 50}}});
        candidates.push_back({5, {{{"fast"}, 50}}});
    }
    if (isWaveInRange(waveNumber, 12, 16)) {
        candidates.push_back({20, {{{"medic", "strong", "strong"}, 50}, {{"strongFast"}, 50}}});
        candidates.push_back({10, {{{"strong"}, 50}, {{"strongFast"}, 50}}});
        candidates.push_back({10, {{{"medic", "strongFast"}, 50}}});
        candidates.push_back({10, {{{"strong"}, 25}, {{"stronger"}, 25}, {{"strongFast"}, 50}}});
        candidates.push_back({10, {{{"strong"}, 25}, {{"medic"}, 25}, {{"strongFast"}, 50}}});
        candidates.push_back({20, {{{"medic", "stronger", "stronger"}, 50}}});
        candidates.push_back({10, {{{"medic", "stronger", "strong"}, 50}}});
        candidates.push_back({10, {{{"medic", "strong"}, 50}, {{"medic", "strongFast"}, 50}}});
        candidates.push_back({5, {{{"strongFast"}, 100}}});
        candidates.push_back({20, {{{"stronger"}, 50}}});
    }
    if (isWaveInRange(waveNumber, 13, 20)) {
        candidates.push_back({40, {{{"tank", "stronger", "stronger", "stronger"}, 10}}});
        candidates.push_back({10, {{{"medic", "stronger", "stronger"}, 50}}});
        candidates.push_back({40, {{{"tank"}, 25}}});
        candidates.push_back({20, {{{"tank", "stronger", "stronger"}, 50}}});
        candidates.push_back({20, {{{"tank", "medic"}, 50}, {{"strongFast"}, 25}}});
    }
    if (isWaveInRange(waveNumber, 14, 20)) {
        candidates.push_back({20, {{{"tank", "stronger", "stronger"}, 50}}});
        candidates.push_back({20, {{{"tank", "medic", "medic"}, 50}}});
        candidates.push_back({20, {{{"tank", "medic"}, 50}, {{"strongFast"}, 25}}});
        candidates.push_back({10, {{{"tank"}, 50}, {{"strongFast"}, 25}}});
        candidates.push_back({10, {{{"faster"}, 50}}});
        candidates.push_back({20, {{{"tank"}, 50}, {{"faster"}, 25}}});
    }
    if (isWaveInRange(waveNumber, 17, 25)) {
        candidates.push_back({20, {{{"taunt", "stronger", "stronger", "stronger"}, 25}}});
        candidates.push_back({20, {{{"spawner", "stronger", "stronger", "stronger"}, 25}}});
        candidates.push_back({20, {{{"taunt", "tank", "tank", "tank"}, 25}}});
        candidates.push_back({40, {{{"taunt", "tank", "tank", "tank"}, 25}}});
    }
    if (isWaveInRange(waveNumber, 19)) {
        candidates.push_back({20, {{{"spawner"}, 1}, {{"tank"}, 20}, {{"stronger"}, 25}}});
        candidates.push_back({20, {{{"spawner"}, 1}, {{"faster"}, 25}}});
    }
    if (isWaveInRange(waveNumber, 23)) {
        candidates.push_back({20, {{{"taunt", "medic", "tank"}, 25}}});
        candidates.push_back({20, {{{"spawner"}, 2}, {{"taunt", "medic", "tank"}, 25}}});
        candidates.push_back({10, {{{"spawner"}, 1}, {{"faster"}, 100}}});
        candidates.push_back({5, {{{"faster"}, 100}}});
        candidates.push_back({20, {{{"tank"}, 100}, {{"faster"}, 50}, {{"taunt", "tank", "tank", "tank"}, 50}}});
        candidates.push_back({10, {{{"taunt", "stronger", "tank", "stronger"}, 50}, {{"faster"}, 50}}});
    }
    if (isWaveInRange(waveNumber, 25)) {
        candidates.push_back({5, {{{"taunt", "medic", "tank"}, 50}, {{"faster"}, 50}}});
        candidates.push_back({5, {{{"taunt", "faster", "faster", "faster"}, 50}}});
        candidates.push_back({10, {{{"taunt", "tank", "tank", "tank"}, 50}, {{"faster"}, 50}}});
    }
    if (isWaveInRange(waveNumber, 30)) {
        candidates.push_back({5, {{{"taunt", "faster", "faster", "faster"}, 50}}});
        candidates.push_back({5, {{{"taunt", "tank", "tank", "tank"}, 50}}});
        candidates.push_back({5, {{{"taunt", "medic", "tank", "tank"}, 50}}});
        candidates.push_back({1, {{{"faster"}, 200}}});
    }
    if (isWaveInRange(waveNumber, 35)) {
        candidates.push_back({0, {{{"taunt", "faster"}, 200}}});
    }

    if (candidates.empty()) {
        candidates.push_back({20, {{{"weak"}, 25}, {{"strong"}, 25}}});
    }

    static std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<size_t> indexDist(0, candidates.size() - 1);
    WavePatternDef chosen = candidates[indexDist(rng)];
    if (difficulty == 0) {
        chosen.spawnCooldownTicks = std::max(chosen.spawnCooldownTicks, 20);
        for (WaveGroupDef &group : chosen.groups) {
            group.count = std::max(1, static_cast<int>(std::floor(static_cast<float>(group.count) * 0.85f)));
        }
    } else if (difficulty == 2) {
        chosen.spawnCooldownTicks = std::max(0, chosen.spawnCooldownTicks - 5);
        for (WaveGroupDef &group : chosen.groups) {
            group.count = std::max(1, static_cast<int>(std::ceil(static_cast<float>(group.count) * 1.2f)));
        }
    }
    return chosen;
}

bool isProceduralMapId(const std::string &mapId) {
    return mapId == "empty2" || mapId == "empty3" ||
           mapId == "sparse2" || mapId == "sparse3" ||
           mapId == "dense2" || mapId == "dense3" ||
           mapId == "solid2" || mapId == "solid3" ||
           mapId == "custom";
}

float damageMultiplierFor(EnemyArchetypeId archetypeId, std::string_view damageType) {
    if (archetypeId == EnemyArchetypeId::Tank) {
        if (damageType == "poison" || damageType == "slow") {
            return 0.0f;
        }
        if (damageType == "energy" || damageType == "physical") {
            return 0.5f;
        }
        if (damageType == "explosion" || damageType == "piercing") {
            return 1.5f;
        }
    } else if (archetypeId == EnemyArchetypeId::Taunt) {
        if (damageType == "poison" || damageType == "slow") {
            return 0.0f;
        }
        if (damageType == "energy" || damageType == "physical") {
            return 0.5f;
        }
    } else if (archetypeId == EnemyArchetypeId::Faster) {
        if (damageType == "explosion") {
            return 0.5f;
        }
    } else if (archetypeId == EnemyArchetypeId::Medic) {
        if (damageType == "regen") {
            return 0.0f;
        }
    }
    return 1.0f;
}

std::string_view damageTypeForTower(TowerKindId towerKind) {
    if (towerKind == TowerKindId::Laser || towerKind == TowerKindId::BeamEmitter ||
        towerKind == TowerKindId::Tesla || towerKind == TowerKindId::Plasma) {
        return "energy";
    }
    if (towerKind == TowerKindId::Slow) {
        return "slow";
    }
    if (towerKind == TowerKindId::Poison) {
        return "poison";
    }
    if (towerKind == TowerKindId::Rocket || towerKind == TowerKindId::MissileSilo ||
        towerKind == TowerKindId::Bomb || towerKind == TowerKindId::ClusterBomb) {
        return "explosion";
    }
    if (towerKind == TowerKindId::Railgun) {
        return "piercing";
    }
    return "physical";
}

bool isTowerFamily(std::string_view towerKind, std::string_view familyKind) {
    if (towerKind == familyKind) {
        return true;
    }
    if (familyKind == "gun") return towerKind == "machineGun";
    if (familyKind == "laser") return towerKind == "beamEmitter";
    if (familyKind == "slow") return towerKind == "poison";
    if (familyKind == "sniper") return towerKind == "railgun";
    if (familyKind == "rocket") return towerKind == "missileSilo";
    if (familyKind == "bomb") return towerKind == "clusterBomb";
    if (familyKind == "tesla") return towerKind == "plasma";
    return false;
}

int directionToward(int fromCol, int fromRow, int toCol, int toRow) {
    if (toCol < fromCol) {
        return 1;
    }
    if (toRow < fromRow) {
        return 2;
    }
    if (toCol > fromCol) {
        return 3;
    }
    if (toRow > fromRow) {
        return 4;
    }
    return 0;
}

void rebuildPathData(
    int cols,
    int rows,
    int exitCol,
    int exitRow,
    const std::vector<int> &grid,
    std::vector<int> *distanceField,
    std::vector<int> *paths
) {
    distanceField->assign(static_cast<size_t>(cols * rows), 1000000);
    paths->assign(static_cast<size_t>(cols * rows), 0);

    std::queue<std::pair<int, int>> frontier;
    frontier.push({exitCol, exitRow});
    (*distanceField)[static_cast<size_t>(exitRow * cols + exitCol)] = 0;

    constexpr std::array<int, 4> dx = {1, -1, 0, 0};
    constexpr std::array<int, 4> dy = {0, 0, 1, -1};
    while (!frontier.empty()) {
        const auto [currentCol, currentRow] = frontier.front();
        frontier.pop();
        const int currentDistance = (*distanceField)[static_cast<size_t>(currentRow * cols + currentCol)];
        for (size_t index = 0; index < dx.size(); ++index) {
            const int nextCol = currentCol + dx[index];
            const int nextRow = currentRow + dy[index];
            if (nextCol < 0 || nextRow < 0 || nextCol >= cols || nextRow >= rows) {
                continue;
            }
            const size_t nextIndex = static_cast<size_t>(nextRow * cols + nextCol);
            const int tile = grid[nextIndex];
            if (tile == 1 || tile == 3) {
                continue;
            }
            if ((*distanceField)[nextIndex] <= currentDistance + 1) {
                continue;
            }
            (*distanceField)[nextIndex] = currentDistance + 1;
            frontier.push({nextCol, nextRow});
        }
    }

    for (int row = 0; row < rows; ++row) {
        for (int col = 0; col < cols; ++col) {
            const size_t index = static_cast<size_t>(row * cols + col);
            if ((*distanceField)[index] >= 1000000 || (col == exitCol && row == exitRow)) {
                continue;
            }

            int bestCol = col;
            int bestRow = row;
            int bestDistance = (*distanceField)[index];
            for (size_t dirIndex = 0; dirIndex < dx.size(); ++dirIndex) {
                const int nextCol = col + dx[dirIndex];
                const int nextRow = row + dy[dirIndex];
                if (nextCol < 0 || nextRow < 0 || nextCol >= cols || nextRow >= rows) {
                    continue;
                }
                const size_t nextIndex = static_cast<size_t>(nextRow * cols + nextCol);
                if ((*distanceField)[nextIndex] < bestDistance) {
                    bestDistance = (*distanceField)[nextIndex];
                    bestCol = nextCol;
                    bestRow = nextRow;
                }
            }
            (*paths)[index] = directionToward(col, row, bestCol, bestRow);
        }
    }
}
}

NativeEngine &NativeEngine::instance() {
    static NativeEngine engine;
    return engine;
}

NativeEngine::~NativeEngine() {
    renderer_.shutdown();
}

void NativeEngine::onSurfaceCreated() {
    std::scoped_lock lock(mutex_);
    renderer_.initialize();
    if (grid_.empty()) {
        loadMapById(mapId_);
    }
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    lastFrameAt_ = std::chrono::steady_clock::now();
}

void NativeEngine::onSurfaceChanged(int width, int height) {
    std::scoped_lock lock(mutex_);
    surfaceWidth_ = width;
    surfaceHeight_ = height;
    glViewport(0, 0, width, height);
    updateBoardMetrics();
}

void NativeEngine::onDrawFrame() {
    std::scoped_lock lock(mutex_);
    if (surfaceWidth_ <= 0 || surfaceHeight_ <= 0) {
        return;
    }

    const auto now = std::chrono::steady_clock::now();
    double dtSeconds = std::chrono::duration<double>(now - lastFrameAt_).count();
    lastFrameAt_ = now;
    dtSeconds = std::clamp(dtSeconds, 0.0, 0.25);
    if (dtSeconds > 0.00001) {
        const float frameTimeMs = static_cast<float>(dtSeconds * 1000.0);
        lastFrameTimeMs_ = frameTimeMs;
        smoothedFrameTimeMs_ = (smoothedFrameTimeMs_ * 0.9f) + (frameTimeMs * 0.1f);
        lastFps_ = smoothedFrameTimeMs_ > 0.0001f
            ? (1000.0f / smoothedFrameTimeMs_)
            : 0.0f;
    }

    updatePlacementCountdown(dtSeconds);

    if (!paused_) {
        updateSimulation(dtSeconds);
    }

    const float pulse = static_cast<float>(0.5 + 0.5 * std::sin(simTimeSeconds_ * 1.25));
    (void)pulse;
    glClearColor(11.0f / 255.0f, 18.0f / 255.0f, 34.0f / 255.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    renderer_.beginFrame(surfaceWidth_, surfaceHeight_);
    renderBoard(pulse);
    renderer_.flush();
}

void NativeEngine::onPause() {
    std::scoped_lock lock(mutex_);
    lifecyclePaused_ = true;
    syncPausedState();
}

void NativeEngine::onResume() {
    std::scoped_lock lock(mutex_);
    lifecyclePaused_ = false;
    userPaused_ = true;
    syncPausedState();
    lastFrameAt_ = std::chrono::steady_clock::now();
    simAccumulatorSeconds_ = 0.0;
    renderAlpha_ = 0.0f;
    smoothedFrameTimeMs_ = std::max(1.0f, lastFrameTimeMs_);
}

void NativeEngine::syncPausedState() {
    paused_ = userPaused_ || lifecyclePaused_ || defeatPaused_ || placementPaused_;
    waveRuntime_.paused = paused_;
}

void NativeEngine::updatePlacementCountdown(double dtSeconds) {
    if (lifecyclePaused_ || health_ <= 0 || !buildMode_ || pendingPlacementExpiryTick_ < 0) {
        placementCountdownAccumulatorSeconds_ = 0.0;
        return;
    }

    placementCountdownAccumulatorSeconds_ = std::min(
        placementCountdownAccumulatorSeconds_ + dtSeconds,
        kFixedStepSeconds * static_cast<double>(kMaxSimulationStepsPerFrame)
    );

    while (placementCountdownAccumulatorSeconds_ >= kFixedStepSeconds && pendingPlacementExpiryTick_ >= 0) {
        placementCountdownAccumulatorSeconds_ -= kFixedStepSeconds;
        pendingPlacementExpiryTick_--;
        if (pendingPlacementExpiryTick_ <= 0) {
            pendingPlacementExpiryTick_ = -1;
            buildMode_ = false;
            pendingPlacementCol_ = -1;
            pendingPlacementRow_ = -1;
            placementMessage_.clear();
            placementPaused_ = false;
            selectedCol_ = -1;
            selectedRow_ = -1;
            syncPausedState();
            break;
        }
    }
}

void NativeEngine::startPlacementCountdown() {
    pendingPlacementExpiryTick_ = 7 * 60;
    placementCountdownAccumulatorSeconds_ = 0.0;
}

void NativeEngine::clearPlacementCountdown() {
    pendingPlacementExpiryTick_ = -1;
    placementCountdownAccumulatorSeconds_ = 0.0;
}

void NativeEngine::restartRunLocked() {
    const int baseHealth = config_.difficulty == 0 ? 55 : (config_.difficulty == 2 ? 30 : 40);
    int baseCash = config_.difficulty == 0 ? 75 : (config_.difficulty == 2 ? 45 : 55);
    if (isProceduralMapId(mapId_) && !mapId_.empty() && mapId_.back() == '3') {
        baseCash = 65;
    }
    simTimeSeconds_ = 0.0;
    simAccumulatorSeconds_ = 0.0;
    renderAlpha_ = 0.0f;
    tickCount_ = 0;
    runId_++;
    enemies_.clear();
    towers_.clear();
    projectiles_.clear();
    explosions_.clear();
    trailParticles_.clear();
    enemyDeathEffects_.clear();
    tempSpawns_.clear();
    pendingEnemyQueue_.clear();
    waveCooldownTicksRemaining_ = 0;
    waitingForNextWave_ = false;
    clearPlacementCountdown();
    health_ = baseHealth;
    maxHealth_ = health_;
    cash_ = baseCash;
    kills_ = 0;
    builtCount_ = 0;
    leakCount_ = 0;
    totalDamage_ = 0.0f;
    userPaused_ = true;
    lifecyclePaused_ = false;
    defeatPaused_ = false;
    placementPaused_ = false;
    syncPausedState();
    buildMode_ = false;
    placementMessage_.clear();
    hoveredCol_ = -1;
    hoveredRow_ = -1;
    selectedCol_ = -1;
    selectedRow_ = -1;
    pendingPlacementCol_ = -1;
    pendingPlacementRow_ = -1;
    resetWaveRuntime(waveRuntime_);
    waveRuntime_.waveNumber = 0;
    syncPausedState();
    queueNextWave();
}

void NativeEngine::onPointer(float xPx, float yPx, int phase) {
    std::scoped_lock lock(mutex_);
    pointerX_ = xPx;
    pointerY_ = yPx;
    pointerPhase_ = phase;
    if (boardPointToTile(xPx, yPx, &hoveredCol_, &hoveredRow_)) {
        const bool shouldHandleSelection =
            phase == 4 || (buildMode_ && (phase == 0 || phase == 1));
        if (shouldHandleSelection) {
            selectedCol_ = hoveredCol_;
            selectedRow_ = hoveredRow_;
            handleBoardSelection(selectedCol_, selectedRow_);
        }
    } else {
        hoveredCol_ = -1;
        hoveredRow_ = -1;
        if (buildMode_) {
            pendingPlacementCol_ = -1;
            pendingPlacementRow_ = -1;
            clearPlacementCountdown();
            placementPaused_ = false;
            placementMessage_ = "Choose a tile.";
            syncPausedState();
        }
        if (phase == 4) {
            selectedCol_ = -1;
            selectedRow_ = -1;
        }
    }
}

void NativeEngine::setActiveScreen(int screenId) {
    std::scoped_lock lock(mutex_);
    activeScreen_ = screenId;
}

bool NativeEngine::invokeAction(const std::string &actionId, const std::string &payload) {
    std::scoped_lock lock(mutex_);
    if (actionId == "togglePause") {
        if (health_ <= 0) {
            return false;
        }
        userPaused_ = !userPaused_;
        syncPausedState();
        return true;
    } else if (actionId == "restart") {
        if (isProceduralMapId(mapId_)) {
            loadMapById(mapId_);
            updateBoardMetrics();
        }
        restartRunLocked();
        return true;
    } else if (actionId == "toggleEffects") {
        config_.effects = !config_.effects;
        if (!config_.effects) {
            explosions_.clear();
            trailParticles_.clear();
            enemyDeathEffects_.clear();
        }
        return config_.effects;
    } else if (actionId == "toggleHealthBars") {
        config_.healthBars = !config_.healthBars;
        return config_.healthBars;
    } else if (actionId == "toggleMute") {
        config_.muted = !config_.muted;
        return config_.muted;
    } else if (actionId == "toggleAutoSend") {
        config_.autoSend = !config_.autoSend;
        return config_.autoSend;
    } else if (actionId == "toggleAdaptiveQuality") {
        config_.adaptiveQuality = !config_.adaptiveQuality;
        return config_.adaptiveQuality;
    } else if (actionId == "setShowFps") {
        config_.showFps = (payload == "true");
        return config_.showFps;
    } else if (actionId == "setGodMode") {
        config_.godMode = (payload == "true");
        return config_.godMode;
    } else if (actionId == "setFiringDisabled") {
        config_.firingDisabled = (payload == "true");
        return config_.firingDisabled;
    } else if (actionId == "setDifficulty") {
        if (!payload.empty()) {
            config_.difficulty = std::clamp(std::stoi(payload), 0, 2);
            restartRunLocked();
            return true;
        }
        return false;
    } else if (actionId == "setWaveMode") {
        if (!payload.empty()) {
            config_.waveMode = std::clamp(std::stoi(payload), 0, 2);
            restartRunLocked();
            return true;
        }
        return false;
    } else if (actionId == "setQuality") {
        if (!payload.empty()) {
            config_.quality = std::clamp(std::stoi(payload), 0, 2);
            return true;
        }
        return false;
    } else if (actionId == "importMap") {
        if (!payload.empty()) {
            loadMapById(payload);
            updateBoardMetrics();
            restartRunLocked();
            return true;
        }
        return false;
    } else if (actionId == "setActiveScreen") {
        if (!payload.empty()) {
            activeScreen_ = std::stoi(payload);
            return true;
        }
        return false;
    } else if (actionId == "setMap") {
        loadMapById(payload);
        updateBoardMetrics();
        restartRunLocked();
        return true;
    } else if (actionId == "selectTower") {
        buildMode_ = findTowerCatalogEntry(payload) != nullptr;
        if (buildMode_) {
            const TowerCatalogEntry *entry = findTowerCatalogEntry(payload);
            buildTowerKind_ = payload;
            placementMessage_ = "Choose a tile for " + std::string(entry->title) + ".";
            selectedCol_ = -1;
            selectedRow_ = -1;
            pendingPlacementCol_ = -1;
            pendingPlacementRow_ = -1;
            clearPlacementCountdown();
            if (hoveredCol_ >= 0 && hoveredRow_ >= 0 && entry != nullptr) {
                handleBoardSelection(hoveredCol_, hoveredRow_);
            }
        }
        return buildMode_;
    } else if (actionId == "confirmPlacement") {
        int col = pendingPlacementCol_;
        int row = pendingPlacementRow_;
        if (buildMode_ &&
            col < 0 &&
            row < 0 &&
            hoveredCol_ >= 0 &&
            hoveredRow_ >= 0 &&
            canPlace(hoveredCol_, hoveredRow_)) {
            col = hoveredCol_;
            row = hoveredRow_;
        }
        bool placementConfirmed = false;
        if (buildMode_ && col >= 0 && row >= 0) {
            const TowerCatalogEntry *entry = findTowerCatalogEntry(buildTowerKind_);
            if (entry != nullptr && canPlace(col, row)) {
                if (!config_.godMode && cash_ < entry->cost) {
                    placementMessage_ = "Not enough cash.";
                } else {
                    if (!config_.godMode) {
                        cash_ -= entry->cost;
                    }
                    towers_.push_back(createTowerInstance(buildTowerKind_, col, row));
                    buildMode_ = false;
                    selectedCol_ = col;
                    selectedRow_ = row;
                    builtCount_++;
                    placementMessage_.clear();
                    rebuildDynamicPaths();
                    placementConfirmed = true;
                }
            }
            pendingPlacementCol_ = -1;
            pendingPlacementRow_ = -1;
            placementPaused_ = false;
            clearPlacementCountdown();
            syncPausedState();
        }
        return placementConfirmed;
    } else if (actionId == "cancelPlacement") {
        const bool hadPendingPlacement = pendingPlacementCol_ >= 0 && pendingPlacementRow_ >= 0;
        buildMode_ = false;
        pendingPlacementCol_ = -1;
        pendingPlacementRow_ = -1;
        selectedCol_ = -1;
        selectedRow_ = -1;
        placementPaused_ = false;
        clearPlacementCountdown();
        placementMessage_.clear();
        syncPausedState();
        return hadPendingPlacement;
    } else if (actionId == "setTargetingMode") {
        if (selectedCol_ >= 0 && selectedRow_ >= 0 && isValidTargetingModeId(payload)) {
            for (TowerInstance &tower : towers_) {
                if (tower.alive && tower.col == selectedCol_ && tower.row == selectedRow_) {
                    tower.targetingMode = parseTargetingMode(payload);
                    return true;
                }
            }
        }
        return false;
    } else if (actionId == "upgradeTower") {
        if (selectedCol_ >= 0 && selectedRow_ >= 0) {
            for (TowerInstance &tower : towers_) {
                if (!tower.alive || tower.col != selectedCol_ || tower.row != selectedRow_) {
                    continue;
                }
                if (const TowerCatalogEntry *catalogEntry = findTowerCatalogEntry(tower.kindId)) {
                    const int upgradePrice = computeUpgradePrice(tower.kindId);
                    if (!config_.godMode && cash_ < upgradePrice) {
                        return false;
                    }
                    if (!config_.godMode) {
                        cash_ -= upgradePrice;
                    }
                    applyTowerUpgrade(tower);
                    return true;
                }
                return false;
            }
        }
        return false;
    } else if (actionId == "sellTower") {
        if (selectedCol_ >= 0 && selectedRow_ >= 0) {
            for (TowerInstance &tower : towers_) {
                if (!tower.alive || tower.col != selectedCol_ || tower.row != selectedRow_) {
                    continue;
                }
                cash_ += computeSellPrice(tower.investedCost);
                tower.alive = false;
                selectedCol_ = -1;
                selectedRow_ = -1;
                placementMessage_.clear();
                rebuildDynamicPaths();
                return true;
            }
        }
        return false;
    }
    return false;
}

void NativeEngine::setBoardViewport(int leftPx, int topPx, int widthPx, int heightPx, float density) {
    const int previousWidth = boardViewportWidthPx_;
    const int previousHeight = boardViewportHeightPx_;
    boardViewportLeftPx_ = std::max(0, leftPx);
    boardViewportTopPx_ = std::max(0, topPx);
    boardViewportWidthPx_ = std::max(0, widthPx);
    boardViewportHeightPx_ = std::max(0, heightPx);
    densityScale_ = std::max(1.0f, density);
    if ((previousWidth <= 0 || previousHeight <= 0) &&
        boardViewportWidthPx_ > 0 &&
        boardViewportHeightPx_ > 0 &&
        isProceduralMapId(mapId_)) {
        loadMapById(mapId_);
    }
    updateBoardMetrics();
}

void NativeEngine::handleBoardTap(float xPx, float yPx) {
    onPointer(xPx, yPx, 4);
}

void NativeEngine::handleBoardDrag(float xPx, float yPx, int phase) {
    onPointer(xPx, yPx, phase);
}

const NativeGameSnapshot &NativeEngine::snapshot() {
    std::scoped_lock lock(mutex_);
    const int builtCount = std::max(
        builtCount_,
        static_cast<int>(towers_.size())
    );
    snapshot_ = NativeGameSnapshot{};
    const TowerInstance *selectedTower = nullptr;
    if (selectedCol_ >= 0 && selectedRow_ >= 0) {
        for (const TowerInstance &tower : towers_) {
            if (tower.alive && tower.col == selectedCol_ && tower.row == selectedRow_) {
                selectedTower = &tower;
                break;
            }
        }
    }
    const bool selectedHasTower = selectedTower != nullptr;
    const bool hasSelection = selectedHasTower || buildMode_;
    int popupPlacementCol = pendingPlacementCol_;
    int popupPlacementRow = pendingPlacementRow_;
    const bool hasPendingPlacement =
        buildMode_ &&
        popupPlacementCol >= 0 &&
        popupPlacementRow >= 0;
    const std::string selectedKindString = selectedHasTower
        ? selectedTower->kind
        : (buildMode_ ? buildTowerKind_ : "gun");
    const TowerCatalogEntry *catalogEntry = findTowerCatalogEntry(selectedKindString);
    const std::string towerTitle = catalogEntry != nullptr ? std::string(catalogEntry->title) : "Gun Tower";
    const float damageMin = selectedHasTower
        ? selectedTower->damageMin
        : (catalogEntry != nullptr ? catalogEntry->damageMin : 4.0f);
    const float damageMax = selectedHasTower
        ? selectedTower->damageMax
        : (catalogEntry != nullptr ? catalogEntry->damageMax : 8.0f);
    const float range = selectedHasTower
        ? selectedTower->range
        : (catalogEntry != nullptr ? catalogEntry->range : 3.2f);
    const int rawCooldownTicks = selectedHasTower
        ? (selectedTower->cooldownMin + selectedTower->cooldownMax) / 2
        : (catalogEntry != nullptr ? (catalogEntry->cooldownMin + catalogEntry->cooldownMax) / 2 : 22);
    const int cooldownTicks = std::max(0, static_cast<int>(std::round(rawCooldownTicks * kTowerCooldownScale)));
    std::ostringstream damageBuilder;
    if (selectedKindString == "beamEmitter") {
        damageBuilder << static_cast<int>(std::ceil(damageMin)) << "-" << static_cast<int>(std::ceil(damageMax));
    } else {
        damageBuilder << static_cast<int>(damageMin) << "-" << static_cast<int>(damageMax);
    }
    const std::string damageText = damageBuilder.str();
    const double cooldownSeconds = static_cast<double>(cooldownTicks) / 60.0;
    const double averageDamage = selectedKindString == "beamEmitter"
        ? static_cast<double>(std::max(1.0f, (damageMin + damageMax) * 0.5f))
        : static_cast<double>((damageMin + damageMax) * 0.5f);
    const double dps = cooldownSeconds > 0.0 ? averageDamage / cooldownSeconds : averageDamage;
    const std::string effectText = catalogEntry != nullptr ? std::string(catalogEntry->effectText) : "Direct damage";
    const int cost = catalogEntry != nullptr ? catalogEntry->cost : 25;
    const int sellPrice = selectedHasTower
        ? computeSellPrice(selectedTower->investedCost)
        : 0;
    const TowerCatalogEntry *nextEntry = selectedHasTower && catalogEntry != nullptr
        ? nextTowerUpgrade(selectedTower->kind)
        : nullptr;
    const int upgradePrice = (selectedHasTower && nextEntry != nullptr)
        ? computeUpgradePrice(selectedTower->kind)
        : 0;
    std::string upgradeDelta = "No more upgrades";
    if (selectedHasTower && nextEntry != nullptr) {
        std::ostringstream delta;
        bool wrote = false;
        if (nextEntry->damageMin != selectedTower->damageMin ||
            nextEntry->damageMax != selectedTower->damageMax) {
            delta << "damage " << static_cast<int>(std::round(nextEntry->damageMin))
                  << "-" << static_cast<int>(std::round(nextEntry->damageMax));
            wrote = true;
        }
        if (nextEntry->range != selectedTower->range) {
            if (wrote) {
                delta << ", ";
            }
            delta << "range " << nextEntry->range;
            wrote = true;
        }
        if (nextEntry->cooldownMin != selectedTower->cooldownMin ||
            nextEntry->cooldownMax != selectedTower->cooldownMax) {
            if (wrote) {
                delta << ", ";
            }
            delta << "cooldown "
                  << (static_cast<double>(nextEntry->cooldownMin + nextEntry->cooldownMax) * 0.5 * kTowerCooldownScale / 60.0)
                  << "s";
            wrote = true;
        }
        upgradeDelta = wrote ? delta.str() : "Stat shift";
    }
    const std::string damageTypeLabel = catalogEntry != nullptr ? std::string(catalogEntry->damageTypeLabel) : "PHYSICAL";
    std::string placementReason = "No tower selected. Tap a placed tower or choose one from the dock.";
    bool placementAllowed = false;
    bool placementAffordable = false;
    bool showPlaceAction = false;
    int remainingPlacementTicks = -1;
    if (buildMode_) {
        if (hasPendingPlacement && catalogEntry != nullptr) {
            placementAllowed = canPlace(popupPlacementCol, popupPlacementRow);
            placementAffordable = config_.godMode || cash_ >= catalogEntry->cost;
            remainingPlacementTicks = std::max(0, pendingPlacementExpiryTick_);
            if (!placementAllowed) {
                placementReason = describePlacement(popupPlacementCol, popupPlacementRow);
            } else if (!placementAffordable) {
                placementReason = "Insufficient money";
            } else {
                placementReason = "Ready to place " + towerTitle;
            }
            showPlaceAction = placementAllowed && placementAffordable;
        } else if (!placementMessage_.empty()) {
            placementReason = placementMessage_;
        } else {
            placementReason = "Choose a tile.";
        }
    } else if (selectedHasTower) {
        placementReason.clear();
    }
    const bool defeatVisible = health_ <= 0;
    const std::string targetingLabel = selectedHasTower
        ? std::string(targetingModeLabel(selectedTower->targetingMode))
        : std::string(targetingModeLabel(TargetingMode::First));
    const std::string selectionStatus = selectedHasTower
        ? "Selected: " + towerTitle
        : (buildMode_ ? "Placing: " + towerTitle : "Selected: None");
    const unsigned int titleColor = catalogEntry != nullptr ? catalogEntry->displayColor : packColor(255, 255, 255);
    snapshot_.runId = runId_;
    snapshot_.tick = tickCount_;
    snapshot_.simTimeMs = static_cast<long long>(simTimeSeconds_ * 1000.0);
    snapshot_.activeScreen = activeScreen_;

    snapshot_.hud.health = health_;
    snapshot_.hud.maxHealth = maxHealth_;
    snapshot_.hud.cash = cash_;
    snapshot_.hud.wave = waveRuntime_.waveNumber;
    snapshot_.hud.kills = kills_;
    copyCString(snapshot_.hud.waveState, waveStateLabel(waveRuntime_));
    snapshot_.hud.paused = paused_ ? 1 : 0;

    snapshot_.perf.show = config_.showFps ? 1 : 0;
    snapshot_.perf.fps = static_cast<float>(static_cast<int>(lastFps_ + 0.5f));
    snapshot_.perf.frameTimeMs = smoothedFrameTimeMs_;
    snapshot_.perf.quality = config_.quality;

    snapshot_.defeatVisible = defeatVisible ? 1 : 0;
    if (defeatVisible) {
        copyCString(
            snapshot_.defeatSummary,
            "Reached wave " + std::to_string(waveRuntime_.waveNumber) +
                "\nTowers built: " + std::to_string(builtCount) +
                "\nKills: " + std::to_string(kills_) +
                "\nDamage dealt: " + std::to_string(static_cast<int>(std::round(totalDamage_))) +
                "\nLeaks: " + std::to_string(leakCount_)
        );
    }

    snapshot_.config.difficulty = config_.difficulty;
    snapshot_.config.waveMode = config_.waveMode;
    snapshot_.config.quality = config_.quality;
    snapshot_.config.effects = config_.effects ? 1 : 0;
    snapshot_.config.healthBars = config_.healthBars ? 1 : 0;
    snapshot_.config.muted = config_.muted ? 1 : 0;
    snapshot_.config.autoSend = config_.autoSend ? 1 : 0;
    snapshot_.config.adaptiveQuality = config_.adaptiveQuality ? 1 : 0;
    snapshot_.config.showFps = config_.showFps ? 1 : 0;
    snapshot_.config.godMode = config_.godMode ? 1 : 0;
    snapshot_.config.firingDisabled = config_.firingDisabled ? 1 : 0;
    snapshot_.config.zoom = config_.zoom;
    copyCString(snapshot_.config.mapId, mapId_);

    snapshot_.runStats.built = builtCount;
    snapshot_.runStats.kills = kills_;
    snapshot_.runStats.leaks = leakCount_;
    snapshot_.runStats.totalDamage = totalDamage_;

    snapshot_.selection.present = hasSelection ? 1 : 0;
    if (hasSelection) {
        snapshot_.selection.titleColor = titleColor;
        snapshot_.selection.cost = static_cast<float>(cost);
        snapshot_.selection.sellPrice = static_cast<float>(sellPrice);
        snapshot_.selection.hasUpgradePrice = (selectedHasTower && nextEntry != nullptr) ? 1 : 0;
        snapshot_.selection.upgradePrice = static_cast<float>(upgradePrice);
        snapshot_.selection.dps = static_cast<float>(dps);
        snapshot_.selection.range = range;
        snapshot_.selection.cooldownSeconds = static_cast<float>(cooldownSeconds);
        snapshot_.selection.canSell = selectedHasTower ? 1 : 0;
        snapshot_.selection.canUpgrade =
            (selectedHasTower && nextEntry != nullptr && (config_.godMode || cash_ >= upgradePrice)) ? 1 : 0;
        copyCString(snapshot_.selection.status, selectionStatus);
        copyCString(snapshot_.selection.title, towerTitle);
        copyCString(snapshot_.selection.upgradeDelta, upgradeDelta);
        copyCString(snapshot_.selection.damage, damageText);
        copyCString(snapshot_.selection.damageTypeLabel, damageTypeLabel);
        copyCString(
            snapshot_.selection.targeting,
            selectedHasTower
                ? targetingLabel
                : (catalogEntry != nullptr ? std::string(catalogEntry->targetingText) : targetingLabel)
        );
        copyCString(snapshot_.selection.effect, effectText);
        copyCString(snapshot_.selection.placementReason, placementReason);
    }

    snapshot_.pendingPlacement.present = hasPendingPlacement ? 1 : 0;
    if (hasPendingPlacement) {
        copyCString(
            snapshot_.pendingPlacement.id,
            std::to_string(popupPlacementCol) + "," + std::to_string(popupPlacementRow) + ":" + buildTowerKind_
        );
        copyCString(snapshot_.pendingPlacement.title, towerTitle);
        snapshot_.pendingPlacement.cost = static_cast<float>(cost);
        snapshot_.pendingPlacement.anchorX = tileCenterX(popupPlacementCol) / densityScale_;
        snapshot_.pendingPlacement.anchorY = tileCenterY(popupPlacementRow) / densityScale_;
        snapshot_.pendingPlacement.placementAllowed = placementAllowed ? 1 : 0;
        snapshot_.pendingPlacement.placementAffordable = placementAffordable ? 1 : 0;
        snapshot_.pendingPlacement.showPlaceAction = showPlaceAction ? 1 : 0;
        snapshot_.pendingPlacement.remainingTicks = std::max(0, remainingPlacementTicks);
        copyCString(snapshot_.pendingPlacement.statusText, placementReason);
    }

    copyCString(snapshot_.exportMap, mapId_);
    return snapshot_;
}

int NativeEngine::consumeAudioEvents(NativeAudioEvent *buffer, int maxEvents) {
    if (buffer == nullptr || maxEvents <= 0) {
        return 0;
    }
    std::scoped_lock lock(mutex_);
    const int available = static_cast<int>(std::min(audioQueueSize_, static_cast<size_t>(maxEvents)));
    for (int index = 0; index < available; ++index) {
        buffer[index] = audioQueue_[audioQueueReadIndex_];
        audioQueueReadIndex_ = (audioQueueReadIndex_ + 1) % kAudioQueueCapacity;
    }
    audioQueueSize_ -= static_cast<size_t>(available);
    return available;
}

void NativeEngine::queueAudioEvent(SoundType soundId, float volume) {
    if (soundId == SoundType::None) {
        return;
    }
    audioQueue_[audioQueueWriteIndex_] = NativeAudioEvent{
        static_cast<std::uint8_t>(soundId),
        volume,
    };
    audioQueueWriteIndex_ = (audioQueueWriteIndex_ + 1) % kAudioQueueCapacity;
    if (audioQueueSize_ == kAudioQueueCapacity) {
        audioQueueReadIndex_ = (audioQueueReadIndex_ + 1) % kAudioQueueCapacity;
    } else {
        audioQueueSize_++;
    }
}

void NativeEngine::updateSimulation(double dtSeconds) {
    simAccumulatorSeconds_ = std::min(
        simAccumulatorSeconds_ + dtSeconds,
        kFixedStepSeconds * static_cast<double>(kMaxSimulationStepsPerFrame)
    );

    int stepCount = 0;
    while (simAccumulatorSeconds_ >= kFixedStepSeconds && stepCount < kMaxSimulationStepsPerFrame) {
        simTimeSeconds_ += kFixedStepSeconds;
        tickCount_++;
        stepCount++;
        syncPausedState();
        waveRuntime_.defeated = health_ <= 0;
        if (health_ <= 0) {
            defeatPaused_ = true;
            syncPausedState();
            waitingForNextWave_ = false;
            waveCooldownTicksRemaining_ = 0;
            pendingEnemyQueue_.clear();
            waveRuntime_.waveActive = false;
            simAccumulatorSeconds_ = 0.0;
            renderAlpha_ = 0.0f;
            return;
        }
        if (health_ > 0) {
            if (waitingForNextWave_) {
                if (waveCooldownTicksRemaining_ > 0) {
                    waveCooldownTicksRemaining_--;
                }
                if (waveCooldownTicksRemaining_ <= 0 || (config_.autoSend && pendingEnemyQueue_.empty())) {
                    waitingForNextWave_ = false;
                    queueNextWave();
                }
            } else if (pendingEnemyQueue_.empty() && enemies_.empty()) {
                waitingForNextWave_ = true;
                waveCooldownTicksRemaining_ = config_.difficulty == 2 ? 90 : (config_.difficulty == 0 ? 150 : kDefaultWaveCooldown);
            }
        }
        updateEnemies();
        updateTowers();
        updateProjectiles();
        updateExplosions();
        updateTrailParticles();
        updateEnemyDeathEffects();
        waveRuntime_.waveActive = !pendingEnemyQueue_.empty() || !enemies_.empty();
        simAccumulatorSeconds_ -= kFixedStepSeconds;
    }

    renderAlpha_ = static_cast<float>(std::clamp(simAccumulatorSeconds_ / kFixedStepSeconds, 0.0, 1.0));
}

void NativeEngine::queueNextWave() {
    waveRuntime_.waveNumber += 1;
    waveRuntime_.nextSpawnIndex = 0;
    waveRuntime_.spawnTickCounter = 0;
    const int waveNumber = std::max(1, waveRuntime_.waveNumber);
    const WavePatternDef pattern = config_.waveMode == 0
        ? randomWavePattern(waveNumber, config_.difficulty)
        : choosePresetWave(waveNumber, config_.waveMode);
    waveRuntime_.spawnCooldownTicks = std::max(0, pattern.spawnCooldownTicks);
    pendingEnemyQueue_ = expandWavePattern(pattern);
}

void NativeEngine::updateBoardMetrics() {
    const int viewportWidth = boardViewportWidthPx_ > 0 ? boardViewportWidthPx_ : surfaceWidth_;
    const int viewportHeight = boardViewportHeightPx_ > 0 ? boardViewportHeightPx_ : surfaceHeight_;
    const int viewportLeft = boardViewportLeftPx_;
    const int viewportTop = boardViewportTopPx_;

    if (viewportWidth <= 0 || viewportHeight <= 0) {
        tileSize_ = 0.0f;
        return;
    }

    tileSize_ = std::min(
        static_cast<float>(viewportWidth) / static_cast<float>(boardCols_),
        static_cast<float>(viewportHeight) / static_cast<float>(boardRows_)
    );
    const float boardWidth = tileSize_ * static_cast<float>(boardCols_);
    const float boardHeight = tileSize_ * static_cast<float>(boardRows_);
    boardLeft_ = static_cast<float>(viewportLeft) + (static_cast<float>(viewportWidth) - boardWidth) * 0.5f;
    boardTop_ = static_cast<float>(viewportTop) + (static_cast<float>(viewportHeight) - boardHeight) * 0.5f;
}

void NativeEngine::renderBoard(float pulse) {
    (void)pulse;
    if (tileSize_ <= 0.0f) {
        return;
    }

    struct TowerVisual {
        RgbColor color;
        RgbColor secondary;
        RgbColor flash;
        float length;
        float radius;
        float width;
        bool baseOnTop;
        bool drawLine;
        bool hasBase;
    };

    const auto towerVisual = [](TowerKindId kind) -> TowerVisual {
        if (kind == TowerKindId::BeamEmitter) {
            return TowerVisual{{107, 155, 149}, {156, 160, 154}, {156, 220, 214}, 0.65f, 0.9f, 0.35f, true, true, true};
        }
        if (kind == TowerKindId::Laser) {
            return TowerVisual{{83, 120, 117}, {128, 136, 126}, {156, 220, 214}, 0.55f, 0.8f, 0.25f, true, true, true};
        }
        if (kind == TowerKindId::Poison) {
            return TowerVisual{{114, 128, 86}, {135, 145, 132}, {255, 214, 170}, 1.1f, 0.9f, 0.3f, false, false, true};
        }
        if (kind == TowerKindId::Slow || kind == TowerKindId::Poison) {
            return TowerVisual{{98, 110, 96}, {135, 145, 132}, {255, 214, 170}, 1.1f, 0.9f, 0.3f, false, false, true};
        }
        if (kind == TowerKindId::Railgun) {
            return TowerVisual{{85, 90, 102}, {118, 126, 140}, {255, 224, 184}, 0.7f, 1.0f, 0.4f, false, true, true};
        }
        if (kind == TowerKindId::Sniper || kind == TowerKindId::Railgun) {
            return TowerVisual{{108, 102, 90}, {148, 142, 128}, {255, 224, 184}, 0.7f, 0.9f, 0.3f, false, true, false};
        }
        if (kind == TowerKindId::MissileSilo) {
            return TowerVisual{{112, 126, 138}, {98, 108, 115}, {255, 214, 170}, 0.6f, 0.75f, 0.2f, false, false, true};
        }
        if (kind == TowerKindId::Rocket || kind == TowerKindId::MissileSilo) {
            return TowerVisual{{94, 114, 82}, {130, 136, 126}, {255, 214, 170}, 0.6f, 0.75f, 0.2f, false, false, true};
        }
        if (kind == TowerKindId::ClusterBomb) {
            return TowerVisual{{103, 97, 82}, {119, 124, 115}, {255, 214, 170}, 0.6f, 1.1f, 0.35f, false, false, true};
        }
        if (kind == TowerKindId::Bomb || kind == TowerKindId::ClusterBomb) {
            return TowerVisual{{103, 97, 82}, {119, 124, 115}, {255, 214, 170}, 0.6f, 1.0f, 0.35f, false, false, true};
        }
        if (kind == TowerKindId::Plasma) {
            return TowerVisual{{142, 198, 214}, {78, 102, 112}, {156, 220, 214}, 0.5f, 1.1f, 0.28f, false, true, false};
        }
        if (kind == TowerKindId::Tesla || kind == TowerKindId::Plasma) {
            return TowerVisual{{168, 188, 198}, {88, 108, 118}, {156, 220, 214}, 0.5f, 1.0f, 0.28f, false, true, false};
        }
        if (kind == TowerKindId::MachineGun) {
            return TowerVisual{{126, 118, 86}, {128, 136, 126}, {255, 191, 128}, 0.65f, 0.9f, 0.3f, true, true, true};
        }
        return TowerVisual{{96, 112, 86}, {128, 136, 126}, {255, 212, 146}, 0.65f, 0.9f, 0.3f, true, true, true};
    };

    const auto tileCenter = [this](int col, int row) -> Point2D {
        return Point2D{
            boardLeft_ + (static_cast<float>(col) + 0.5f) * tileSize_,
            boardTop_ + (static_cast<float>(row) + 0.5f) * tileSize_,
        };
    };

    const auto drawObjectiveMarker = [this, &tileCenter](int col, int row, RgbColor primary, RgbColor secondary) {
        const Point2D c = tileCenter(col, row);
        drawShadow(renderer_, c.x, c.y + tileSize_ * 0.22f, tileSize_ * 0.8f, tileSize_ * 0.28f, 60);
        renderer_.drawRect(
            static_cast<float>(col) * tileSize_ + boardLeft_ + tileSize_ * 0.14f,
            static_cast<float>(row) * tileSize_ + boardTop_ + tileSize_ * 0.14f,
            tileSize_ * 0.72f,
            tileSize_ * 0.72f,
            rgba(primary.r, primary.g, primary.b, 210)
        );
        renderer_.drawRect(
            static_cast<float>(col) * tileSize_ + boardLeft_ + tileSize_ * 0.28f,
            static_cast<float>(row) * tileSize_ + boardTop_ + tileSize_ * 0.28f,
            tileSize_ * 0.44f,
            tileSize_ * 0.44f,
            rgba(secondary.r, secondary.g, secondary.b, 225)
        );
    };

    const auto drawBaseTile = [this](int col, int row) {
        const float left = boardLeft_ + static_cast<float>(col) * tileSize_;
        const float top = boardTop_ + static_cast<float>(row) * tileSize_;
        renderer_.drawRect(left, top, tileSize_, tileSize_, rgba(4, 7, 10));
    };

    const auto drawWallLikeTile = [this](int col, int row) {
        const float left = boardLeft_ + static_cast<float>(col) * tileSize_;
        const float top = boardTop_ + static_cast<float>(row) * tileSize_;
        renderer_.drawRect(left, top, tileSize_, tileSize_, rgba(8, 71, 92));
        renderer_.drawRect(
            left + tileSize_ * 0.08f,
            top + tileSize_ * 0.08f,
            tileSize_ * 0.84f,
            tileSize_ * 0.84f,
            rgba(13, 93, 118)
        );
    };

    const auto drawRoadTile = [this, &drawBaseTile](int col, int row, int dir) {
        drawBaseTile(col, row);
        if (dir == 0) {
            return;
        }
        const Point2D c = {
            boardLeft_ + (static_cast<float>(col) + 0.5f) * tileSize_,
            boardTop_ + (static_cast<float>(row) + 0.5f) * tileSize_,
        };
        const float angle = ((dir - 1) % 2 == 0) ? 0.0f : 1.57079632679f;
        drawOrientedRect(renderer_, c.x, c.y, angle, -tileSize_ * 0.18f, -tileSize_ * 0.04f, tileSize_ * 0.36f, tileSize_ * 0.08f, rgba(184, 203, 231));
    };

    const auto drawTowerBase = [this](float centerX, float centerY, const TowerVisual &style, int alpha) {
        const float size = style.radius * tileSize_;
        renderer_.drawRect(centerX - size * 0.5f, centerY - size * 0.5f, size, size, rgba(0, 0, 0, 180 * alpha / 255));
        renderer_.drawRect(centerX - size * 0.46f, centerY - size * 0.46f, size * 0.92f, size * 0.92f, rgba(style.color.r, style.color.g, style.color.b, alpha));
        renderer_.drawRect(centerX - tileSize_ * 0.08f, centerY - tileSize_ * 0.1f, size * 0.4f, size * 0.28f, rgba(255, 255, 255, std::min(alpha, 35)));
    };

    const auto drawGenericTower = [this, &drawTowerBase, &towerVisual](const TowerInstance &tower, int alpha) {
        const TowerVisual style = towerVisual(tower.kindId);
        const float cx = tileCenterX(tower.col);
        const float cy = tileCenterY(tower.row);
        drawShadow(renderer_, cx, cy + tileSize_ * 0.18f, style.radius * tileSize_ * 0.95f, style.radius * tileSize_ * 0.45f, 70 * alpha / 255);
        if (style.hasBase && !style.baseOnTop) {
            drawTowerBase(cx, cy, style, alpha);
        }

        const float angle = tower.angle;
        if (tower.kindId == TowerKindId::Slow || tower.kindId == TowerKindId::Poison) {
            drawOrientedRect(renderer_, cx, cy, angle, -style.length * tileSize_ * 0.5f, -style.width * tileSize_ * 0.5f, style.length * tileSize_, style.width * tileSize_, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedRect(renderer_, cx, cy, angle, -style.length * tileSize_ * 0.5f + tileSize_ * 0.02f, -style.width * tileSize_ * 0.5f + tileSize_ * 0.02f, style.length * tileSize_ - tileSize_ * 0.04f, style.width * tileSize_ - tileSize_ * 0.04f, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            drawOrientedRect(renderer_, cx, cy, angle, -style.length * tileSize_ * 0.36f, -tileSize_ * 0.06f, tileSize_ * 0.12f, tileSize_ * 0.12f, rgba(86, 95, 84, alpha));
            drawOrientedRect(renderer_, cx, cy, angle, -style.length * tileSize_ * 0.06f, -tileSize_ * 0.06f, tileSize_ * 0.12f, tileSize_ * 0.12f, rgba(86, 95, 84, alpha));
            drawOrientedRect(renderer_, cx, cy, angle, style.length * tileSize_ * 0.24f, -tileSize_ * 0.06f, tileSize_ * 0.12f, tileSize_ * 0.12f, rgba(86, 95, 84, alpha));
        } else if (tower.kindId == TowerKindId::Rocket) {
            drawOrientedRect(renderer_, cx, cy, angle, 0.0f, -style.width * tileSize_, style.length * tileSize_, style.width * tileSize_, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedRect(renderer_, cx, cy, angle, 0.0f, 0.0f, style.length * tileSize_, style.width * tileSize_, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedRect(renderer_, cx, cy, angle, tileSize_ * 0.02f, -style.width * tileSize_ + tileSize_ * 0.02f, style.length * tileSize_ - tileSize_ * 0.04f, style.width * tileSize_ - tileSize_ * 0.04f, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            drawOrientedRect(renderer_, cx, cy, angle, tileSize_ * 0.02f, tileSize_ * 0.02f, style.length * tileSize_ - tileSize_ * 0.04f, style.width * tileSize_ - tileSize_ * 0.04f, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            drawOrientedTriangle(renderer_, cx, cy, angle, {style.length * tileSize_, -style.width * tileSize_}, {style.length * tileSize_ + style.width * tileSize_ * 2.0f, -style.width * tileSize_ * 0.5f}, {style.length * tileSize_, 0.0f}, rgba(181, 82, 64, alpha));
            drawOrientedTriangle(renderer_, cx, cy, angle, {style.length * tileSize_, style.width * tileSize_}, {style.length * tileSize_ + style.width * tileSize_ * 2.0f, style.width * tileSize_ * 0.5f}, {style.length * tileSize_, 0.0f}, rgba(181, 82, 64, alpha));
            drawOrientedQuad(
                renderer_, cx, cy, angle,
                {-style.width * tileSize_ * 0.75f, -style.width * tileSize_ * 4.0f},
                {-style.width * tileSize_ * 0.75f, style.width * tileSize_ * 4.0f},
                {style.width * tileSize_ * 1.25f, style.width * tileSize_ * 1.5f},
                {style.width * tileSize_ * 1.25f, -style.width * tileSize_ * 1.5f},
                rgba(style.color.r, style.color.g, style.color.b, alpha)
            );
        } else if (tower.kindId == TowerKindId::MissileSilo) {
            drawOrientedRect(renderer_, cx, cy, angle, 0.0f, -style.width * tileSize_, style.length * tileSize_, style.width * tileSize_, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedRect(renderer_, cx, cy, angle, 0.0f, 0.0f, style.length * tileSize_, style.width * tileSize_, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedRect(renderer_, cx, cy, angle, tileSize_ * 0.02f, -style.width * tileSize_ + tileSize_ * 0.02f, style.length * tileSize_ - tileSize_ * 0.04f, style.width * tileSize_ - tileSize_ * 0.04f, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            drawOrientedRect(renderer_, cx, cy, angle, tileSize_ * 0.02f, tileSize_ * 0.02f, style.length * tileSize_ - tileSize_ * 0.04f, style.width * tileSize_ - tileSize_ * 0.04f, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            drawOrientedTriangle(renderer_, cx, cy, angle, {style.length * tileSize_, -style.width * tileSize_}, {style.length * tileSize_ + style.width * tileSize_ * 2.0f, -style.width * tileSize_ * 0.5f}, {style.length * tileSize_, 0.0f}, rgba(style.color.r, style.color.g, style.color.b, alpha));
            drawOrientedTriangle(renderer_, cx, cy, angle, {style.length * tileSize_, style.width * tileSize_}, {style.length * tileSize_ + style.width * tileSize_ * 2.0f, style.width * tileSize_ * 0.5f}, {style.length * tileSize_, 0.0f}, rgba(style.color.r, style.color.g, style.color.b, alpha));
            drawOrientedQuad(
                renderer_, cx, cy, angle,
                {-style.width * tileSize_ * 0.75f, -style.width * tileSize_ * 4.0f},
                {-style.width * tileSize_ * 0.75f, style.width * tileSize_ * 4.0f},
                {style.width * tileSize_ * 1.25f, style.width * tileSize_ * 1.5f},
                {style.width * tileSize_ * 1.25f, -style.width * tileSize_ * 1.5f},
                rgba(74, 88, 104, alpha)
            );
        } else if (tower.kindId == TowerKindId::Sniper) {
            const float height = style.radius * tileSize_ * 0.8660254f;
            const float back = -height / 3.0f;
            const float front = height * 2.0f / 3.0f;
            const float side = style.radius * tileSize_ * 0.5f;
            drawOrientedTriangle(renderer_, cx, cy, angle, {back, -side}, {back, side}, {front, 0.0f}, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedTriangle(renderer_, cx, cy, angle, {back + tileSize_ * 0.02f, -side + tileSize_ * 0.02f}, {back + tileSize_ * 0.02f, side - tileSize_ * 0.02f}, {front - tileSize_ * 0.02f, 0.0f}, rgba(style.color.r, style.color.g, style.color.b, alpha));
            drawOrientedRect(renderer_, cx, cy, angle, back - tileSize_ * 0.18f, -tileSize_ * 0.08f, tileSize_ * 0.22f, tileSize_ * 0.16f, rgba(148, 142, 128, alpha));
        } else if (tower.kindId == TowerKindId::Railgun) {
            const float base = -style.length * tileSize_;
            const float side = -style.width * tileSize_ * 0.5f;
            drawOrientedRect(renderer_, cx, cy, angle, base, side, style.length * tileSize_ * 2.0f, style.width * tileSize_, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedRect(renderer_, cx, cy, angle, base + tileSize_ * 0.02f, side + tileSize_ * 0.02f, style.length * tileSize_ * 2.0f - tileSize_ * 0.04f, style.width * tileSize_ - tileSize_ * 0.04f, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            drawOrientedRect(renderer_, cx, cy, angle, -style.radius * tileSize_ * 0.25f, -style.radius * tileSize_ * 0.25f, style.radius * tileSize_ * 0.5f, style.radius * tileSize_ * 0.5f, rgba(179, 70, 58, alpha));
        } else if (tower.kindId == TowerKindId::Bomb || tower.kindId == TowerKindId::ClusterBomb) {
            drawOrientedRect(renderer_, cx, cy, angle, 0.0f, -style.width * tileSize_ * 0.5f, style.length * tileSize_, style.width * tileSize_, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedRect(renderer_, cx, cy, angle, tileSize_ * 0.02f, -style.width * tileSize_ * 0.5f + tileSize_ * 0.02f, style.length * tileSize_ - tileSize_ * 0.04f, style.width * tileSize_ - tileSize_ * 0.04f, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            const int accent = tower.kindId == TowerKindId::ClusterBomb ? 202 : 171;
            drawOrientedRect(renderer_, cx, cy, angle, -style.radius * tileSize_ * 0.25f, -style.radius * tileSize_ * 0.25f, style.radius * tileSize_ * 0.5f, style.radius * tileSize_ * 0.5f, rgba(accent, 138, 76, alpha));
        } else if (tower.kindId == TowerKindId::Tesla || tower.kindId == TowerKindId::Plasma) {
            drawRegularPolygon(renderer_, cx, cy, style.radius * tileSize_ * 0.25f, 6, angle, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            const float core = (tower.kindId == TowerKindId::Plasma ? 0.6f : 0.55f) * tileSize_;
            renderer_.drawRect(cx - core * 0.5f, cy - core * 0.5f, core, core, rgba(style.color.r, style.color.g, style.color.b, alpha));
        } else {
            const float recoil = tower.recoil * tileSize_ * 0.16f;
            drawOrientedRect(renderer_, cx, cy, angle, -recoil, -style.width * tileSize_ * 0.5f, style.length * tileSize_, style.width * tileSize_, rgba(0, 0, 0, 180 * alpha / 255));
            drawOrientedRect(renderer_, cx, cy, angle, -recoil + tileSize_ * 0.02f, -style.width * tileSize_ * 0.5f + tileSize_ * 0.02f, style.length * tileSize_ - tileSize_ * 0.04f, style.width * tileSize_ - tileSize_ * 0.04f, rgba(style.secondary.r, style.secondary.g, style.secondary.b, alpha));
            drawOrientedRect(renderer_, cx, cy, angle, -recoil + style.length * tileSize_ * 0.55f, -style.width * tileSize_ * 0.35f, style.length * tileSize_ * 0.3f, style.width * tileSize_ * 0.7f, rgba(92, 98, 93, alpha * 180 / 255));
            if (tower.flash > 0.02f) {
                const float spread = style.width * tileSize_ * (1.2f + tower.flash);
                const float len = style.length * tileSize_ + tower.flash * tileSize_ * 0.55f;
                drawOrientedTriangle(renderer_, cx, cy, angle, {len, 0.0f}, {len - spread * 1.2f, -spread * 0.7f}, {len - spread * 1.2f, spread * 0.7f}, rgba(style.flash.r, style.flash.g, style.flash.b, static_cast<int>(180.0f * tower.flash) * alpha / 255));
                drawOrientedRect(renderer_, cx, cy, angle, len - spread * 0.35f - spread * 0.36f, -spread * 0.24f, spread * 0.72f, spread * 0.48f, rgba(255, 245, 220, static_cast<int>(130.0f * tower.flash) * alpha / 255));
            }
        }

        if (style.hasBase && style.baseOnTop) {
            drawTowerBase(cx, cy, style, alpha);
        }
    };

    const float boardWidth = tileSize_ * static_cast<float>(boardCols_);
    const float boardHeight = tileSize_ * static_cast<float>(boardRows_);
    renderer_.drawRect(boardLeft_, boardTop_, boardWidth, boardHeight, rgba(0, 0, 0));

    for (int x = 0; x < boardCols_; ++x) {
        for (int y = 0; y < boardRows_; ++y) {
            const int tile = tileAt(x, y);
            if (tile == 1) {
                drawWallLikeTile(x, y);
            } else if (tile == 3) {
                drawWallLikeTile(x, y);
            } else if (tile == 2 || tile == 4) {
                drawRoadTile(x, y, pathAt(x, y));
            } else {
                drawBaseTile(x, y);
            }
        }
    }

    for (size_t index = 0; index + 1 < spawnPoints_.size(); index += 2) {
        drawObjectiveMarker(spawnPoints_[index], spawnPoints_[index + 1], {84, 142, 84}, {178, 208, 122});
    }
    drawObjectiveMarker(exitCol_, exitRow_, {144, 70, 58}, {232, 173, 120});

    for (int i = 0; i <= boardCols_; ++i) {
        const float x = boardLeft_ + static_cast<float>(i) * tileSize_;
        renderer_.drawLine(x, boardTop_, x, boardTop_ + boardHeight, 1.0f, rgba(224, 232, 241, 78));
    }
    for (int j = 0; j <= boardRows_; ++j) {
        const float y = boardTop_ + static_cast<float>(j) * tileSize_;
        renderer_.drawLine(boardLeft_, y, boardLeft_ + boardWidth, y, 1.0f, rgba(224, 232, 241, 78));
    }

    for (const EnemyInstance &enemy : enemies_) {
        if (!enemy.alive) {
            continue;
        }
        const float enemyX = enemy.prevX + (enemy.x - enemy.prevX) * renderAlpha_;
        const float enemyY = enemy.prevY + (enemy.y - enemy.prevY) * renderAlpha_;

        const EnemyPalette palette = enemyPaletteFor(enemy.archetype, enemy.slowTicks > 0);
        const RgbColor primary = palette.primary;
        const RgbColor secondary = palette.secondary;
        const float angle = std::atan2(enemy.vy, enemy.vx);

        if (enemy.archetype == EnemyArchetypeId::Fast ||
            enemy.archetype == EnemyArchetypeId::StrongFast ||
            enemy.archetype == EnemyArchetypeId::Faster) {
            const int baseAlpha = 255;
            const unsigned int primaryColor = rgba(primary.r, primary.g, primary.b, baseAlpha);
            const unsigned int secondaryColor = rgba(secondary.r, secondary.g, secondary.b, baseAlpha);
            const float scale = enemy.archetype == EnemyArchetypeId::StrongFast ? 0.8f : (enemy.archetype == EnemyArchetypeId::Faster ? 0.7f : 0.55f);
            const float back = -scale * tileSize_ / 3.0f;
            const float front = back + scale * tileSize_;
            const float side = (enemy.archetype == EnemyArchetypeId::StrongFast ? 1.0f : (enemy.archetype == EnemyArchetypeId::Faster ? 0.9f : 0.8f)) * tileSize_ * 0.5f;
            drawOrientedQuad(renderer_, enemyX, enemyY, angle, {back, -side}, {0.0f, 0.0f}, {back, side}, {front, 0.0f}, rgba(0, 0, 0, 180));
            drawOrientedQuad(renderer_, enemyX, enemyY, angle, {back + tileSize_ * 0.02f, -side + tileSize_ * 0.02f}, {tileSize_ * 0.02f, 0.0f}, {back + tileSize_ * 0.02f, side - tileSize_ * 0.02f}, {front - tileSize_ * 0.02f, 0.0f}, primaryColor);
            if (enemy.archetype == EnemyArchetypeId::Faster) {
                drawOrientedTriangle(renderer_, enemyX, enemyY, angle, {back + tileSize_ * 0.06f, -tileSize_ * 0.14f}, {front - tileSize_ * 0.08f, 0.0f}, {back + tileSize_ * 0.06f, tileSize_ * 0.14f}, secondaryColor);
            } else {
                drawOrientedRect(renderer_, enemyX, enemyY, angle, back + tileSize_ * 0.08f, -(enemy.archetype == EnemyArchetypeId::StrongFast ? tileSize_ * 0.1f : tileSize_ * 0.08f), enemy.archetype == EnemyArchetypeId::StrongFast ? tileSize_ * 0.22f : tileSize_ * 0.18f, enemy.archetype == EnemyArchetypeId::StrongFast ? tileSize_ * 0.2f : tileSize_ * 0.16f, secondaryColor);
            }
        } else {
            drawShadow(renderer_, enemyX, enemyY + tileSize_ * 0.18f, enemy.radius * tileSize_ * 0.9f, enemy.radius * tileSize_ * 0.38f, 65);
            const float size = enemy.radius * tileSize_;
            const int baseAlpha = 255;
            const unsigned int primaryColor = rgba(primary.r, primary.g, primary.b, baseAlpha);
            const unsigned int secondaryColor = rgba(secondary.r, secondary.g, secondary.b, baseAlpha);
            if (enemy.archetype == EnemyArchetypeId::Tank) {
                const float front = enemy.radius * tileSize_ * 0.5f;
                const float side = 0.35f * tileSize_;
                const float barrel = 0.075f * tileSize_;
                const float length = 0.7f * tileSize_;
                renderer_.drawRect(enemyX - front, enemyY - side, front * 2.0f, side * 2.0f, rgba(0, 0, 0, 180));
                renderer_.drawRect(enemyX - front + tileSize_ * 0.02f, enemyY - side + tileSize_ * 0.02f, front * 2.0f - tileSize_ * 0.04f, side * 2.0f - tileSize_ * 0.04f, primaryColor);
                renderer_.drawRect(enemyX, enemyY - barrel, length, barrel * 2.0f, secondaryColor);
                renderer_.drawCircle(enemyX, enemyY, 0.2f * tileSize_, secondaryColor, 18);
                renderer_.drawRect(enemyX - front + tileSize_ * 0.08f, enemyY - side + tileSize_ * 0.06f, tileSize_ * 0.32f, tileSize_ * 0.14f, rgba(255, 255, 255, 22));
            } else if (enemy.archetype == EnemyArchetypeId::Taunt) {
                const float edge = enemy.radius * tileSize_ * 0.5f;
                renderer_.drawRect(enemyX - edge, enemyY - edge, enemy.radius * tileSize_, enemy.radius * tileSize_, rgba(0, 0, 0, 180));
                renderer_.drawRect(enemyX - edge + tileSize_ * 0.02f, enemyY - edge + tileSize_ * 0.02f, enemy.radius * tileSize_ - tileSize_ * 0.04f, enemy.radius * tileSize_ - tileSize_ * 0.04f, primaryColor);
                drawAxisAlignedRectOutline(renderer_, enemyX - 0.3f * tileSize_, enemyY - 0.3f * tileSize_, 0.6f * tileSize_, 0.6f * tileSize_, 1.0f, secondaryColor);
                drawAxisAlignedRectOutline(renderer_, enemyX - 0.2f * tileSize_, enemyY - 0.2f * tileSize_, 0.4f * tileSize_, 0.4f * tileSize_, 1.0f, secondaryColor);
            } else {
                renderer_.drawRect(enemyX - size * 0.5f, enemyY - size * 0.5f, size, size, rgba(28, 26, 22));
                renderer_.drawRect(enemyX - size * 0.46f, enemyY - size * 0.46f, size * 0.92f, size * 0.92f, primaryColor);
                renderer_.drawRect(enemyX - tileSize_ * 0.06f, enemyY - tileSize_ * 0.08f, enemy.radius * tileSize_ * 0.32f, enemy.radius * tileSize_ * 0.18f, rgba(255, 255, 255, 34 + static_cast<int>(enemy.hitFlash * 100.0f)));
            }
        }

        if (config_.healthBars && enemy.health < enemy.maxHealth) {
            const float edge = 0.7f * tileSize_ * 0.5f;
            const float percent = std::clamp(enemy.health / std::max(enemy.maxHealth, 0.001f), 0.0f, 1.0f);
            const float top = 0.2f * tileSize_;
            const float height = 0.15f * tileSize_;
            renderer_.drawRect(enemyX - edge, enemyY + top, edge * 2.0f, height, rgba(255, 255, 255, 180));
            renderer_.drawRect(enemyX - edge + tileSize_ * 0.02f, enemyY + top + tileSize_ * 0.02f, std::max(0.0f, (edge * 2.0f - tileSize_ * 0.04f) * percent), std::max(0.0f, height - tileSize_ * 0.04f), rgba(207, 0, 15));
        }
    }

    if (config_.effects) {
        for (const EnemyDeathEffect &effect : enemyDeathEffects_) {
            if (!effect.alive || effect.duration <= 0.0f) {
                continue;
            }
            const float progress = std::clamp(effect.age / effect.duration, 0.0f, 1.0f);
            const float fade = 1.0f - progress;
            const float size = effect.size * (0.88f + progress * 0.16f);
            const float half = size * 0.5f;
            const float shutterDepth = std::max(tileSize_ * 0.08f, size * 0.22f * fade);
            const float shutterTravel = size * 0.16f * progress;
            const int frameAlpha = static_cast<int>(170.0f * fade);
            const int panelAlpha = static_cast<int>(220.0f * fade);
            const int glowAlpha = static_cast<int>(90.0f * fade);
            renderer_.drawRect(
                effect.x - half - tileSize_ * 0.02f,
                effect.y - half - tileSize_ * 0.02f,
                size + tileSize_ * 0.04f,
                size + tileSize_ * 0.04f,
                rgba(18, 18, 18, frameAlpha)
            );
            renderer_.drawRect(
                effect.x - half + tileSize_ * 0.02f,
                effect.y - half + tileSize_ * 0.02f,
                size - tileSize_ * 0.04f,
                size - tileSize_ * 0.04f,
                rgba(effect.primaryR, effect.primaryG, effect.primaryB, glowAlpha)
            );
            renderer_.drawRect(
                effect.x - half,
                effect.y - half - shutterTravel,
                size,
                shutterDepth,
                rgba(effect.secondaryR, effect.secondaryG, effect.secondaryB, panelAlpha)
            );
            renderer_.drawRect(
                effect.x - half,
                effect.y + half - shutterDepth + shutterTravel,
                size,
                shutterDepth,
                rgba(effect.secondaryR, effect.secondaryG, effect.secondaryB, panelAlpha)
            );
            renderer_.drawRect(
                effect.x - half - shutterTravel,
                effect.y - half,
                shutterDepth,
                size,
                rgba(effect.primaryR, effect.primaryG, effect.primaryB, panelAlpha)
            );
            renderer_.drawRect(
                effect.x + half - shutterDepth + shutterTravel,
                effect.y - half,
                shutterDepth,
                size,
                rgba(effect.primaryR, effect.primaryG, effect.primaryB, panelAlpha)
            );
        }
    }

    for (const TowerInstance &tower : towers_) {
        if (!tower.alive) {
            continue;
        }
        const TowerVisual style = towerVisual(tower.kindId);
        const float cx = tileCenterX(tower.col);
        const float cy = tileCenterY(tower.row);
        if (style.drawLine && tower.flash > 0.02f) {
            const bool laserFamily = tower.kindId == TowerKindId::Laser || tower.kindId == TowerKindId::BeamEmitter;
            const bool teslaFamily = tower.kindId == TowerKindId::Tesla || tower.kindId == TowerKindId::Plasma;
            const int lineAlpha = laserFamily ? 255 : 220;
            const float lineWeight = tower.kindId == TowerKindId::BeamEmitter ? 3.0f : (tower.kindId == TowerKindId::Railgun ? 4.0f : (teslaFamily ? 7.0f : 2.0f));
            if (teslaFamily) {
                const float midX = (cx + tower.beamTargetX) * 0.5f + tileSize_ * 0.12f;
                const float midY = (cy + tower.beamTargetY) * 0.5f - tileSize_ * 0.12f;
                renderer_.drawLine(cx, cy, midX, midY, lineWeight, rgba(style.color.r, style.color.g, style.color.b, lineAlpha));
                renderer_.drawLine(midX, midY, tower.beamTargetX, tower.beamTargetY, std::max(1.0f, lineWeight - 1.0f), rgba(style.color.r, style.color.g, style.color.b, lineAlpha));
            } else {
                renderer_.drawLine(cx, cy, tower.beamTargetX, tower.beamTargetY, lineWeight, rgba(style.color.r, style.color.g, style.color.b, lineAlpha));
            }
        }
        if ((tower.kindId == TowerKindId::Slow || tower.kindId == TowerKindId::Poison) && tower.flash > 0.02f) {
            const float r = (tower.range * 2.0f + 1.0f) * tileSize_;
            renderer_.drawRect(cx - r * 0.5f, cy - r * 0.5f, r, r, rgba(style.color.r, style.color.g, style.color.b, 70));
        }
        drawGenericTower(tower, 255);
    }

    for (const ProjectileInstance &projectile : projectiles_) {
        if (!projectile.alive) {
            continue;
        }
        const float projectileX = projectile.prevX + (projectile.x - projectile.prevX) * renderAlpha_;
        const float projectileY = projectile.prevY + (projectile.y - projectile.prevY) * renderAlpha_;
        float angle = std::atan2(projectile.vy, projectile.vx);
        if (std::abs(projectile.vx) < 0.0001f && std::abs(projectile.vy) < 0.0001f) {
            const int targetIndex = findEnemyIndexById(projectile.targetEnemyId);
            if (targetIndex >= 0) {
                const EnemyInstance &targetEnemy = enemies_[static_cast<size_t>(targetIndex)];
                const float targetX = targetEnemy.prevX + (targetEnemy.x - targetEnemy.prevX) * renderAlpha_;
                const float targetY = targetEnemy.prevY + (targetEnemy.y - targetEnemy.prevY) * renderAlpha_;
                angle = std::atan2(targetY - projectileY, targetX - projectileX);
            }
        }
        const float length = 0.6f * tileSize_;
        const float width = 0.2f * tileSize_;
        const float base = length * 0.5f;
        const float side = width * 0.5f;
        const float tip = base + width * 2.0f;
        const float back = -base - base * (2.0f / 3.0f);
        const float fin = side * 4.0f;
        drawOrientedRect(renderer_, projectileX, projectileY, angle, -base, -side, base * 2.0f, side * 2.0f, rgba(189, 195, 199));
        drawOrientedTriangle(renderer_, projectileX, projectileY, angle, {base, -side}, {tip, 0.0f}, {base, side}, rgba(207, 0, 15));
        drawOrientedTriangle(renderer_, projectileX, projectileY, angle, {-base, side}, {back, fin}, {0.0f, side}, rgba(207, 0, 15));
        drawOrientedTriangle(renderer_, projectileX, projectileY, angle, {-base, -side}, {back, -fin}, {0.0f, -side}, rgba(207, 0, 15));
        drawOrientedTriangle(renderer_, projectileX, projectileY, angle, {-base - width, 0.0f}, {-base - width * 3.0f, -side * 0.8f}, {-base - width * 3.0f, side * 0.8f}, rgba(255, 184, 92, 180));
    }

    if (config_.effects) {
        for (const TrailParticleInstance &particle : trailParticles_) {
            if (!particle.alive) {
                continue;
            }
            const float alpha = std::clamp(particle.alpha * 0.45f, 0.0f, 255.0f);
            renderer_.drawRect(
                particle.x - particle.size * 0.5f,
                particle.y - particle.size * 0.5f,
                particle.size,
                particle.size,
                rgba(100, 94, 84, static_cast<int>(alpha))
            );
        }
    }

    if (config_.effects) {
        for (const ExplosionInstance &explosion : explosions_) {
            if (!explosion.alive || explosion.duration <= 0.0f) {
                continue;
            }
            const float progress = std::clamp(explosion.age / explosion.duration, 0.0f, 1.0f);
            const float fade = 1.0f - progress;
            const float outerSize = (explosion.radius + 0.5f) * tileSize_ * 2.0f * (0.7f + progress * 0.3f);
            const bool bombLike = explosion.radius <= 1.2f;
            renderer_.drawRect(
                explosion.x - outerSize * 0.5f,
                explosion.y - outerSize * 0.5f,
                outerSize,
                outerSize,
                bombLike
                    ? rgba(219, 170, 102, static_cast<int>(110.0f * fade))
                    : rgba(207, 0, 15, static_cast<int>(127.0f * fade))
            );
        }
    }

    const TowerInstance *selectedTower = nullptr;
    for (const TowerInstance &tower : towers_) {
        if (tower.alive && tower.col == selectedCol_ && tower.row == selectedRow_) {
            selectedTower = &tower;
            break;
        }
    }

    if (buildMode_ && hoveredCol_ >= 0 && hoveredRow_ >= 0) {
        const TowerVisual style = towerVisual(parseTowerKindId(buildTowerKind_));
        const Point2D c = tileCenter(hoveredCol_, hoveredRow_);
        const float radius = ((findTowerCatalogEntry(buildTowerKind_) != nullptr ? findTowerCatalogEntry(buildTowerKind_)->range : 3.0f) + 0.5f) * tileSize_;
        renderer_.drawRect(c.x - radius, c.y - radius, radius * 2.0f, radius * 2.0f, rgba(style.color.r, style.color.g, style.color.b, 16));
        drawCircleRing(renderer_, c.x, c.y, radius, std::max(1.0f, tileSize_ * 0.05f), style.color, 150);
        const bool valid = canPlace(hoveredCol_, hoveredRow_);
        renderer_.drawRect(
            boardLeft_ + static_cast<float>(hoveredCol_) * tileSize_,
            boardTop_ + static_cast<float>(hoveredRow_) * tileSize_,
            tileSize_,
            tileSize_,
            valid ? rgba(106, 170, 104, 70) : rgba(176, 86, 62, 90)
        );
        TowerInstance preview = createTowerInstance(buildTowerKind_, hoveredCol_, hoveredRow_);
        preview.angle = 0.0f;
        drawGenericTower(preview, 178);
        if (!valid) {
            renderer_.drawLine(c.x - tileSize_ * 0.32f, c.y - tileSize_ * 0.32f, c.x + tileSize_ * 0.32f, c.y + tileSize_ * 0.32f, tileSize_ * 0.1f, rgba(176, 86, 62, 180));
            renderer_.drawLine(c.x + tileSize_ * 0.32f, c.y - tileSize_ * 0.32f, c.x - tileSize_ * 0.32f, c.y + tileSize_ * 0.32f, tileSize_ * 0.1f, rgba(176, 86, 62, 180));
        }
    } else if (selectedTower != nullptr) {
        const TowerVisual style = towerVisual(selectedTower->kindId);
        const float cx = tileCenterX(selectedTower->col);
        const float cy = tileCenterY(selectedTower->row);
        const float radius = (selectedTower->range + 0.5f) * tileSize_;
        renderer_.drawRect(cx - radius, cy - radius, radius * 2.0f, radius * 2.0f, rgba(style.color.r, style.color.g, style.color.b, 16));
        drawCircleRing(renderer_, cx, cy, radius, std::max(1.0f, tileSize_ * 0.05f), style.color, 150);
    } else if (hoveredCol_ >= 0 && hoveredRow_ >= 0) {
        renderer_.drawRect(boardLeft_ + static_cast<float>(hoveredCol_) * tileSize_, boardTop_ + static_cast<float>(hoveredRow_) * tileSize_, tileSize_, tileSize_, rgba(255, 255, 255, 22));
    }
}

unsigned int NativeEngine::packColor(int r, int g, int b, int a) const {
    return (static_cast<unsigned int>(a) << 24) |
           (static_cast<unsigned int>(b) << 16) |
           (static_cast<unsigned int>(g) << 8) |
           static_cast<unsigned int>(r);
}

void NativeEngine::loadMapById(const std::string &mapId) {
    runId_++;
    tickCount_ = 0;
    simTimeSeconds_ = 0.0;
    simAccumulatorSeconds_ = 0.0;
    renderAlpha_ = 0.0f;
    const GeneratedMapSpec *chosen = nullptr;
    for (size_t index = 0; index < kGeneratedMapCount; ++index) {
        if (mapId == kGeneratedMaps[index].name) {
            chosen = &kGeneratedMaps[index];
            break;
        }
    }
    if (chosen == nullptr && isProceduralMapId(mapId)) {
        const std::string resolvedMapId = mapId == "custom" ? "sparse2" : mapId;
        const int viewportWidthPx = boardViewportWidthPx_ > 0 ? boardViewportWidthPx_ : (surfaceWidth_ > 0 ? surfaceWidth_ : 576);
        const int viewportHeightPx = boardViewportHeightPx_ > 0 ? boardViewportHeightPx_ : (surfaceHeight_ > 0 ? surfaceHeight_ : 336);
        const int viewportWidth = std::max(1, static_cast<int>(std::round(static_cast<float>(viewportWidthPx) / densityScale_)));
        const int viewportHeight = std::max(1, static_cast<int>(std::round(static_cast<float>(viewportHeightPx) / densityScale_)));
        const int zoom = 18;
        const int cols = std::max(14, viewportWidth / zoom);
        const int rows = std::max(8, viewportHeight / zoom);
        const int spawnCount = (!resolvedMapId.empty() && resolvedMapId.back() == '3') ? 3 : 2;
        const float wallCover =
            (resolvedMapId == "empty2" || resolvedMapId == "empty3") ? 0.0f :
            (resolvedMapId == "dense2" || resolvedMapId == "dense3") ? 0.20f :
            (resolvedMapId == "solid2" || resolvedMapId == "solid3") ? 0.30f : 0.10f;

        std::random_device device;
        std::mt19937 rng(device());
        std::uniform_real_distribution<float> chance(0.0f, 1.0f);
        std::uniform_int_distribution<int> colDist(0, cols - 1);
        std::uniform_int_distribution<int> rowDist(0, rows - 1);

        bool generated = false;
        std::vector<int> generatedGrid;
        std::vector<int> generatedSpawns;
        int generatedExitCol = cols - 2;
        int generatedExitRow = rows / 2;

        for (int attempt = 0; attempt < 96 && !generated; ++attempt) {
            generatedGrid.assign(static_cast<size_t>(cols * rows), 0);
            generatedSpawns.clear();

            generatedExitCol = colDist(rng);
            generatedExitRow = rowDist(rng);

            for (int row = 0; row < rows; ++row) {
                for (int col = 0; col < cols; ++col) {
                    generatedGrid[static_cast<size_t>(row * cols + col)] = chance(rng) < wallCover ? 1 : 0;
                }
            }

            for (int dy = -1; dy <= 1; ++dy) {
                for (int dx = -1; dx <= 1; ++dx) {
                    const int clearCol = generatedExitCol + dx;
                    const int clearRow = generatedExitRow + dy;
                    if (clearCol < 0 || clearRow < 0 || clearCol >= cols || clearRow >= rows) {
                        continue;
                    }
                    generatedGrid[static_cast<size_t>(clearRow * cols + clearCol)] = 0;
                }
            }

            int guard = 0;
            while (static_cast<int>(generatedSpawns.size() / 2) < spawnCount && guard < 1000) {
                ++guard;
                const int spawnCol = colDist(rng);
                const int spawnRow = rowDist(rng);
                const int manhattan = std::abs(spawnCol - generatedExitCol) + std::abs(spawnRow - generatedExitRow);
                if (generatedGrid[static_cast<size_t>(spawnRow * cols + spawnCol)] != 0 || manhattan < 10) {
                    continue;
                }

                bool duplicate = false;
                for (size_t index = 0; index + 1 < generatedSpawns.size(); index += 2) {
                    if (generatedSpawns[index] == spawnCol && generatedSpawns[index + 1] == spawnRow) {
                        duplicate = true;
                        break;
                    }
                }
                if (duplicate) {
                    continue;
                }

                generatedSpawns.push_back(spawnCol);
                generatedSpawns.push_back(spawnRow);
            }

            if (static_cast<int>(generatedSpawns.size() / 2) != spawnCount) {
                continue;
            }

            generatedGrid[static_cast<size_t>(generatedExitRow * cols + generatedExitCol)] = 4;
            for (size_t index = 0; index + 1 < generatedSpawns.size(); index += 2) {
                generatedGrid[static_cast<size_t>(generatedSpawns[index + 1] * cols + generatedSpawns[index])] = 2;
            }

            std::vector<int> generatedDistanceField;
            std::vector<int> generatedPaths;
            rebuildPathData(cols, rows, generatedExitCol, generatedExitRow, generatedGrid, &generatedDistanceField, &generatedPaths);

            generated = true;
            for (size_t index = 0; index + 1 < generatedSpawns.size(); index += 2) {
                const size_t spawnIndex = static_cast<size_t>(generatedSpawns[index + 1] * cols + generatedSpawns[index]);
                if (generatedDistanceField[spawnIndex] >= 1000000) {
                    generated = false;
                    break;
                }
            }

            if (generated) {
                mapId_ = mapId;
                boardCols_ = cols;
                boardRows_ = rows;
                exitCol_ = generatedExitCol;
                exitRow_ = generatedExitRow;
                grid_ = std::move(generatedGrid);
                paths_ = std::move(generatedPaths);
                distanceField_ = std::move(generatedDistanceField);
                spawnPoints_ = std::move(generatedSpawns);
            }
        }

        if (!generated) {
            chosen = &kGeneratedMaps[1];
        }
    }

    if (chosen == nullptr && grid_.empty()) {
        chosen = &kGeneratedMaps[1];
    }

    if (chosen != nullptr) {
        mapId_ = chosen->name;
        boardCols_ = chosen->cols;
        boardRows_ = chosen->rows;
        exitCol_ = chosen->exitX;
        exitRow_ = chosen->exitY;
        grid_.assign(chosen->grid, chosen->grid + (chosen->cols * chosen->rows));
        paths_.assign(chosen->paths, chosen->paths + (chosen->cols * chosen->rows));
        distanceField_.assign(static_cast<size_t>(chosen->cols * chosen->rows), 1000000);
        spawnPoints_.assign(chosen->spawnPoints, chosen->spawnPoints + (chosen->spawnPointCount * 2));
    }

    enemies_.clear();
    towers_.clear();
    projectiles_.clear();
    explosions_.clear();
    trailParticles_.clear();
    enemyDeathEffects_.clear();
    tempSpawns_.clear();
    clearPlacementCountdown();
    health_ = 40;
    maxHealth_ = 40;
    cash_ = 55;
    kills_ = 0;
    userPaused_ = true;
    lifecyclePaused_ = false;
    defeatPaused_ = false;
    placementPaused_ = false;
    syncPausedState();
    buildMode_ = false;
    placementMessage_.clear();
    hoveredCol_ = -1;
    hoveredRow_ = -1;
    selectedCol_ = -1;
    selectedRow_ = -1;
    pendingPlacementCol_ = -1;
    pendingPlacementRow_ = -1;
    resetWaveRuntime(waveRuntime_);
    syncPausedState();

    rebuildPathData(boardCols_, boardRows_, exitCol_, exitRow_, grid_, &distanceField_, &paths_);
    updateProceduralBalanceScale();
}

void NativeEngine::rebuildDynamicPaths() {
    std::vector<int> dynamicGrid = grid_;
    for (const TowerInstance &tower : towers_) {
        if (!tower.alive) {
            continue;
        }
        if (tileAt(tower.col, tower.row) != 0) {
            continue;
        }
        const size_t index = static_cast<size_t>(tower.row * boardCols_ + tower.col);
        if (index < dynamicGrid.size()) {
            dynamicGrid[index] = 1;
        }
    }
    rebuildPathData(boardCols_, boardRows_, exitCol_, exitRow_, dynamicGrid, &distanceField_, &paths_);
}

void NativeEngine::updateProceduralBalanceScale() {
    proceduralEnemySpeedScale_ = 1.0f;
    proceduralAverageSpawnDistance_ = 0.0f;

    if (!isProceduralMapId(mapId_) || spawnPoints_.size() < 2) {
        return;
    }

    float totalDistance = 0.0f;
    int measuredSpawns = 0;
    for (size_t index = 0; index + 1 < spawnPoints_.size(); index += 2) {
        const int distance = tileDistanceToExit(spawnPoints_[index], spawnPoints_[index + 1]);
        if (distance >= 1000000) {
            continue;
        }
        totalDistance += static_cast<float>(distance);
        measuredSpawns++;
    }

    if (measuredSpawns <= 0) {
        return;
    }

    proceduralAverageSpawnDistance_ = totalDistance / static_cast<float>(measuredSpawns);
    proceduralEnemySpeedScale_ = std::clamp(
        proceduralAverageSpawnDistance_ / kReferenceProceduralSpawnDistanceTiles,
        kMinimumProceduralEnemySpeedScale,
        1.0f
    );
}

bool NativeEngine::boardPointToTile(float xPx, float yPx, int *col, int *row) const {
    if (tileSize_ <= 0.0f) {
        return false;
    }

    const float localX = xPx - boardLeft_;
    const float localY = yPx - boardTop_;
    if (localX < 0.0f || localY < 0.0f) {
        return false;
    }

    const int tileCol = static_cast<int>(localX / tileSize_);
    const int tileRow = static_cast<int>(localY / tileSize_);
    if (tileCol < 0 || tileRow < 0 || tileCol >= boardCols_ || tileRow >= boardRows_) {
        return false;
    }

    if (col != nullptr) {
        *col = tileCol;
    }
    if (row != nullptr) {
        *row = tileRow;
    }
    return true;
}

int NativeEngine::tileAt(int col, int row) const {
    if (col < 0 || row < 0 || col >= boardCols_ || row >= boardRows_) {
        return 0;
    }
    const size_t index = static_cast<size_t>(row * boardCols_ + col);
    if (index >= grid_.size()) {
        return 0;
    }
    return grid_[index];
}

int NativeEngine::pathAt(int col, int row) const {
    if (col < 0 || row < 0 || col >= boardCols_ || row >= boardRows_) {
        return 0;
    }
    const size_t index = static_cast<size_t>(row * boardCols_ + col);
    if (index >= paths_.size()) {
        return 0;
    }
    return paths_[index];
}

void NativeEngine::spawnEnemyAt(int spawnCol, int spawnRow, const std::string &archetypeId) {
    EnemyBlueprint blueprint;
    if (const EnemyArchetypeSpec *enemySpec = findEnemyArchetype(archetypeId)) {
        blueprint.archetype = enemySpec->archetype;
        blueprint.baseSpeed = enemySpec->speed;
        blueprint.radius = enemySpec->radius;
        blueprint.health = enemySpec->health;
        blueprint.cash = enemySpec->cash;
        blueprint.damage = enemySpec->damage;
    }
    if (isProceduralMapId(mapId_)) {
        blueprint.baseSpeed *= proceduralEnemySpeedScale_;
    }
    enemies_.push_back(makeEnemyInstance(
        waveRuntime_.nextEnemyId++,
        spawnCol,
        spawnRow,
        boardLeft_,
        boardTop_,
        tileSize_,
        blueprint
    ));
}

void NativeEngine::processEnemyKilled(EnemyInstance &enemy) {
    if (!enemy.alive) {
        return;
    }
    enemy.alive = false;
    cash_ += enemy.cash;
    kills_++;
    queueAudioEvent(enemy.archetype == EnemyArchetypeId::Taunt ? SoundType::Taunt : SoundType::Pop);
    if (config_.effects) {
        const EnemyPalette palette = enemyPaletteFor(enemy.archetype, enemy.slowTicks > 0);
        enemyDeathEffects_.push_back(EnemyDeathEffect{
            enemy.x,
            enemy.y,
            std::max(tileSize_ * 0.72f, enemy.radius * tileSize_ * 1.2f),
            0.0f,
            10.0f,
            palette.primary.r,
            palette.primary.g,
            palette.primary.b,
            palette.secondary.r,
            palette.secondary.g,
            palette.secondary.b,
            true,
        });
    }

    if (enemy.archetype == EnemyArchetypeId::Spawner) {
        int col = 0;
        int row = 0;
        if (!boardPointToTile(enemy.x, enemy.y, &col, &row)) {
            return;
        }
        if (col == exitCol_ && row == exitRow_) {
            return;
        }
        for (const TempSpawnPoint &spawn : tempSpawns_) {
            if (spawn.col == col && spawn.row == row) {
                return;
            }
        }
        tempSpawns_.push_back(TempSpawnPoint{col, row, 40});
    }
}

void NativeEngine::updateEnemies() {
    if (tileSize_ <= 0.0f || spawnPoints_.size() < 2) {
        return;
    }

    static std::mt19937 rng(std::random_device{}());
    std::uniform_real_distribution<float> chance(0.0f, 1.0f);

    for (EnemyInstance &enemy : enemies_) {
        if (!enemy.alive) {
            continue;
        }
        if (enemy.poisonTicks > 0) {
            enemy.poisonTicks--;
            const float multiplier = damageMultiplierFor(enemy.archetype, "poison");
            if (multiplier > 0.0f) {
                enemy.hitFlash = std::min(1.0f, enemy.hitFlash + 0.45f);
                enemy.health -= 1.0f * multiplier;
                if (enemy.health <= 0.0f) {
                    processEnemyKilled(enemy);
                }
            }
        }
        if (enemy.regenTicks > 0) {
            enemy.regenTicks--;
            if (enemy.health < enemy.maxHealth && chance(rng) < 0.2f) {
                enemy.health = std::min(enemy.maxHealth, enemy.health + 1.0f);
            }
        }
    }

    if (!pendingEnemyQueue_.empty()) {
        if (waveRuntime_.spawnTickCounter > 0) {
            waveRuntime_.spawnTickCounter--;
        } else {
            const std::string enemyId = pendingEnemyQueue_.front();
            pendingEnemyQueue_.erase(pendingEnemyQueue_.begin());
            for (size_t spawnIndex = 0; spawnIndex + 1 < spawnPoints_.size(); spawnIndex += 2) {
                spawnEnemyAt(spawnPoints_[spawnIndex], spawnPoints_[spawnIndex + 1], enemyId);
            }
            for (TempSpawnPoint &spawn : tempSpawns_) {
                if (spawn.ticksRemaining <= 0) {
                    continue;
                }
                spawnEnemyAt(spawn.col, spawn.row, enemyId);
                spawn.ticksRemaining--;
            }
            waveRuntime_.spawnTickCounter = std::max(0, waveRuntime_.spawnCooldownTicks);
        }
    }
    updateEnemiesFixedStep(
        enemies_,
        tileSize_,
        exitCol_,
        exitRow_,
        [this](int col, int row) { return pathAt(col, row); },
        [this](float xPx, float yPx, int *col, int *row) { return boardPointToTile(xPx, yPx, col, row); },
        [this](float xPx, float yPx, int col, int row) { return atTileCenter(xPx, yPx, col, row); },
        [this](const EnemyInstance &enemy) {
            if (!config_.godMode) {
                health_ = std::max(0, health_ - enemy.damage);
            }
            leakCount_ += enemy.damage;
        }
    );
    for (EnemyInstance &enemy : enemies_) {
        if (!enemy.alive || enemy.archetypeId != "medic") {
            continue;
        }
        for (EnemyInstance &other : enemies_) {
            if (!other.alive) {
                continue;
            }
            const float dx = other.x - enemy.x;
            const float dy = other.y - enemy.y;
            const float healRangePx = (2.0f + 1.0f) * tileSize_;
            if (dx * dx + dy * dy > healRangePx * healRangePx) {
                continue;
            }
            other.regenTicks = std::max(other.regenTicks, 1);
        }
    }

    tempSpawns_.erase(
        std::remove_if(
            tempSpawns_.begin(),
            tempSpawns_.end(),
            [](const TempSpawnPoint &spawn) { return spawn.ticksRemaining <= 0; }
        ),
        tempSpawns_.end()
    );
    waveRuntime_.activeEnemyCount = static_cast<int>(enemies_.size());
}

void NativeEngine::steerEnemy(EnemyInstance &enemy) {
    int col = 0;
    int row = 0;
    if (!boardPointToTile(enemy.x, enemy.y, &col, &row)) {
        return;
    }
    const int direction = pathAt(col, row);
    if (!atTileCenter(enemy.x, enemy.y, col, row) || direction == 0) {
        return;
    }

    const float speed = enemy.speed * tileSize_ / 24.0f;
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

bool NativeEngine::atTileCenter(float xPx, float yPx, int col, int row) const {
    const float centerX = boardLeft_ + (static_cast<float>(col) + 0.5f) * tileSize_;
    const float centerY = boardTop_ + (static_cast<float>(row) + 0.5f) * tileSize_;
    const float tolerance = tileSize_ / 24.0f;
    return xPx > centerX - tolerance &&
           xPx < centerX + tolerance &&
           yPx > centerY - tolerance &&
           yPx < centerY + tolerance;
}

bool NativeEngine::towerAt(int col, int row) const {
    for (const TowerInstance &tower : towers_) {
        if (tower.alive && tower.col == col && tower.row == row) {
            return true;
        }
    }
    return false;
}

bool NativeEngine::walkable(int col, int row, int ignoreTowerCol, int ignoreTowerRow) const {
    const int gridValue = tileAt(col, row);
    if (gridValue == 1 || gridValue == 3) {
        return false;
    }
    for (const TowerInstance &tower : towers_) {
        if (!tower.alive) {
            continue;
        }
        if (tower.col == ignoreTowerCol && tower.row == ignoreTowerRow) {
            continue;
        }
        if (tower.col == col && tower.row == row) {
            return false;
        }
    }
    return true;
}

bool NativeEngine::emptyTile(int col, int row) const {
    if (!walkable(col, row)) {
        return false;
    }
    for (size_t index = 0; index + 1 < spawnPoints_.size(); index += 2) {
        if (spawnPoints_[index] == col && spawnPoints_[index + 1] == row) {
            return false;
        }
    }
    if (exitCol_ == col && exitRow_ == row) {
        return false;
    }
    return true;
}

bool NativeEngine::placeable(int col, int row) const {
    std::vector<char> visited(static_cast<size_t>(boardCols_ * boardRows_), 0);
    std::queue<std::pair<int, int>> frontier;
    frontier.push({exitCol_, exitRow_});
    visited[static_cast<size_t>(exitRow_ * boardCols_ + exitCol_)] = 1;

    constexpr std::array<int, 4> dx = {1, -1, 0, 0};
    constexpr std::array<int, 4> dy = {0, 0, 1, -1};
    while (!frontier.empty()) {
        const auto [currentCol, currentRow] = frontier.front();
        frontier.pop();

        for (size_t index = 0; index < dx.size(); ++index) {
            const int nextCol = currentCol + dx[index];
            const int nextRow = currentRow + dy[index];
            if (nextCol < 0 || nextRow < 0 || nextCol >= boardCols_ || nextRow >= boardRows_) {
                continue;
            }
            if (nextCol == col && nextRow == row) {
                continue;
            }
            if (!walkable(nextCol, nextRow)) {
                continue;
            }
            const size_t visitIndex = static_cast<size_t>(nextRow * boardCols_ + nextCol);
            if (visited[visitIndex]) {
                continue;
            }
            visited[visitIndex] = 1;
            frontier.push({nextCol, nextRow});
        }
    }

    for (size_t index = 0; index + 1 < spawnPoints_.size(); index += 2) {
        const int spawnCol = spawnPoints_[index];
        const int spawnRow = spawnPoints_[index + 1];
        const size_t visitIndex = static_cast<size_t>(spawnRow * boardCols_ + spawnCol);
        if (!visited[visitIndex]) {
            return false;
        }
    }

    return true;
}

NativeEngine::TileKind NativeEngine::classifyTile(int col, int row) const {
    switch (tileAt(col, row)) {
        case 1:
            return TileKind::Blocked;
        case 2:
        case 4:
            return TileKind::Path;
        case 3:
            return TileKind::Socket;
        default:
            return TileKind::Buildable;
    }
}

bool NativeEngine::canPlace(int col, int row) const {
    switch (classifyTile(col, row)) {
        case TileKind::Blocked:
        case TileKind::Path:
            return false;
        case TileKind::Socket:
            return !towerAt(col, row);
        case TileKind::Buildable:
            return emptyTile(col, row) && placeable(col, row);
    }
    return false;
}

std::string NativeEngine::describePlacement(int col, int row) const {
    switch (classifyTile(col, row)) {
        case TileKind::Blocked:
            return "Blocked by terrain.";
        case TileKind::Path:
            return "Path tiles cannot hold towers.";
        case TileKind::Socket:
            return towerAt(col, row) ? "Another tower already occupies this tile." : "Tower-only socket available.";
        case TileKind::Buildable:
            break;
    }
    if (towerAt(col, row)) {
        return "Another tower already occupies this tile.";
    }
    for (size_t index = 0; index + 1 < spawnPoints_.size(); index += 2) {
        if (spawnPoints_[index] == col && spawnPoints_[index + 1] == row) {
            return "Spawn tiles cannot hold towers.";
        }
    }
    if (exitCol_ == col && exitRow_ == row) {
        return "The exit tile must stay open.";
    }
    if (!placeable(col, row)) {
        return "Placement would block enemy pathing.";
    }
    return "Valid placement.";
}

void NativeEngine::handleBoardSelection(int col, int row) {
    for (TowerInstance &tower : towers_) {
        if (tower.alive && tower.col == col && tower.row == row) {
            selectedCol_ = col;
            selectedRow_ = row;
            placementPaused_ = false;
            buildMode_ = false;
            pendingPlacementCol_ = -1;
            pendingPlacementRow_ = -1;
            placementMessage_.clear();
            clearPlacementCountdown();
            syncPausedState();
            return;
        }
    }
    if (!buildMode_) {
        return;
    }
    if (pendingPlacementCol_ != col || pendingPlacementRow_ != row) {
        startPlacementCountdown();
    }
    pendingPlacementCol_ = col;
    pendingPlacementRow_ = row;
    if (!canPlace(col, row)) {
        placementMessage_ = describePlacement(col, row);
        placementPaused_ = false;
        syncPausedState();
        return;
    }
    const TowerCatalogEntry *entry = findTowerCatalogEntry(buildTowerKind_);
    if (entry == nullptr) {
        return;
    }
    if (!config_.godMode && cash_ < entry->cost) {
        placementMessage_ = "Not enough cash.";
        placementPaused_ = false;
        syncPausedState();
        return;
    }
    placementMessage_ = "Confirm placement.";
    placementPaused_ = health_ > 0;
    syncPausedState();
}

void NativeEngine::updateTowers() {
    if (config_.firingDisabled) {
        for (TowerInstance &tower : towers_) {
            decayTowerVisuals(tower, 1);
        }
        return;
    }

    const auto markEnemyKilled = [this](EnemyInstance &enemy) {
        if (enemy.health <= 0.0f && enemy.alive) {
            processEnemyKilled(enemy);
        }
    };

    const auto dealDamage = [this, &markEnemyKilled](EnemyInstance &enemy, float amount, std::string_view damageType) {
        const float multiplier = damageMultiplierFor(enemy.archetype, damageType);
        if (multiplier <= 0.0f) {
            return;
        }
        const float appliedDamage = std::min(enemy.health, amount * multiplier);
        enemy.hitFlash = std::min(1.0f, enemy.hitFlash + 0.45f);
        enemy.health -= amount * multiplier;
        totalDamage_ += std::max(0.0f, appliedDamage);
        markEnemyKilled(enemy);
    };

    const auto rollCooldown = [this](const TowerInstance &tower) -> int {
        const auto scaleCooldown = [](int value) -> int {
            return std::max(0, static_cast<int>(std::round(static_cast<float>(value) * kTowerCooldownScale)));
        };
        if (tower.cooldownMax <= tower.cooldownMin) {
            return scaleCooldown(tower.cooldownMin);
        }
        return scaleCooldown(static_cast<int>(std::round(randomRange(
            static_cast<float>(tower.cooldownMin),
            static_cast<float>(tower.cooldownMax)
        ))));
    };

    const auto rollDamage = [this](const TowerInstance &tower) -> float {
        return std::round(randomRange(tower.damageMin, tower.damageMax));
    };

    for (TowerInstance &tower : towers_) {
        if (!tower.alive) {
            continue;
        }
        decayTowerVisuals(tower, 1);
        const float centerX = tileCenterX(tower.col);
        const float centerY = tileCenterY(tower.row);
        const float rangePx = (tower.range + 1.0f) * tileSize_;
        const float rangeSquared = rangePx * rangePx;

        towerCandidatesScratch_.clear();
        towerTauntsScratch_.clear();
        for (size_t index = 0; index < enemies_.size(); ++index) {
            const EnemyInstance &enemy = enemies_[index];
            if (!enemy.alive) {
                continue;
            }
            const float dx = enemy.x - centerX;
            const float dy = enemy.y - centerY;
            if (dx * dx + dy * dy > rangeSquared) {
                continue;
            }
            towerCandidatesScratch_.push_back(static_cast<int>(index));
            if (enemy.archetype == EnemyArchetypeId::Taunt) {
                towerTauntsScratch_.push_back(static_cast<int>(index));
            }
        }
        std::vector<int> &candidates = towerTauntsScratch_.empty() ? towerCandidatesScratch_ : towerTauntsScratch_;
        if (candidates.empty()) {
            tower.lastTargetEnemyId = -1;
            tower.beamChargeTicks = 0;
            continue;
        }

        if (tower.kindId == TowerKindId::Slow || tower.kindId == TowerKindId::Poison) {
            const EnemyInstance &visualTarget = enemies_[static_cast<size_t>(candidates.front())];
            tower.angle = std::atan2(visualTarget.y - centerY, visualTarget.x - centerX);
            tower.beamTargetX = visualTarget.x;
            tower.beamTargetY = visualTarget.y;
            if (tower.cooldown > 0) {
                continue;
            }
            prepareTowerFireState(tower, visualTarget, boardLeft_, boardTop_, tileSize_, rollCooldown(tower), 0);
            for (int index : candidates) {
                EnemyInstance &enemy = enemies_[static_cast<size_t>(index)];
                if (tower.kindId == TowerKindId::Slow) {
                    if (damageMultiplierFor(enemy.archetype, "slow") <= 0.0f) {
                        continue;
                    }
                    enemy.slowFactor = 0.55f;
                    enemy.slowTicks = std::max(enemy.slowTicks, 40);
                } else {
                    if (damageMultiplierFor(enemy.archetype, "poison") <= 0.0f) {
                        continue;
                    }
                    enemy.poisonTicks = std::max(enemy.poisonTicks, 60);
                }
            }
            continue;
        }

        int targetIndex = -1;
        if (tower.kindId == TowerKindId::Rocket || tower.kindId == TowerKindId::MissileSilo) {
            float bestDistance = 1e30f;
            for (int index : candidates) {
                const EnemyInstance &enemy = enemies_[static_cast<size_t>(index)];
                const float dx = enemy.x - centerX;
                const float dy = enemy.y - centerY;
                const float distSquared = dx * dx + dy * dy;
                if (distSquared < bestDistance) {
                    bestDistance = distSquared;
                    targetIndex = index;
                }
            }
        } else if (tower.kindId == TowerKindId::Sniper || tower.kindId == TowerKindId::Railgun || tower.targetingMode == TargetingMode::Strongest) {
            float bestHealth = -1.0f;
            for (int index : candidates) {
                const EnemyInstance &enemy = enemies_[static_cast<size_t>(index)];
                if (enemy.health > bestHealth) {
                    bestHealth = enemy.health;
                    targetIndex = index;
                }
            }
        } else if (tower.targetingMode == TargetingMode::Nearest) {
            float bestDistance = 1e30f;
            for (int index : candidates) {
                const EnemyInstance &enemy = enemies_[static_cast<size_t>(index)];
                const float dx = enemy.x - centerX;
                const float dy = enemy.y - centerY;
                const float distSquared = dx * dx + dy * dy;
                if (distSquared < bestDistance) {
                    bestDistance = distSquared;
                    targetIndex = index;
                }
            }
        } else {
            float bestMetric = 1e9f;
            for (int index : candidates) {
                const EnemyInstance &enemy = enemies_[static_cast<size_t>(index)];
                const float metric = pathProgressScore(enemy.x, enemy.y);
                if (metric < bestMetric) {
                    bestMetric = metric;
                    targetIndex = index;
                }
            }
        }

        if (targetIndex < 0) {
            continue;
        }

        EnemyInstance &enemy = enemies_[static_cast<size_t>(targetIndex)];
        tower.angle = std::atan2(enemy.y - centerY, enemy.x - centerX);
        tower.beamTargetX = enemy.x;
        tower.beamTargetY = enemy.y;
        const std::string_view damageType = damageTypeForTower(tower.kindId);

        if (tower.kindId == TowerKindId::BeamEmitter) {
            if (tower.lastTargetEnemyId == enemy.id) {
                tower.beamChargeTicks++;
            } else {
                tower.lastTargetEnemyId = enemy.id;
                tower.beamChargeTicks = 0;
            }
        } else {
            tower.lastTargetEnemyId = enemy.id;
            tower.beamChargeTicks = 0;
        }

        if (tower.cooldown > 0) {
            continue;
        }

        prepareTowerFireState(tower, enemy, boardLeft_, boardTop_, tileSize_, rollCooldown(tower));

        if (tower.kindId == TowerKindId::Rocket || tower.kindId == TowerKindId::MissileSilo) {
            ProjectileInstance projectile;
            projectile.x = centerX;
            projectile.y = centerY;
            projectile.prevX = centerX;
            projectile.prevY = centerY;
            projectile.damageMin = tower.damageMin;
            projectile.damageMax = tower.damageMax;
            projectile.splashRadius = tower.kindId == TowerKindId::MissileSilo ? 2.0f : 1.0f;
            projectile.accAmt = (tower.kindId == TowerKindId::MissileSilo ? 0.7f : 0.6f) * tileSize_ / 24.0f;
            projectile.topSpeed = (tower.kindId == TowerKindId::MissileSilo ? 6.0f : 4.0f) * tileSize_ / 24.0f;
            projectile.lifetime = 60;
            projectile.trailCooldown = 0;
            projectile.range = tower.range;
            projectile.targetEnemyId = enemy.id;
            projectiles_.push_back(projectile);
            queueAudioEvent(SoundType::Missile);
            continue;
        }

        if (tower.kindId == TowerKindId::Bomb) {
            const float blastRange = (1.0f + 1.0f) * tileSize_;
            const float blastRangeSquared = blastRange * blastRange;
            for (EnemyInstance &other : enemies_) {
                if (!other.alive) {
                    continue;
                }
                const float dx = other.x - enemy.x;
                const float dy = other.y - enemy.y;
                const float distSquared = dx * dx + dy * dy;
                if (distSquared > blastRangeSquared) {
                    continue;
                }
                const float dist = std::sqrt(distSquared);
                const float falloff = std::clamp(1.0f - dist / blastRange, 0.35f, 1.0f);
                dealDamage(other, rollDamage(tower) * falloff, damageType);
            }
            explosions_.push_back(towerdefense::spawnExplosion(enemy.x, enemy.y, 1.0f));
            queueAudioEvent(SoundType::Boom);
            continue;
        }

        if (tower.kindId == TowerKindId::ClusterBomb) {
            explosions_.push_back(towerdefense::spawnExplosion(enemy.x, enemy.y, 1.0f));
            static std::mt19937 rng(std::random_device{}());
            std::uniform_real_distribution<float> angleDist(0.0f, 6.28318530718f);
            const float startAngle = angleDist(rng);
            for (int segment = 0; segment < 3; ++segment) {
                const float angle = startAngle + (6.28318530718f / 3.0f) * static_cast<float>(segment);
                const float blastX = enemy.x + std::cos(angle) * 2.0f * tileSize_;
                const float blastY = enemy.y + std::sin(angle) * 2.0f * tileSize_;
                explosions_.push_back(towerdefense::spawnExplosion(blastX, blastY, 1.0f));
                for (EnemyInstance &other : enemies_) {
                    if (!other.alive) {
                        continue;
                    }
                    const float dx = other.x - blastX;
                    const float dy = other.y - blastY;
                    const float dist = std::sqrt(dx * dx + dy * dy);
                    const float rangePx = (1.0f + 1.0f) * tileSize_;
                    if (dist > rangePx) {
                        continue;
                    }
                    const float falloff = std::clamp(1.0f - dist / rangePx, 0.25f, 1.0f);
                    dealDamage(other, rollDamage(tower) * falloff, damageType);
                }
            }
            queueAudioEvent(SoundType::Boom);
            continue;
        }

        if (tower.kindId == TowerKindId::Railgun) {
            dealDamage(enemy, rollDamage(tower), damageType);
            queueAudioEvent(SoundType::Railgun);
            continue;
        }

        if (tower.kindId == TowerKindId::Tesla || tower.kindId == TowerKindId::Plasma) {
            towerChainScratch_.clear();
            int chainIndex = targetIndex;
            float damage = rollDamage(tower);
            int chainCount = 0;
            while (chainIndex >= 0 && damage > 1.0f && chainCount < 6) {
                EnemyInstance &chainedEnemy = enemies_[static_cast<size_t>(chainIndex)];
                dealDamage(chainedEnemy, damage, damageType);
                towerChainScratch_.push_back(chainedEnemy.id);
                float bestDistance = 1e30f;
                int nextIndex = -1;
                for (size_t index = 0; index < enemies_.size(); ++index) {
                    const EnemyInstance &candidate = enemies_[index];
                    if (!candidate.alive || std::find(towerChainScratch_.begin(), towerChainScratch_.end(), candidate.id) != towerChainScratch_.end()) {
                        continue;
                    }
                    const float dx = candidate.x - chainedEnemy.x;
                    const float dy = candidate.y - chainedEnemy.y;
                    const float distSquared = dx * dx + dy * dy;
                    if (distSquared < bestDistance) {
                        bestDistance = distSquared;
                        nextIndex = static_cast<int>(index);
                    }
                }
                chainIndex = nextIndex;
                damage *= 0.5f;
                chainCount++;
            }
            queueAudioEvent(SoundType::Spark);
            continue;
        }

        if (tower.kindId == TowerKindId::BeamEmitter) {
            const float baseDamage = std::max(1.0f, randomRange(tower.damageMin, tower.damageMax));
            const float charge = static_cast<float>(std::max(1, tower.beamChargeTicks));
            dealDamage(enemy, baseDamage * charge * charge, damageType);
            continue;
        }

        dealDamage(enemy, rollDamage(tower), damageType);
        if (tower.kindId == TowerKindId::Sniper) {
            queueAudioEvent(SoundType::Sniper);
        }
    }
}

void NativeEngine::updateProjectiles() {
    std::vector<int> previousCashByEnemyId;
    std::vector<char> wasAliveByEnemyId;
    previousCashByEnemyId.reserve(enemies_.size() * 2 + 1);
    int maxEnemyId = 0;
    for (const EnemyInstance &enemy : enemies_) {
        maxEnemyId = std::max(maxEnemyId, enemy.id);
    }
    previousCashByEnemyId.assign(static_cast<size_t>(maxEnemyId + 1), 0);
    wasAliveByEnemyId.assign(static_cast<size_t>(maxEnemyId + 1), 0);
    for (const EnemyInstance &enemy : enemies_) {
        if (enemy.id >= 0) {
            previousCashByEnemyId[static_cast<size_t>(enemy.id)] = enemy.cash;
            wasAliveByEnemyId[static_cast<size_t>(enemy.id)] = enemy.alive ? 1 : 0;
        }
    }

    for (ProjectileInstance &projectile : projectiles_) {
        if (!projectile.alive) {
            continue;
        }
        if (projectile.trailCooldown <= 0) {
            TrailParticleInstance smoke;
            smoke.x = projectile.x;
            smoke.y = projectile.y;
            smoke.vx = -projectile.vx * 0.08f + randomRange(-0.15f, 0.15f);
            smoke.vy = -projectile.vy * 0.08f + randomRange(-0.15f, 0.15f);
            smoke.size = randomRange(0.22f, 0.5f) * tileSize_;
            smoke.alpha = randomRange(48.0f, 72.0f);
            smoke.decay = randomRange(2.0f, 4.0f);
            trailParticles_.push_back(smoke);
            projectile.trailCooldown = 2;
        } else {
            projectile.trailCooldown--;
        }
    }

    const auto impacts = advanceProjectiles(
        projectiles_,
        enemies_,
        tileSize_ * 0.24f,
        tileSize_
    );
    for (const auto &impact : impacts) {
        const float splashRadiusPx = impact.splashRadius * tileSize_;
        const float splashRadiusSquared = splashRadiusPx * splashRadiusPx;
        for (EnemyInstance &enemy : enemies_) {
            if (!enemy.alive) {
                continue;
            }
            const float dx = enemy.x - impact.x;
            const float dy = enemy.y - impact.y;
            const float distanceSquared = dx * dx + dy * dy;
            if (distanceSquared > splashRadiusSquared) {
                continue;
            }
            const float dist = std::sqrt(distanceSquared);
            const float falloff = std::clamp(1.0f - dist / ((impact.splashRadius + 1.0f) * tileSize_), 0.2f, 1.0f);
            const float multiplier = damageMultiplierFor(enemy.archetype, "explosion");
            if (multiplier <= 0.0f) {
                continue;
            }
            enemy.hitFlash = std::min(1.0f, enemy.hitFlash + 0.65f);
            enemy.health -= randomRange(impact.damageMin, impact.damageMax) * falloff * multiplier;
            if (enemy.health <= 0.0f) {
                processEnemyKilled(enemy);
            }
        }
        explosions_.push_back(towerdefense::spawnExplosion(impact.x, impact.y, impact.splashRadius));
        queueAudioEvent(SoundType::Boom);
    }

    for (EnemyInstance &enemy : enemies_) {
        if (!enemy.alive && enemy.health <= 0.0f && enemy.id >= 0 &&
            static_cast<size_t>(enemy.id) < previousCashByEnemyId.size() &&
            wasAliveByEnemyId[static_cast<size_t>(enemy.id)] != 0) {
            enemy.health = 0.0f;
        }
    }
    enemies_.erase(
        std::remove_if(
            enemies_.begin(),
            enemies_.end(),
            [](const EnemyInstance &enemy) { return !enemy.alive; }
        ),
        enemies_.end()
    );
}

void NativeEngine::updateExplosions() {
    ageExplosions(explosions_);
}

void NativeEngine::updateTrailParticles() {
    for (TrailParticleInstance &particle : trailParticles_) {
        if (!particle.alive) {
            continue;
        }
        particle.x += particle.vx;
        particle.y += particle.vy;
        particle.vx *= 0.94f;
        particle.vy = particle.vy * 0.94f - 0.01f * tileSize_ / 24.0f;
        particle.alpha -= particle.decay;
        if (particle.alpha <= 0.0f) {
            particle.alive = false;
        }
    }

    trailParticles_.erase(
        std::remove_if(
            trailParticles_.begin(),
            trailParticles_.end(),
            [](const TrailParticleInstance &particle) { return !particle.alive; }
        ),
        trailParticles_.end()
    );
}

void NativeEngine::updateEnemyDeathEffects() {
    for (EnemyDeathEffect &effect : enemyDeathEffects_) {
        if (!effect.alive) {
            continue;
        }
        effect.age += 1.0f;
        if (effect.age >= effect.duration) {
            effect.alive = false;
        }
    }

    enemyDeathEffects_.erase(
        std::remove_if(
            enemyDeathEffects_.begin(),
            enemyDeathEffects_.end(),
            [](const EnemyDeathEffect &effect) { return !effect.alive; }
        ),
        enemyDeathEffects_.end()
    );
}

int NativeEngine::findEnemyIndexById(int enemyId) const {
    if (enemyId < 0) {
        return -1;
    }
    for (size_t index = 0; index < enemies_.size(); ++index) {
        if (enemies_[index].id == enemyId) {
            return static_cast<int>(index);
        }
    }
    return -1;
}

int NativeEngine::findNearestEnemyIndex(float xPx, float yPx, int excludeEnemyId) const {
    int bestIndex = -1;
    float bestDistanceSquared = 1e30f;
    for (size_t index = 0; index < enemies_.size(); ++index) {
        const EnemyInstance &enemy = enemies_[index];
        if (!enemy.alive || enemy.id == excludeEnemyId) {
            continue;
        }
        const float dx = enemy.x - xPx;
        const float dy = enemy.y - yPx;
        const float distanceSquared = dx * dx + dy * dy;
        if (distanceSquared < bestDistanceSquared) {
            bestDistanceSquared = distanceSquared;
            bestIndex = static_cast<int>(index);
        }
    }
    return bestIndex;
}

void NativeEngine::spawnExplosion(float xPx, float yPx, float radiusTiles) {
    ExplosionInstance explosion;
    explosion.x = xPx;
    explosion.y = yPx;
    explosion.radius = std::max(0.8f, radiusTiles);
    explosion.duration = 14.0f;
    explosion.age = 0.0f;
    explosions_.push_back(explosion);
}

int NativeEngine::findNearestEnemyInRange(const TowerInstance &tower) const {
    const float centerX = tileCenterX(tower.col);
    const float centerY = tileCenterY(tower.row);
    const float rangePx = tower.range * tileSize_;
    const float rangeSquared = rangePx * rangePx;

    int bestIndex = -1;
    float bestMetric = 1e9f;
    for (size_t index = 0; index < enemies_.size(); ++index) {
        const EnemyInstance &enemy = enemies_[index];
        if (!enemy.alive) {
            continue;
        }
        const float dx = enemy.x - centerX;
        const float dy = enemy.y - centerY;
        const float distSquared = dx * dx + dy * dy;
        if (distSquared > rangeSquared) {
            continue;
        }

        int col = 0;
        int row = 0;
        if (!boardPointToTile(enemy.x, enemy.y, &col, &row)) {
            continue;
        }
        const float metric = pathProgressScore(enemy.x, enemy.y);
        if (metric < bestMetric) {
            bestMetric = metric;
            bestIndex = static_cast<int>(index);
        }
    }
    return bestIndex;
}

float NativeEngine::tileCenterX(int col) const {
    return boardLeft_ + (static_cast<float>(col) + 0.5f) * tileSize_;
}

float NativeEngine::tileCenterY(int row) const {
    return boardTop_ + (static_cast<float>(row) + 0.5f) * tileSize_;
}

float NativeEngine::randomRange(float minValue, float maxValue) {
    static std::mt19937 rng(std::random_device{}());
    if (maxValue <= minValue) {
        return minValue;
    }
    std::uniform_real_distribution<float> dist(minValue, maxValue);
    return dist(rng);
}

int NativeEngine::tileDistanceToExit(int col, int row) const {
    if (col < 0 || row < 0 || col >= boardCols_ || row >= boardRows_) {
        return 1000000;
    }
    const size_t index = static_cast<size_t>(row * boardCols_ + col);
    if (index >= distanceField_.size()) {
        return 1000000;
    }
    return distanceField_[index];
}

float NativeEngine::pathProgressScore(float xPx, float yPx) const {
    int col = 0;
    int row = 0;
    if (!boardPointToTile(xPx, yPx, &col, &row)) {
        return 1000000.0f;
    }
    const float centerX = tileCenterX(col);
    const float centerY = tileCenterY(row);
    const int direction = pathAt(col, row);
    float progress = 0.0f;
    switch (direction) {
        case 1:
            progress = (centerX - xPx) / tileSize_;
            break;
        case 2:
            progress = (centerY - yPx) / tileSize_;
            break;
        case 3:
            progress = (xPx - centerX) / tileSize_;
            break;
        case 4:
            progress = (yPx - centerY) / tileSize_;
            break;
        default:
            break;
    }
    return static_cast<float>(tileDistanceToExit(col, row)) - progress;
}

NativeEngine::TowerInstance NativeEngine::createTowerInstance(const std::string &kind, int col, int row) const {
    return makeTowerRuntime(kind, col, row);
}
