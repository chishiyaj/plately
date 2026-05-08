import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

// ── Per-recipe image map ────────────────────────────────────────────────────
const _recipeImages = <String, String>{
  'chicken stir fry':           'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=800&q=80&fit=crop',
  'egg fried rice':             'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800&q=80&fit=crop',
  'tuna pasta':                 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=800&q=80&fit=crop',
  'beef bowl':                  'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=800&q=80&fit=crop',
  'veggie omelette':            'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=800&q=80&fit=crop',
  'garlic shrimp pasta':        'https://images.unsplash.com/photo-1633964913295-ceb43826e7c5?w=800&q=80&fit=crop',
  'tofu scramble':              'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80&fit=crop',
  'salmon with garlic rice':    'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800&q=80&fit=crop',
  'pork cabbage stir fry':      'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800&q=80&fit=crop',
  'bacon and egg toast':        'https://images.unsplash.com/photo-1528607929212-2636ec44253e?w=800&q=80&fit=crop',
  'mushroom and spinach pasta': 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=800&q=80&fit=crop',
  'coconut milk chicken':       'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800&q=80&fit=crop',
  'potato and egg hash':        'https://images.unsplash.com/photo-1606851091851-e8c8c0fea8b1?w=800&q=80&fit=crop',
  'spicy tuna rice bowl':       'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80&fit=crop',
  // Filipino
  'chicken adobo':   'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=800&q=80&fit=crop',
  'pork adobo':      'https://images.unsplash.com/photo-1559847844-5315695dadae?w=800&q=80&fit=crop',
  'sinangag':        'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800&q=80&fit=crop',
  'tapsilog':        'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=800&q=80&fit=crop',
  'chicken tinola':  'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop',
  'sinigang na baboy':'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop',
  'ginisang monggo': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80&fit=crop',
  'tortang talong':  'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=800&q=80&fit=crop',
  'champorado':      'https://images.unsplash.com/photo-1511690743698-d9d85f2fbf38?w=800&q=80&fit=crop',
  'arroz caldo':     'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop',
  'bistek tagalog':  'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=800&q=80&fit=crop',
  'pork nilaga':     'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop',
  'pork menudo':     'https://images.unsplash.com/photo-1559847844-5315695dadae?w=800&q=80&fit=crop',
  'chicken afritada':'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=800&q=80&fit=crop',
  'pancit bihon':    'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800&q=80&fit=crop',
  'lomi':            'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop',
  'bicol express':   'https://images.unsplash.com/photo-1559847844-5315695dadae?w=800&q=80&fit=crop',
  'kare-kare':       'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop',
  'sisig':           'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=800&q=80&fit=crop',
  'lugaw':           'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop',
};

String _keywordImage(String n) {
  if (n.contains('adobo'))                                  return 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=800&q=80&fit=crop';
  if (n.contains('sinigang') || n.contains('nilaga') || n.contains('tinola') || n.contains('arroz') || n.contains('lomi') || n.contains('lugaw') || n.contains('kare')) return 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop';
  if (n.contains('pancit') || n.contains('bihon'))          return 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800&q=80&fit=crop';
  if (n.contains('sisig') || n.contains('pork'))            return 'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=800&q=80&fit=crop';
  if (n.contains('chicken'))                                return 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=800&q=80&fit=crop';
  if (n.contains('shrimp') || n.contains('prawn'))          return 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c5?w=800&q=80&fit=crop';
  if (n.contains('salmon') || n.contains('fish'))           return 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800&q=80&fit=crop';
  if (n.contains('beef') || n.contains('steak') || n.contains('bistek')) return 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=800&q=80&fit=crop';
  if (n.contains('bacon'))                                  return 'https://images.unsplash.com/photo-1528607929212-2636ec44253e?w=800&q=80&fit=crop';
  if (n.contains('tuna'))                                   return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80&fit=crop';
  if (n.contains('egg') || n.contains('omelette') || n.contains('torta')) return 'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=800&q=80&fit=crop';
  if (n.contains('pasta') || n.contains('spaghetti'))       return 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=800&q=80&fit=crop';
  if (n.contains('tofu') || n.contains('monggo') || n.contains('veggie') || n.contains('vegetable')) return 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80&fit=crop';
  if (n.contains('rice') && n.contains('fried'))            return 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800&q=80&fit=crop';
  if (n.contains('coconut'))                                return 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800&q=80&fit=crop';
  if (n.contains('soup'))                                   return 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80&fit=crop';
  if (n.contains('toast') || n.contains('bread'))           return 'https://images.unsplash.com/photo-1528607929212-2636ec44253e?w=800&q=80&fit=crop';
  if (n.contains('stir') || n.contains('wok'))              return 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800&q=80&fit=crop';
  if (n.contains('salad'))                                  return 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80&fit=crop';
  return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=80&fit=crop';
}

/// Returns the best food image URL for a recipe name.
String recipeImageUrl(String name) {
  final key = name.toLowerCase().trim();
  return _recipeImages[key] ?? _keywordImage(key);
}

// ── Gradient placeholder colours per card index ─────────────────────────────
const _placeholderGradients = [
  [Color(0xFFD8EDD4), Color(0xFFC5DFC0)],
  [Color(0xFFDDE8F5), Color(0xFFC8D8EE)],
  [Color(0xFFF5E8D8), Color(0xFFEDD4BC)],
  [Color(0xFFEDE0F5), Color(0xFFDDC8EE)],
  [Color(0xFFF5F0D8), Color(0xFFEDE8BC)],
  [Color(0xFFD8F0F5), Color(0xFFBCE4EE)],
];

class RecipeCard extends StatelessWidget {
  final String title, time, calories, protein, difficulty;
  final int index;
  final VoidCallback onTap;
  final List<Color>? cardGradientColors;
  final Color? cardFgColor;
  /// When non-empty, the DB/API image URL takes priority over the keyword map.
  final String imageUrl;
  final int costPhp;

  const RecipeCard({
    required this.title, required this.time, required this.calories,
    required this.protein, required this.difficulty, required this.index,
    required this.onTap, this.cardGradientColors, this.cardFgColor,
    this.imageUrl = '',
    this.costPhp = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer the DB image_url; fall back to keyword lookup.
    final imgUrl = imageUrl.isNotEmpty ? imageUrl : recipeImageUrl(title);
    final gradColors = cardGradientColors ??
        _placeholderGradients[index % _placeholderGradients.length];
    final fgColor = cardFgColor ?? const Color(0xFF4A8A46);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Stack(children: [
                // ── Image with CachedNetworkImage + shimmer placeholder ─────
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: imgUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 100),
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: gradColors[0],
                      highlightColor: gradColors[1].withValues(alpha: 0.6),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: gradColors,
                          ),
                        ),
                        child: Center(
                          child: Icon(LucideIcons.utensils, size: 32,
                              color: fgColor.withValues(alpha: 0.25)),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: gradColors,
                        ),
                      ),
                      child: Center(
                        child: Icon(LucideIcons.chefHat, size: 44,
                            color: fgColor.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ),
                // ── Bottom scrim ───────────────────────────────────────────
                Positioned(bottom: 0, left: 0, right: 0, height: 50,
                  child: Container(decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  )),
                ),
                // ── Difficulty badge ───────────────────────────────────────
                Positioned(top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(difficulty, style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            // ── Info section ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  _Stat(icon: LucideIcons.clock3, label: time),
                  const SizedBox(width: 8),
                  _Stat(icon: LucideIcons.flame, label: calories, color: AppTheme.orange),
                ]),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(LucideIcons.dumbbell, size: 10, color: AppTheme.greenDark),
                    const SizedBox(width: 3),
                    Text(protein, style: const TextStyle(
                        color: AppTheme.greenDark, fontSize: 10,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (costPhp > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.yellow.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('₱', style: TextStyle(
                          color: AppTheme.orange, fontSize: 10,
                          fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                      const SizedBox(width: 2),
                      Text('$costPhp per serving', style: const TextStyle(
                          color: AppTheme.orange, fontSize: 10,
                          fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      )
      .animate(delay: (index * 60).ms)
      .fadeIn(duration: 350.ms)
      .slideY(begin: 0.12, curve: Curves.easeOutCubic),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _Stat({required this.icon, required this.label, this.color = AppTheme.mutedText});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 11, color: color), const SizedBox(width: 3),
    Text(label, style: TextStyle(color: color, fontSize: 11,
        fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
  ]);
}
