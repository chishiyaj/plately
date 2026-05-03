import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/user_prefs_service.dart';
import '../services/notification_service.dart';
import '../models/recipe.dart';
import '../widgets/tap_scale.dart';
import '../widgets/ai_tip_card.dart';
import '../widgets/recipe_card.dart' show recipeImageUrl;
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
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;
  final Set<int> _checked = {};
  // Serving size scaler — all macros + ingredient amounts multiply by this
  double _servings = 1.0;
  static const _servingOptions = [0.5, 1.0, 1.5, 2.0, 3.0];

  Recipe get r => widget.recipe;

  List<String> get _steps => r.instructions
      .split('\n')
      .map((s) => s.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroCtrl.forward();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    if (r.id < 0) return; // AI-generated recipes can't be favorited
    final saved = await ApiService.isFavorite(r.id);
    if (mounted) setState(() => _isFavorited = saved);
  }

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
    final newState = await ApiService.toggleFavorite(r.id);
    if (mounted) setState(() => _isFavorited = newState);
  }

  @override
  void dispose() { _heroCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      extendBody: true,
      floatingActionButton: Padding(
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
      ),
    );
  }

  String _aiTip() {
    if (r.tags.contains('Asian'))       return 'For best stir-fry results, use high heat and keep ingredients moving — this gives that restaurant-style wok hei flavour.';
    if (r.tags.contains('Italian'))     return 'Salt your pasta water generously — it should taste like the sea. This is the only chance to season the pasta itself.';
    if (r.tags.contains('High-Protein')) return 'Let protein rest 2–3 min after cooking — it stays juicier and retains more nutrients.';
    return 'Prep all ingredients before you start cooking — it makes the whole process faster and less stressful.';
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
            child: Image.network(
              imgUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: const Color(0xFFD8EDD4),
                  child: const Center(child: Icon(LucideIcons.utensils, size: 60, color: Color(0x664A8A46))),
                );
              },
              errorBuilder: (_, __, ___) => Container(
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
          // Favorite button
          Positioned(
            top: 48, right: 16,
            child: TapScale(
              onTap: _toggleFavorite,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _isFavorited ? AppTheme.red.withValues(alpha: 0.9) : Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.heart,
                    color: _isFavorited ? Colors.white : Colors.white60, size: 18),
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
          color: AppTheme.lightGray.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        _Tab(label: 'Ingredients', selected: _showIngredients,  onTap: () => setState(() => _showIngredients = true)),
        _Tab(label: 'Steps',       selected: !_showIngredients, onTap: () => setState(() => _showIngredients = false)),
      ]),
    );
  }

  Widget _buildIngredients() {
    final ings = r.ingredients;
    if (ings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No ingredient details available.',
            style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText))),
      );
    }
    return Column(
      children: List.generate(ings.length, (i) {
        final ing = ings[i];
        // Scale ingredient amount by serving multiplier
        final scaledAmount = _scaleAmount(ing.amount, _servings);
        return TapScale(
          onTap: () => setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
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
                      color: _checked.contains(i) ? AppTheme.green : AppTheme.borderGray, width: 1.5),
                ),
                child: _checked.contains(i)
                    ? const Icon(LucideIcons.check, color: Colors.white, size: 13) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(ing.name, style: TextStyle(
                color: _checked.contains(i) ? AppTheme.mutedText : AppTheme.darkText,
                fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
                decoration: _checked.contains(i) ? TextDecoration.lineThrough : null,
              ))),
              Text(scaledAmount, style: TextStyle(
                color: _servings != 1.0 ? AppTheme.primaryDark : AppTheme.mutedText,
                fontSize: 13, fontFamily: 'DM Sans',
                fontWeight: _servings != 1.0 ? FontWeight.w700 : FontWeight.w500,
              )),
            ]),
          ).animate(delay: (i * 40).ms).fadeIn(duration: 300.ms).slideX(begin: 0.04),
        );
      }),
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
      children: List.generate(steps.length, (i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
            child: Center(child: Text('${i + 1}', style: const TextStyle(
                color: Colors.white, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(steps[i], style: const TextStyle(
              color: AppTheme.darkText, fontSize: 14, fontFamily: 'DM Sans', height: 1.5))),
        ]),
      ).animate(delay: (i * 50).ms).fadeIn(duration: 300.ms).slideX(begin: 0.04)),
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
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        // ── Header + serving scaler ────────────────────────────────────────
        Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nutrition Facts', style: TextStyle(
                color: AppTheme.darkText, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            Text('Tap to adjust servings', style: TextStyle(
                color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans')),
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
                  color: selected ? AppTheme.primaryDark : AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? AppTheme.primaryDark : AppTheme.borderGray),
                ),
                child: Text(label, style: TextStyle(
                  color: selected ? Colors.white : AppTheme.mutedText,
                  fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                )),
              ),
            );
          })),
        ]),
        const SizedBox(height: 16),
        // ── Macro circles ─────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
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
      ]),
    );
  }

  Widget _buildActionBtn() {
    return TapScale(
      onTap: () async {
        if (_showIngredients) {
          setState(() => _showIngredients = false);
        } else {
          await Future.wait([
            ApiService.logHistory(
              ingredientNames: r.ingredients.isEmpty
                  ? r.name
                  : r.ingredients.map((i) => i.name).join(', '),
              actionType: 'cooked',
              recipeCount: 1,
            ),
            UserPrefsService.incrementRecipeCount(),
            NotificationService.notifyCookingDone(r.name),
          ]);
          if (mounted) Navigator.pop(context);
        }
      },
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: _showIngredients ? AppTheme.tealGradient : AppTheme.greenGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x44043B3C), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_showIngredients ? LucideIcons.chefHat : LucideIcons.circleCheck,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(_showIngredients ? "Let's Cook" : 'Finish Cooking',
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
        ]),
      ),
    );
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
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? const [BoxShadow(color: Color(0x12000000), blurRadius: 6)] : [],
        ),
        child: Center(child: Text(label, style: TextStyle(
          color: selected ? AppTheme.primaryDark : AppTheme.mutedText,
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
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 58, height: 58,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Center(child: Text(value, style: TextStyle(
          color: color, fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w800))),
    ),
    const SizedBox(height: 5),
    Text(unit, style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans')),
    Text(label, style: const TextStyle(
        color: AppTheme.darkText, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
  ]);
}
