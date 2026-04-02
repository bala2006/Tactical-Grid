#include "TowerCatalog.h"

namespace towerdefense {

namespace {

constexpr std::array<TowerCatalogEntry, 14> kTowerCatalogEntries = {{
    {
        TowerKindId::Gun,
        "gun",
        "Gun Tower",
        25,
        1.0f,
        20.0f,
        3.0f,
        8,
        18,
        "PHYSICAL",
        "Light autocannon with reliable kinetic fire",
        0xFF567060,
        true,
        "Targets the leading enemy",
        TowerKindId::MachineGun,
        "machineGun",
    },
    {
        TowerKindId::MachineGun,
        "machineGun",
        "Machine Gun",
        75,
        0.0f,
        10.0f,
        3.0f,
        0,
        5,
        "PHYSICAL",
        "High-rate cannon with sustained suppressive fire",
        0xFF56767E,
        false,
        "Targets the leading enemy",
        TowerKindId::Unknown,
        "",
    },
    {
        TowerKindId::Laser,
        "laser",
        "Laser Tower",
        75,
        1.0f,
        3.0f,
        2.0f,
        0,
        1,
        "ENERGY",
        "Directed-energy turret for close defense",
        0xFF787853,
        true,
        "Targets the leading enemy",
        TowerKindId::BeamEmitter,
        "beamEmitter",
    },
    {
        TowerKindId::BeamEmitter,
        "beamEmitter",
        "Beam Emitter",
        200,
        1.0f,
        4.0f,
        3.0f,
        0,
        0,
        "ENERGY",
        "Beam dwell time compounds thermal damage",
        0xFF959B6B,
        false,
        "Targets the leading enemy",
        TowerKindId::Unknown,
        "",
    },
    {
        TowerKindId::Slow,
        "slow",
        "Slow Tower",
        100,
        0.0f,
        0.0f,
        1.0f,
        0,
        0,
        "SLOW",
        "Area denial emitter disrupts enemy movement",
        0xFF606E62,
        true,
        "Affects all enemies in range",
        TowerKindId::Poison,
        "poison",
    },
    {
        TowerKindId::Poison,
        "poison",
        "Poison Tower",
        150,
        0.0f,
        0.0f,
        2.0f,
        60,
        60,
        "POISON",
        "Chemical dispersal damages targets over time",
        0xFF568072,
        false,
        "Affects all enemies in range",
        TowerKindId::Unknown,
        "",
    },
    {
        TowerKindId::Sniper,
        "sniper",
        "Sniper Tower",
        150,
        100.0f,
        100.0f,
        9.0f,
        60,
        100,
        "PHYSICAL",
        "Long-range anti-materiel rifle",
        0xFF5A666C,
        true,
        "Targets the strongest visible enemy",
        TowerKindId::Railgun,
        "railgun",
    },
    {
        TowerKindId::Railgun,
        "railgun",
        "Railgun",
        300,
        200.0f,
        200.0f,
        11.0f,
        100,
        120,
        "PIERCING",
        "Electromagnetic slug impacts nearby armored targets",
        0xFF665A55,
        false,
        "Targets the strongest visible enemy",
        TowerKindId::Unknown,
        "",
    },
    {
        TowerKindId::Rocket,
        "rocket",
        "Rocket Tower",
        250,
        40.0f,
        60.0f,
        7.0f,
        60,
        80,
        "EXPLOSION",
        "Guided micro-missiles with blast damage",
        0xFF52725E,
        true,
        "Targets the nearest valid enemy within range",
        TowerKindId::MissileSilo,
        "missileSilo",
    },
    {
        TowerKindId::MissileSilo,
        "missileSilo",
        "Missile Silo",
        250,
        100.0f,
        120.0f,
        9.0f,
        40,
        80,
        "EXPLOSION",
        "Heavier missiles with larger shaped blasts",
        0xFF8A7E70,
        false,
        "Targets the nearest valid enemy within range",
        TowerKindId::Unknown,
        "",
    },
    {
        TowerKindId::Bomb,
        "bomb",
        "Bomb Tower",
        250,
        20.0f,
        60.0f,
        2.0f,
        40,
        60,
        "EXPLOSION",
        "Short-range mortar with fragmentation blast",
        0xFF526167,
        true,
        "Targets the leading enemy",
        TowerKindId::ClusterBomb,
        "clusterBomb",
    },
    {
        TowerKindId::ClusterBomb,
        "clusterBomb",
        "Cluster Bomb",
        250,
        100.0f,
        140.0f,
        2.0f,
        40,
        80,
        "EXPLOSION",
        "Splits into multiple secondary explosions",
        0xFF616752,
        false,
        "Targets the leading enemy",
        TowerKindId::Unknown,
        "",
    },
    {
        TowerKindId::Tesla,
        "tesla",
        "Tesla Coil",
        350,
        256.0f,
        512.0f,
        4.0f,
        60,
        80,
        "ENERGY",
        "Prototype coil discharge chaining through nearby targets",
        0xFFC6BCA8,
        true,
        "Targets the leading enemy, then chains",
        TowerKindId::Plasma,
        "plasma",
    },
    {
        TowerKindId::Plasma,
        "plasma",
        "Plasma Tower",
        250,
        1024.0f,
        2048.0f,
        4.0f,
        40,
        60,
        "ENERGY",
        "Higher-output plasma discharge with faster recovery",
        0xFFD6C68E,
        false,
        "Targets the leading enemy, then chains",
        TowerKindId::Unknown,
        "",
    },
}};

}  // namespace

const std::array<TowerCatalogEntry, 14> &towerCatalogEntries() {
    return kTowerCatalogEntries;
}

const TowerCatalogEntry *findTowerCatalogEntry(std::string_view kindId) {
    for (const TowerCatalogEntry &entry : kTowerCatalogEntries) {
        if (entry.kindId == kindId) {
            return &entry;
        }
    }
    return nullptr;
}

const TowerCatalogEntry *findTowerCatalogEntry(TowerKindId kindId) {
    for (const TowerCatalogEntry &entry : kTowerCatalogEntries) {
        if (entry.kind == kindId) {
            return &entry;
        }
    }
    return nullptr;
}

const TowerCatalogEntry *findNextTowerUpgrade(std::string_view kindId) {
    const TowerCatalogEntry *entry = findTowerCatalogEntry(kindId);
    if (entry == nullptr || entry->nextUpgradeKindId.empty()) {
        return nullptr;
    }
    return findTowerCatalogEntry(entry->nextUpgradeKindId);
}

const TowerCatalogEntry *findNextTowerUpgrade(TowerKindId kindId) {
    const TowerCatalogEntry *entry = findTowerCatalogEntry(kindId);
    if (entry == nullptr || entry->nextUpgradeKind == TowerKindId::Unknown) {
        return nullptr;
    }
    return findTowerCatalogEntry(entry->nextUpgradeKind);
}

}  // namespace towerdefense
