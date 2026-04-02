#ifndef TOWERDEFENSE_WAVE_RUNTIME_H
#define TOWERDEFENSE_WAVE_RUNTIME_H

#include <string_view>

#include "GameRuntimeTypes.h"

namespace towerdefense {

void resetWaveRuntime(WaveRuntimeState &state);
void tickSpawnCadence(WaveRuntimeState &state);
bool advanceWaveByTicks(WaveRuntimeState &state, int ticksElapsed);
std::string_view waveStateLabel(const WaveRuntimeState &state);

}  // namespace towerdefense

#endif
