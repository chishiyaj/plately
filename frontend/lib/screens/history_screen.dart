import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../services/api_service.dart';
import 'recipe_results_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getHistory();
    if (mounted) setState(() { _history = data; _loading = false; });
  }

  Future<void> _deleteEntry(int id) async {
    HapticFeedback.mediumImpact();
    setState(() => _history.removeWhere((h) => h['id'] == id));
    await ApiService.deleteHistory(id);
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All History', style: TextStyle(fontFamily: 'DM Sans',
            fontWeight: FontWeight.w800, color: AppTheme.darkText)),
        content: const Text('This will permanently delete all your cooking history.',
            style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear All', style: TextStyle(fontFamily: 'DM Sans',
                  color: AppTheme.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _history.clear());
      await ApiService.clearHistory();
    }
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final now = DateTime.now();
    final groups = <String, List<Map<String, dynamic>>>{
      'Today': [], 'Yesterday': [], 'This Week': [], 'Older': [],
    };
    for (final h in _history) {
      try {
        final dt = DateTime.parse(h['timestamp'] as String? ?? '');
        final diff = now.difference(dt);
        if (diff.inDays == 0)      { groups['Today']!.add(h); }
        else if (diff.inDays == 1) { groups['Yesterday']!.add(h); }
        else if (diff.inDays <= 7) { groups['This Week']!.add(h); }
        else                       { groups['Older']!.add(h); }
      } catch (_) { groups['Older']!.add(h); }
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  int get _thisWeek   => _history.where((h) {
    try { return DateTime.now().difference(DateTime.parse(h['timestamp'] ?? '')).inDays <= 7; }
    catch (_) { return false; }
  }).length;
  int get _totalRecipes => _history.fold(0, (s, h) => s + ((h['recipe_count'] as int?) ?? 1));

  String _fmtTime(String ts, String group) {
    try {
      final dt = DateTime.parse(ts);
      final h = dt.hour; final m = dt.minute.toString().padLeft(2, '0');
      final pm = h >= 12 ? 'PM' : 'AM'; final hh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      final t = '$hh:$m $pm';
      if (group == 'Today' || group == 'Yesterday') return '$group, $t';
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${days[dt.weekday - 1]} $t';
    } catch (_) { return ts; }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.creamBg,
    body: SafeArea(child: Column(children: [
      _header(),
      Expanded(child: _loading ? _shimmer() : _content()),
    ])),
  );

  Widget _header() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    child: Row(children: [
      if (Navigator.canPop(context))
        TapScale(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderGray)),
            child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
          ),
        )
      else
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderGray)),
          child: const Icon(LucideIcons.calendarDays, color: AppTheme.primaryDark, size: 18)),
      const SizedBox(width: 12),
      const Text('Your Activity', style: TextStyle(color: AppTheme.darkText, fontSize: 18,
          fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
      const Spacer(),
      if (_history.isNotEmpty)
        TapScale(onTap: _clearAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.red.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Icon(LucideIcons.trash2, color: AppTheme.red, size: 13),
              SizedBox(width: 5),
              Text('Clear All', style: TextStyle(color: AppTheme.red, fontSize: 12,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      const SizedBox(width: 8),
      TapScale(onTap: _load,
        child: Container(width: 42, height: 42,
          decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderGray)),
          child: const Icon(LucideIcons.refreshCw, color: AppTheme.primaryDark, size: 16)),
      ),
    ]),
  ).animate().fadeIn(duration: 280.ms);

  Widget _shimmer() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      Container(height: 120, decoration: BoxDecoration(
          color: AppTheme.lightGray.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24)))
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6)),
      const SizedBox(height: 20),
      ...List.generate(4, (_) => Container(
        margin: const EdgeInsets.only(bottom: 10), height: 68,
        decoration: BoxDecoration(color: AppTheme.lightGray.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16)))
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6))),
    ]),
  );

  Widget _content() {
    final grouped = _grouped;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
      // Stats card — ALWAYS shown, even when history is empty (shows 0s)
      _statsCard().animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),
      const SizedBox(height: 24),
      // Empty state below the stats card
      if (grouped.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(children: [
            Container(width: 64, height: 64,
              decoration: BoxDecoration(color: AppTheme.borderGray.withValues(alpha: 0.4), shape: BoxShape.circle),
              child: const Icon(LucideIcons.chefHat, size: 28, color: AppTheme.mutedText)),
            const SizedBox(height: 14),
            const Text('No cooking sessions yet', style: TextStyle(color: AppTheme.darkText,
                fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Cook a recipe to see your activity here',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
          ]).animate().fadeIn(duration: 300.ms),
        )
      else
        ...grouped.entries.expand((entry) => [
          // Group label
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Text(entry.key, style: const TextStyle(color: AppTheme.darkText, fontSize: 13,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: AppTheme.borderGray)),
              const SizedBox(width: 8),
              Text('${entry.value.length}', style: const TextStyle(color: AppTheme.mutedText,
                  fontSize: 11, fontFamily: 'DM Sans')),
            ]),
          ),
          // Swipeable rows
          ...entry.value.map((h) {
            final id = h['id'] as int? ?? -1;
            final ingredients = h['ingredient_names'] as String? ?? '';
            final timeLabel = _fmtTime(h['timestamp'] as String? ?? '', entry.key);
            final recipeCount = h['recipe_count'] as int? ?? 1;
            return Dismissible(
              key: Key('hist_$id'),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(LucideIcons.trash2, color: AppTheme.red, size: 20),
              ),
              onDismissed: (_) => _deleteEntry(id),
              child: _HistoryRow(
                ingredients: ingredients,
                time: timeLabel,
                recipeCount: recipeCount,
                actionType: h['action_type'] as String? ?? 'cooked',
                onTap: () {
                  final ings = ingredients.split(',').map((s) => s.trim())
                      .where((s) => s.isNotEmpty).toList();
                  if (ings.isNotEmpty) {
                    Navigator.push(context, AppTheme.slideUp(RecipeResultsScreen(ingredients: ings)));
                  }
                },
              ).animate().fadeIn(duration: 280.ms).slideX(begin: 0.04),
            );
          }),
          const SizedBox(height: 12),
        ]),
    ]);
  }

  Widget _statsCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x40043B3C), blurRadius: 20, offset: Offset(0, 8))]),
    child: Row(children: [
      _StatCol(icon: LucideIcons.flame,        bg: AppTheme.scanGreen,    value: '$_thisWeek',        label: 'Sessions\nThis Week'),
      _Divider(),
      _StatCol(icon: LucideIcons.calendarDays, bg: AppTheme.typeBlue,     value: '${_history.length}', label: 'Total\nSessions'),
      _Divider(),
      _StatCol(icon: LucideIcons.chefHat,      bg: AppTheme.browseYellow, value: '$_totalRecipes',    label: 'Recipes\nCooked'),
    ]),
  );
}

class _StatCol extends StatelessWidget {
  final IconData icon; final Color bg; final String value, label;
  const _StatCol({required this.icon, required this.bg, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 36, height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppTheme.primaryDark, size: 17)),
    const SizedBox(height: 10),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 26,
        fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.0)),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
        fontSize: 11, fontFamily: 'DM Sans', height: 1.3)),
  ]));
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 60, margin: const EdgeInsets.symmetric(horizontal: 16),
    color: Colors.white.withValues(alpha: 0.12));
}

class _HistoryRow extends StatelessWidget {
  final String ingredients, time, actionType;
  final int recipeCount;
  final VoidCallback onTap;
  const _HistoryRow({required this.ingredients, required this.time,
      required this.recipeCount, required this.actionType, required this.onTap});

  @override
  Widget build(BuildContext context) => TapScale(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(12)),
          child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            ingredients.isNotEmpty ? ingredients : 'Cooking session',
            style: const TextStyle(color: AppTheme.darkText, fontSize: 13,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(LucideIcons.clock3, size: 11, color: AppTheme.mutedText),
            const SizedBox(width: 4),
            Text(time, style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans')),
          ]),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text('$recipeCount recipe${recipeCount != 1 ? 's' : ''}',
                style: const TextStyle(color: AppTheme.greenDark, fontSize: 11,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          const Icon(LucideIcons.chevronRight, size: 14, color: AppTheme.mutedText),
        ]),
      ]),
    ),
  );
}
