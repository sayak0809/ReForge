import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/trophy_badge.dart';

class _TierInfo {
  final String title;
  final int minLevel;
  final int? maxLevel; // null = no upper bound

  const _TierInfo(this.title, this.minLevel, this.maxLevel);

  String get levelRange => maxLevel == null ? 'Level $minLevel+' : 'Level $minLevel–$maxLevel';
}

const _tiers = [
  _TierInfo('Novice', 1, 4),
  _TierInfo('Walker', 5, 9),
  _TierInfo('Runner', 10, 14),
  _TierInfo('Athlete', 15, 19),
  _TierInfo('Champion', 20, 29),
  _TierInfo('Legend', 30, null),
];

/// Mirrors xp_service.py's _xp_required_for_level exactly: cumulative XP
/// needed to reach a level is a triangular number * 100.
int _xpRequiredForLevel(int level) => (level - 1) * level ~/ 2 * 100;

class TrophyTiersScreen extends StatelessWidget {
  final int currentLevel;

  const TrophyTiersScreen({super.key, required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        title: const Text(
          'TROPHY TIERS',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _tiers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildTierCard(_tiers[index]),
      ),
    );
  }

  Widget _buildTierCard(_TierInfo tier) {
    final maxLevel = tier.maxLevel;
    final isCurrent = currentLevel >= tier.minLevel && (maxLevel == null || currentLevel <= maxLevel);
    final xpRequired = _xpRequiredForLevel(tier.minLevel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        children: [
          TrophyBadge(title: tier.title, size: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tier.title,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(tier.levelRange, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  xpRequired == 0 ? 'Starting tier' : '$xpRequired XP to unlock',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
