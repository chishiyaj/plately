import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../widgets/tap_scale.dart';
import 'pantry_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  final List<Recipe> recipes;
  const ShoppingListScreen({required this.recipes, super.key});
  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  Map<String, _ShopItem> _items = {};
  bool _loading = true;
  String? _loadingMsg;
  final Set<String> _checked = {};

  @override
  void initState() {
    super.initState();
    _build();
  }

  // ── Build the shopping list ─────────────────────────────────────────────
  // KEY FIX: browse-mode recipes have empty ingredients (API only returns them
  // on /api/recipe/<id>). We detect this and fetch full details first.
  Future<void> _build() async {
    // Step 1: resolve full recipes (fetch ingredients if missing)
    final fullRecipes = <Recipe>[];
    for (final r in widget.recipes) {
      if (r.ingredients.isNotEmpty) {
        fullRecipes.add(r);
      } else if (r.id > 0) {
        // Browse-mode recipe -- no ingredients loaded yet, fetch them
        if (mounted) {
          setState(() => _loadingMsg = 'Loading ${r.name}...');
        }
        try {
          final full = await ApiService.getRecipeDetail(r.id);
          fullRecipes.add(full ?? r);
        } catch (_) {
          fullRecipes.add(r); // use stub if fetch fails
        }
      } else {
        fullRecipes.add(r); // AI recipe with negative id -- skip fetch
      }
    }

    // Step 2: cross-ref with pantry
    final stocked = (await getAlwaysStocked()).map((s) => s.toLowerCase()).toSet();
    final pantry  = (await getPantryItems()).map((s) => s.toLowerCase()).toSet();

    final merged = <String, _ShopItem>{};
    for (final r in fullRecipes) {
      for (final ing in r.ingredients) {
        final key = ing.name.toLowerCase().trim();
        if (key.isEmpty) continue;
        // Skip "always stocked" items -- user says they always have them
        if (stocked.contains(key)) continue;
        final inPantry = pantry.contains(key);
        if (merged.containsKey(key)) {
          merged[key] = _ShopItem(
            name: ing.name,
            amounts: [...merged[key]!.amounts, '${ing.amount} (${r.name})'],
            inPantry: inPantry,
          );
        } else {
          merged[key] = _ShopItem(
            name: ing.name,
            amounts: ['${ing.amount} (${r.name})'],
            inPantry: inPantry,
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _items = merged;
        _loadingMsg = null;
        _loading = false;
      });
    }
  }

  // ── Launch helpers ──────────────────────────────────────────────────────
  Future<void> _openShopee(String item) async {
    final url = Uri.parse('https://shopee.ph/search?keyword=${Uri.encodeComponent(item)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _copyItem(item);
    }
  }

  Future<void> _openLazada(String item) async {
    final url = Uri.parse('https://www.lazada.com.ph/catalog/?q=${Uri.encodeComponent(item)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _copyItem(item);
    }
  }

  void _copyItem(String item) {
    Clipboard.setData(ClipboardData(text: item));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied "$item" to clipboard',
          style: const TextStyle(fontFamily: 'DM Sans')),
      backgroundColor: AppTheme.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(seconds: 2),
    ));
  }

  void _copyAll() {
    final lines = _items.values
        .where((i) => !i.inPantry && !_checked.contains(i.name.toLowerCase()))
        .map((i) => '• ${i.name}  ${i.amounts.first.split(' (').first}')
        .join('\n');
    if (lines.isEmpty) return;
    final text = 'Shopping List 🛒\n\n$lines\n\n(from Plately)';
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('List copied! Paste it in WhatsApp or anywhere.',
          style: TextStyle(fontFamily: 'DM Sans')),
      backgroundColor: AppTheme.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(seconds: 3),
    ));
  }

  void _shareAll() {
    final lines = _items.values
        .where((i) => !i.inPantry && !_checked.contains(i.name.toLowerCase()))
        .map((i) => '• ${i.name}  ${i.amounts.first.split(' (').first}')
        .join('\n');
    if (lines.isEmpty) return;
    final text = 'Shopping List 🛒\n\n$lines\n\n(from Plately)';
    Share.share(text, subject: 'My Plately Shopping List');
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.scaffoldBg(context),
    body: SafeArea(child: Column(children: [
      _header(context),
      Expanded(child: _loading ? _shimmer(context) : _body(context)),
    ])),
  );

  Widget _header(BuildContext context) => Container(
    color: AppTheme.cardBg(context),
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    child: Row(children: [
      TapScale(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppTheme.cardAltBg(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Shopping List', style: TextStyle(color: AppTheme.textPrimary(context),
            fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        Text(
          _loading
              ? (_loadingMsg ?? 'Loading ingredients...')
              : '${widget.recipes.length} recipe${widget.recipes.length != 1 ? 's' : ''}',
          style: TextStyle(color: AppTheme.textMuted(context),
              fontSize: 11, fontFamily: 'DM Sans'),
        ),
      ])),
      if (!_loading)
        Row(children: [
          TapScale(
            onTap: _shareAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.15)),
              ),
              child: const Row(children: [
                Icon(LucideIcons.share2, color: AppTheme.primaryDark, size: 13),
                SizedBox(width: 5),
                Text('Share', style: TextStyle(color: AppTheme.primaryDark, fontSize: 12,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          TapScale(
            onTap: _copyAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.15)),
              ),
              child: const Row(children: [
                Icon(LucideIcons.copy, color: AppTheme.primaryDark, size: 13),
                SizedBox(width: 5),
                Text('Copy', style: TextStyle(color: AppTheme.primaryDark, fontSize: 12,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
    ]),
  ).animate().fadeIn(duration: 280.ms);

  Widget _shimmer(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
    children: [
      if (_loadingMsg != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(children: [
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Text(_loadingMsg!, style: TextStyle(
              color: AppTheme.textMuted(context), fontSize: 12, fontFamily: 'DM Sans')),
          ]),
        ),
      ...List.generate(6, (i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border(context)),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
       .shimmer(duration: 1200.ms,
           color: AppTheme.cardBg(context).withValues(alpha: 0.7))),
    ],
  );

  Widget _body(BuildContext context) {
    if (_items.isEmpty) {
      // Were ingredients actually loaded?
      final allEmpty = widget.recipes.every((r) => r.ingredients.isEmpty && r.id <= 0);
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.shoppingCart,
              size: 48, color: AppTheme.textMuted(context).withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            allEmpty
                ? 'These recipes don\'t have ingredient details yet.'
                : 'All ingredients are already covered by your pantry!',
            style: TextStyle(color: AppTheme.textPrimary(context),
                fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            allEmpty
                ? 'Try scanning ingredients or searching for a recipe first.'
                : 'Check your fridge -- you\'re all set to cook!',
            style: TextStyle(color: AppTheme.textMuted(context),
                fontSize: 13, fontFamily: 'DM Sans'),
            textAlign: TextAlign.center,
          ),
        ]),
      ));
    }

    final needToBuy   = _items.values.where((i) => !i.inPantry).toList();
    final haveAlready = _items.values.where((i) => i.inPantry).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Recipe chips
        Wrap(spacing: 8, runSpacing: 6,
          children: widget.recipes.map((r) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.15)),
            ),
            child: Text(r.name, style: TextStyle(
              color: AppTheme.textPrimary(context), fontSize: 11,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
            )),
          )).toList(),
        ),
        const SizedBox(height: 20),

        // To Buy section
        if (needToBuy.isNotEmpty) ...[
          _sectionLabel(context, 'To Buy', needToBuy.length),
          const SizedBox(height: 10),
          ...needToBuy.map((item) => _itemRow(context, item)),
          const SizedBox(height: 20),
        ],

        // Already in pantry section
        if (haveAlready.isNotEmpty) ...[
          _sectionLabel(context, 'Already in Pantry', haveAlready.length),
          const SizedBox(height: 10),
          ...haveAlready.map((item) => _itemRow(context, item, dimmed: true)),
          const SizedBox(height: 20),
        ],

        // Shop online buttons
        if (needToBuy.isNotEmpty) _shopButtons(needToBuy.first.name),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label, int count) =>
      Row(children: [
        Text(label, style: TextStyle(color: AppTheme.textPrimary(context),
            fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppTheme.border(context))),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(color: AppTheme.textMuted(context),
            fontSize: 11, fontFamily: 'DM Sans')),
      ]);

  Widget _itemRow(BuildContext context, _ShopItem item, {bool dimmed = false}) {
    final key  = item.name.toLowerCase();
    final done = _checked.contains(key);
    return TapScale(
      onTap: () => setState(() => done ? _checked.remove(key) : _checked.add(key)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: done ? AppTheme.cardAltBg(context) : AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(children: [
          // Checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: done ? AppTheme.green : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: done ? AppTheme.green : AppTheme.border(context),
                  width: 1.5),
            ),
            child: done
                ? const Icon(LucideIcons.check, color: Colors.white, size: 13)
                : null,
          ),
          const SizedBox(width: 12),
          // Name + amount
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: TextStyle(
              color: done || dimmed
                  ? AppTheme.textMuted(context)
                  : AppTheme.textPrimary(context),
              fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
              decoration: done ? TextDecoration.lineThrough : null,
            )),
            Text(
              item.amounts.first.split(' (').first,
              style: TextStyle(color: AppTheme.textMuted(context),
                  fontSize: 11, fontFamily: 'DM Sans'),
            ),
          ])),
          // Shop buttons -- only on items still to buy
          if (!done && !dimmed) ...[
            _shopeeBtn(item.name),
            const SizedBox(width: 6),
            _lazadaBtn(item.name),
          ],
        ]),
      ).animate().fadeIn(duration: 260.ms).slideX(begin: 0.04),
    );
  }

  // Small per-item Shopee button
  Widget _shopeeBtn(String item) => TapScale(
    onTap: () => _openShopee(item),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEE4D2D).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEE4D2D).withValues(alpha: 0.25)),
      ),
      // TODO: Replace Text with Image.asset('assets/images/shopee_logo.png', height: 16)
      // once the file is added to assets/images/ and pubspec.yaml
      child: const Text('Shopee', style: TextStyle(
        color: Color(0xFFEE4D2D), fontSize: 10,
        fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
      )),
    ),
  );

  // Small per-item Lazada button
  Widget _lazadaBtn(String item) => TapScale(
    onTap: () => _openLazada(item),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F146D).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0F146D).withValues(alpha: 0.22)),
      ),
      // TODO: Replace Text with Image.asset('assets/images/lazada_logo.png', height: 16)
      // once the file is added to assets/images/ and pubspec.yaml
      child: const Text('Lazada', style: TextStyle(
        color: Color(0xFF0F146D), fontSize: 10,
        fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
      )),
    ),
  );

  // Bottom "Shop all on..." buttons
  Widget _shopButtons(String firstItem) => Column(children: [
    const SizedBox(height: 4),
    Row(children: [
      Expanded(
        child: TapScale(
          onTap: () => _openShopee(firstItem),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFEE4D2D),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: const Color(0xFFEE4D2D).withValues(alpha: 0.28),
                blurRadius: 10, offset: const Offset(0, 4),
              )],
            ),
            // TODO: Add Image.asset('assets/images/shopee_logo.png', height: 20, color: Colors.white)
            // alongside the text once the file is available
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.shoppingCart, color: Colors.white, size: 15),
              SizedBox(width: 7),
              Text('Shop on Shopee', style: TextStyle(
                color: Colors.white, fontSize: 13,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
              )),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: TapScale(
          onTap: () => _openLazada(firstItem),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0F146D),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: const Color(0xFF0F146D).withValues(alpha: 0.28),
                blurRadius: 10, offset: const Offset(0, 4),
              )],
            ),
            // TODO: Add Image.asset('assets/images/lazada_logo.png', height: 20, color: Colors.white)
            // alongside the text once the file is available
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.shoppingBag, color: Colors.white, size: 15),
              SizedBox(width: 7),
              Text('Shop on Lazada', style: TextStyle(
                color: Colors.white, fontSize: 13,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
              )),
            ]),
          ),
        ),
      ),
    ]),
    const SizedBox(height: 8),
    Text('Opens first item to buy -- search others manually',
        style: TextStyle(color: AppTheme.textMuted(context),
            fontSize: 10, fontFamily: 'DM Sans'),
        textAlign: TextAlign.center),
  ]);
}

class _ShopItem {
  final String name;
  final List<String> amounts;
  final bool inPantry;
  const _ShopItem({required this.name, required this.amounts, required this.inPantry});
}
