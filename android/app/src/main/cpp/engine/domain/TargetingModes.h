#ifndef TOWERDEFENSE_TARGETING_MODES_H
#define TOWERDEFENSE_TARGETING_MODES_H

#include <string_view>

namespace towerdefense {

enum class TargetingMode : int {
    First = 0,
    Nearest = 1,
    Strongest = 2,
};

inline constexpr std::string_view targetingModeId(TargetingMode mode) {
    switch (mode) {
        case TargetingMode::First:
            return "first";
        case TargetingMode::Nearest:
            return "nearest";
        case TargetingMode::Strongest:
            return "strongest";
        default:
            return "first";
    }
}

inline constexpr std::string_view targetingModeLabel(TargetingMode mode) {
    switch (mode) {
        case TargetingMode::First:
            return "First";
        case TargetingMode::Nearest:
            return "Nearest";
        case TargetingMode::Strongest:
            return "Strongest";
        default:
            return "First";
    }
}

inline constexpr TargetingMode parseTargetingMode(std::string_view id) {
    if (id == "first") {
        return TargetingMode::First;
    }
    if (id == "nearest") {
        return TargetingMode::Nearest;
    }
    if (id == "strongest") {
        return TargetingMode::Strongest;
    }
    return TargetingMode::First;
}

inline constexpr bool isValidTargetingModeId(std::string_view id) {
    return id == "first" || id == "nearest" || id == "strongest";
}

}  // namespace towerdefense

#endif
