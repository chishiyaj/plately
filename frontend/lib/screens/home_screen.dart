import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _loadingRecipes = true;
  bool _loadingHistory = true;
  bool _historyError = false;
  bool _offline = false;
  bool _wakingUp = false;
  bool _didInit = false; // AE-3: skip didChangeDependencies on first build
  Timer? _wakeTimer;
  int _calGoal = 2200;
  int _proteinGoal = 120;
  int _calConsumed = 0;
  int _proteinConsumed = 0;
  int _streak = 0;
  // Calendar state â€" _selectedDay defaults to today; sheet manages the picker
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  Map<String, dynamic> _selectedDayData = {};
  bool _loadingDayData = false;

  // â"€â"€ Update checker â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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
    // AE-3: Skip the very first call (fires right after initState, would double-load)
    if (!_didInit) { _didInit = true; return; }
    // Reload macros and recent activity every time the home tab becomes active
    // (e.g. returning from recipe detail after cooking).
    _loadPrefs();
    _loadHistory();
  }

  Future<void> _loadPrefs() async {
    await UserPrefsService.resetStreakIfExpired();
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
      // Read top pantry items for personalised notification copy
      final pantryNames = await _loadPantryNames();
      NotificationService.schedulePersonalized(
        name: name,
        proteinGoal: (data['protein_goal'] as int?) ?? 120,
        proteinConsumed: (data['protein_consumed'] as int?) ?? 0,
        streak: _streak,
        lastCookedName: lastCooked,
        pantryItems: pantryNames,
      );
    }
  }

  // â"€â"€ Streak milestone popups â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
  Future<void> _checkStreakMilestones(int streak) async {
    const milestones = [3, 7, 14, 30];
    if (!milestones.contains(streak)) return;
    final seen = await UserPrefsService.hasSeenStreakMilestone(streak);
    if (seen || !mounted) return;
    await UserPrefsService.markStreakMilestoneSeen(streak);
    if (!mounted) return;
    _showMilestoneDialog(streak);
  }

  /// Returns up to 5 pantry item names for the current user (non-stocked items first).
  Future<List<String>> _loadPantryNames() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final key = '$uid:pantry_items_v2';
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(key) ?? '[]';
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      // Prefer non-always-stocked items (more likely to be relevant)
      final names = list
          .where((e) => !(e['alwaysStocked'] as bool? ?? false))
          .map((e) => e['name'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .take(5)
          .toList();
      if (names.isEmpty) {
        return list
            .map((e) => e['name'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .take(5)
            .toList();
      }
      return names;
    } catch (_) {
      return [];
    }
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
            color: AppTheme.cardBg(ctx),
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
              Text(data['title']!, style: TextStyle(
                color: AppTheme.textPrimary(ctx), fontSize: 20,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
              ), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('$streak days cooking with Plately',
                style: TextStyle(color: AppTheme.textMuted(ctx), fontSize: 14, fontFamily: 'DM Sans'),
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
                child: Text('Keep cooking', style: TextStyle(
                  color: AppTheme.textMuted(ctx), fontFamily: 'DM Sans')),
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
        text: '$streak days cooking with Plately â€" Pre-cook macro tracking hits different. #Plately #NoCap',
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
    try {
      final history = await ApiService.getHistory();
      if (mounted) {
        setState(() {
          _allHistory = history;
          // AE-14: _recentHistory field removed; _buildActivity() uses _allHistory.take(2) inline
          _loadingHistory = false;
          _historyError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loadingHistory = false; _historyError = true; });
    }
  }

  /// Manual macro entry dialog -- lets user log food eaten outside the app.
  Future<void> _showManualMacroDialog() async {
    HapticFeedback.selectionClick();
    final calCtrl = TextEditingController();
    final proCtrl = TextEditingController();

    // AE-4: await showDialog so we can dispose controllers after it closes
    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(dCtx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.tealGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.pencil, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Text('Log food manually',
              style: TextStyle(
                color: AppTheme.textPrimary(dCtx),
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800, fontSize: 16,
              )),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Ate outside? Add your macros here.',
            style: TextStyle(color: AppTheme.textMuted(dCtx), fontSize: 13, fontFamily: 'DM Sans'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: calCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppTheme.textPrimary(dCtx), fontFamily: 'DM Sans'),
            decoration: AppTheme.inputDecoration(
              context: dCtx,
              label: 'Calories (kcal)',
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppTheme.orange, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: proCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppTheme.textPrimary(dCtx), fontFamily: 'DM Sans'),
            decoration: AppTheme.inputDecoration(
              context: dCtx,
              label: 'Protein (g)',
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted(dCtx), fontFamily: 'DM Sans')),
          ),
          TextButton(
            onPressed: () async {
              final cal = int.tryParse(calCtrl.text.trim()) ?? 0;
              final pro = int.tryParse(proCtrl.text.trim()) ?? 0;
              if (cal <= 0 && pro <= 0) { Navigator.pop(dCtx); return; }
              Navigator.pop(dCtx);
              // AE-4: mounted check immediately after pop, before any await
              if (!mounted) return;
              final prefs = await UserPrefsService.load();
              if (!mounted) return;
              final calNow = (prefs['cal_consumed'] as int?) ?? 0;
              final proNow = (prefs['protein_consumed'] as int?) ?? 0;
              await Future.wait([
                UserPrefsService.saveCalConsumed(calNow + cal),
                UserPrefsService.saveProteinConsumed(proNow + pro),
                ApiService.logHistory(
                  ingredientNames: 'Manual entry',
                  actionType: 'manual',
                  recipeCount: 0,
                  caloriesLogged: cal,
                  proteinLogged: pro,
                  recipeId: 0,
                  recipeName: 'Manual entry',
                ),
              ]);
              if (!mounted) return;
              _loadPrefs();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(LucideIcons.circleCheck, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${cal > 0 ? '+$cal kcal' : ''}${cal > 0 && pro > 0 ? ' · ' : ''}${pro > 0 ? '+${pro}g protein' : ''} logged!',
                    style: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
                  ),
                ]),
                backgroundColor: AppTheme.primaryDark,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                duration: const Duration(seconds: 3),
              ));
            },
            child: const Text('Log it',
                style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    // AE-4: Dispose controllers after dialog closes (whether saved or cancelled)
    calCtrl.dispose();
    proCtrl.dispose();
  }

  Future<void> _selectDay(DateTime day) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    setState(() {
      _selectedDay = day;
      _selectedDayData = {};
      _loadingDayData = day != today;
    });
    if (day == today) return;
    final uid = _getUid();
    final dateStr = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
    final data = await ApiService.getDailyHistory(uid, dateStr);
    if (mounted) setState(() { _selectedDayData = data; _loadingDayData = false; });
  }

  String _getUid() {
    // MUST match ApiService._uid -- Firebase UID, not email.
    // History is written with the UID, so lookups must use the UID too.
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
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
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          await Future.wait([_loadPrefs(), _loadSuggested(), _loadHistory()]);
          if (mounted) await _selectDay(today);
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
            SliverToBoxAdapter(child: _buildMacroCard()),
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

  // â"€â"€ Update banner â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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
            'New update just dropped â€" ${info.message}',
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
          child: Text('Later', style: TextStyle(
            color: AppTheme.textMuted(context), fontSize: 12, fontFamily: 'DM Sans',
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
        'Waking up serverâ€¦ first load may take 30â€"60s',
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
        'No internet connection â€" showing cached data',
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
        PlatelyLogo(iconSize: 36, wordmarkSize: 18, theme: AppTheme.isDark(context) ? PlatelyLogoTheme.onDark : PlatelyLogoTheme.onLight),
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
        Text(_greeting, style: TextStyle(
          color: AppTheme.textMuted(context), fontSize: 14, fontFamily: 'DM Sans',
        )),
        const SizedBox(height: 4),
        Text(_headline, style: TextStyle(
          color: AppTheme.textPrimary(context), fontSize: 30,
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
                Text('Scan or type â€" get recipes instantly', style: TextStyle(
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

  // â"€â"€ Unified macro + date card â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
  // Date label at top-center â€" tap opens calendar bottom sheet picker.
  // Macro rings always show. Day detail appears below rings when day != today
  // or when today has data.
  Widget _buildMacroCard() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isToday = _selectedDay == today;

    // Determine which macros to display
    final int displayCal;
    final int displayProtein;
    final List<String> displayRecipes;

    if (isToday) {
      displayCal     = _calConsumed;
      displayProtein = _proteinConsumed;
      displayRecipes = _allHistory.where((h) {
        try {
          final dt = DateTime.parse(h['timestamp'] as String? ?? '');
          return DateTime(dt.year, dt.month, dt.day) == today;
        } catch (_) { return false; }
      }).map((h) {
        // AE-9: Show recipe_name (dish name) not ingredient_names
        final name = (h['recipe_name'] as String?)?.trim() ?? '';
        return name.isNotEmpty ? name : (h['ingredient_names'] as String? ?? '');
      }).where((s) => s.isNotEmpty).take(3).toList();
    } else {
      displayCal     = (_selectedDayData['total_calories'] as int?) ?? 0;
      displayProtein = (_selectedDayData['total_protein']  as int?) ?? 0;
      final raw = (_selectedDayData['recipes'] as List?)?.cast<String>() ?? [];
      displayRecipes = raw.take(3).toList();
    }

    final calPct = (_calGoal > 0 ? displayCal / _calGoal : 0.0).clamp(0.0, 1.0);
    final proPct = (_proteinGoal > 0 ? displayProtein / _proteinGoal : 0.0).clamp(0.0, 1.0);
    final bothDone = calPct >= 1.0 && proPct >= 1.0;

    // Date label text
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dateLabel = isToday
        ? 'Today, ${months[_selectedDay.month - 1]} ${_selectedDay.day}'
        : '${days[_selectedDay.weekday - 1]}, ${months[_selectedDay.month - 1]} ${_selectedDay.day}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(children: [
          // â"€â"€ Date label â€" tappable, opens calendar sheet â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
          TapScale(
            onTap: _showCalendarSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context)
                    ? AppTheme.primaryDark.withValues(alpha: 0.35)
                    : AppTheme.primaryDark.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.isDark(context)
                      ? AppTheme.primaryDark.withValues(alpha: 0.6)
                      : AppTheme.primaryDark.withValues(alpha: 0.15),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.calendarDays, color: AppTheme.textPrimary(context), size: 13),
                const SizedBox(width: 6),
                Text(dateLabel, style: TextStyle(
                  color: AppTheme.textPrimary(context), fontSize: 13,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                )),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown, color: AppTheme.textPrimary(context), size: 12),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // â"€â"€ Macro rings row â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
          Row(children: [
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
              Text(isToday ? "Today's Macros" : 'Macros that day',
                  style: TextStyle(color: AppTheme.textPrimary(context),
                      fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppTheme.primaryDark, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('$displayCal / $_calGoal cal',
                    style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12, fontFamily: 'DM Sans')),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${displayProtein}g / ${_proteinGoal}g protein',
                    style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12, fontFamily: 'DM Sans')),
              ]),
            ])),
            Column(mainAxisSize: MainAxisSize.min, children: [
              // Log food manually -- only visible for today
              if (isToday)
                TapScale(
                  onTap: _showManualMacroDialog,
                  child: Container(
                    width: 38, height: 38,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: AppTheme.isDark(context) ? 0.35 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryDark.withValues(alpha: AppTheme.isDark(context) ? 0.6 : 0.18),
                      ),
                    ),
                    child: Icon(LucideIcons.plus,
                        color: AppTheme.isDark(context) ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                        size: 16),
                  ),
                ),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _streak > 0 ? AppTheme.yellow.withValues(alpha: 0.15) : AppTheme.border(context).withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.flame,
                    color: _streak > 0 ? AppTheme.orange : AppTheme.textMuted(context), size: 20),
              ),
              const SizedBox(height: 4),
              Text('$_streak day${_streak != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: _streak > 0 ? AppTheme.orange : AppTheme.textMuted(context),
                    fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                  )),
            ]),
          ]),
          // â"€â"€ Day detail â€" loading / data / empty â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
          const SizedBox(height: 12),
          if (_loadingDayData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardAltBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark)),
                const SizedBox(width: 10),
                Text('Loading...', style: TextStyle(color: AppTheme.textMuted(context),
                    fontSize: 12, fontFamily: 'DM Sans')),
              ]),
            )
          else if (displayCal > 0 || displayProtein > 0 || displayRecipes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardAltBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _macroChip(displayCal, 'kcal', AppTheme.primaryDark),
                  const SizedBox(width: 8),
                  _macroChip(displayProtein, 'g protein', AppTheme.green),
                ]),
                if (displayRecipes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: displayRecipes.map((r) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_trimIngredientNames(r), style: TextStyle(
                      color: AppTheme.textPrimary(context), fontSize: 11,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
                    )),
                  )).toList()),
                ],
              ]),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardAltBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(children: [
                Icon(LucideIcons.moonStar, size: 13, color: AppTheme.textMuted(context)),
                const SizedBox(width: 8),
                Text(isToday ? 'Nothing logged yet today.' : 'No cooking logged this day.',
                    style: TextStyle(color: AppTheme.textMuted(context),
                        fontSize: 12, fontFamily: 'DM Sans')),
              ]),
            ),
        ]),
      ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05),
    );
  }

  // â"€â"€ Calendar bottom sheet â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
  void _showCalendarSheet() {
    HapticFeedback.selectionClick();
    // Sheet has its own month state so scrolling months doesn't affect main screen
    DateTime sheetMonth = DateTime(_selectedDay.year, _selectedDay.month);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          final firstDay    = DateTime(sheetMonth.year, sheetMonth.month, 1);
          final lastDay     = DateTime(sheetMonth.year, sheetMonth.month + 1, 0);
          final startOffset = (firstDay.weekday - 1) % 7;
          final rows        = ((startOffset + lastDay.day) / 7).ceil();

          final historyDates = <DateTime>{};
          for (final h in _allHistory) {
            try {
              final dt = DateTime.parse(h['timestamp'] as String? ?? '');
              historyDates.add(DateTime(dt.year, dt.month, dt.day));
            } catch (_) {}
          }

          final months = ['January','February','March','April','May','June',
              'July','August','September','October','November','December'];

          return Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // drag handle
              Center(child: Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.border(context),
                      borderRadius: BorderRadius.circular(2)))),
              // month nav
              Row(children: [
                TapScale(
                  onTap: () => setSt(() => sheetMonth = DateTime(sheetMonth.year, sheetMonth.month - 1)),
                  child: Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: AppTheme.cardAltBg(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border(context))),
                    child: const Icon(LucideIcons.chevronLeft, color: AppTheme.primaryDark, size: 15)),
                ),
                Expanded(child: Center(child: Text(
                  '${months[sheetMonth.month - 1]} ${sheetMonth.year}',
                  style: TextStyle(color: AppTheme.textPrimary(context),
                      fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w800),
                ))),
                Builder(builder: (ctx2) {
                  final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
                  final isAtCurrentMonth = sheetMonth.year == currentMonth.year && sheetMonth.month == currentMonth.month;
                  return TapScale(
                    onTap: isAtCurrentMonth ? null : () => setSt(() => sheetMonth = DateTime(sheetMonth.year, sheetMonth.month + 1)),
                    child: Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: AppTheme.cardAltBg(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border(context))),
                      child: Icon(LucideIcons.chevronRight,
                          color: isAtCurrentMonth ? AppTheme.border(context) : AppTheme.primaryDark, size: 15)),
                  );
                }),
              ]),
              const SizedBox(height: 14),
              // weekday headers
              Row(children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
                child: Center(child: Text(d, style: TextStyle(color: AppTheme.textMuted(context),
                    fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
              )).toList()),
              const SizedBox(height: 6),
              // day grid
              ...List.generate(rows, (row) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: List.generate(7, (col) {
                  final idx    = row * 7 + col;
                  final dayNum = idx - startOffset + 1;
                  if (dayNum < 1 || dayNum > lastDay.day) {
                    return const Expanded(child: SizedBox(height: 36));
                  }
                  final cellDate  = DateTime(sheetMonth.year, sheetMonth.month, dayNum);
                  final isToday2  = cellDate == today;
                  final isSelected= cellDate == _selectedDay;
                  final hasDot    = historyDates.contains(cellDate);
                  final isFuture  = cellDate.isAfter(today);
                  return Expanded(
                    child: TapScale(
                      onTap: isFuture ? null : () {
                        Navigator.pop(ctx);
                        _selectDay(cellDate);
                      },
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryDark
                              : isToday2
                                  ? AppTheme.primaryDark.withValues(alpha: 0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isToday2 && !isSelected
                              ? Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.35))
                              : null,
                        ),
                        child: Stack(alignment: Alignment.center, children: [
                          Text('$dayNum', style: TextStyle(
                            fontFamily: 'DM Sans', fontSize: 13,
                            fontWeight: isToday2 || isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected ? Colors.white
                                : isFuture ? AppTheme.textMuted(ctx).withValues(alpha: 0.35)
                                : AppTheme.textPrimary(ctx),
                          )),
                          if (hasDot && !isSelected)
                            Positioned(bottom: 4,
                              child: Container(width: 4, height: 4,
                                  decoration: const BoxDecoration(
                                      color: AppTheme.primaryDark, shape: BoxShape.circle))),
                        ]),
                      ),
                    ),
                  );
                })),
              )),
              const SizedBox(height: 8),
              // Today shortcut
              TapScale(
                onTap: () { Navigator.pop(ctx); _selectDay(today); },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(child: Text('Jump to Today',
                      style: TextStyle(color: Colors.white, fontSize: 14,
                          fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _macroChip(int value, String unit, Color color) {
    // In dark mode, AppTheme.primaryDark (#043B3C) on a dark card is invisible.
    // Use a brighter colour when the chip color is primaryDark and we're in dark mode.
    final effectiveColor = (color == AppTheme.primaryDark && AppTheme.isDark(context))
        ? AppTheme.darkTextPrimary
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: AppTheme.isDark(context) ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: effectiveColor, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$value $unit', style: TextStyle(
          color: effectiveColor, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
        )),
      ]),
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
      Text(title, style: TextStyle(
        color: AppTheme.textPrimary(context), fontSize: 17,
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Text('No recipes found. Is the backend running?',
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans')),
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
    if (_historyError) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(children: [
            Icon(LucideIcons.wifiOff, color: AppTheme.textMuted(context), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text("Couldn't load activity. Pull down to retry.",
                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans')),
            ),
          ]),
        ),
      );
    }
    if (_allHistory.take(2).isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(children: [
            Icon(LucideIcons.chefHat, color: AppTheme.textMuted(context), size: 20),
            const SizedBox(width: 12),
            Text('No cooking sessions yet. Start cooking!',
                style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans')),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: _allHistory.take(2).toList().asMap().entries.map((e) {
          final i = e.key;
          final h = e.value;
          final ts = h['timestamp'] as String? ?? '';
          return ActivityRow(
            recipeName: (h['recipe_name'] as String? ?? '').isNotEmpty
                ? h['recipe_name'] as String
                : _trimIngredientNames(h['ingredient_names'] as String? ?? 'Cooking session'),
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
    return '${raw.substring(0, 37)}â€¦';
  }

  String _formatTimestamp(String ts) {
    if (ts.isEmpty) return '';
    try {
      final dt = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) { return ts; }
  }
}

// â"€â"€ Ring painter â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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
