import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../widgets/activity_row.dart';
import 'recipe_results_screen.dart';

// ─── HistoryScreen — Your Activity ───────────────────────────────────────────
// Timeline of what the user COOKED — one session per row.
// A session = one cook event. User may have scanned AND/OR typed ingredients
// in the same session. We don't separate them — we show the result.

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _grouped = [
    _Group(label: 'Today', entries: [
      _Entry(
        recipeName: 'Chicken Stir Fry',
        ingredients: 'Chicken, Garlic, Onion',
        time: '2:30 PM',
      ),
      _Entry(
        recipeName: 'Cheesy Scrambled Eggs',
        ingredients: 'Eggs, Tomato, Cheese',
        time: '11:00 AM',
      ),
    ]),
    _Group(label: 'Yesterday', entries: [
      _Entry(
        recipeName: 'Beef & Broccoli Bowl',
        ingredients: 'Beef, Broccoli',
        time: '7:00 PM',
      ),
    ]),
    _Group(label: 'This Week', entries: [
      _Entry(
        recipeName: 'Veggie Stir Fry',
        ingredients: 'Mixed Vegetables',
        time: 'Mon 6:00 PM',
      ),
      _Entry(
        recipeName: 'Garlic Fried Rice',
        ingredients: 'Rice, Garlic, Soy Sauce',
        time: 'Tue 1:00 PM',
      ),
    ]),
    _Group(label: 'Older', entries: [
      _Entry(
        recipeName: 'Tomato Pasta',
        ingredients: 'Pasta, Cheese, Tomato',
        time: 'Last week',
      ),
    ]),
  ];

  void _openResults(BuildContext context, _Entry e) {
    final ings = e.ingredients.split(',').map((s) => s.trim()).toList();
    Navigator.push(context, AppTheme.slideUp(RecipeResultsScreen(ingredients: ings)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(children: [
          _Header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _StatsCard()
                    .animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),
                const SizedBox(height: 28),
                ..._grouped.asMap().entries.expand((outer) {
                  final groupIdx = outer.key;
                  final group    = outer.value;
                  return [
                    _GroupLabel(label: group.label)
                        .animate()
                        .fadeIn(delay: (80 + groupIdx * 60).ms, duration: 280.ms),
                    const SizedBox(height: 10),
                    ...group.entries.asMap().entries.map((inner) {
                      final rowIdx = inner.key;
                      final entry  = inner.value;
                      final timeLabel = (group.label == 'Today' || group.label == 'Yesterday')
                          ? '${group.label}, ${entry.time}'
                          : entry.time;
                      return ActivityRow(
                        recipeName: entry.recipeName,
                        ingredients: entry.ingredients,
                        time: timeLabel,
                        onTap: () => _openResults(context, entry),
                      ).animate()
                          .fadeIn(delay: (100 + groupIdx * 60 + rowIdx * 45).ms, duration: 300.ms)
                          .slideX(begin: 0.04, end: 0,
                              delay: (100 + groupIdx * 60 + rowIdx * 45).ms, duration: 300.ms);
                    }),
                    const SizedBox(height: 20),
                  ];
                }),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── HEADER ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    child: Row(children: [
      TapScale(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppTheme.creamBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderGray),
          ),
          child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
        ),
      ),
      const Expanded(
        child: Center(child: Text('Your Activity', style: TextStyle(
          color: AppTheme.darkText, fontSize: 18,
          fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
        ))),
      ),
      const SizedBox(width: 42),
    ]),
  ).animate().fadeIn(duration: 280.ms);
}

// ── STATS CARD ─────────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  static const _stats = [
    _Stat(value: '7',   label: 'Sessions\nThis Week', icon: LucideIcons.flame,        bg: AppTheme.scanGreen),
    _Stat(value: '24',  label: 'Total\nSessions',     icon: LucideIcons.calendarDays, bg: AppTheme.typeBlue),
    _Stat(value: '145', label: 'Recipes\nCooked',     icon: LucideIcons.chefHat,      bg: AppTheme.browseYellow),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppTheme.tealGradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x40043B3C), blurRadius: 20, offset: Offset(0, 8))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Overview', style: TextStyle(
        color: Colors.white60, fontSize: 12,
        fontFamily: 'DM Sans', fontWeight: FontWeight.w600, letterSpacing: 0.8,
      )),
      const SizedBox(height: 16),
      Row(children: _stats.asMap().entries.map((e) {
        final s = e.value;
        final isLast = e.key == _stats.length - 1;
        return Expanded(child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(s.icon, color: AppTheme.primaryDark, size: 17),
            ),
            const SizedBox(height: 10),
            Text(s.value, style: const TextStyle(
              color: Colors.white, fontSize: 26,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.0,
            )),
            const SizedBox(height: 3),
            Text(s.label, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5), fontSize: 11,
              fontFamily: 'DM Sans', height: 1.3,
            )),
          ])),
          if (!isLast)
            Container(width: 1, height: 60, margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withValues(alpha: 0.12)),
        ]));
      }).toList()),
    ]),
  );
}

// ── GROUP LABEL ────────────────────────────────────────────────────────────────
class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(
      color: AppTheme.darkText, fontSize: 13,
      fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
    )),
    const SizedBox(width: 10),
    Expanded(child: Container(height: 1, color: AppTheme.borderGray)),
  ]);
}

// ── DATA MODELS ────────────────────────────────────────────────────────────────
class _Group {
  final String label;
  final List<_Entry> entries;
  const _Group({required this.label, required this.entries});
}

class _Entry {
  final String recipeName;
  final String ingredients;
  final String time;
  const _Entry({
    required this.recipeName,
    required this.ingredients,
    required this.time,
  });
}

class _Stat {
  final String value, label;
  final IconData icon;
  final Color bg;
  const _Stat({required this.value, required this.label, required this.icon, required this.bg});
}
