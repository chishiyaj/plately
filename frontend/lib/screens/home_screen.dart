import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/tap_scale.dart';
import 'recipe_results_screen.dart';
import 'recipe_detail_screen.dart';
import 'ai_chat_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  final _ingredientCtrl = TextEditingController();

  static const _suggested = [
    {'title': 'Chicken Stir Fry', 'time': '20 min', 'cal': '420 cal', 'protein': '38g protein', 'diff': 'Easy'},
    {'title': 'Egg Fried Rice',   'time': '15 min', 'cal': '380 cal', 'protein': '22g protein', 'diff': 'Easy'},
    {'title': 'Tuna Pasta',       'time': '18 min', 'cal': '490 cal', 'protein': '34g protein', 'diff': 'Medium'},
    {'title': 'Beef Bowl',        'time': '25 min', 'cal': '550 cal', 'protein': '45g protein', 'diff': 'Medium'},
  ];

  static const _actions = [
    {'icon': LucideIcons.scanLine,     'label': 'Scan',   'bg': AppTheme.scanGreen,    'fg': Color(0xFF2E6B29)},
    {'icon': LucideIcons.pencilLine,   'label': 'Type',   'bg': AppTheme.typeBlue,     'fg': Color(0xFF2E3472)},
    {'icon': LucideIcons.layoutGrid,   'label': 'Browse', 'bg': AppTheme.browseYellow, 'fg': Color(0xFF6B5A10)},
    {'icon': LucideIcons.sparkles,     'label': 'Ask AI', 'bg': AppTheme.askPurple,    'fg': Color(0xFF5A1F6B)},
  ];

  @override
  void dispose() { _ingredientCtrl.dispose(); super.dispose(); }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    Widget screen;
    switch (index) {
      case 1: screen = const FavoritesScreen(); break;
      case 3: screen = const AiChatScreen();    break;
      case 4: screen = const ProfileScreen();   break;
      default: return;
    }
    Navigator.push(context, AppTheme.slideRight(screen))
        .then((_) => setState(() => _navIndex = 0));
    setState(() => _navIndex = index);
  }

  void _onScanTap() => Navigator.push(context, AppTheme.slideUp(
      const RecipeResultsScreen(ingredients: ['chicken', 'eggs', 'rice'])));

  void _onActionTap(String label) {
    switch (label) {
      case 'Scan':   _onScanTap(); break;
      case 'Browse': Navigator.push(context, AppTheme.slideRight(const RecipeResultsScreen(ingredients: []))); break;
      case 'Ask AI': Navigator.push(context, AppTheme.slideRight(const AiChatScreen())); break;
      case 'Type':   FocusScope.of(context).requestFocus(FocusNode()); break;
    }
  }

  void _submitIngredients() {
    final text = _ingredientCtrl.text.trim();
    if (text.isEmpty) return;
    final ings = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    Navigator.push(context, AppTheme.slideUp(RecipeResultsScreen(ingredients: ings)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildGreeting()),
          SliverToBoxAdapter(child: _buildScanCard()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(child: _buildSectionHeader('Suggested For You',
              onSeeAll: () => Navigator.push(context, AppTheme.slideRight(const RecipeResultsScreen(ingredients: []))))),
          SliverToBoxAdapter(child: _buildSuggestedRecipes()),
          SliverToBoxAdapter(child: _buildSectionHeader('Recent Activity',
              onSeeAll: () => Navigator.push(context, AppTheme.slideRight(const HistoryScreen())))),
          SliverToBoxAdapter(child: _buildActivity()),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
      bottomNavigationBar: PlatelyBottomNav(currentIndex: _navIndex, onTap: _onNavTap, onScanTap: _onScanTap),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: AppTheme.creamBg,
      elevation: 0,
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.utensils, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Plately', style: TextStyle(color: AppTheme.primaryDark, fontSize: 20, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
            const Spacer(),
            TapScale(
              onTap: () => Navigator.push(context, AppTheme.slideRight(const HistoryScreen())),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderGray),
                    boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8)]),
                child: const Icon(LucideIcons.bell, color: AppTheme.primaryDark, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            TapScale(
              onTap: () => Navigator.push(context, AppTheme.slideRight(const ProfileScreen())),
              child: Container(
                width: 38, height: 38,
                decoration: const BoxDecoration(
                  gradient: AppTheme.tealGradient, shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('M', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: const TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans')),
          const SizedBox(height: 2),
          const Text('What are you\ncooking today?', style: TextStyle(color: AppTheme.darkText, fontSize: 28, fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.15)),
        ],
      )
      .animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildScanCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.tealGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x44043B3C), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Type your ingredients', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: TextField(
                        controller: _ingredientCtrl,
                        onSubmitted: (_) => _submitIngredients(),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'DM Sans'),
                        decoration: InputDecoration(
                          hintText: 'chicken, rice, eggs...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, fontFamily: 'DM Sans'),
                          prefixIcon: Icon(LucideIcons.search, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TapScale(
                      onTap: _submitIngredients,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: AppTheme.green,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Color(0x4476CC4F), blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.chefHat, color: Colors.white, size: 16),
                            SizedBox(width: 7),
                            Text('Find Recipes', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TapScale(
                onTap: _onScanTap,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.camera, color: Colors.white, size: 26),
                      const SizedBox(height: 4),
                      Text('Scan', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
      .animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_actions.length, (i) {
          final a = _actions[i];
          return TapScale(
            onTap: () => _onActionTap(a['label'] as String),
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: a['bg'] as Color,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: (a['bg'] as Color).withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Icon(a['icon'] as IconData, color: a['fg'] as Color, size: 26),
                ),
                const SizedBox(height: 7),
                Text(a['label'] as String, style: const TextStyle(color: AppTheme.darkText, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
              ],
            ).animate(delay: (i * 60).ms).fadeIn(duration: 350.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.darkText, fontSize: 17, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
          if (onSeeAll != null)
            TapScale(
              onTap: onSeeAll,
              child: Row(
                children: [
                  const Text('See all', style: TextStyle(color: AppTheme.primaryDark, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  const Icon(LucideIcons.chevronRight, color: AppTheme.primaryDark, size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestedRecipes() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, top: 14),
        itemCount: _suggested.length,
        itemBuilder: (_, i) {
          final r = _suggested[i];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 155,
              child: RecipeCard(
                title: r['title']!, time: r['time']!, calories: r['cal']!,
                protein: r['protein']!, difficulty: r['diff']!, index: i,
                onTap: () => Navigator.push(context, AppTheme.slideUp(RecipeDetailScreen(title: r['title']!))),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          _ActivityTile(
            icon: LucideIcons.scanLine, bg: AppTheme.scanGreen, fg: const Color(0xFF2E6B29),
            title: 'Scanned ingredients', subtitle: 'Chicken, Garlic, Onion',
            time: 'Today, 2:30 PM', count: '12 recipes',
            onTap: () => Navigator.push(context, AppTheme.slideRight(const HistoryScreen())),
          ).animate(delay: 40.ms).fadeIn(duration: 350.ms).slideX(begin: 0.04),
          const SizedBox(height: 10),
          _ActivityTile(
            icon: LucideIcons.pencilLine, bg: AppTheme.typeBlue, fg: const Color(0xFF2E3472),
            title: 'Manual entry', subtitle: 'Eggs, Tomato, Cheese',
            time: 'Today, 11:00 AM', count: '18 recipes',
            onTap: () => Navigator.push(context, AppTheme.slideRight(const HistoryScreen())),
          ).animate(delay: 100.ms).fadeIn(duration: 350.ms).slideX(begin: 0.04),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final String title, subtitle, time, count;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.icon, required this.bg, required this.fg,
    required this.title, required this.subtitle, required this.time,
    required this.count, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.darkText, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
                  const SizedBox(height: 2),
                  Text(time, style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans')),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
              ),
              child: Text(count, style: const TextStyle(color: AppTheme.greenDark, fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronRight, color: AppTheme.mutedText, size: 15),
          ],
        ),
      ),
    );
  }
}
