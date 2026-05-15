import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'plately_logo.dart';

/// Post-cook share card -- screenshot-able via ScreenshotController.
/// Design: recipe image hero at top, cream card body, colored macro pills, Plately footer.
class PlatelyShareCard extends StatelessWidget {
  final String dishName;
  final int calories;
  final int protein;
  final int streak;
  final String? imageUrl;

  const PlatelyShareCard({
    super.key,
    required this.dishName,
    required this.calories,
    required this.protein,
    required this.streak,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEE9), // creamBg -- always light
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Recipe image hero ──────────────────────────────────────────
          _imageHero(),

          // ── Card body ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "just cooked" eyebrow
                Text(
                  'JUST COOKED',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppTheme.primaryDark.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 5),

                // Dish name
                Text(
                  dishName,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                    height: 1.15,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 14),

                // Macro pills
                Row(
                  children: [
                    _MacroPill(
                      label: '$calories kcal',
                      icon: LucideIcons.flame,
                      bg: AppTheme.green.withValues(alpha: 0.12),
                      border: AppTheme.green.withValues(alpha: 0.30),
                      iconColor: AppTheme.green,
                      textColor: const Color(0xFF2A6010),
                    ),
                    const SizedBox(width: 8),
                    _MacroPill(
                      label: '${protein}g protein',
                      icon: LucideIcons.dumbbell,
                      bg: const Color(0xFFBA5CCC).withValues(alpha: 0.10),
                      border: const Color(0xFFBA5CCC).withValues(alpha: 0.28),
                      iconColor: const Color(0xFFBA5CCC),
                      textColor: const Color(0xFF7A2E8A),
                    ),
                  ],
                ),

                // Streak badge (if ≥ 2)
                if (streak >= 2) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEABA1C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFEABA1C).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          '$streak day streak',
                          style: const TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB07C00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────
          Container(
            color: AppTheme.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                const PlatelyLogo(
                  theme: PlatelyLogoTheme.onDark,
                  iconSize: 22,
                  wordmarkSize: 11,
                ),
                const Spacer(),
                Text(
                  'Know your macros before you cook',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageHero() {
    const height = 170.0;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholderHero(height),
          errorWidget: (_, __, ___) => _placeholderHero(height),
        ),
      );
    }
    return _placeholderHero(height);
  }

  Widget _placeholderHero(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF043B3C), Color(0xFF0A5A5B)],
        ),
      ),
      child: Center(
        child: Icon(
          LucideIcons.utensils,
          size: 42,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color border;
  final Color iconColor;
  final Color textColor;

  const _MacroPill({
    required this.label,
    required this.icon,
    required this.bg,
    required this.border,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
