#include "WaveRuntime.h"

#include <algorithm>

namespace towerdefense {

void resetWaveRuntime(WaveRuntimeState &state) {
    state.waveNumber = 1;
    state.totalTicks = 0;
    state.ticksInWave = 0;
    state.ticksPerWave = std::max(1, state.ticksPerWave);
    state.spawnCooldownTicks = std::max(1, state.spawnCooldownTicks);
    state.spawnTickCounter = 0;
    state.nextSpawnIndex = 0;
    state.paused = false;
    state.waveActive = false;
    state.defeated = false;
}

void tickSpawnCadence(WaveRuntimeState &state) {
    state.spawnCooldownTicks = std::max(1, state.spawnCooldownTicks);
    if (state.spawnTickCounter <= 0) {
        state.spawnTickCounter = state.spawnCooldownTicks;
        state.waveActive = true;
        return;
    }
    --state.spawnTickCounter;
}

bool advanceWaveByTicks(WaveRuntimeState &state, int ticksElapsed) {
    if (ticksElapsed <= 0) {
        return false;
    }

    const int clampedTicks = std::max(0, ticksElapsed);
    state.totalTicks += clampedTicks;
    state.ticksInWave += clampedTicks;
    state.ticksPerWave = std::max(1, state.ticksPerWave);

    if (state.ticksInWave < state.ticksPerWave) {
        return false;
    }

    const int completedWaves = state.ticksInWave / state.ticksPerWave;
    state.waveNumber += completedWaves;
    state.ticksInWave %= state.ticksPerWave;
    state.nextSpawnIndex = 0;
    state.spawnTickCounter = 0;
    state.waveActive = false;
    return true;
}

std::string_view waveStateLabel(const WaveRuntimeState &state) {
    if (state.defeated) {
        return "Defeated";
    }
    if (state.paused) {
        return "Paused";
    }
    if (state.waveActive) {
        return "Engaged";
    }
    return "Standby";
}

}  // namespace towerdefense
