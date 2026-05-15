import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animations/animations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ingredient_entry_screen.dart';

// ─── MainShell ────────────────────────────────────────────────────────────────
// Single root widget owning the bottom nav + all 4 tab bodies.
// IndexedStack keeps every tab alive -- no rebuilds on switch.
// FAB center navigates to IngredientEntryScreen (full-screen push).
// Profile avatar on HomeScreen calls MainShell.switchTab(3) -- no duplicate push.

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  // Static accessor so HomeScreen can switch to Profile tab without a push
  static _MainShellState? _instance;
  static void switchTab(int shellIndex) {
    if (_instance != null && _instance!.mounted) _instance!._switchTab(shellIndex);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _current = 0;
  int _previous = 0;

  // Tab order: 0=Home, 1=Favorites, 2=AiChat, 3=Profile
  // Nav indices: 0=Home, 1=Saved, 2=Scan(FAB), 3=AI, 4=Profile
  static const _tabScreens = [
    HomeScreen(),
    FavoritesScreen(),
    AiChatScreen(),
    ProfileScreen(),
  ];

  static const _navIndexMap = [0, 1, 3, 4];

  @override
  void initState() {
    super.initState();
    MainShell._instance = this;
  }

  @override
  void dispose() {
    if (MainShell._instance == this) MainShell._instance = null;
    super.dispose();
  }

  void _switchTab(int shellIndex) {
    if (shellIndex == _current) return;
    setState(() {
      _previous = _current;
      _current  = shellIndex;
    });
  }

  void _onNavTap(int navIndex) {
    if (navIndex == 2) {
      Navigator.push(context, AppTheme.slideUp(const IngredientEntryScreen()));
      return;
    }
    final shellIndex = switch (navIndex) {
      0 => 0,
      1 => 1,
      3 => 2,
      4 => 3,
      _ => 0,
    };
    _switchTab(shellIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      resizeToAvoidBottomInset: false,
      extendBody: true, // needed so other tabs' content scrolls behind the floating pill nav
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        reverse: _current < _previous,
        transitionBuilder: (child, anim, secAnim) => SharedAxisTransition(
          animation: anim,
          secondaryAnimation: secAnim,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: AppTheme.scaffoldBg(context),
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_current),
          child: _tabScreens[_current],
        ),
      ),
      bottomNavigationBar: _ShellNav(
        currentNavIndex: _navIndexMap[_current],
        onTap: _onNavTap,
      ),
    );
  }
}

// ─── Shell Bottom Nav ─────────────────────────────────────────────────────────
class _ShellNav extends StatelessWidget {
  final int currentNavIndex;
  final ValueChanged<int> onTap;
  const _ShellNav({required this.currentNavIndex, required this.onTap});

  static const _items = [
    (icon: LucideIcons.house,      label: 'Home',    index: 0),
    (icon: LucideIcons.heart,      label: 'Saved',   index: 1),
    (icon: LucideIcons.scanLine,   label: 'Scan',    index: 2),
    (icon: LucideIcons.chefHat,    label: 'AI',      index: 3),
    (icon: LucideIcons.circleUser, label: 'Profile', index: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          SizedBox(
            height: 76,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.93),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: _items.map((item) {
                      if (item.index == 2) return const Expanded(child: SizedBox());
                      return _NavItem(
                        icon: item.icon, label: item.label,
                        index: item.index, current: currentNavIndex,
                        onTap: onTap,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            child: _ScanFab(onTap: () => onTap(2)),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  const _NavItem({required this.icon, required this.label, required this.index,
      required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppTheme.green.withValues(alpha: 0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20,
                  color: active ? AppTheme.green : Colors.white.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: active ? AppTheme.green : Colors.white.withValues(alpha: 0.35),
                fontSize: 10, fontFamily: 'DM Sans',
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// FAB -- sits above nav bar, unclipped via Stack(clipBehavior: Clip.none)
class _ScanFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanFab({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.mediumImpact();
      onTap();
    },
    child: Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        gradient: AppTheme.tealGradient,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.scaffoldBg(context), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x88043B3C), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: const Icon(LucideIcons.scanLine, color: Colors.white, size: 24),
    ),
  );
}
