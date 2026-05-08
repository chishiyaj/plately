import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

// ─── PlatelyLogo ───────────────────────────────────────────────────────────────
// Single source of truth for the Plately brand mark.
//
// Usage:
//   PlatelyLogo(theme: PlatelyLogoTheme.onDark)   → tealGradient box + white wordmark
//   PlatelyLogo(theme: PlatelyLogoTheme.onLight)  → greenGradient box + primaryDark wordmark
//   PlatelyLogo(iconSize: 36, wordmarkSize: 18)
//   PlatelyLogo(showWordmark: false)

enum PlatelyLogoTheme { onDark, onLight }

class PlatelyLogo extends StatelessWidget {
  final double iconSize;
  final double wordmarkSize;
  final bool showWordmark;
  final PlatelyLogoTheme theme;

  const PlatelyLogo({
    super.key,
    this.iconSize = 44,
    this.wordmarkSize = 22,
    this.showWordmark = true,
    this.theme = PlatelyLogoTheme.onDark,
  });

  @override
  Widget build(BuildContext context) {
    final isOnDark = theme == PlatelyLogoTheme.onDark;
    const gradient = AppTheme.tealGradient;
    const shadowColor = Color(0xFF043B3C);
    final wordmarkColor = isOnDark ? Colors.white : AppTheme.primaryDark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(iconSize * 0.318),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.40),
                blurRadius: iconSize * 0.36,
                offset: Offset(0, iconSize * 0.09),
              ),
            ],
          ),
          child: Icon(
            LucideIcons.utensils,
            color: Colors.white,
            size: iconSize * 0.455,
          ),
        ),
        if (showWordmark) ...[
          SizedBox(width: iconSize * 0.27),
          Text(
            'Plately',
            style: TextStyle(
              color: wordmarkColor,
              fontSize: wordmarkSize,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ],
    );
  }
}
