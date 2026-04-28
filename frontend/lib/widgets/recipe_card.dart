import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

class RecipeCard extends StatelessWidget {
  final String title, time, calories, protein, difficulty;
  final int index;
  final VoidCallback onTap;
  final List<Color>? cardGradientColors;
  final Color? cardFgColor;

  const RecipeCard({
    required this.title, required this.time, required this.calories,
    required this.protein, required this.difficulty, required this.index,
    required this.onTap, this.cardGradientColors, this.cardFgColor, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: cardGradientColors ?? const [Color(0xFFD8EDD4), Color(0xFFC5DFC0)],
                        ),
                      ),
                      child: Center(
                        child: Icon(LucideIcons.chefHat, size: 44, color: cardFgColor ?? const Color(0xFF4A8A46)),
                      ),
                    ),
                    // Difficulty badge
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          difficulty,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info area
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: AppTheme.darkText, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Stat(icon: LucideIcons.clock3, label: time),
                        const SizedBox(width: 8),
                        _Stat(icon: LucideIcons.flame, label: calories, color: AppTheme.orange),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.dumbbell, size: 10, color: AppTheme.greenDark),
                              const SizedBox(width: 3),
                              Text(protein, style: const TextStyle(color: AppTheme.greenDark, fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
      .animate(delay: (index * 60).ms)
      .fadeIn(duration: 350.ms)
      .slideY(begin: 0.12, curve: Curves.easeOutCubic),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Stat({required this.icon, required this.label, this.color = AppTheme.mutedText});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
      ],
    );
  }
}
