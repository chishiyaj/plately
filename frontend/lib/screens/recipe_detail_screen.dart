import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/tap_scale.dart';
import '../widgets/ai_tip_card.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';
import 'recipe_results_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String title;
  const RecipeDetailScreen({required this.title, super.key});
  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> with TickerProviderStateMixin {
  bool _showIngredients = true;
  bool _isFavorited = false;
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;
  final Set<int> _checked = {};

  static const _ingredients = [
    {'name': 'Chicken breast',   'amount': '200g'},
    {'name': 'Mixed vegetables', 'amount': '1.5 cups'},
    {'name': 'Soy sauce',        'amount': '2 tbsp'},
    {'name': 'Garlic',           'amount': '3 cloves'},
    {'name': 'Ginger',           'amount': '1 tsp'},
    {'name': 'Sesame oil',       'amount': '1 tbsp'},
    {'name': 'Cornstarch',       'amount': '1 tbsp'},
  ];

  static const _steps = [
    'Slice chicken breast into thin strips. Season generously with salt and pepper.',
    'Mix soy sauce, sesame oil, and cornstarch in a small bowl. Set aside.',
    'Heat a wok or large pan over high heat. Add oil until shimmering.',
    'Add chicken and cook for 3â€“4 minutes until golden. Remove and set aside.',
    'In the same pan, stir-fry vegetables for 2â€“3 minutes until tender-crisp.',
    'Return chicken to pan. Pour sauce over everything and toss to coat.',
    'Serve hot over rice and garnish with sesame seeds.',
  ];

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroCtrl.forward();
  }

  @override
  void dispose() { _heroCtrl.dispose(); super.dispose(); }

  void _onNavTap(int index) {
    Widget screen;
    switch (index) {
      case 0: screen = const HomeScreen();      break;
      case 1: screen = const FavoritesScreen(); break;
      case 2: screen = RecipeResultsScreen(ingredients: const ['chicken', 'eggs', 'rice']); break;
      case 3: screen = const AiChatScreen();    break;
      case 4: screen = const ProfileScreen();   break;
      default: return;
    }
    Navigator.pushReplacement(context, AppTheme.slideRight(screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      extendBody: true,
      body: Column(
        children: [
          _buildHero(context),
          _buildTabs(),
          Expanded(
            child: AnimatedSwitcher(
              duration: 280.ms,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim), child: child),
              ),
              child: SingleChildScrollView(
                key: ValueKey(_showIngredients),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                child: Column(
                  children: [
                    _showIngredients ? _buildIngredients() : _buildSteps(),
                    const SizedBox(height: 16),
                    _buildNutrition(),
                    const SizedBox(height: 14),
                    const AiTipCard(tip: 'Velvet the chicken by marinating in cornstarch + egg white for 15 min before cooking â€” it stays incredibly tender at high heat.'),
                    const SizedBox(height: 18),
                    _buildActionBtn(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: PlatelyBottomNav(currentIndex: 2, onTap: _onNavTap, onScanTap: () => _onNavTap(2)),
    );
  }

  Widget _buildHero(BuildContext context) {
    return FadeTransition(
      opacity: _heroFade,
      child: Stack(
        children: [
          Container(
            height: 260, width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFD8EDD4), Color(0xFFC0DCB3)],
              ),
            ),
            child: const Center(child: Icon(LucideIcons.chefHat, size: 80, color: Color(0xFF4A8A46))),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 130,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Color(0xEE000000), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16, left: 20, right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Wrap(spacing: 8, children: [
                  _MetaBadge(icon: LucideIcons.clock3,          label: '20 min'),
                  _MetaBadge(icon: LucideIcons.flame,           label: '420 cal'),
                  _MetaBadge(icon: LucideIcons.dumbbell,        label: '38g protein', highlight: true),
                  _MetaBadge(icon: LucideIcons.signalHigh,      label: 'Easy'),
                ]),
              ],
            ),
          ),
          // Back
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
          // Favourite
          Positioned(
            top: 48, right: 16,
            child: TapScale(
              onTap: () => setState(() => _isFavorited = !_isFavorited),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _isFavorited ? AppTheme.red.withValues(alpha: 0.9) : Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_isFavorited ? LucideIcons.heartCrack : LucideIcons.heart, color: Colors.white, size: 18),
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
      decoration: BoxDecoration(color: AppTheme.lightGray.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _Tab(label: 'Ingredients', selected: _showIngredients,  onTap: () => setState(() => _showIngredients = true)),
          _Tab(label: 'Steps',       selected: !_showIngredients, onTap: () => setState(() => _showIngredients = false)),
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    return Column(
      children: List.generate(_ingredients.length, (i) {
        final ing = _ingredients[i];
        return TapScale(
          onTap: () => setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: 200.ms,
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _checked.contains(i) ? AppTheme.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _checked.contains(i) ? AppTheme.green : AppTheme.borderGray, width: 1.5),
                  ),
                  child: _checked.contains(i) ? const Icon(LucideIcons.check, color: Colors.white, size: 13) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(ing['name']!, style: TextStyle(
                  color: _checked.contains(i) ? AppTheme.mutedText : AppTheme.darkText,
                  fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
                  decoration: _checked.contains(i) ? TextDecoration.lineThrough : null,
                ))),
                Text(ing['amount']!, style: const TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
              ],
            ),
          ).animate(delay: (i * 40).ms).fadeIn(duration: 300.ms).slideX(begin: 0.04),
        );
      }),
    );
  }

  Widget _buildSteps() {
    return Column(
      children: List.generate(_steps.length, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
                child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_steps[i], style: const TextStyle(color: AppTheme.darkText, fontSize: 14, fontFamily: 'DM Sans', height: 1.5))),
            ],
          ),
        ).animate(delay: (i * 50).ms).fadeIn(duration: 300.ms).slideX(begin: 0.04);
      }),
    );
  }

  Widget _buildNutrition() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Row(children: [
            Text('Nutrition per serving', style: TextStyle(color: AppTheme.darkText, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            Spacer(),
            Text('1 serving', style: TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
          ]),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NutriBadge(label: 'Calories', value: '420', unit: 'kcal', color: AppTheme.orange),
              _NutriBadge(label: 'Protein',  value: '38',  unit: 'g',    color: AppTheme.green),
              _NutriBadge(label: 'Carbs',    value: '32',  unit: 'g',    color: AppTheme.typeBlue),
              _NutriBadge(label: 'Fat',      value: '12',  unit: 'g',    color: AppTheme.askPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn() {
    return TapScale(
      onTap: () => _showIngredients ? setState(() => _showIngredients = false) : Navigator.pop(context),
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: _showIngredients ? AppTheme.tealGradient : AppTheme.greenGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x44043B3C), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_showIngredients ? LucideIcons.chefHat : LucideIcons.circleCheck, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(_showIngredients ? "Let's Cook" : 'Finish Cooking', style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
          child: Center(
            child: Text(label, style: TextStyle(
              color: selected ? AppTheme.primaryDark : AppTheme.mutedText,
              fontSize: 13, fontFamily: 'DM Sans', fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            )),
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _MetaBadge({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.green : Colors.black38,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: highlight ? AppTheme.primaryDark : Colors.white),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: highlight ? AppTheme.primaryDark : Colors.white, fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _NutriBadge extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _NutriBadge({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Center(child: Text(value, style: TextStyle(color: color, fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w800))),
        ),
        const SizedBox(height: 5),
        Text(unit, style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans')),
        Text(label, style: const TextStyle(color: AppTheme.darkText, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
      ],
    );
  }
}

