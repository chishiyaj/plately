import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/tap_scale.dart';
import 'recipe_results_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _filter = 'All';
  final _searchCtrl = TextEditingController();
  String _query = '';

  final _filters = const ['All', 'Breakfast', 'Lunch', 'Dinner', 'Asian', 'Italian', 'Vegan'];

  final _favorites = const [
    {'title': 'Chicken Stir Fry', 'time': '20 min', 'cal': '420 cal', 'protein': '38g protein', 'diff': 'Easy'},
    {'title': 'Egg Fried Rice',   'time': '15 min', 'cal': '380 cal', 'protein': '22g protein', 'diff': 'Easy'},
    {'title': 'Tuna Pasta',       'time': '18 min', 'cal': '490 cal', 'protein': '34g protein', 'diff': 'Medium'},
    {'title': 'Greek Salad',      'time': '10 min', 'cal': '280 cal', 'protein': '14g protein', 'diff': 'Easy'},
    {'title': 'Beef Bowl',        'time': '25 min', 'cal': '550 cal', 'protein': '45g protein', 'diff': 'Medium'},
    {'title': 'Omelette',         'time': '8 min',  'cal': '240 cal', 'protein': '18g protein', 'diff': 'Easy'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filtered =>
      _favorites.where((r) => r['title']!.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 4),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
      // No bottomNavigationBar — MainShell owns it
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Favorites',
                    style: TextStyle(color: AppTheme.darkText, fontSize: 24,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                Text('${_favorites.length} saved recipes',
                    style: const TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
              ],
            ),
          ),
          TapScale(
            onTap: () {},
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderGray),
              ),
              child: const Icon(LucideIcons.arrowUpDown, color: AppTheme.primaryDark, size: 18),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGray),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 14, fontFamily: 'DM Sans', color: AppTheme.darkText),
        decoration: const InputDecoration(
          hintText: 'Search saved recipes...',
          hintStyle: TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans'),
          prefixIcon: Padding(
            padding: EdgeInsets.all(14),
            child: Icon(LucideIcons.search, size: 18, color: AppTheme.mutedText),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 15),
          border: InputBorder.none,
        ),
      ),
    ).animate().fadeIn(delay: 80.ms, duration: 300.ms);
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 24),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f = _filters[i];
          final sel = _filter == f;
          return TapScale(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primaryDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppTheme.primaryDark : AppTheme.borderGray),
                boxShadow: sel
                    ? [const BoxShadow(color: Color(0x22043B3C), blurRadius: 8, offset: Offset(0, 3))]
                    : [],
              ),
              child: Center(
                child: Text(f,
                    style: TextStyle(
                      color: sel ? Colors.white : AppTheme.darkText,
                      fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  color: AppTheme.borderGray.withValues(alpha: 0.5),
                  shape: BoxShape.circle),
              child: const Icon(LucideIcons.searchX, size: 36, color: AppTheme.mutedText),
            ),
            const SizedBox(height: 16),
            const Text('No recipes found',
                style: TextStyle(color: AppTheme.darkText, fontSize: 16,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Try a different search',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
          ],
        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final r = items[i];
        return RecipeCard(
          title: r['title']!, time: r['time']!, calories: r['cal']!,
          protein: r['protein']!, difficulty: r['diff']!, index: i,
          onTap: () => Navigator.push(context,
              AppTheme.slideUp(RecipeResultsScreen(ingredients: [r['title']!.split(' ').first.toLowerCase()]))),
        ).animate().fadeIn(delay: (i * 60).ms, duration: 300.ms)
            .slideY(begin: 0.1, end: 0, delay: (i * 60).ms, duration: 300.ms);
      },
    );
  }
}
