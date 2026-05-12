import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';

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
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
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
            Text(
              recipeName,
              style: TextStyle(
                color: AppTheme.textPrimary(context), fontSize: 14,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              '$ingredients · $time',
              style: TextStyle(
                color: AppTheme.textMuted(context), fontSize: 12, fontFamily: 'DM Sans',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronRight, color: AppTheme.textMuted(context), size: 15),
        ]),
      ),
    );
  }
}
