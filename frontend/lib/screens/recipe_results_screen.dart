import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/tap_scale.dart';
import 'recipe_detail_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';

class RecipeResultsScreen extends StatefulWidget {
  final List<String> ingredients;
  const RecipeResultsScreen({required this.ingredients, super.key});
  @override
  State<RecipeResultsScreen> createState() => _RecipeResultsScreenState();
}

class _RecipeResultsScreenState extends State<RecipeResultsScreen> {
  int _navIndex = 2;
  String _activeFilter = 'All';

  static const _filters = ['All', 'Asian', 'Italian', 'Vegetarian', 'Low-Cal', 'High-Protein'];

  static const _recipes = [
    {'title': 'Chicken Stir Fry',       'time': '20 min', 'cal': '420 cal', 'protein': '38g protein', 'diff': 'Easy'},
    {'title': 'Egg Fried Rice',          'time': '15 min', 'cal': '380 cal', 'protein': '22g protein', 'diff': 'Easy'},
    {'title': 'Tuna Pasta',              'time': '18 min', 'cal': '490 cal', 'protein': '34g protein', 'diff': 'Medium'},
    {'title': 'Beef Bowl',               'time': '25 min', 'cal': '550 cal', 'protein': '45g protein', 'diff': 'Medium'},
    {'title': 'Veggie Omelette',         'time': '10 min', 'cal': '310 cal', 'protein': '24g protein', 'diff': 'Easy'},
    {'title': 'Garlic Shrimp Pasta',     'time': '22 min', 'cal': '520 cal', 'protein': '32g protein', 'diff': 'Medium'},
  ];

  void _onNavTap(int index) {
    Widget screen;
    switch (index) {
      case 0: screen = const HomeScreen();      break;
      case 1: screen = const FavoritesScreen(); break;
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildFilterRow(),
            const SizedBox(height: 4),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
      bottomNavigationBar: PlatelyBottomNav(currentIndex: _navIndex, onTap: _onNavTap, onScanTap: () {}),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          TapScale(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderGray),
                  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8)]),
              child: const Icon(LucideIcons.arrowLeft, size: 18, color: AppTheme.primaryDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recipe Results', style: TextStyle(color: AppTheme.darkText, fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                if (widget.ingredients.isNotEmpty)
                  Text(widget.ingredients.take(3).join(', '), style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans'), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_recipes.length} found', style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _filters.length,
          itemBuilder: (_, i) {
            final active = _filters[i] == _activeFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TapScale(
                onTap: () => setState(() => _activeFilter = _filters[i]),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? AppTheme.primaryDark : AppTheme.borderGray),
                    boxShadow: active ? const [BoxShadow(color: Color(0x33043B3C), blurRadius: 8, offset: Offset(0, 3))] : [],
                  ),
                  child: Text(_filters[i], style: TextStyle(
                    color: active ? Colors.white : AppTheme.mutedText,
                    fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
                  )),
                ),
              ),
            );
          },
        ),
      ),
    ).animate().fadeIn(duration: 350.ms, delay: 80.ms);
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 14, mainAxisSpacing: 14,
      ),
      itemCount: _recipes.length,
      itemBuilder: (_, i) {
        final r = _recipes[i];
        return RecipeCard(
          title: r['title']!, time: r['time']!, calories: r['cal']!,
          protein: r['protein']!, difficulty: r['diff']!, index: i,
          onTap: () => Navigator.push(context, AppTheme.slideUp(RecipeDetailScreen(title: r['title']!))),
        );
      },
    );
  }
}
