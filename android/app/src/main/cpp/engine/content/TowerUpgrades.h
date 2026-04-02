#ifndef TOWERDEFENSE_TOWER_UPGRADES_H
#define TOWERDEFENSE_TOWER_UPGRADES_H

#include "GameRuntimeTypes.h"
#include "TowerCatalog.h"

namespace towerdefense {

int computeSellPrice(int investedCost);
int computeUpgradePrice(std::string_view kindId);
int computeUpgradePrice(TowerKindId kindId);
const TowerCatalogEntry *nextTowerUpgrade(std::string_view kindId);
const TowerCatalogEntry *nextTowerUpgrade(TowerKindId kindId);
bool applyTowerUpgrade(TowerRuntime &tower);

}  // namespace towerdefense

#endif
