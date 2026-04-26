import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

class PlatelyBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScanTap;

  const PlatelyBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onScanTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                _NavItem(icon: LucideIcons.house,       label: 'Home',      index: 0, current: currentIndex, onTap: onTap),
                _NavItem(icon: LucideIcons.heart,       label: 'Saved',     index: 1, current: currentIndex, onTap: onTap),
                _ScanButton(onTap: onScanTap),
                _NavItem(icon: LucideIcons.messageCircle, label: 'AI',      index: 3, current: currentIndex, onTap: onTap),
                _NavItem(icon: LucideIcons.circleUser,  label: 'Profile',   index: 4, current: currentIndex, onTap: onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon, required this.label,
    required this.index, required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppTheme.green.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: active ? AppTheme.green : Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppTheme.green : Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                  fontFamily: 'DM Sans',
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            width: 50, height: 50,
            decoration: const BoxDecoration(
              gradient: AppTheme.tealGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x66043B3C), blurRadius: 14, offset: Offset(0, 4)),
              ],
            ),
            child: const Icon(LucideIcons.scanLine, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
