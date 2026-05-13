import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import '../widgets/tap_scale.dart';
import '../services/api_service.dart';
import 'recipe_detail_screen.dart';
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
  List<Recipe> _favorites = [];
  bool _loading = true;

  final _filters = const ['All', 'Asian', 'Filipino', 'Italian', 'Vegetarian', 'High-Protein', 'Low-Cal'];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final favs = await ApiService.getFavorites();
    if (mounted) setState(() { _favorites = favs; _loading = false; });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Recipe> get _filtered {
    var list = _favorites.where((r) =>
        r.name.toLowerCase().contains(_query.toLowerCase())).toList();
    if (_filter != 'All') {
      list = list.where((r) => r.tags.contains(_filter)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 4),
            Expanded(child: _loading ? _buildShimmer() : RefreshIndicator(
              color: AppTheme.primaryDark,
              backgroundColor: AppTheme.cardBg(context),
              onRefresh: _loadFavorites,
              child: _buildGrid(),
            )),
          ],
        ),
      ),
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
                Text('Favorites',
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 24,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                Text(_loading ? 'Loading...' : '${_favorites.length} saved recipes',
                    style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans')),
              ],
            ),
          ),
          TapScale(
            onTap: _loadFavorites,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: const Icon(LucideIcons.refreshCw, color: AppTheme.primaryDark, size: 18),
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
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(fontSize: 14, fontFamily: 'DM Sans', color: AppTheme.textPrimary(context)),
        decoration: InputDecoration(
          hintText: 'Search saved recipes...',
          hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 14, fontFamily: 'DM Sans'),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(LucideIcons.search, size: 18, color: AppTheme.textMuted(context)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
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
                color: sel ? AppTheme.primaryDark : AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppTheme.primaryDark : AppTheme.border(context)),
                boxShadow: sel
                    ? [const BoxShadow(color: Color(0x22043B3C), blurRadius: 8, offset: Offset(0, 3))]
                    : [],
              ),
              child: Center(
                child: Text(f,
                    style: TextStyle(
                      color: sel ? Colors.white : AppTheme.textPrimary(context),
                      fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.lightGray.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
       .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6)),
    );
  }

  Widget _buildGrid() {
    final items = _filtered;

    if (_favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustrated icon stack — plate + heart
              SizedBox(
                width: 100, height: 100,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(LucideIcons.utensils, size: 44,
                      color: AppTheme.primaryDark.withValues(alpha: 0.18)),
                  Positioned(
                    bottom: 14, right: 14,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border(context), width: 1.5),
                      ),
                      child: const Icon(LucideIcons.heart, size: 16, color: AppTheme.red),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text('No saved recipes yet',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context), fontSize: 17,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 8),
              Text(
                'Tap the heart on any recipe to save it here for later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted(context), fontSize: 13,
                  fontFamily: 'DM Sans', height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TapScale(
                // FIX: open the full recipe browse grid instead of Home tab
                onTap: () => Navigator.push(
                  context,
                  AppTheme.slideUp(const RecipeResultsScreen(ingredients: [])),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33043B3C), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.chefHat, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Browse Recipes', style: TextStyle(
                      color: Colors.white, fontSize: 14,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                    )),
                  ]),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06),
        ),
      );
    }

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
            Text('No recipes found',
                style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 16,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Try a different search or filter',
                style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans')),
          ],
        ).animate().fadeIn(duration: 300.ms),
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
          title: r.name, time: r.cookTime,
          calories: '${r.calories} cal',
          protein: '${r.protein}g protein',
          difficulty: r.difficulty, index: i,
          imageUrl: r.imageUrl,
          costPhp: r.costPhp,
          isFavorited: true,
          onTap: () => Navigator.push(context,
              AppTheme.slideUp(RecipeDetailScreen(recipe: r))).then((_) => _loadFavorites()),
        ).animate().fadeIn(delay: (i * 60).ms, duration: 300.ms)
            .slideY(begin: 0.1, end: 0, delay: (i * 60).ms, duration: 300.ms);
      },
    );
  }
}
