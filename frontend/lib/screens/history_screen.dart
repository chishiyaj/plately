import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/tap_scale.dart';
import 'recipe_results_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _stats = [
    {'label': 'Total Scans',   'value': '10',  'colorKey': 'scan'},
    {'label': 'This Week',     'value': '7',   'colorKey': 'week'},
    {'label': 'Recipes Found', 'value': '145', 'colorKey': 'recipe'},
  ];

  static const _grouped = {
    'Today': [
      {'type': 'scan', 'item': 'Chicken, Garlic, Onion',  'time': '2:30 PM',     'count': '12'},
      {'type': 'type', 'item': 'Eggs, Tomato, Cheese',    'time': '11:00 AM',    'count': '18'},
    ],
    'Yesterday': [
      {'type': 'scan', 'item': 'Beef, Broccoli',          'time': '7:00 PM',     'count': '9'},
    ],
    'This Week': [
      {'type': 'scan', 'item': 'Mixed Vegetables',        'time': 'Mon 6:00 PM', 'count': '14'},
      {'type': 'type', 'item': 'Rice, Garlic, Soy Sauce', 'time': 'Tue 1:00 PM', 'count': '21'},
    ],
    'Older': [
      {'type': 'scan', 'item': 'Pasta, Cheese, Tomato',   'time': 'Last week',   'count': '7'},
    ],
  };

  void _openResults(Map<String, String> a) {
    final ings = a['item']!.split(',').map((e) => e.trim()).toList();
    Navigator.push(context, AppTheme.slideUp(RecipeResultsScreen(ingredients: ings)));
  }

  Color _statColor(String key) {
    switch (key) {
      case 'scan':   return AppTheme.scanGreen;
      case 'week':   return AppTheme.typeBlue;
      default:       return AppTheme.browseYellow;
    }
  }

  IconData _statIcon(String key) {
    switch (key) {
      case 'scan':   return LucideIcons.scanLine;
      case 'week':   return LucideIcons.calendarDays;
      default:       return LucideIcons.bookOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow()
                        .animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
                    const SizedBox(height: 28),
                    ..._grouped.entries.toList().asMap().entries.map((outer) {
                      final i = outer.key;
                      final entry = outer.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key,
                              style: const TextStyle(
                                  color: AppTheme.darkText, fontSize: 14,
                                  fontFamily: 'DM Sans', fontWeight: FontWeight.w700))
                              .animate().fadeIn(delay: (100 + i * 60).ms, duration: 300.ms),
                          const SizedBox(height: 10),
                          ...entry.value.asMap().entries.map((inner) {
                            final j = inner.key;
                            return _ActivityRow(
                              activity: inner.value,
                              onTap: () => _openResults(inner.value),
                            ).animate()
                                .fadeIn(delay: (120 + i * 60 + j * 50).ms, duration: 300.ms)
                                .slideX(begin: 0.04, end: 0,
                                    delay: (120 + i * 60 + j * 50).ms, duration: 300.ms);
                          }),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PlatelyBottomNav(currentIndex: 0, onTap: (_) {}, onScanTap: () {}),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 24, 14),
      child: Row(
        children: [
          TapScale(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGray)),
              child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('Your Activity',
                  style: TextStyle(color: AppTheme.darkText, fontSize: 18,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            ),
          ),
          TapScale(
            onTap: () {},
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGray)),
              child: const Icon(LucideIcons.slidersHorizontal, color: AppTheme.primaryDark, size: 18),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildStatsRow() {
    return Row(
      children: _stats.asMap().entries.map((e) {
        final s = e.value;
        final color = _statColor(s['colorKey']!);
        final icon  = _statIcon(s['colorKey']!);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key < _stats.length - 1 ? 10 : 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderGray),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: AppTheme.primaryDark, size: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(s['value']!,
                      style: const TextStyle(color: AppTheme.darkText, fontSize: 22,
                          fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                  Text(s['label']!,
                      style: const TextStyle(color: AppTheme.mutedText, fontSize: 10,
                          fontFamily: 'DM Sans'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, String> activity;
  final VoidCallback onTap;
  const _ActivityRow({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isScan = activity['type'] == 'scan';
    return TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderGray),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))
            ]),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: isScan ? AppTheme.scanGreen : AppTheme.typeBlue,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(isScan ? LucideIcons.scanLine : LucideIcons.pencilLine,
                  color: AppTheme.primaryDark, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isScan ? 'Scan Ingredients' : 'Manual Entry',
                      style: const TextStyle(color: AppTheme.darkText, fontSize: 14,
                          fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(activity['item']!,
                      style: const TextStyle(color: AppTheme.mutedText,
                          fontSize: 12, fontFamily: 'DM Sans')),
                  const SizedBox(height: 2),
                  Text(activity['time']!,
                      style: const TextStyle(color: AppTheme.mutedText,
                          fontSize: 11, fontFamily: 'DM Sans')),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${activity['count']} recipes',
                  style: const TextStyle(color: AppTheme.primaryDark, fontSize: 11,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronRight, color: AppTheme.mutedText, size: 16),
          ],
        ),
      ),
    );
  }
}
