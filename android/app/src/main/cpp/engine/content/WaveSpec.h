#ifndef TOWERDEFENSE_WAVE_SPEC_H
#define TOWERDEFENSE_WAVE_SPEC_H

#include <string_view>

namespace towerdefense {

struct WaveSpec {
    std::string_view archetypeId;
    int spawnCooldownTicks;
    int burstCount;
    int waveDurationTicks;
};

int clampDifficultyLevel(int difficulty);
std::string_view chooseWaveArchetypeId(int waveNumber, int difficulty);
int spawnCooldownTicksForWave(int waveNumber, int difficulty);
int burstCountForWave(int waveNumber, int difficulty);
WaveSpec makeWaveSpec(int waveNumber, int difficulty);

}  // namespace towerdefense

#endif
