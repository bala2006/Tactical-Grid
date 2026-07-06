import 'package:flutter/material.dart';

import '../../../game/domain/content.dart';
import '../../../game/domain/models.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/domain/profile.dart';
import '../../../progression/domain/shop.dart';
import '../game_theme.dart';
import 'screen_chrome.dart';

/// Spend crystals to permanently unlock turrets. Presented as a scannable list:
/// each row shows the turret's role and key combat stats (damage, range, fire
/// rate) alongside its unlock cost, so the trade-off is clear at a glance.
class ShopScreen extends StatelessWidget {
  const ShopScreen({
    required this.progression,
    required this.onBack,
    super.key,
  });

  final ProgressionController progression;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return TacticalBackground(
      key: const ValueKey<String>('shop'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GameSpace.sm),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ValueListenableBuilder<PlayerProfile>(
                valueListenable: progression.profileListenable,
                builder: (BuildContext context, PlayerProfile profile, _) {
                  final int owned = Shop.towerUnlocks
                      .where((TowerUnlock u) => progression.isTowerUnlocked(u.kind))
                      .length;
                  return GlassPanel(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        ScreenHeader(
                          eyebrow: 'PROCUREMENT',
                          title: 'Armory',
                          onBack: onBack,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _Pill(
                                label: 'UNLOCKED',
                                value: '$owned/${Shop.towerUnlocks.length}',
                              ),
                              const SizedBox(width: 8),
                              ResourceBadge(
                                icon: Icons.diamond_rounded,
                                color: GameColors.crystal,
                                label: '${profile.crystals}',
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Unlock advanced turrets with crystals earned from star '
                          'ratings and bonus objectives.',
                          style: TextStyle(
                            color: GameColors.muted,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: Shop.towerUnlocks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (BuildContext context, int index) {
                              final TowerUnlock unlock =
                                  Shop.towerUnlocks[index];
                              return _UnlockRow(
                                unlock: unlock,
                                owned: progression.isTowerUnlocked(unlock.kind),
                                affordable:
                                    profile.crystals >= unlock.crystalCost,
                                onBuy: () => progression.unlockTower(unlock),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GameColors.panelStrong,
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        border: Border.all(color: GameColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          Text(
            label,
            style: const TextStyle(
              color: GameColors.muted,
              fontSize: 7.5,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockRow extends StatelessWidget {
  const _UnlockRow({
    required this.unlock,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });

  final TowerUnlock unlock;
  final bool owned;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final TowerBlueprint? bp = towerBlueprints[unlock.kind];
    final String title = bp?.title ?? unlock.kind.name;
    final DamageType type = bp?.damageType ?? DamageType.physical;
    final Color accent = GameColors.forDamageType(type);
    final bool statusOnly = bp == null || bp.damageMax <= 0;

    final String dmg = bp == null || statusOnly
        ? '—'
        : '${bp.damageMin.round()}–${bp.damageMax.round()}';
    final String range = bp == null ? '—' : bp.range.toStringAsFixed(1);
    final double avgCd =
        bp == null ? 0 : (bp.cooldownMin + bp.cooldownMax) / 2;
    final String rate = avgCd <= 0
        ? '—'
        : '${(60 / avgCd).toStringAsFixed((60 / avgCd) >= 10 ? 0 : 1)}/s';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            accent.withValues(alpha: owned ? 0.14 : 0.09),
            GameColors.panel,
          ],
        ),
        borderRadius: BorderRadius.circular(GameSpace.radiusLg),
        border: Border.all(
          color: owned
              ? GameColors.success.withValues(alpha: 0.55)
              : accent.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Identity icon.
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(GameSpace.radiusMd),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Icon(towerKindIcon(unlock.kind), color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            // Name, type, blurb, stats.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(label: damageTypeLabel(type), color: accent),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    unlock.blurb,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GameColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: <Widget>[
                      _Stat(
                        label: statusOnly ? 'TYPE' : 'DMG',
                        value: statusOnly ? 'Utility' : dmg,
                      ),
                      _StatDivider(),
                      _Stat(label: 'RNG', value: range),
                      _StatDivider(),
                      _Stat(label: 'RATE', value: rate),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Action.
            SizedBox(
              width: 124,
              child: owned ? const _OwnedBadge() : _buyButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buyButton() {
    return TacticalButton(
      label: '${unlock.crystalCost}',
      icon: Icons.diamond_rounded,
      dense: true,
      variant: affordable
          ? TacticalButtonVariant.primary
          : TacticalButtonVariant.secondary,
      onPressed: affordable ? onBuy : null,
    );
  }
}

class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: GameColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        border: Border.all(color: GameColors.success.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.check_circle_rounded, color: GameColors.success, size: 15),
          SizedBox(width: 5),
          Text(
            'DEPLOYED',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.8,
              color: GameColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: GameColors.faint,
            fontSize: 8.5,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: GameColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: GameColors.border,
    );
  }
}
