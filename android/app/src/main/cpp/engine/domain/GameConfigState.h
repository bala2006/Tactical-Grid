#ifndef TOWERDEFENSE_GAME_CONFIG_STATE_H
#define TOWERDEFENSE_GAME_CONFIG_STATE_H

struct GameConfigState {
    int difficulty = 1;
    int waveMode = 0;
    int quality = 0;
    // Number of waves to survive for a campaign level. 0 means endless (no win
    // condition) — the classic sandbox behaviour.
    int totalWaves = 0;
    bool effects = true;
    bool healthBars = true;
    bool muted = false;
    bool autoSend = false;
    bool adaptiveQuality = false;
    bool showFps = true;
    bool godMode = false;
    bool firingDisabled = false;
    int zoom = 18;

    void reset() {
        *this = GameConfigState{};
    }
};

#endif
