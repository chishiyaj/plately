import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../services/api_service.dart';
import '../services/user_prefs_service.dart';
import '../main_shell.dart';
import 'recipe_detail_screen.dart';
import '../models/recipe.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  int _proteinGoal = 120;

  // Weekly calendar navigation: 0 = this week, -1 = last week, etc.
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getHistory(),
        UserPrefsService.load(),
      ]);
      final data = results[0] as List<Map<String, dynamic>>;
      final prefs = results[1] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _history = data;
          _proteinGoal = (prefs['protein_goal'] as int?) ?? 120;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteEntry(int id) async {
    HapticFeedback.mediumImpact();
    setState(() => _history.removeWhere((h) => h['id'] == id));
    await ApiService.deleteHistory(id);
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(dCtx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All History', style: TextStyle(fontFamily: 'DM Sans',
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary(dCtx))),
        content: Text('This will permanently delete all your cooking history.',
            style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.textMuted(dCtx))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false),
              child: Text('Cancel', style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.textMuted(dCtx)))),
          TextButton(onPressed: () => Navigator.pop(dCtx, true),
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

  // ── Weekly calendar data ──────────────────────────────────────────────────
  // Returns the 7 days for the current _weekOffset
  List<_DayData> _daysForWeek(int weekOffset) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    // Find Monday of current week
    final monday = todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
    final weekStart = monday.add(Duration(days: weekOffset * 7));

    return List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final sessions = _history.where((h) {
        try {
          final dt = DateTime.parse(h['timestamp'] as String? ?? '').toLocal();
          return dt.year == day.year && dt.month == day.month && dt.day == day.day;
        } catch (_) { return false; }
      }).toList();
      final cal = sessions.fold(0, (s, h) {
        final logged = (h['calories_logged'] as int?) ?? 0;
        if (logged > 0) return s + logged;
        return s + ((h['recipe_count'] as int?) ?? 1) * 420;
      });
      final protein = sessions.fold(0, (s, h) {
        final logged = (h['protein_logged'] as int?) ?? 0;
        if (logged > 0) return s + logged;
        return s + ((h['recipe_count'] as int?) ?? 1) * 32;
      });
      const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
      final isFuture = day.isAfter(todayMidnight);
      return _DayData(
        label: dayLabels[i],
        dateNum: day.day,
        cal: cal,
        protein: protein,
        isToday: isToday,
        isFuture: isFuture,
        sessionCount: sessions.length,
      );
    });
  }

  String _weekLabel(int weekOffset) {
    if (weekOffset == 0) return 'This Week';
    if (weekOffset == -1) return 'Last Week';
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = monday.add(Duration(days: weekOffset * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[weekStart.month - 1]} ${weekStart.day} – ${months[weekEnd.month - 1]} ${weekEnd.day}';
  }

  // ── Grouped history ───────────────────────────────────────────────────────
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final now = DateTime.now();
    final groups = <String, List<Map<String, dynamic>>>{
      'Today': [], 'Yesterday': [], 'This Week': [], 'Older': [],
    };
    for (final h in _history) {
      try {
        final dt = DateTime.parse(h['timestamp'] as String? ?? '').toLocal();
        final diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(dt.year, dt.month, dt.day));
        if (diff.inDays == 0)      { groups['Today']!.add(h); }
        else if (diff.inDays == 1) { groups['Yesterday']!.add(h); }
        else if (diff.inDays <= 7) { groups['This Week']!.add(h); }
        else                       { groups['Older']!.add(h); }
      } catch (_) { groups['Older']!.add(h); }
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  int get _thisWeek => _history.where((h) {
    try { return DateTime.now().difference(DateTime.parse(h['timestamp'] ?? '')).inDays <= 7; }
    catch (_) { return false; }
  }).length;
  int get _totalRecipes => _history.fold(0, (s, h) => s + ((h['recipe_count'] as int?) ?? 1));

  // Human-friendly timestamp — Session E fix
  String _formatTimestamp(String ts, String group) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final pm = h >= 12 ? 'PM' : 'AM';
      final hh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      final timeStr = '$hh:$m $pm';

      final today = DateTime(now.year, now.month, now.day);
      final dtDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(dtDay).inDays;

      if (diff == 0) return 'Today, $timeStr';
      if (diff == 1) return 'Yesterday, $timeStr';
      const dayNames = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      if (diff <= 6) return '${dayNames[dt.weekday - 1]}, $timeStr';
      const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${monthNames[dt.month - 1]} ${dt.day}, $timeStr';
    } catch (_) { return ts; }
  }

  // ── Open specific recipe detail from history entry ────────────────────────
  void _openHistoryEntry(Map<String, dynamic> h) {
    final recipeId = h['recipe_id'] as int?;
    if (recipeId != null && recipeId > 0) {
      final stub = Recipe(
        id: recipeId,
        name: h['recipe_name'] as String? ?? 'Recipe',
        cookTime: '',
        difficulty: '',
        instructions: '',
        calories: (h['calories_logged'] as int?) ?? 0,
        protein: (h['protein_logged'] as int?) ?? 0,
        carbs: 0,
        fat: 0,
        costPhp: 0,
        ingredients: const [],
      );
      Navigator.push(context, AppTheme.slideUp(RecipeDetailScreen(recipe: stub)));
    } else {
      final ingredientNames = (h['ingredient_names'] as String? ?? '')
          .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final recipeName = h['recipe_name'] as String? ?? '';
      if (ingredientNames.isNotEmpty || recipeName.isNotEmpty) {
        final stub = Recipe(
          id: -1,
          name: recipeName.isNotEmpty ? recipeName : 'Cooking session',
          cookTime: '',
          difficulty: '',
          instructions: '',
          calories: (h['calories_logged'] as int?) ?? 0,
          protein: (h['protein_logged'] as int?) ?? 0,
          carbs: 0,
          fat: 0,
          costPhp: 0,
          ingredients: ingredientNames
              .map((n) => RecipeIngredient(name: n, amount: ''))
              .toList(),
        );
        Navigator.push(context, AppTheme.slideUp(RecipeDetailScreen(recipe: stub)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No recipe detail recorded for this session.',
              style: TextStyle(fontFamily: 'DM Sans')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.scaffoldBg(context),
    body: SafeArea(child: Column(children: [
      _header(),
      Expanded(child: _loading ? _shimmer() : _content()),
    ])),
  );

  Widget _header() => Container(
    color: AppTheme.cardBg(context),
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    child: Row(children: [
      if (Navigator.canPop(context))
        TapScale(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.cardAltBg(context), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context))),
            child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
          ),
        )
      else
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: AppTheme.cardAltBg(context), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border(context))),
          child: const Icon(LucideIcons.calendarDays, color: AppTheme.primaryDark, size: 18)),
      const SizedBox(width: 12),
      Text('Your Activity', style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 18,
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
          decoration: BoxDecoration(color: AppTheme.cardAltBg(context), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border(context))),
          child: const Icon(LucideIcons.refreshCw, color: AppTheme.primaryDark, size: 16)),
      ),
    ]),
  ).animate().fadeIn(duration: 280.ms);

  Widget _shimmer() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      Container(height: 220, decoration: BoxDecoration(
          color: AppTheme.lightGray.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24)))
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6)),
      const SizedBox(height: 16),
      Container(height: 120, decoration: BoxDecoration(
          color: AppTheme.lightGray.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24)))
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6)),
      const SizedBox(height: 16),
      ...List.generate(3, (_) => Container(
        margin: const EdgeInsets.only(bottom: 10), height: 68,
        decoration: BoxDecoration(color: AppTheme.lightGray.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16)))
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6))),
    ]),
  );

  Widget _content() {
    final grouped = _grouped;
    return RefreshIndicator(
      color: AppTheme.primaryDark,
      backgroundColor: AppTheme.cardBg(context),
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
        _statsCard().animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),
        const SizedBox(height: 16),
        _weeklyCalendar().animate().fadeIn(duration: 400.ms).slideY(begin: 0.06),
        const SizedBox(height: 24),
        if (grouped.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(children: [
              Container(width: 72, height: 72,
                decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
                child: const Icon(LucideIcons.chefHat, size: 30, color: Colors.white)),
              const SizedBox(height: 18),
              Text('No cooking sessions yet', style: TextStyle(
                color: AppTheme.textPrimary(context),
                fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text('Cook a recipe to start tracking your macros!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13,
                        fontFamily: 'DM Sans', height: 1.5)),
              ),
              const SizedBox(height: 24),
              TapScale(
                onTap: () => MainShell.switchTab(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x33043B3C), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.chefHat, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Find a Recipe', style: TextStyle(color: Colors.white,
                        fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]).animate().fadeIn(duration: 300.ms),
          )
        else
          ...grouped.entries.expand((entry) => [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Text(entry.key, style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: AppTheme.border(context))),
                const SizedBox(width: 8),
                Text('${entry.value.length}', style: TextStyle(color: AppTheme.textMuted(context),
                    fontSize: 11, fontFamily: 'DM Sans')),
              ]),
            ),
            ...entry.value.map((h) {
              final id = h['id'] as int? ?? -1;
              final ingredients = h['ingredient_names'] as String? ?? '';
              final recipeName = h['recipe_name'] as String? ?? '';
              final displayName = recipeName.isNotEmpty ? recipeName
                  : (ingredients.isNotEmpty ? ingredients : 'Cooking session');
              final timeLabel = _formatTimestamp(h['timestamp'] as String? ?? '', entry.key);
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
                  displayName: displayName,
                  time: timeLabel,
                  recipeCount: recipeCount,
                  actionType: h['action_type'] as String? ?? 'cooked',
                  onTap: () => _openHistoryEntry(h),
                  onCookAgain: (h['recipe_id'] as int? ?? -1) > 0
                      ? () => _openHistoryEntry(h)
                      : null,
                ).animate().fadeIn(duration: 280.ms).slideX(begin: 0.04),
              );
            }),
            const SizedBox(height: 12),
          ]),
      ]),
    );
  }

  Widget _statsCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x40043B3C), blurRadius: 20, offset: Offset(0, 8))]),
    child: Row(children: [
      _StatCol(icon: LucideIcons.flame,        bg: AppTheme.scanGreen,    value: '$_thisWeek',         label: 'Sessions\nThis Week'),
      _Divider(),
      _StatCol(icon: LucideIcons.calendarDays, bg: AppTheme.typeBlue,     value: '${_history.length}', label: 'Total\nSessions'),
      _Divider(),
      _StatCol(icon: LucideIcons.chefHat,      bg: AppTheme.browseYellow, value: '$_totalRecipes',     label: 'Recipes\nCooked'),
    ]),
  );

  // ── Weekly calendar view ──────────────────────────────────────────────────
  Widget _weeklyCalendar() {
    final days = _daysForWeek(_weekOffset);
    final totalCal = days.where((d) => !d.isFuture).fold(0, (s, d) => s + d.cal);
    final activeDays = days.where((d) => !d.isFuture && d.sessionCount > 0).length;
    final totalPro = days.where((d) => !d.isFuture).fold(0, (s, d) => s + d.protein);
    final avgCal = activeDays > 0 ? (totalCal / activeDays).round() : 0;
    final avgPro = activeDays > 0 ? (totalPro / activeDays).round() : 0;
    final maxCal = days.map((d) => d.cal).fold(1, (a, b) => a > b ? a : b);

    final canGoForward = _weekOffset < 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header + week navigation
        Row(children: [
          const Icon(LucideIcons.chartBar, color: AppTheme.primaryDark, size: 18),
          const SizedBox(width: 8),
          Text('Weekly Overview', style: TextStyle(color: AppTheme.textPrimary(context),
              fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
          const Spacer(),
          // Prev week
          TapScale(
            onTap: () => setState(() => _weekOffset--),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: AppTheme.cardAltBg(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Icon(LucideIcons.chevronLeft, size: 14, color: AppTheme.textPrimary(context)),
            ),
          ),
          const SizedBox(width: 8),
          Text(_weekLabel(_weekOffset),
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          // Next week — disabled if current week
          TapScale(
            onTap: canGoForward ? () => setState(() => _weekOffset++) : null,
            child: AnimatedOpacity(
              opacity: canGoForward ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.cardAltBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Icon(LucideIcons.chevronRight, size: 14, color: AppTheme.textPrimary(context)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        // Day columns Mon–Sun
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: days.map((d) => Expanded(child: _dayColumn(d, maxCal))).toList(),
        ),
        const SizedBox(height: 16),
        // Summary row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardAltBg(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            _SummaryItem(label: 'Avg Cal', value: '$avgCal'),
            _SummaryDivider(),
            _SummaryItem(label: 'Avg Protein', value: '${avgPro}g'),
            _SummaryDivider(),
            _SummaryItem(label: 'Active Days', value: '$activeDays/7'),
          ]),
        ),
      ]),
    );
  }

  Widget _dayColumn(_DayData d, int maxCal) {
    const barMaxHeight = 72.0;
    final barH = maxCal > 0 && d.cal > 0 ? (d.cal / maxCal * barMaxHeight).clamp(4.0, barMaxHeight) : 0.0;
    final proH = _proteinGoal > 0 && d.protein > 0
        ? (d.protein / _proteinGoal * barMaxHeight * 0.65).clamp(4.0, barMaxHeight) : 0.0;

    return Column(children: [
      // Protein bar (green, smaller)
      if (proH > 0)
        Container(
          height: proH,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: d.isFuture ? Colors.transparent
                : d.isToday ? AppTheme.green : AppTheme.green.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        )
      else
        SizedBox(height: barMaxHeight * 0.65), // ignore: prefer_const_constructors
      // Calorie bar (teal)
      if (barH > 0)
        Container(
          height: barH,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: d.isFuture ? AppTheme.border(context)
                : d.isToday ? AppTheme.primaryDark : AppTheme.primaryDark.withValues(alpha: 0.3),
            borderRadius: d.cal > 0 && proH == 0
                ? BorderRadius.circular(4) : const BorderRadius.vertical(bottom: Radius.circular(4)),
          ),
        )
      else
        Container(
          height: barMaxHeight,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: d.isFuture ? Colors.transparent : AppTheme.border(context).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      const SizedBox(height: 6),
      // Date number
      Text('${d.dateNum}', style: TextStyle(
        color: d.isToday ? AppTheme.primaryDark
            : d.isFuture ? AppTheme.border(context) : AppTheme.textMuted(context),
        fontSize: 10, fontFamily: 'DM Sans',
        fontWeight: d.isToday ? FontWeight.w800 : FontWeight.w400,
      )),
      const SizedBox(height: 2),
      // Day label
      Container(
        padding: d.isToday ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1) : EdgeInsets.zero,
        decoration: d.isToday ? BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(6),
        ) : null,
        child: Text(d.label, style: TextStyle(
          color: d.isToday ? Colors.white
              : d.isFuture ? AppTheme.border(context) : AppTheme.textMuted(context),
          fontSize: 9, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
        )),
      ),
      // Session dot
      const SizedBox(height: 4),
      Container(
        width: 5, height: 5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: d.sessionCount > 0 ? AppTheme.green : Colors.transparent,
        ),
      ),
    ]);
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _DayData {
  final String label;
  final int dateNum;
  final int cal;
  final int protein;
  final bool isToday;
  final bool isFuture;
  final int sessionCount;
  const _DayData({
    required this.label,
    required this.dateNum,
    required this.cal,
    required this.protein,
    required this.isToday,
    required this.isFuture,
    required this.sessionCount,
  });
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  const _SummaryItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 15,
        fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: AppTheme.textMuted(context), fontSize: 10, fontFamily: 'DM Sans')),
  ]));
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.border(context));
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
  final String displayName, time, actionType;
  final int recipeCount;
  final VoidCallback onTap;
  final VoidCallback? onCookAgain;
  const _HistoryRow({required this.displayName, required this.time,
      required this.recipeCount, required this.actionType, required this.onTap,
      this.onCookAgain});

  @override
  Widget build(BuildContext context) => TapScale(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardBg(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(12)),
          child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            displayName,
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(children: [
            Icon(LucideIcons.clock3, size: 11, color: AppTheme.textMuted(context)),
            const SizedBox(width: 4),
            Text(time, style: TextStyle(color: AppTheme.textMuted(context),
                fontSize: 11, fontFamily: 'DM Sans')),
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
          if (onCookAgain != null) ...[
            const SizedBox(height: 6),
            TapScale(
              onTap: onCookAgain!,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.18)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.refreshCw, size: 10, color: AppTheme.primaryDark),
                  SizedBox(width: 4),
                  Text('Cook Again', style: TextStyle(color: AppTheme.primaryDark,
                      fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Icon(LucideIcons.chevronRight, size: 14, color: AppTheme.textMuted(context)),
          ],
        ]),
      ]),
    ),
  );
}
