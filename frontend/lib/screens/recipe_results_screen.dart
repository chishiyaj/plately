import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/tap_scale.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';

class RecipeResultsScreen extends StatefulWidget {
  final List<String> ingredients;
  const RecipeResultsScreen({required this.ingredients, super.key});
  @override
  State<RecipeResultsScreen> createState() => _RecipeResultsScreenState();
}

class _RecipeResultsScreenState extends State<RecipeResultsScreen> {
  String _activeFilter = 'All';
  List<Recipe> _all = [];
  bool _loading = true;
  String? _error;

  static const _filters = ['All', 'Asian', 'Italian', 'Vegetarian', 'Low-Cal', 'High-Protein'];

  List<Recipe> get _filtered => _activeFilter == 'All'
      ? _all
      : _all.where((r) => r.tags.contains(_activeFilter)).toList();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() { _loading = true; _error = null; });
    try {
      final recipes = await ApiService.getRecipes(widget.ingredients);
      if (mounted) setState(() { _all = recipes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
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
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      // No bottomNavigationBar — this is a pushed screen, back arrow handles nav
    );
  }

  Widget _buildContent() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (_filtered.isEmpty) return _buildEmpty();
    return _buildGrid();
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0DDD8),
      highlightColor: const Color(0xFFF5F3EF),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 14, mainAxisSpacing: 14,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.wifiOff, size: 48, color: AppTheme.mutedText),
          const SizedBox(height: 16),
          const Text('Could not load recipes', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.darkText)),
          const SizedBox(height: 8),
          const Text('Is the backend running?', style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: AppTheme.mutedText)),
          const SizedBox(height: 20),
          TapScale(
            onTap: _loadRecipes,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: AppTheme.primaryDark, borderRadius: BorderRadius.circular(24)),
              child: const Text('Retry', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.chefHat, size: 48, color: AppTheme.mutedText),
        const SizedBox(height: 16),
        const Text('No recipes found', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.darkText)),
        const SizedBox(height: 6),
        Text(_activeFilter == 'All' ? 'Try different ingredients' : 'No $_activeFilter recipes yet',
            style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: AppTheme.mutedText)),
      ]),
    );
  }

  Widget _buildGrid() {
    final recipes = _filtered;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 14, mainAxisSpacing: 14,
      ),
      itemCount: recipes.length,
      itemBuilder: (_, i) {
        final r = recipes[i];
        return RecipeCard(
          title: r.name,
          time: r.cookTime,
          calories: '${r.calories} cal',
          protein: '${r.protein}g protein',
          difficulty: r.difficulty,
          index: i,
          onTap: () => Navigator.push(context, AppTheme.slideUp(RecipeDetailScreen(recipe: r))),
        );
      },
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
                  Text(widget.ingredients.take(3).join(', '),
                      style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans'),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (!_loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_filtered.length} found',
                  style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
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
}
