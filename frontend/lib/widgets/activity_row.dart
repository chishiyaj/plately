import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Reusable activity row — used in Home preview and History screen
class ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String time;
  final String count;
  final VoidCallback? onTap;

  const ActivityRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.count,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderGray),
        ),
        child: Row(
          children: [
            // Colored icon box
            Container(
              width: 49, height: 48,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: AppTheme.primaryDark),
            ),
            const SizedBox(width: 14),
            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.darkText, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w500, letterSpacing: 0.26)),
                  Text(subtitle, style: AppTheme.bodySmall),
                  Text(time, style: AppTheme.caption),
                ],
              ),
            ),
            // Recipe count badge
            Text(count, style: const TextStyle(color: AppTheme.darkText, fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
