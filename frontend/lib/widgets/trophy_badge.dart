import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _TrophyTier {
  final IconData icon;
  final List<Color> colors;
  final bool glow;
  final bool sparkle;

  const _TrophyTier({
    required this.icon,
    required this.colors,
    this.glow = false,
    this.sparkle = false,
  });
}

const Map<String, _TrophyTier> _tiers = {
  'Novice': _TrophyTier(
    icon: Icons.shield_outlined,
    colors: [AppColors.trophyNovice, AppColors.trophyNovice],
  ),
  'Walker': _TrophyTier(
    icon: Icons.emoji_events_outlined,
    colors: [AppColors.trophyWalker, Color(0xFF8C6239)],
  ),
  'Runner': _TrophyTier(
    icon: Icons.emoji_events,
    colors: [Color(0xFFC7CDCB), AppColors.trophyRunner],
  ),
  'Athlete': _TrophyTier(
    icon: Icons.emoji_events,
    colors: [AppColors.primaryLight, AppColors.trophyAthlete],
    glow: true,
  ),
  'Champion': _TrophyTier(
    icon: Icons.emoji_events,
    colors: [Color(0xFFE6C158), AppColors.trophyChampion],
    glow: true,
  ),
  'Legend': _TrophyTier(
    icon: Icons.emoji_events,
    colors: [AppColors.trophyLegendStart, AppColors.trophyLegendEnd],
    glow: true,
    sparkle: true,
  ),
};

/// A tiered trophy badge representing a level title (Novice through Legend).
/// Each tier is visually richer than the last: plain outline, bronze, silver,
/// emerald, gold, then a glowing emerald-to-gold gradient with a sparkle accent.
class TrophyBadge extends StatelessWidget {
  final String title;
  final double size;

  const TrophyBadge({super.key, required this.title, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final tier = _tiers[title] ?? _tiers['Novice']!;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tier.colors,
              ),
              boxShadow: tier.glow
                  ? [
                      BoxShadow(
                        color: tier.colors.last.withValues(alpha: 0.45),
                        blurRadius: size * 0.35,
                        spreadRadius: size * 0.02,
                      ),
                    ]
                  : null,
              border: Border.all(color: AppColors.surface, width: size * 0.045),
            ),
            child: Center(
              child: Icon(tier.icon, color: Colors.white, size: size * 0.52),
            ),
          ),
          if (tier.sparkle)
            Positioned(
              top: -size * 0.06,
              right: -size * 0.06,
              child: Icon(Icons.auto_awesome, color: AppColors.trophyChampion, size: size * 0.32),
            ),
        ],
      ),
    );
  }
}

/// Plays a celebratory pop-in of the trophy — for level-up moments.
class TrophyReveal extends StatelessWidget {
  final String title;
  final double size;

  const TrophyReveal({super.key, required this.title, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value.clamp(0.0, 1.4),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: TrophyBadge(title: title, size: size),
    );
  }
}
