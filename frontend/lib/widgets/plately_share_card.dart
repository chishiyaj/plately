import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'plately_logo.dart';

/// Standalone share card for post-cook sharing.
/// Rendered via ScreenshotController then shared as PNG.
class PlatelyShareCard extends StatelessWidget {
  final String dishName;
  final int calories;
  final int protein;
  final int streak;

  const PlatelyShareCard({
    super.key,
    required this.dishName,
    required this.calories,
    required this.protein,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 498, // ~9:16 portrait
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Radial green glow top-right
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.green.withValues(alpha: 0.20),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Bottom glow
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primaryDark.withValues(alpha: 0.0),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                const PlatelyLogo(
                  iconSize: 34,
                  wordmarkSize: 15,
                  theme: PlatelyLogoTheme.onDark,
                ),

                const SizedBox(height: 36),

                // "just cooked" label
                Text(
                  'just cooked',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Dish name
                Text(
                  dishName,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 24),

                // Macro pills
                Row(
                  children: [
                    _MacroPill(label: '$calories kcal', icon: LucideIcons.flame),
                    const SizedBox(width: 10),
                    _MacroPill(label: '${protein}g protein', icon: LucideIcons.dumbbell),
                  ],
                ),

                const SizedBox(height: 20),

                // Streak badge
                if (streak >= 2)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.yellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.yellow.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 7),
                        Text(
                          '$streak day streak',
                          style: const TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.orange,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Divider
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 14),

                // Footer
                Row(
                  children: [
                    const Icon(LucideIcons.trendingUp, color: AppTheme.green, size: 14),
                    const SizedBox(width: 7),
                    Text(
                      'track yours → plately.app',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MacroPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.green.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.green),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.green,
            ),
          ),
        ],
      ),
    );
  }
}
