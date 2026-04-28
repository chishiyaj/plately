import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/tap_scale.dart';
import '../widgets/plately_logo.dart';
import '../widgets/activity_row.dart';
import '../services/user_prefs_service.dart';
import '../main_shell.dart';
import 'recipe_results_screen.dart';
import 'history_screen.dart';
import 'ingredient_entry_screen.dart';
import 'ai_chat_screen.dart';

// ─── HomeScreen ───────────────────────────────────────────────────────────────
// Tab child of MainShell (index 0). No back nav, no bottom nav logic.
// Profile avatar calls MainShell.switchTab(3) — no duplicate push.
// Recent Activity uses shared ActivityRow widget — same as HistoryScreen.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollCtrl = ScrollController();
  String _initials = 'M';

  static const _suggested = [
    {'title': 'Chicken Stir Fry', 'time': '20 min', 'cal': '420 cal', 'protein': '38g protein', 'diff': 'Easy'},
    {'title': 'Egg Fried Rice',   'time': '15 min', 'cal': '380 cal', 'protein': '22g protein', 'diff': 'Easy'},
    {'title': 'Tuna Pasta',       'time': '18 min', 'cal': '490 cal', 'protein': '34g protein', 'diff': 'Medium'},
    {'title': 'Beef Bowl',        'time': '25 min', 'cal': '550 cal', 'protein': '45g protein', 'diff': 'Medium'},
  ];

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
    _loadInitials();
  }

  Future<void> _loadInitials() async {
    final data = await UserPrefsService.load();
    final name = (data['name'] as String?) ?? 'Marc';
    final parts = name.trim().split(' ');
    final ini = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();
    if (mounted) setState(() => _initials = ini);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
      backgroundColor: AppTheme.creamBg,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildHero()),
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
    );
  }

  Widget _buildAppBar() => SliverAppBar(
    backgroundColor: AppTheme.creamBg,
    elevation: 0, floating: true, snap: true,
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    title: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        const PlatelyLogo(iconSize: 36, wordmarkSize: 18, theme: PlatelyLogoTheme.onLight),
        const Spacer(),
        TapScale(
          onTap: () => MainShell.switchTab(3),
          child: Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
              gradient: AppTheme.tealGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_initials, style: const TextStyle(
                color: Colors.white, fontSize: 14,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
              )),
            ),
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
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.green,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x5576CC4F), blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: const Icon(LucideIcons.arrowRight, color: Colors.white, size: 16),
              ),
            ]),
          ),
        ),
      ]).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildActionRow() {
    const actions = [
      {'icon': LucideIcons.bookOpenText, 'label': 'Browse',  'bg': Color(0xFFDFDC9E), 'fg': Color(0xFF6B5A10)},
      {'icon': LucideIcons.chefHat,      'label': 'Ask AI',  'bg': Color(0xFFD3A7DC), 'fg': Color(0xFF5A1F6B)},
      {'icon': LucideIcons.history,      'label': 'History', 'bg': Color(0xFFC0DCB3), 'fg': Color(0xFF2E6B29)},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                    Navigator.push(context, AppTheme.slideUp(const AiChatScreen()));
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
    padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
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
                title: r['title']!, time: r['time']!,
                calories: r['cal']!, protein: r['protein']!,
                difficulty: r['diff']!, index: i,
                cardGradientColors: colors,
                cardFgColor: _cardFg[i % _cardFg.length],
                onTap: () => Navigator.push(context, AppTheme.zoomIn(
                  RecipeResultsScreen(ingredients: [r['title']!.split(' ').first.toLowerCase()]),
                )),
              ),
            ),
          );
        },
      ),
    );
  }

  // Uses shared ActivityRow — same widget as HistoryScreen. Zero duplication.
  Widget _buildActivity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(children: [
        ActivityRow(
          recipeName: 'Chicken Stir Fry',
          ingredients: 'Chicken, Garlic, Onion',
          time: 'Today, 2:30 PM',
          onTap: () => Navigator.push(context, AppTheme.slideUp(const HistoryScreen())),
        ).animate(delay: 40.ms).fadeIn(duration: 350.ms).slideX(begin: 0.04),
        ActivityRow(
          recipeName: 'Cheesy Scrambled Eggs',
          ingredients: 'Eggs, Tomato, Cheese',
          time: 'Today, 11:00 AM',
          onTap: () => Navigator.push(context, AppTheme.slideUp(const HistoryScreen())),
        ).animate(delay: 100.ms).fadeIn(duration: 350.ms).slideX(begin: 0.04),
      ]),
    );
  }
}
