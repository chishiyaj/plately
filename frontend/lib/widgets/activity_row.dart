import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';

// ─── ActivityRow ──────────────────────────────────────────────────────────────
// Shared widget — HomeScreen recent activity + HistoryScreen timeline.
// One source of truth, never duplicate.
//
// Each row = ONE cooking session. User may have scanned AND typed ingredients
// in the same session — we don't separate them. We show the result: what they
// cooked, what ingredients they used, and when.
//
// Usage:
//   ActivityRow(
//     recipeName: 'Chicken Stir Fry',
//     ingredients: 'Chicken, Garlic, Onion',
//     time: 'Today, 2:30 PM',
//     onTap: () { ... },
//   )

class ActivityRow extends StatelessWidget {
  final String recipeName;
  final String ingredients;
  final String time;
  final VoidCallback? onTap;

  const ActivityRow({
    required this.recipeName,
    required this.ingredients,
    required this.time,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap ?? () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          // chefHat badge — represents a completed cook session
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppTheme.scanGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(LucideIcons.chefHat, color: AppTheme.primaryDark, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Primary: what they cooked
            Text(
              recipeName,
              style: const TextStyle(
                color: AppTheme.darkText, fontSize: 14,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            // Secondary: ingredients used · time
            Text(
              '$ingredients · $time',
              style: const TextStyle(
                color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          const SizedBox(width: 8),
          const Icon(LucideIcons.chevronRight, color: AppTheme.mutedText, size: 15),
        ]),
      ),
    );
  }
}
