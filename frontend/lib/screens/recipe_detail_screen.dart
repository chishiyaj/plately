import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/user_prefs_service.dart';
import '../services/notification_service.dart';
import 'pantry_screen.dart' show deductPantryIngredients;
import '../models/recipe.dart';
import '../widgets/tap_scale.dart';
import '../widgets/ai_tip_card.dart';
import '../widgets/recipe_card.dart' show recipeImageUrl;
import '../widgets/plately_share_card.dart';
import 'ai_chat_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({required this.recipe, super.key});
  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> with TickerProviderStateMixin {
  bool _showIngredients = true;
  bool _isFavorited = false;
  bool _loadingDetail = false;
  bool _isOffline = false;
  Recipe? _fetchedRecipe;
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;
  final Set<int> _checked = {};
  double _servings = 1.0;
  static const _servingOptions = [0.5, 1.0, 1.5, 2.0, 3.0];

  // Step timers: stepIndex → deadline DateTime (null = not running)
  final Map<int, DateTime> _timerDeadlines = {};
  final Map<int, Timer?> _timers = {};
  final Map<int, int> _timerSeconds = {}; // display cache, updated each tick
  final _screenshotCtrl = ScreenshotController();

  // Step completion: tap a step row to mark it done (separate from timer done)
  final Set<int> _completedSteps = {};

  // The active recipe — either the passed-in one or the fully-fetched version
  Recipe get r => _fetchedRecipe ?? widget.recipe;

  List<String> get _steps {
    final raw = r.instructions;
    // Try newline split first (preferred format from AI and DB)
    var parts = raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    // If only one part came back, the AI used ". " as delimiter — split on numbered pattern
    if (parts.length == 1) {
      parts = raw.split(RegExp(r'(?=\d+\. )')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return parts.map((s) => s.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim()).where((s) => s.isNotEmpty).toList();
  }

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroCtrl.forward();
    _loadFavoriteState();
    // Fetch full recipe data when coming from browse-mode (ingredients not pre-loaded)
    final needsFetch = widget.recipe.id > 0 && widget.recipe.ingredients.isEmpty;
    if (needsFetch) _fetchFullRecipe();
  }

  Future<void> _fetchFullRecipe() async {
    setState(() => _loadingDetail = true);
    try {
      final full = await ApiService.getRecipeDetail(widget.recipe.id);
      if (mounted && full != null) {
        setState(() {
          _fetchedRecipe = full;
          _loadingDetail = false;
          _isOffline = false;
        });
      } else {
        if (mounted) setState(() { _loadingDetail = false; _isOffline = true; });
      }
    } catch (_) {
      if (mounted) setState(() { _loadingDetail = false; _isOffline = true; });
    }
  }

  Future<void> _loadFavoriteState() async {
    if (r.id < 0) return; // AI-generated recipes can't be favorited
    final saved = await ApiService.isFavorite(r.id);
    if (mounted) setState(() => _isFavorited = saved);
  }

  // Favorite: optimistic update first, revert on failure
  Future<void> _toggleFavorite() async {
    if (r.id < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Cook this recipe first — AI recipes can be saved after cooking.',
            style: TextStyle(fontFamily: 'DM Sans')),
        backgroundColor: AppTheme.primaryDark, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    // Optimistic update — feels instant
    final optimistic = !_isFavorited;
    setState(() => _isFavorited = optimistic);
    final newState = await ApiService.toggleFavorite(r.id);
    if (mounted) setState(() => _isFavorited = newState);
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    for (final t in _timers.values) { t?.cancel(); }
    _timerDeadlines.clear();
    super.dispose();
  }

  // ── Extract seconds from step text ("simmer 5 minutes" → 300) ─────────────
  int? _extractSeconds(String step) {
    final s = step.toLowerCase();
    final hourMatch = RegExp(r'(\d+)\s*hours?').firstMatch(s);
    if (hourMatch != null) return (int.tryParse(hourMatch.group(1) ?? '') ?? 0) * 3600;
    final minMatch = RegExp(r'(\d+)\s*(?:to\s*\d+\s*)?min(?:utes?)?').firstMatch(s);
    if (minMatch != null) return (int.tryParse(minMatch.group(1) ?? '') ?? 0) * 60;
    final secMatch = RegExp(r'(\d+)\s*secs?(?:onds?)?').firstMatch(s);
    if (secMatch != null) return int.tryParse(secMatch.group(1) ?? '');
    return null;
  }

  void _startTimer(int stepIdx, int totalSeconds) {
    _timers[stepIdx]?.cancel();
    final deadline = DateTime.now().add(Duration(seconds: totalSeconds));
    _timerDeadlines[stepIdx] = deadline;
    setState(() => _timerSeconds[stepIdx] = totalSeconds);
    _timers[stepIdx] = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        t.cancel();
        _timerDeadlines.remove(stepIdx);
        HapticFeedback.heavyImpact();
        setState(() => _timerSeconds[stepIdx] = 0);
        NotificationService.notifyCookingDone('Timer done — Step ${stepIdx + 1}');
      } else {
        setState(() => _timerSeconds[stepIdx] = remaining);
      }
    });
  }

  void _stopTimer(int stepIdx) {
    _timers[stepIdx]?.cancel();
    _timerDeadlines.remove(stepIdx);
    setState(() => _timerSeconds.remove(stepIdx));
  }

  String _fmtTimer(int secs) {
    if (secs >= 3600) {
      final h = secs ~/ 3600; final m = (secs % 3600) ~/ 60; final s = secs % 60;
      return '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    }
    final m = secs ~/ 60; final s = secs % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  // ── Share recipe card ─────────────────────────────────────────────────────
  Future<void> _shareRecipe() async {
    final image = await _screenshotCtrl.captureFromLongWidget(
      _buildShareCard(),
      delay: const Duration(milliseconds: 10),
      pixelRatio: 3.0,
      context: context,
    );
    await Share.shareXFiles([XFile.fromData(image, mimeType: 'image/png', name: '${r.name}.png')]);
  }

  Widget _buildShareCard() => Material(
    child: Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(gradient: AppTheme.tealGradient),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Text('Plately', style: TextStyle(
              color: Colors.white, fontSize: 13, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          const Icon(LucideIcons.chefHat, color: Colors.white, size: 20),
        ]),
        const SizedBox(height: 16),
        Text(r.name, style: const TextStyle(
          color: Colors.white, fontSize: 22, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('${r.cookTime}  ·  ${r.difficulty}', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontFamily: 'DM Sans')),
        const SizedBox(height: 16),
        Row(children: [
          _ShareStat('${(r.calories * _servings).round()}', 'kcal', AppTheme.orange),
          const SizedBox(width: 12),
          _ShareStat('${(r.protein * _servings).round()}g', 'protein', AppTheme.green),
          const SizedBox(width: 12),
          _ShareStat('${(r.carbs * _servings).round()}g', 'carbs', AppTheme.typeBlue),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Cooked with Plately — know your macros before you cook.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'DM Sans')),
        ),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      extendBody: true,
      floatingActionButton: _isOffline ? null : Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: TapScale(
          onTap: () => Navigator.push(
            context,
            AppTheme.slideUp(AiChatScreen(
              initialPrompt: 'I\'m cooking ${r.name}. Give me tips and any ingredient substitutions if needed.',
            )),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x66043B3C), blurRadius: 14, offset: Offset(0, 5))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.chefHat, color: AppTheme.green, size: 16),
              SizedBox(width: 7),
              Text('Ask AI', style: TextStyle(color: Colors.white, fontSize: 13,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            ]),
          ),
        ).animate(delay: 400.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),
      ),
      body: Column(
        children: [
          _buildHero(context),
          if (_loadingDetail)
            Expanded(child: _buildSkeleton(context))
          else ...[
            _buildTabs(),
            Expanded(
              child: AnimatedSwitcher(
                duration: 280.ms,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: SingleChildScrollView(
                  key: ValueKey(_showIngredients),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                  child: Column(children: [
                    _showIngredients ? _buildIngredients() : _buildSteps(),
                    const SizedBox(height: 16),
                    _buildNutrition(),
                    const SizedBox(height: 14),
                    AiTipCard(tip: _aiTip()),
                    const SizedBox(height: 18),
                    _buildActionBtn(),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _aiTip() {
    if (r.tags.contains('Asian'))       return 'For best stir-fry results, use high heat and keep ingredients moving — this gives that restaurant-style wok hei flavour.';
    if (r.tags.contains('Italian'))     return 'Salt your pasta water generously — it should taste like the sea. This is the only chance to season the pasta itself.';
    if (r.tags.contains('High-Protein')) return 'Let protein rest 2–3 min after cooking — it stays juicier and retains more nutrients.';
    return 'Prep all ingredients before you start cooking — it makes the whole process faster and less stressful.';
  }

  Widget _buildSkeleton(BuildContext context) {
    final baseColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[300]!;
    final highlightColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[100]!;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Tab bar skeleton
          Container(height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          const SizedBox(height: 18),
          // Ingredient rows
          ...List.generate(5, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          )),
          const SizedBox(height: 16),
          // Nutrition card skeleton
          Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
          const SizedBox(height: 14),
          // AI tip skeleton
          Container(height: 72, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 18),
          // Action button skeleton
          Container(height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        ]),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final imgUrl = recipeImageUrl(r.name);
    return FadeTransition(
      opacity: _heroFade,
      child: Stack(
        children: [
          // Real food image
          SizedBox(
            height: 260, width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: imgUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: const Color(0xFFD8EDD4),
                child: const Center(child: Icon(LucideIcons.utensils, size: 60, color: Color(0x664A8A46))),
              ),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFFD8EDD4),
                child: const Center(child: Icon(LucideIcons.chefHat, size: 80, color: Color(0xFF4A8A46))),
              ),
            ),
          ),
          // Gradient scrim
          Positioned(
            bottom: 0, left: 0, right: 0, height: 160,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Color(0xF0000000), Colors.transparent],
                ),
              ),
            ),
          ),
          // Name + badges
          Positioned(
            bottom: 16, left: 20, right: 20,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(
                color: Colors.white, fontSize: 22,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _MetaBadge(icon: LucideIcons.clock3,     label: r.cookTime),
                _MetaBadge(icon: LucideIcons.flame,      label: '${r.calories} cal'),
                _MetaBadge(icon: LucideIcons.dumbbell,   label: '${r.protein}g protein', highlight: true),
                _MetaBadge(icon: LucideIcons.signalHigh, label: r.difficulty),
              ]),
            ]),
          ),
          // Back button
          Positioned(
            top: 48, left: 16,
            child: TapScale(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 18),
              ),
            ),
          ),
          // Offline badge (shown when detail fetch failed — using cached data)
          if (_isOffline)
            Positioned(
              top: 52, right: 62,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.yellow.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.wifiOff, size: 11, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                  )),
                ]),
              ),
            ),
          // Favorite button — only icon color changes, not container bg
          Positioned(
            top: 48, right: 16,
            child: TapScale(
              onTap: _toggleFavorite,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorited ? AppTheme.red : Colors.white60,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      height: 44,
      decoration: BoxDecoration(
          color: AppTheme.cardAltBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border(context))),
      child: Row(children: [
        _Tab(label: 'Ingredients', selected: _showIngredients,  onTap: () => setState(() => _showIngredients = true)),
        _Tab(label: 'Steps',       selected: !_showIngredients, onTap: () => setState(() => _showIngredients = false)),
      ]),
    );
  }

  Widget _buildIngredients() {
    final ings = r.ingredients;
    if (ings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No ingredient details available.',
            style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.textMuted(context)))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Helper label — clarifies tap behaviour and pre-calc macros
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Tap to check off — macros are pre-calculated for the full recipe.',
            style: TextStyle(
              color: AppTheme.textMuted(context),
              fontSize: 12,
              fontFamily: 'DM Sans',
            ),
          ),
        ),
        ...List.generate(ings.length, (i) {
          final ing = ings[i];
          final scaledAmount = _scaleAmount(ing.amount, _servings);
          return TapScale(
            onTap: () => setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context), borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: 200.ms,
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _checked.contains(i) ? AppTheme.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _checked.contains(i) ? AppTheme.green : AppTheme.border(context), width: 1.5),
                  ),
                  child: _checked.contains(i)
                      ? const Icon(LucideIcons.check, color: Colors.white, size: 13) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(ing.name, style: TextStyle(
                  color: _checked.contains(i) ? AppTheme.textMuted(context) : AppTheme.textPrimary(context),
                  fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
                  decoration: _checked.contains(i) ? TextDecoration.lineThrough : null,
                ))),
                Text(scaledAmount, style: TextStyle(
                  color: _servings != 1.0 ? AppTheme.primaryDark : AppTheme.textMuted(context),
                  fontSize: 13, fontFamily: 'DM Sans',
                  fontWeight: _servings != 1.0 ? FontWeight.w700 : FontWeight.w500,
                )),
              ]),
            ).animate(delay: (i * 40).ms).fadeIn(duration: 300.ms).slideX(begin: 0.04),
          );
        }),
      ],
    );
  }

  /// Scales an ingredient amount string by the serving multiplier.
  /// Handles formats like "200g", "1 cup", "2 tbsp", "3 cloves", "to taste".
  String _scaleAmount(String amount, double multiplier) {
    if (multiplier == 1.0) return amount;
    if (amount == 'to taste' || amount.isEmpty) return amount;
    // Extract leading number
    final match = RegExp(r'^([\d.\/]+)\s*(.*)$').firstMatch(amount.trim());
    if (match == null) return amount;
    final numStr = match.group(1)!;
    final unit   = match.group(2) ?? '';
    double? num;
    if (numStr.contains('/')) {
      final parts = numStr.split('/');
      num = (double.tryParse(parts[0]) ?? 1) / (double.tryParse(parts[1]) ?? 1);
    } else {
      num = double.tryParse(numStr);
    }
    if (num == null) return amount;
    final scaled = num * multiplier;
    // Format: drop trailing .0, round to 1 decimal
    final formatted = scaled == scaled.roundToDouble()
        ? scaled.toInt().toString()
        : scaled.toStringAsFixed(1);
    return '$formatted${unit.isNotEmpty ? ' $unit' : ''}';
  }

  Widget _buildSteps() {
    final steps = _steps;
    return Column(
      children: [
        // Tappable hint — disappears once user taps first step
        if (_completedSteps.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.hand, size: 12, color: AppTheme.textMuted(context)),
              const SizedBox(width: 5),
              Text('Tap a step to mark it done',
                style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11, fontFamily: 'DM Sans'),
              ),
            ]),
          ),
        ...List.generate(steps.length, (i) {
        final timerSecs = _extractSeconds(steps[i]);
        final timerRunning = _timerSeconds.containsKey(i);
        final timerRemaining = _timerSeconds[i] ?? 0;
        final timerDone = timerRunning && timerRemaining == 0;
        final manualDone = _completedSteps.contains(i);
        final done = timerDone || manualDone;

        return TapScale(
          onTap: () => setState(() =>
              manualDone ? _completedSteps.remove(i) : _completedSteps.add(i)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: done ? AppTheme.green.withValues(alpha: 0.08) : AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: done ? AppTheme.green.withValues(alpha: 0.4) : Colors.transparent),
              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    gradient: done ? null : AppTheme.tealGradient,
                    color: done ? AppTheme.green : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: done
                    ? const Icon(LucideIcons.check, color: Colors.white, size: 14)
                    : Text('${i + 1}', style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: TextStyle(
                    color: done ? AppTheme.greenDark : AppTheme.textPrimary(context),
                    fontSize: 14, fontFamily: 'DM Sans', height: 1.5,
                    decoration: manualDone ? TextDecoration.lineThrough : null))),
                if (timerSecs != null) ...[
                  const SizedBox(width: 8),
                  TapScale(
                    onTap: () {
                      if (timerRunning) { _stopTimer(i); } else { _startTimer(i, timerSecs); }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: timerRunning
                            ? (timerDone ? AppTheme.green : AppTheme.orange.withValues(alpha: 0.15))
                            : AppTheme.primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: timerRunning ? (timerDone ? AppTheme.green : AppTheme.orange) : AppTheme.primaryDark.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          timerDone ? LucideIcons.checkCheck : (timerRunning ? LucideIcons.pause : LucideIcons.timer),
                          size: 13,
                          color: timerDone ? Colors.white : (timerRunning ? AppTheme.orange : AppTheme.primaryDark),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timerDone ? 'Done!' : (timerRunning ? _fmtTimer(timerRemaining) : _fmtTimer(timerSecs)),
                          style: TextStyle(
                            color: timerDone ? Colors.white : (timerRunning ? AppTheme.orange : AppTheme.primaryDark),
                            fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        ).animate(delay: (i * 50).ms).fadeIn(duration: 300.ms).slideX(begin: 0.04);
      }),
      ],
    );
  }

  Widget _buildNutrition() {
    // Scale all macros by serving multiplier
    final cal  = (r.calories * _servings).round();
    final pro  = (r.protein  * _servings).round();
    final carb = (r.carbs    * _servings).round();
    final fat  = (r.fat      * _servings).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context), borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        // ── Header + serving scaler ────────────────────────────────────────
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nutrition Facts', style: TextStyle(
                color: AppTheme.textPrimary(context), fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            Text('Tap to adjust servings', style: TextStyle(
                color: AppTheme.textMuted(context), fontSize: 11, fontFamily: 'DM Sans')),
          ]),
          const Spacer(),
          // Serving size picker chips
          ...(_servingOptions.map((s) {
            final selected = _servings == s;
            final label = s == 0.5 ? '½x' : s == 1.0 ? '1x' : s == 1.5 ? '1.5x' : s == 2.0 ? '2x' : '3x';
            return TapScale(
              onTap: () => setState(() { _servings = s; _checked.clear(); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryDark : AppTheme.cardAltBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? AppTheme.primaryDark : AppTheme.border(context)),
                ),
                child: Text(label, style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMuted(context),
                  fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                )),
              ),
            );
          })),
        ]),
        const SizedBox(height: 16),
        // ── Macro 2×2 grid ────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: [
            _NutriBadge(label: 'Calories', value: '$cal',  unit: 'kcal', color: AppTheme.orange),
            _NutriBadge(label: 'Protein',  value: '$pro',  unit: 'g',    color: AppTheme.green),
            _NutriBadge(label: 'Carbs',    value: '$carb', unit: 'g',    color: AppTheme.typeBlue),
            _NutriBadge(label: 'Fat',      value: '$fat',  unit: 'g',    color: AppTheme.askPurple),
          ],
        ),
        if (_servings != 1.0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.scanGreen.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Scaled to ${_servings == 0.5 ? "½" : _servings.toString().replaceAll(".0", "")} serving${_servings == 0.5 ? "" : "s"} — ingredient amounts adjusted below.',
              style: const TextStyle(
                color: Color(0xFF2E6B29), fontSize: 11,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (r.costPhp > 0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.yellow.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.yellow.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Text('₱', style: TextStyle(
                color: AppTheme.orange, fontSize: 14,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
              )),
              const SizedBox(width: 6),
              Text('${r.costPhp} per serving', style: const TextStyle(
                color: AppTheme.orange, fontSize: 12,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
              )),
              const Spacer(),
              const Text('est. cost', style: TextStyle(
                color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans',
              )),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Macros are estimates based on standard serving sizes.',
          style: TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans'),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  bool _finishLoading = false;

  Future<void> _finishCooking() async {
    if (_finishLoading) return;
    setState(() => _finishLoading = true);

    final prefs      = await UserPrefsService.load();
    final calNow     = (prefs['cal_consumed']     as int?) ?? 0;
    final proteinNow = (prefs['protein_consumed'] as int?) ?? 0;
    final scaledCal  = (r.calories * _servings).round();
    final scaledPro  = (r.protein  * _servings).round();

    await Future.wait([
      ApiService.logHistory(
        ingredientNames: r.ingredients.isEmpty
            ? r.name
            : r.ingredients.map((i) => i.name).join(', '),
        actionType: 'cooked',
        recipeCount: 1,
        caloriesLogged: scaledCal,
        proteinLogged: scaledPro,
      ),
      UserPrefsService.saveCalConsumed(calNow + scaledCal),
      UserPrefsService.saveProteinConsumed(proteinNow + scaledPro),
      UserPrefsService.incrementRecipeCount(),
      UserPrefsService.incrementStreak(),
      UserPrefsService.saveLastCookDate(),
      NotificationService.notifyCookingDone(
        r.name,
        cal:      scaledCal,
        protein:  scaledPro,
        userName: (prefs['name'] as String?) ?? 'chef',
      ),
      deductPantryIngredients(r.ingredients.map((i) => i.name).toList()),
    ]);

    if (!mounted) return;
    setState(() => _finishLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(LucideIcons.circleCheck, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          '+$scaledCal kcal · +${scaledPro}g protein logged!',
          style: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
        )),
      ]),
      backgroundColor: AppTheme.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      duration: const Duration(seconds: 3),
    ));

    // Save last cooked name for hyperpersonalised notifications (Session 28)
    await UserPrefsService.saveLastCookedName(r.name);

    // Show share sheet after snackbar has a moment to appear
    final currentStreak = await UserPrefsService.getStreak();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    _showShareSheet(cal: scaledCal, protein: scaledPro, streak: currentStreak);
    // Navigator.pop is now inside the share sheet's Done button — user controls dismissal
  }

  // ── Post-cook share sheet ─────────────────────────────────────────────────
  void _showShareSheet({required int cal, required int protein, required int streak}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareBottomSheet(
        dishName: r.name,
        calories: cal,
        protein: protein,
        streak: streak,
        screenshotCtrl: _screenshotCtrl,
      ),
    );
  }

  Widget _buildActionBtn() {
    return Row(children: [
      TapScale(
        onTap: _shareRecipe,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: const Icon(LucideIcons.share2, color: AppTheme.primaryDark, size: 20),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TapScale(
          onTap: _finishCooking,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: _finishLoading ? null : AppTheme.greenGradient,
              color: _finishLoading ? AppTheme.primaryDark.withValues(alpha: 0.6) : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _finishLoading ? [] : const [
                BoxShadow(color: Color(0x44043B3C), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Center(child: _finishLoading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(LucideIcons.circleCheck, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Finish Cooking', style: TextStyle(color: Colors.white, fontSize: 16,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.cardBg(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? const [BoxShadow(color: Color(0x12000000), blurRadius: 6)] : [],
        ),
        child: Center(child: Text(label, style: TextStyle(
          color: selected ? AppTheme.primaryDark : AppTheme.textMuted(context),
          fontSize: 13, fontFamily: 'DM Sans',
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ))),
      ),
    ),
  );
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _MetaBadge({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: highlight ? AppTheme.green : Colors.black38,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: highlight ? AppTheme.primaryDark : Colors.white),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
        color: highlight ? AppTheme.primaryDark : Colors.white,
        fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
      )),
    ]),
  );
}

class _NutriBadge extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _NutriBadge({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('$value $unit', style: TextStyle(color: color, fontSize: 15,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 10,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
      ]),
    ]),
  );
}

class _ShareStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _ShareStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(color: color, fontSize: 15,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 10,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
      ]),
    ]),
  );
}

// ── Post-cook share bottom sheet ───────────────────────────────────────────────
class _ShareBottomSheet extends StatefulWidget {
  final String dishName;
  final int calories;
  final int protein;
  final int streak;
  final ScreenshotController screenshotCtrl;

  const _ShareBottomSheet({
    required this.dishName,
    required this.calories,
    required this.protein,
    required this.streak,
    required this.screenshotCtrl,
  });

  @override
  State<_ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<_ShareBottomSheet> {
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final bytes = await widget.screenshotCtrl.captureFromLongWidget(
        Material(
          color: Colors.transparent,
          child: PlatelyShareCard(
            dishName: widget.dishName,
            calories: widget.calories,
            protein: widget.protein,
            streak: widget.streak,
          ),
        ),
        pixelRatio: 3.0,
        context: context,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'plately_cook.png')],
        text: 'Just cooked ${widget.dishName} 🔥 +${widget.calories}kcal +${widget.protein}g protein. '
              'Tracking macros before I cook, not after. #Plately #NoCap',
      );
      if (!mounted) return;
      Navigator.pop(context); // close sheet
      Navigator.pop(context); // back to previous screen
    } catch (_) {
      // share failed silently
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text('Share your W', style: TextStyle(
            color: AppTheme.textPrimary(context), fontSize: 18,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 4),
          Text('let the world know you ate different today',
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans')),
          const SizedBox(height: 20),
          Center(
            child: PlatelyShareCard(
              dishName: widget.dishName,
              calories: widget.calories,
              protein: widget.protein,
              streak: widget.streak,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sharing ? null : _share,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _sharing
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Share', style: TextStyle(
                      fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close sheet
              Navigator.pop(context); // back to previous screen
            },
            child: Text('Done', style: TextStyle(
                color: AppTheme.textMuted(context), fontFamily: 'DM Sans', fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
