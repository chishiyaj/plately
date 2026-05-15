import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/tap_scale.dart';
import '../services/api_service.dart';
import '../services/offline_recipe_service.dart';
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
  bool _offline = false;
  bool _fromCache = false;
  String? _errorMsg;    // non-null = API returned an error to show

  // ── Search ─────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Infinite scroll ────────────────────────────────────────────────────────
  static const _pageSize = 10;
  int _visibleCount = _pageSize;
  bool _loadingMore = false;
  late final ScrollController _scrollCtrl;

  static const _filters = ['All', 'Asian', 'Filipino', 'Italian', 'Vegetarian', 'Low-Cal', 'High-Protein'];

  List<Recipe> get _filtered {
    var list = _activeFilter == 'All'
        ? _all
        : _all.where((r) => r.tags.contains(_activeFilter)).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) => r.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<Recipe> get _visible {
    final f = _filtered;
    return f.take(_visibleCount).toList();
  }

  bool get _hasMore => _visibleCount < _filtered.length;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _searchCtrl.addListener(() {
      setState(() { _searchQuery = _searchCtrl.text.trim(); _visibleCount = _pageSize; });
    });
    _loadRecipes();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) _loadMore();
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _visibleCount = (_visibleCount + _pageSize).clamp(0, _filtered.length);
          _loadingMore = false;
        });
      }
    });
  }

  Future<void> _loadRecipes() async {
    setState(() { _loading = true; _offline = false; _fromCache = false; _errorMsg = null; _visibleCount = _pageSize; });

    RecipesResult? result;
    try {
      result = await ApiService.getRecipesResult(widget.ingredients);
    } on RecipeApiException catch (e) {
      if (!mounted) return;
      // Cache browse-mode results even on previous success
      setState(() { _errorMsg = e.message; _loading = false; });
      return;
    }

    if (!mounted) return;

    if (result.offline) {
      // Network unreachable -- try cache for browse mode
      if (widget.ingredients.isEmpty) {
        final cached = await OfflineRecipeService.getCachedRecipes();
        if (!mounted) return;
        if (cached.isNotEmpty) {
          setState(() { _all = cached; _fromCache = true; _offline = false; _loading = false; });
        } else {
          setState(() { _all = []; _offline = true; _fromCache = false; _loading = false; });
        }
      } else {
        setState(() { _all = []; _offline = true; _fromCache = false; _loading = false; });
      }
      return;
    }

    final recipes = result.recipes;
    if (recipes.isNotEmpty && widget.ingredients.isEmpty) {
      await OfflineRecipeService.cacheRecipes(recipes);
    }
    setState(() { _all = recipes; _offline = false; _fromCache = false; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(context),
          _buildFilterRow(),
          // Show search bar only in browse mode (no ingredients) when we have results
          if (!_loading && !_offline && widget.ingredients.isEmpty)
            _buildSearchBar(),
          // Offline cache banner
          if (_fromCache) _buildOfflineBanner(),
          const SizedBox(height: 4),
          Expanded(child: _buildContent()),
        ]),
      ),
    );
  }

  // ── Offline cache banner ───────────────────────────────────────────────────
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.yellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.yellow.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(LucideIcons.wifiOff, size: 14, color: AppTheme.yellow),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Offline mode -- showing saved recipes',
            style: TextStyle(
              color: AppTheme.yellow, fontSize: 12,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TapScale(
          onTap: _loadRecipes,
          child: const Text('Retry',
            style: TextStyle(color: AppTheme.yellow, fontSize: 12,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: AppTheme.textPrimary(context)),
        decoration: AppTheme.inputDecoration(
          context: context,
          hint: 'Search recipes...',
          prefixIcon: Icon(LucideIcons.search, size: 16, color: AppTheme.textMuted(context)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x, size: 16, color: AppTheme.textMuted(context)),
                  onPressed: () { _searchCtrl.clear(); },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return _buildShimmer();
    if (_errorMsg != null) return _buildErrorState(_errorMsg!);
    if (_offline) return _buildOfflineState();
    if (_filtered.isEmpty && _searchQuery.isNotEmpty) return _buildNoSearchResults();
    if (_filtered.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: AppTheme.primaryDark,
      backgroundColor: AppTheme.cardBg(context),
      onRefresh: _loadRecipes,
      child: _buildGrid(),
    );
  }

  Widget _buildShimmer() {
    final hasIngredients = widget.ingredients.isNotEmpty;
    return Column(children: [
      if (hasIngredients)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(children: [
            const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark)),
            const SizedBox(width: 10),
            Text('AI is generating personalised recipes...',
              style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
          ]),
        ),
      Expanded(
        child: Shimmer.fromColors(
          baseColor: AppTheme.isDark(context) ? AppTheme.darkCardAlt : const Color(0xFFE0DDD8),
          highlightColor: AppTheme.isDark(context) ? AppTheme.darkCard : const Color(0xFFF5F3EF),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.72,
              crossAxisSpacing: 14, mainAxisSpacing: 14,
            ),
            itemCount: 6,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildErrorState(String msg) {
    final isBusy = msg.toLowerCase().contains('busy') || msg.toLowerCase().contains('429');
    return RefreshIndicator(
      color: AppTheme.primaryDark,
      backgroundColor: AppTheme.cardBg(context),
      onRefresh: _loadRecipes,
      child: ListView(padding: const EdgeInsets.all(32), children: [
        const SizedBox(height: 48),
        Center(child: Icon(
          isBusy ? LucideIcons.clockAlert : LucideIcons.serverOff,
          size: 52, color: AppTheme.textMuted(context))),
        const SizedBox(height: 20),
        Center(child: Text(
          isBusy ? 'AI is busy right now' : 'Could not load recipes',
          style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
              fontSize: 17, color: AppTheme.textPrimary(context)))),
        const SizedBox(height: 8),
        Center(child: Text(
          isBusy ? 'Showing saved recipes instead -- try again in a moment.' : msg,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: AppTheme.textMuted(context)))),
        const SizedBox(height: 28),
        Center(child: TapScale(
          onTap: _loadRecipes,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(color: AppTheme.primaryDark, borderRadius: BorderRadius.circular(24)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.refreshCw, color: Colors.white, size: 15),
              SizedBox(width: 8),
              Text('Try Again', style: TextStyle(fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _buildOfflineState() {
    return RefreshIndicator(
      color: AppTheme.primaryDark,
      backgroundColor: AppTheme.cardBg(context),
      onRefresh: _loadRecipes,
      child: ListView(padding: const EdgeInsets.all(32), children: [
        const SizedBox(height: 48),
        Center(child: Icon(LucideIcons.wifiOff, size: 52, color: AppTheme.textMuted(context))),
        const SizedBox(height: 20),
        Center(child: Text('No internet connection',
            style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                fontSize: 17, color: AppTheme.textPrimary(context)))),
        const SizedBox(height: 8),
        Center(child: Text('Connect once to load recipes -- they\'ll be saved for offline use.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: AppTheme.textMuted(context)))),
        const SizedBox(height: 28),
        Center(child: TapScale(
          onTap: _loadRecipes,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(color: AppTheme.primaryDark, borderRadius: BorderRadius.circular(24)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.refreshCw, color: Colors.white, size: 15),
              SizedBox(width: 8),
              Text('Try Again', style: TextStyle(fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.searchX, size: 48, color: AppTheme.textMuted(context)),
      const SizedBox(height: 16),
      Text('No recipes match "$_searchQuery"',
          style: TextStyle(fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary(context))),
      const SizedBox(height: 6),
      Text('Try a different name',
          style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: AppTheme.textMuted(context))),
      const SizedBox(height: 20),
      TapScale(
        onTap: () => _searchCtrl.clear(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryDark, borderRadius: BorderRadius.circular(20)),
          child: const Text('Clear search', style: TextStyle(
              color: Colors.white, fontFamily: 'DM Sans', fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    ]));
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.chefHat, size: 48, color: AppTheme.textMuted(context)),
      const SizedBox(height: 16),
      Text('No recipes found', style: TextStyle(fontFamily: 'DM Sans',
          fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary(context))),
      const SizedBox(height: 6),
      Text(_activeFilter == 'All' ? 'Try different ingredients' : 'No $_activeFilter recipes yet',
          style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: AppTheme.textMuted(context))),
    ]));
  }

  Widget _buildGrid() {
    final visible = _visible;
    final total = _filtered.length;

    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_searchQuery.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                '$total result${total == 1 ? '' : 's'} for "$_searchQuery"',
                style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w500),
              ),
            ),
          )
        else if (total > _pageSize)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Showing ${visible.length} of $total recipes',
                style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w500),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.72,
              crossAxisSpacing: 14, mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final r = visible[i];
                return RecipeCard(
                  title: r.name,
                  time: r.cookTime,
                  calories: '${r.calories} cal',
                  protein: '${r.protein}g protein',
                  difficulty: r.difficulty,
                  index: i,
                  imageUrl: r.imageUrl,
                  costPhp: r.costPhp,
                  onTap: () => Navigator.push(context,
                      AppTheme.slideUp(RecipeDetailScreen(
                        recipe: r,
                        userIngredients: widget.ingredients,
                      ))),
                );
              },
              childCount: visible.length,
            ),
          ),
        ),
        if (_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120, top: 4),
              child: Center(
                child: _loadingMore
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppTheme.primaryDark))
                    : const SizedBox.shrink(),
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        TapScale(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: AppTheme.cardBg(context), shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border(context))),
            child: const Icon(LucideIcons.arrowLeft, size: 18, color: AppTheme.primaryDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.ingredients.isEmpty ? 'Browse Recipes' : 'Your Recipes',
              style: TextStyle(
                color: AppTheme.textPrimary(context), fontSize: 20,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.ingredients.isNotEmpty)
              Text(
                widget.ingredients.join(', '),
                style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12, fontFamily: 'DM Sans'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final active = _activeFilter == f;
          return TapScale(
            onTap: () => setState(() { _activeFilter = f; _visibleCount = _pageSize; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryDark : AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? AppTheme.primaryDark : AppTheme.border(context)),
              ),
              child: Text(f,
                style: TextStyle(
                  color: active ? Colors.white : AppTheme.textMuted(context),
                  fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
                )),
            ),
          );
        },
      ),
    );
  }
}
