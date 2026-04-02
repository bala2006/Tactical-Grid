#ifndef TOWERDEFENSE_TOWER_CATALOG_H
#define TOWERDEFENSE_TOWER_CATALOG_H

#include <array>
#include <string_view>

namespace towerdefense {

struct TowerCatalogEntry {
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
    std::string_view nextUpgradeKindId;
};

const TowerCatalogEntry *findTowerCatalogEntry(std::string_view kindId);
const TowerCatalogEntry *findNextTowerUpgrade(std::string_view kindId);
const std::array<TowerCatalogEntry, 14> &towerCatalogEntries();

}  // namespace towerdefense

#endif
