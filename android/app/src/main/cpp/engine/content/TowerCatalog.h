#ifndef TOWERDEFENSE_TOWER_CATALOG_H
#define TOWERDEFENSE_TOWER_CATALOG_H

#include <array>
#include <string_view>

#include "GameRuntimeTypes.h"

namespace towerdefense {

struct TowerCatalogEntry {
    TowerKindId kind;
    std::string_view kindId;
    std::string_view title;
    int cost;
    float damageMin;
    float damageMax;
    float range;
    int cooldownMin;
    int cooldownMax;
    std::string_view damageTypeLabel;
    std::string_view effectText;
    unsigned int displayColor;
    bool storeVisible;
    std::string_view targetingText;
    TowerKindId nextUpgradeKind = TowerKindId::Unknown;
    std::string_view nextUpgradeKindId;
    // When true the tower is intentionally damage-free (utility/status only) and is
    // exempt from the "no zero-damage tower" content invariant in validateContent().
    bool statusOnly = false;
};

const TowerCatalogEntry *findTowerCatalogEntry(std::string_view kindId);
const TowerCatalogEntry *findTowerCatalogEntry(TowerKindId kindId);
const TowerCatalogEntry *findNextTowerUpgrade(std::string_view kindId);
const TowerCatalogEntry *findNextTowerUpgrade(TowerKindId kindId);
const std::array<TowerCatalogEntry, 20> &towerCatalogEntries();

}  // namespace towerdefense

#endif
