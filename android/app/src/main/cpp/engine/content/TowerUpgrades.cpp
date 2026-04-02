#include "TowerUpgrades.h"

#include <cmath>

namespace towerdefense {

int computeSellPrice(int investedCost) {
    return std::max(0, static_cast<int>(std::floor(static_cast<float>(investedCost) * 0.75f)));
}

const TowerCatalogEntry *nextTowerUpgrade(std::string_view kindId) {
    return findNextTowerUpgrade(kindId);
}

const TowerCatalogEntry *nextTowerUpgrade(TowerKindId kindId) {
    return findNextTowerUpgrade(kindId);
}

int computeUpgradePrice(std::string_view kindId) {
    const TowerCatalogEntry *entry = nextTowerUpgrade(kindId);
    return entry != nullptr ? entry->cost : 0;
}

int computeUpgradePrice(TowerKindId kindId) {
    const TowerCatalogEntry *entry = nextTowerUpgrade(kindId);
    return entry != nullptr ? entry->cost : 0;
}

bool applyTowerUpgrade(TowerRuntime &tower) {
    const TowerCatalogEntry *entry = nextTowerUpgrade(tower.kindId);
    if (entry == nullptr) {
        return false;
    }

    tower.kindId = entry->kind;
    tower.kind = std::string(entry->kindId);
    tower.cooldownMin = entry->cooldownMin;
    tower.cooldownMax = entry->cooldownMax;
    tower.range = entry->range;
    tower.damageMin = entry->damageMin;
    tower.damageMax = entry->damageMax;
    tower.investedCost += entry->cost;
    tower.level = 2;
    tower.upgradeCount = 1;
    tower.cooldown = 0;
    tower.flash = 0.0f;
    tower.recoil = 0.0f;
    tower.beamTicks = 0;
    tower.lastTargetEnemyId = -1;
    tower.beamChargeTicks = 0;
    if (tower.kindId == TowerKindId::Slow) {
        tower.slowFactor = 0.5f;
        tower.slowTicks = 40;
    } else {
        tower.slowFactor = 1.0f;
        tower.slowTicks = 0;
    }
    return true;
}

}  // namespace towerdefense
