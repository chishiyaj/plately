import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

class AiTipCard extends StatelessWidget {
  final String tip;
  const AiTipCard({required this.tip, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryDark.withValues(alpha: 0.06),
            AppTheme.primaryMid.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: AppTheme.tealGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Tip',
                  style: TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(tip, style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans', height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
