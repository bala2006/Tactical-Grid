#include "WaveSpec.h"

#include <algorithm>

namespace towerdefense {

int clampDifficultyLevel(int difficulty) {
    return std::clamp(difficulty, 0, 2);
}

std::string_view chooseWaveArchetypeId(int waveNumber, int difficulty) {
    const int wave = std::max(1, waveNumber);
    const int difficultyLevel = clampDifficultyLevel(difficulty);

    if (wave <= 3 + difficultyLevel) {
        return "grunt";
    }
    if (wave <= 8 + difficultyLevel * 2) {
        return "runner";
    }
    return "brute";
}

int spawnCooldownTicksForWave(int waveNumber, int difficulty) {
    const int wave = std::max(1, waveNumber);
    const int difficultyLevel = clampDifficultyLevel(difficulty);
    const std::string_view archetypeId = chooseWaveArchetypeId(wave, difficultyLevel);

    int baseCooldown = 24;
    if (archetypeId == "runner") {
        baseCooldown = 18;
    } else if (archetypeId == "brute") {
        baseCooldown = 30;
    }

    const int wavePressure = std::min(10, (wave - 1) / 2);
    const int difficultyBias = difficultyLevel * 2;
    return std::max(8, baseCooldown - wavePressure - difficultyBias);
}

int burstCountForWave(int waveNumber, int difficulty) {
    const int wave = std::max(1, waveNumber);
    const int difficultyLevel = clampDifficultyLevel(difficulty);
    const int burst = 1 + (wave + difficultyLevel) / 6;
    return std::clamp(burst, 1, 3);
}

WaveSpec makeWaveSpec(int waveNumber, int difficulty) {
    const int wave = std::max(1, waveNumber);
    WaveSpec spec;
    spec.archetypeId = chooseWaveArchetypeId(wave, difficulty);
    spec.spawnCooldownTicks = spawnCooldownTicksForWave(wave, difficulty);
    spec.burstCount = burstCountForWave(wave, difficulty);
    spec.waveDurationTicks = std::max(360, 540 - (wave * 8) - (clampDifficultyLevel(difficulty) * 24));
    return spec;
}

}  // namespace towerdefense
