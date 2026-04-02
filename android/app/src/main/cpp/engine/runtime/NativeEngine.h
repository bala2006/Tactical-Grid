#ifndef TOWERDEFENSE_NATIVE_ENGINE_H
#define TOWERDEFENSE_NATIVE_ENGINE_H

#include <chrono>
#include <array>
#include <mutex>
#include <string>
#include <vector>

#include "GameRuntimeTypes.h"
#include "GameConfigState.h"
#include "GlRenderer2D.h"
#include "NativeInterop.h"
#include "TowerCatalog.h"
#include "WaveRuntime.h"

class NativeEngine {
public:
    static NativeEngine &instance();

    void onSurfaceCreated();
    void onSurfaceChanged(int width, int height);
    void onDrawFrame();
    void onPause();
    void onResume();
    void onPointer(float xPx, float yPx, int phase);

    void setActiveScreen(int screenId);
    bool invokeAction(const std::string &actionId, const std::string &payload);
    void setBoardViewport(int leftPx, int topPx, int widthPx, int heightPx, float density);
    void handleBoardTap(float xPx, float yPx);
    void handleBoardDrag(float xPx, float yPx, int phase);
    const towerdefense::NativeGameSnapshot &snapshot();
    int consumeAudioEvents(towerdefense::NativeAudioEvent *buffer, int maxEvents);

private:
    enum class TileKind {
        Buildable,
        Blocked,
        Path,
        Socket,
    };

    struct TempSpawnPoint {
        int col = 0;
        int row = 0;
        int ticksRemaining = 0;
    };

    struct EnemyDeathEffect {
        float x = 0.0f;
        float y = 0.0f;
        float size = 0.0f;
        float age = 0.0f;
        float duration = 0.0f;
        int primaryR = 0;
        int primaryG = 0;
        int primaryB = 0;
        int secondaryR = 0;
        int secondaryG = 0;
        int secondaryB = 0;
        bool alive = true;
    };

    using EnemyInstance = towerdefense::EnemyRuntime;
    using TowerInstance = towerdefense::TowerRuntime;
    using ProjectileInstance = towerdefense::ProjectileRuntime;
    using ExplosionInstance = towerdefense::ExplosionRuntime;
    using TrailParticleInstance = towerdefense::TrailParticleRuntime;

    NativeEngine() = default;
    ~NativeEngine();
    NativeEngine(const NativeEngine &) = delete;
    NativeEngine &operator=(const NativeEngine &) = delete;

    void updateSimulation(double dtSeconds);
    void updateBoardMetrics();
    void renderBoard(float pulse);
    unsigned int packColor(int r, int g, int b, int a = 255) const;
    void loadMapById(const std::string &mapId);
    void restartRunLocked();
    bool boardPointToTile(float xPx, float yPx, int *col, int *row) const;
    int tileAt(int col, int row) const;
    int pathAt(int col, int row) const;
    void spawnEnemyAt(int spawnCol, int spawnRow, const std::string &archetypeId);
    void updateEnemies();
    void updateTowers();
    void updateProjectiles();
    void updateExplosions();
    void updateTrailParticles();
    void updateEnemyDeathEffects();
    void queueNextWave();
    void processEnemyKilled(EnemyInstance &enemy);
    void rebuildDynamicPaths();
    void updateProceduralBalanceScale();
    void steerEnemy(EnemyInstance &enemy);
    bool atTileCenter(float xPx, float yPx, int col, int row) const;
    bool towerAt(int col, int row) const;
    bool walkable(int col, int row, int ignoreTowerCol = -1, int ignoreTowerRow = -1) const;
    bool emptyTile(int col, int row) const;
    TileKind classifyTile(int col, int row) const;
    bool placeable(int col, int row) const;
    bool canPlace(int col, int row) const;
    std::string describePlacement(int col, int row) const;
    void handleBoardSelection(int col, int row);
    void syncPausedState();
    void updatePlacementCountdown(double dtSeconds);
    void startPlacementCountdown();
    void clearPlacementCountdown();
    int findNearestEnemyInRange(const TowerInstance &tower) const;
    float tileCenterX(int col) const;
    float tileCenterY(int row) const;
    int tileDistanceToExit(int col, int row) const;
    float randomRange(float minValue, float maxValue);
    float pathProgressScore(float xPx, float yPx) const;
    int findEnemyIndexById(int enemyId) const;
    int findNearestEnemyIndex(float xPx, float yPx, int excludeEnemyId = -1) const;
    void spawnExplosion(float xPx, float yPx, float radiusTiles);
    TowerInstance createTowerInstance(const std::string &kind, int col, int row) const;
    void queueAudioEvent(towerdefense::SoundType soundId, float volume = 1.0f);

    std::mutex mutex_;
    GlRenderer2D renderer_;
    int surfaceWidth_ = 0;
    int surfaceHeight_ = 0;
    int boardCols_ = 24;
    int boardRows_ = 14;
    int exitCol_ = 22;
    int exitRow_ = 7;
    float tileSize_ = 0.0f;
    float boardLeft_ = 0.0f;
    float boardTop_ = 0.0f;
    int boardViewportLeftPx_ = 0;
    int boardViewportTopPx_ = 0;
    int boardViewportWidthPx_ = 0;
    int boardViewportHeightPx_ = 0;
    float densityScale_ = 1.0f;
    bool paused_ = false;
    bool userPaused_ = true;
    bool lifecyclePaused_ = false;
    bool defeatPaused_ = false;
    bool placementPaused_ = false;
    double placementCountdownAccumulatorSeconds_ = 0.0;
    int activeScreen_ = 0;
    std::string mapId_ = "spiral";
    std::string buildTowerKind_ = "gun";
    std::string placementMessage_;
    std::vector<int> grid_;
    std::vector<int> paths_;
    std::vector<int> distanceField_;
    std::vector<int> spawnPoints_;
    std::vector<EnemyInstance> enemies_;
    std::vector<TowerInstance> towers_;
    std::vector<ProjectileInstance> projectiles_;
    std::vector<ExplosionInstance> explosions_;
    std::vector<TrailParticleInstance> trailParticles_;
    std::vector<EnemyDeathEffect> enemyDeathEffects_;
    std::vector<TempSpawnPoint> tempSpawns_;
    std::vector<std::string> pendingEnemyQueue_;
    std::vector<int> towerCandidatesScratch_;
    std::vector<int> towerTauntsScratch_;
    std::vector<int> towerChainScratch_;
    int health_ = 40;
    int maxHealth_ = 40;
    int cash_ = 55;
    int kills_ = 0;
    int builtCount_ = 0;
    int leakCount_ = 0;
    float totalDamage_ = 0.0f;
    bool buildMode_ = false;
    GameConfigState config_;
    towerdefense::WaveRuntimeState waveRuntime_;
    float pointerX_ = 0.0f;
    float pointerY_ = 0.0f;
    int pointerPhase_ = -1;
    int hoveredCol_ = -1;
    int hoveredRow_ = -1;
    int selectedCol_ = -1;
    int selectedRow_ = -1;
    int pendingPlacementCol_ = -1;
    int pendingPlacementRow_ = -1;
    int pendingPlacementExpiryTick_ = -1;
    double simTimeSeconds_ = 0.0;
    int tickCount_ = 0;
    int runId_ = 1;
    double simAccumulatorSeconds_ = 0.0;
    float renderAlpha_ = 0.0f;
    float proceduralEnemySpeedScale_ = 1.0f;
    float proceduralAverageSpawnDistance_ = 0.0f;
    float lastFrameTimeMs_ = 16.7f;
    float smoothedFrameTimeMs_ = 16.7f;
    float lastFps_ = 60.0f;
    int waveCooldownTicksRemaining_ = 0;
    bool waitingForNextWave_ = false;
    towerdefense::NativeGameSnapshot snapshot_{};
    static constexpr size_t kAudioQueueCapacity = 64;
    std::array<towerdefense::NativeAudioEvent, kAudioQueueCapacity> audioQueue_{};
    size_t audioQueueReadIndex_ = 0;
    size_t audioQueueWriteIndex_ = 0;
    size_t audioQueueSize_ = 0;
    std::chrono::steady_clock::time_point lastFrameAt_ = std::chrono::steady_clock::now();
};

#endif
