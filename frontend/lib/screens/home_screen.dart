import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/tap_scale.dart';
import '../widgets/plately_logo.dart';
import '../widgets/activity_row.dart';
import '../widgets/plately_share_card.dart';
import '../services/update_service.dart';
import '../services/user_prefs_service.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';
import '../main_shell.dart';
import 'recipe_results_screen.dart';
import 'history_screen.dart';
import 'ingredient_entry_screen.dart';
import 'recipe_detail_screen.dart';
import 'pantry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollCtrl = ScrollController();
  final _screenshotCtrl = ScreenshotController();
  String _name = 'User';
  List<Recipe> _suggested = [];
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _recentHistory = [];
  bool _loadingRecipes = true;
  bool _loadingHistory = true;
  bool _offline = false;
  bool _wakingUp = false;
  Timer? _wakeTimer;
  int _calGoal = 2200;
  int _proteinGoal = 120;
  int _calConsumed = 0;
  int _proteinConsumed = 0;
  int _streak = 0;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  Map<String, dynamic> _selectedDayData = {};
  bool _loadingDayData = false;

  // ── Update checker ────────────────────────────────────────────────────────
  UpdateInfo? _updateInfo;
  bool _updateDismissed = false;

  static const _cacheKey = 'cached_home_recipes';

  static const _cardGradients = [
    [Color(0xFFD8EDD4), Color(0xFFC0DCB3)],
    [Color(0xFFD4E4ED), Color(0xFFB3CEDC)],
    [Color(0xFFEDD8D4), Color(0xFFDCB3C0)],
    [Color(0xFFEDEAD4), Color(0xFFDCD8B3)],
  ];

  static const _cardFg = [
    Color(0xFF4A8A46),
    Color(0xFF2E6B8A),
    Color(0xFF8A4A46),
    Color(0xFF7A7030),
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadSuggested();
    _loadHistory();
    _checkForUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final data = await UserPrefsService.load();
    final name = (data['name'] as String?) ?? 'User';
    if (mounted) {
      setState(() {
        _name = name;
        _calGoal = (data['cal_goal'] as int?) ?? 2200;
        _proteinGoal = (data['protein_goal'] as int?) ?? 120;
        _calConsumed = (data['cal_consumed'] as int?) ?? 0;
        _proteinConsumed = (data['protein_consumed'] as int?) ?? 0;
        _streak = (data['streak'] as int?) ?? 0;
      });
      _checkStreakMilestones(_streak);
      final lastCooked = await UserPrefsService.getLastCookedName() ?? '';
      NotificationService.schedulePersonalized(
        name: name,
        proteinGoal: (data['protein_goal'] as int?) ?? 120,
        proteinConsumed: (data['protein_consumed'] as int?) ?? 0,
        streak: _streak,
        lastCookedName: lastCooked,
      );
    }
  }

  // ── Streak milestone popups ───────────────────────────────────────────────
  Future<void> _checkStreakMilestones(int streak) async {
    const milestones = [3, 7, 14, 30];
    if (!milestones.contains(streak)) return;
    final seen = await UserPrefsService.hasSeenStreakMilestone(streak);
    if (seen || !mounted) return;
    await UserPrefsService.markStreakMilestoneSeen(streak);
    if (!mounted) return;
    _showMilestoneDialog(streak);
  }

  static Map<String, String> _milestoneData(int streak) {
    switch (streak) {
      case 3:  return {'title': "You're on a hot streak fr"};
      case 7:  return {'title': 'Week-long grind, no cap'};
      case 14: return {'title': 'Two weeks of eating different'};
      case 30: return {'title': 'GOAT behavior, lowkey impressive'};
      default: return {'title': '$streak day streak'};
    }
  }

  void _showMilestoneDialog(int streak) {
    final data = _milestoneData(streak);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg(context),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.yellow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.flame, color: AppTheme.orange, size: 32),
              ),
              const SizedBox(height: 16),
              Text(data['title']!, style: const TextStyle(
                color: AppTheme.darkText, fontSize: 20,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
              ), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('$streak days cooking with Plately',
                style: const TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans'),
                textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _shareMilestone(streak);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Share this W', style: TextStyle(
                    fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Keep cooking', style: TextStyle(
                  color: AppTheme.mutedText, fontFamily: 'DM Sans')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareMilestone(int streak) async {
    try {
      final data = _milestoneData(streak);
      final bytes = await _screenshotCtrl.captureFromLongWidget(
        Material(
          color: Colors.transparent,
          child: PlatelyShareCard(
            dishName: data['title']!,
            calories: 0,
            protein: 0,
            streak: streak,
          ),
        ),
        pixelRatio: 3.0,
        context: context,
      );
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'plately_streak.png')],
        text: '$streak days cooking with Plately — Pre-cook macro tracking hits different. #Plately #NoCap',
      );
    } catch (_) {}
  }

  Future<void> _loadSuggested() async {
    if (mounted) setState(() { _loadingRecipes = true; _wakingUp = false; });
    _wakeTimer?.cancel();
    _wakeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _loadingRecipes) setState(() => _wakingUp = true);
    });
    final recipes = await ApiService.getRecipes([]);
    _wakeTimer?.cancel();
    if (mounted) {
      if (recipes.isEmpty) {
        final cached = await _loadCachedRecipes();
        setState(() {
          _suggested = cached.take(4).toList();
          _offline = true;
          _loadingRecipes = false;
          _wakingUp = false;
        });
      } else {
        await _cacheRecipes(recipes);
        setState(() {
          _suggested = recipes.take(4).toList();
          _offline = false;
          _loadingRecipes = false;
          _wakingUp = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _loadingHistory = true);
    final history = await ApiService.getHistory();
    if (mounted) {
      setState(() {
        _allHistory = history;
        _recentHistory = history.take(2).toList();
        _loadingHistory = false;
      });
    }
  }

  Future<void> _selectDay(DateTime day) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    setState(() {
      _selectedDay = day;
      _selectedDayData = {};
      _loadingDayData = day != todayDate;
    });
    if (day == todayDate) return; // today uses local prefs, no API call needed
    final uid = await _getUid();
    final dateStr = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
    final data = await ApiService.getDailyHistory(uid, dateStr);
    if (mounted) setState(() { _selectedDayData = data; _loadingDayData = false; });
  }

  Future<String> _getUid() async {
    final data = await UserPrefsService.load();
    return data['email'] as String? ?? 'anonymous';
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.check();
    if (info != null && mounted) setState(() => _updateInfo = info);
  }

  Future<void> _cacheRecipes(List<Recipe> recipes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(recipes.map((r) => r.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);
    } catch (_) {}
  }

  Future<List<Recipe>> _loadCachedRecipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded.map((r) => Recipe.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  @override
  void dispose() {
    _wakeTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final first = _name.split(' ').first;
    if (h < 12) return 'Good morning, $first';
    if (h < 17) return 'Good afternoon, $first';
    return 'Good evening, $first';
  }

  String get _headline {
    final idx = DateTime.now().hour % 4;
    return [
      'What\'s in\nyour fridge?',
      'What are you\ncooking today?',
      'Ready to\ncook something?',
      'Hungry?\nLet\'s cook.',
    ][idx];
  }

  void _openIngredientEntry() {
    HapticFeedback.mediumImpact();
    Navigator.push(context, AppTheme.slideUp(const IngredientEntryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: RefreshIndicator(
        color: AppTheme.primaryDark,
        backgroundColor: AppTheme.cardBg(context),
        onRefresh: () async {
          await Future.wait([_loadPrefs(), _loadSuggested(), _loadHistory()]);
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            _buildAppBar(),
            if (_wakingUp) SliverToBoxAdapter(child: _buildWakeUpBanner()),
            if (_offline) SliverToBoxAdapter(child: _buildOfflineBanner()),
            if (_updateInfo != null && !_updateDismissed)
              SliverToBoxAdapter(child: _buildUpdateBanner()),
            SliverToBoxAdapter(child: _buildHero()),
            SliverToBoxAdapter(child: _buildCalendar()),
            SliverToBoxAdapter(child: _buildMacroRings()),
            SliverToBoxAdapter(child: _buildActionRow()),
            SliverToBoxAdapter(child: _buildSectionHeader(
              'Suggested For You',
              onSeeAll: () => Navigator.push(context, AppTheme.zoomIn(const RecipeResultsScreen(ingredients: []))),
            )),
            SliverToBoxAdapter(child: _buildSuggestedRecipes()),
            SliverToBoxAdapter(child: _buildSectionHeader(
              'Recent Activity',
              onSeeAll: () => Navigator.push(context, AppTheme.slideUp(const HistoryScreen())),
            )),
            SliverToBoxAdapter(child: _buildActivity()),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ── Update banner ─────────────────────────────────────────────────────────
  Widget _buildUpdateBanner() {
    final info = _updateInfo!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(LucideIcons.sparkles, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'New update just dropped — ${info.message}',
            style: const TextStyle(
              color: Colors.white, fontSize: 12,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse(info.downloadUrl);
            if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(8)),
            child: const Text('Update', style: TextStyle(
              color: Colors.white, fontSize: 12,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
            )),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _updateDismissed = true),
          child: const Text('Later', style: TextStyle(
            color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans',
          )),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildWakeUpBanner() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.primaryDark.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.18)),
    ),
    child: const Row(children: [
      SizedBox(width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark)),
      SizedBox(width: 10),
      Expanded(child: Text(
        'Waking up server… first load may take 30–60s',
        style: TextStyle(color: AppTheme.primaryDark, fontSize: 12,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w500),
      )),
    ]),
  ).animate().fadeIn(duration: 300.ms);

  Widget _buildOfflineBanner() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
    ),
    child: const Row(children: [
      Icon(LucideIcons.wifiOff, size: 14, color: Color(0xFF8B6914)),
      SizedBox(width: 10),
      Expanded(child: Text(
        'No internet connection — showing cached data',
        style: TextStyle(color: Color(0xFF8B6914), fontSize: 12,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w500),
      )),
    ]),
  ).animate().fadeIn(duration: 300.ms);

  Widget _buildAppBar() => SliverAppBar(
    backgroundColor: AppTheme.scaffoldBg(context),
    elevation: 0, floating: true, snap: true,
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    title: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        const PlatelyLogo(iconSize: 36, wordmarkSize: 18, theme: PlatelyLogoTheme.onLight),
        const Spacer(),
        TapScale(
          onTap: () => Navigator.push(context, AppTheme.slideUp(const PantryScreen())),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.scanGreen.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.12)),
            ),
            child: const Icon(LucideIcons.shoppingBasket, color: AppTheme.primaryDark, size: 18),
          ),
        ),
      ]),
    ),
  );

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_greeting, style: const TextStyle(
          color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans',
        )),
        const SizedBox(height: 4),
        Text(_headline, style: const TextStyle(
          color: AppTheme.darkText, fontSize: 30,
          fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -0.5,
        )),
        if (_streak >= 2) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.yellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.flame, color: AppTheme.orange, size: 16),
              const SizedBox(width: 6),
              Text('$_streak day streak!', style: const TextStyle(
                color: AppTheme.orange, fontSize: 13,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
              )),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        TapScale(
          onTap: _openIngredientEntry,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.tealGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x50043B3C), blurRadius: 28, offset: Offset(0, 10))],
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Icon(LucideIcons.scanLine, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Add Ingredients', style: TextStyle(
                  color: Colors.white, fontSize: 17,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 3),
                Text('Scan or type — get recipes instantly', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontFamily: 'DM Sans',
                )),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Text('Start', style: TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                )),
              ),
            ]),
          ),
        ),
      ]).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),
    );
  }

  // ── Macro history calendar ────────────────────────────────────────────────
  Widget _buildCalendar() {
    final now         = DateTime.now();
    final today       = DateTime(now.year, now.month, now.day);
    final firstDay    = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay     = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells  = startOffset + lastDay.day;
    final rows        = (totalCells / 7).ceil();

    final historyDates = <DateTime>{};
    for (final h in _allHistory) {
      final ts = h['timestamp'] as String? ?? '';
      if (ts.isEmpty) continue;
      try {
        final dt = DateTime.parse(ts);
        historyDates.add(DateTime(dt.year, dt.month, dt.day));
      } catch (_) {}
    }

    final monthLabel = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ][_calendarMonth.month - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(LucideIcons.calendarDays, color: AppTheme.primaryDark, size: 16),
            const SizedBox(width: 8),
            Text('$monthLabel ${_calendarMonth.year}',
                style: const TextStyle(color: AppTheme.darkText, fontSize: 14,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            const Spacer(),
            TapScale(
              onTap: () => setState(() {
                _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                _selectedDay = null;
              }),
              child: Container(width: 28, height: 28,
                decoration: BoxDecoration(color: AppTheme.cardAltBg(context),
                    borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border(context))),
                child: const Icon(LucideIcons.chevronLeft, color: AppTheme.primaryDark, size: 14)),
            ),
            const SizedBox(width: 6),
            TapScale(
              onTap: () => setState(() {
                _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                _selectedDay = null;
              }),
              child: Container(width: 28, height: 28,
                decoration: BoxDecoration(color: AppTheme.cardAltBg(context),
                    borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border(context))),
                child: const Icon(LucideIcons.chevronRight, color: AppTheme.primaryDark, size: 14)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
            child: Center(child: Text(d, style: const TextStyle(color: AppTheme.mutedText,
                fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
          )).toList()),
          const SizedBox(height: 6),
          ...List.generate(rows, (row) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: List.generate(7, (col) {
              final cellIdx = row * 7 + col;
              final dayNum  = cellIdx - startOffset + 1;
              if (dayNum < 1 || dayNum > lastDay.day) {
                return const Expanded(child: SizedBox(height: 32));
              }
              final cellDate = DateTime(_calendarMonth.year, _calendarMonth.month, dayNum);
              final isToday    = cellDate == today;
              final isSelected = _selectedDay == cellDate;
              final hasDot     = historyDates.contains(cellDate);
              final isFuture   = cellDate.isAfter(today);
              return Expanded(
                child: TapScale(
                  onTap: isFuture ? null : () {
                    if (isSelected) {
                      setState(() { _selectedDay = null; _selectedDayData = {}; });
                    } else {
                      _selectDay(cellDate);
                    }
                  },
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryDark
                          : isToday
                              ? AppTheme.primaryDark.withValues(alpha: 0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.35))
                          : null,
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      Text('$dayNum', style: TextStyle(
                        fontFamily: 'DM Sans', fontSize: 12,
                        fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : isFuture
                                ? AppTheme.mutedText.withValues(alpha: 0.4)
                                : AppTheme.darkText,
                      )),
                      if (hasDot && !isSelected)
                        Positioned(
                          bottom: 3,
                          child: Container(width: 4, height: 4,
                              decoration: const BoxDecoration(
                                  color: AppTheme.primaryDark, shape: BoxShape.circle)),
                        ),
                    ]),
                  ),
                ),
              );
            })),
          )),
          if (_selectedDay != null) ...[
            const SizedBox(height: 10),
            _buildDayDetail(today),
          ],
        ]),
      ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05),
    );
  }

  Widget _buildDayDetail(DateTime today) {
    final isToday = _selectedDay == today;

    if (_loadingDayData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardAltBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark)),
          SizedBox(width: 10),
          Text('Loading...', style: TextStyle(color: AppTheme.mutedText,
              fontSize: 12, fontFamily: 'DM Sans')),
        ]),
      );
    }

    final int cal;
    final int protein;
    final List<String> recipes;

    if (isToday) {
      cal     = _calConsumed;
      protein = _proteinConsumed;
      // Pull recipe names from today's history entries
      final todayEntries = _allHistory.where((h) {
        final ts = h['timestamp'] as String? ?? '';
        try {
          final dt = DateTime.parse(ts);
          return DateTime(dt.year, dt.month, dt.day) == today;
        } catch (_) { return false; }
      }).toList();
      recipes = todayEntries
          .map((h) => h['ingredient_names'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
    } else {
      cal     = (_selectedDayData['total_calories'] as int?) ?? 0;
      protein = (_selectedDayData['total_protein']  as int?) ?? 0;
      final raw = (_selectedDayData['recipes'] as List?)?.cast<String>() ?? [];
      recipes = raw.take(3).toList();
    }

    final hasData = cal > 0 || protein > 0 || recipes.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardAltBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: hasData
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _macroChip(cal, 'kcal', AppTheme.primaryDark),
                const SizedBox(width: 8),
                _macroChip(protein, 'g protein', AppTheme.green),
                const Spacer(),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Today', style: TextStyle(color: AppTheme.primaryDark,
                        fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  ),
              ]),
              if (recipes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: recipes.map((r) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_trimIngredientNames(r), style: const TextStyle(
                    color: AppTheme.primaryDark, fontSize: 11,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
                  )),
                )).toList()),
              ],
            ])
          : const Row(children: [
              Icon(LucideIcons.moonStar, size: 14, color: AppTheme.mutedText),
              SizedBox(width: 8),
              Text('No cooking logged this day.',
                  style: TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
            ]),
    );
  }

  Widget _macroChip(int value, String unit, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$value $unit', style: TextStyle(
        color: color, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
      )),
    ]),
  );

  // ── Daily macro rings ─────────────────────────────────────────────────────
  Widget _buildMacroRings() {
    final calPct = (_calGoal > 0 ? _calConsumed / _calGoal : 0).clamp(0.0, 1.0);
    final proPct = (_proteinGoal > 0 ? _proteinConsumed / _proteinGoal : 0).clamp(0.0, 1.0);
    final bothDone = calPct >= 1.0 && proPct >= 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          SizedBox(
            width: 72, height: 72,
            child: Stack(children: [
              CustomPaint(size: const Size(72, 72),
                  painter: _RingPainter(progress: calPct.toDouble(), color: AppTheme.primaryDark, strokeWidth: 8)),
              Padding(padding: const EdgeInsets.all(12),
                child: CustomPaint(size: const Size(48, 48),
                    painter: _RingPainter(progress: proPct.toDouble(), color: AppTheme.green, strokeWidth: 7))),
              if (bothDone)
                const Center(child: Icon(LucideIcons.check, color: AppTheme.green, size: 14)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Today's Macros", style: TextStyle(color: AppTheme.darkText,
                fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.primaryDark, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('$_calConsumed / $_calGoal cal',
                  style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${_proteinConsumed}g / ${_proteinGoal}g protein',
                  style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
            ]),
          ])),
          Column(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _streak > 0 ? AppTheme.yellow.withValues(alpha: 0.15) : AppTheme.borderGray.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.flame,
                  color: _streak > 0 ? AppTheme.orange : AppTheme.mutedText, size: 20),
            ),
            const SizedBox(height: 4),
            Text('$_streak day${_streak != 1 ? 's' : ''}',
              style: TextStyle(
                color: _streak > 0 ? AppTheme.orange : AppTheme.mutedText,
                fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
              )),
          ]),
        ]),
      ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.06),
    );
  }

  Widget _buildActionRow() {
    const actions = [
      {'icon': LucideIcons.utensils,    'label': 'Browse',  'bg': Color(0xFFDFDC9E), 'fg': Color(0xFF6B5A10)},
      {'icon': LucideIcons.chefHat,     'label': 'Ask AI',  'bg': Color(0xFFD3A7DC), 'fg': Color(0xFF5A1F6B)},
      {'icon': LucideIcons.clockFading, 'label': 'History', 'bg': Color(0xFFC0DCB3), 'fg': Color(0xFF2E6B29)},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(actions.length, (i) {
          final a = actions[i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < actions.length - 1 ? 10 : 0),
              child: TapScale(
                onTap: () {
                  if (a['label'] == 'Browse') {
                    Navigator.push(context, AppTheme.zoomIn(const RecipeResultsScreen(ingredients: [])));
                  } else if (a['label'] == 'Ask AI') {
                    MainShell.switchTab(2);
                  } else {
                    Navigator.push(context, AppTheme.slideUp(const HistoryScreen()));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: a['bg'] as Color,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                      color: (a['bg'] as Color).withValues(alpha: 0.5),
                      blurRadius: 10, offset: const Offset(0, 3),
                    )],
                  ),
                  child: Column(children: [
                    Icon(a['icon'] as IconData, color: a['fg'] as Color, size: 22),
                    const SizedBox(height: 6),
                    Text(a['label'] as String, style: TextStyle(
                      color: a['fg'] as Color, fontSize: 12,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                    )),
                  ]),
                ),
              ),
            ),
          );
        }).animate(delay: 0.ms).fadeIn(duration: 350.ms).slideY(begin: 0.08),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(
        color: AppTheme.darkText, fontSize: 17,
        fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
      )),
      if (onSeeAll != null)
        TapScale(
          onTap: onSeeAll,
          child: const Row(children: [
            Text('See all', style: TextStyle(
              color: AppTheme.primaryDark, fontSize: 13,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
            )),
            SizedBox(width: 2),
            Icon(LucideIcons.chevronRight, color: AppTheme.primaryDark, size: 14),
          ]),
        ),
    ]),
  );

  Widget _buildSuggestedRecipes() {
    if (_loadingRecipes) {
      return SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20, top: 14),
          itemCount: 4,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              width: 155,
              decoration: BoxDecoration(
                color: AppTheme.lightGray.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      );
    }
    if (_suggested.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Text('No recipes found. Is the backend running?',
            style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, top: 14),
        itemCount: _suggested.length,
        itemBuilder: (_, i) {
          final r = _suggested[i];
          final colors = _cardGradients[i % _cardGradients.length];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 155,
              child: RecipeCard(
                title: r.name,
                time: r.cookTime,
                calories: '${r.calories} cal',
                protein: '${r.protein}g protein',
                difficulty: r.difficulty,
                index: i,
                imageUrl: r.imageUrl,
                cardGradientColors: colors,
                cardFgColor: _cardFg[i % _cardFg.length],
                onTap: () => Navigator.push(context, AppTheme.zoomIn(RecipeDetailScreen(recipe: r))),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivity() {
    if (_loadingHistory) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(children: List.generate(2, (_) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.lightGray.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6)))),
      );
    }
    if (_recentHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: const Row(children: [
            Icon(LucideIcons.chefHat, color: AppTheme.mutedText, size: 20),
            SizedBox(width: 12),
            Text('No cooking sessions yet. Start cooking!',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: _recentHistory.asMap().entries.map((e) {
          final i = e.key;
          final h = e.value;
          final ts = h['timestamp'] as String? ?? '';
          return ActivityRow(
            recipeName: _trimIngredientNames(h['ingredient_names'] as String? ?? 'Cooking session'),
            ingredients: h['action_type'] as String? ?? 'cooked',
            time: _formatTimestamp(ts),
            onTap: () => Navigator.push(context, AppTheme.slideUp(const HistoryScreen())),
          ).animate(delay: (i * 60).ms).fadeIn(duration: 350.ms).slideX(begin: 0.04);
        }).toList(),
      ),
    );
  }

  String _trimIngredientNames(String raw) {
    if (raw.length <= 40) return raw;
    return '${raw.substring(0, 37)}…';
  }

  String _formatTimestamp(String ts) {
    if (ts.isEmpty) return '';
    try {
      final dt = DateTime.parse(ts);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) { return ts; }
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  const _RingPainter({required this.progress, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    canvas.drawCircle(center, radius,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
