import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/recipe.dart';
import '../widgets/tap_scale.dart';
import 'pantry_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  final List<Recipe> recipes;
  const ShoppingListScreen({required this.recipes, super.key});
  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late Map<String, _ShopItem> _items;
  bool _loading = true;
  final Set<String> _checked = {};

  @override
  void initState() { super.initState(); _build(); }

  Future<void> _build() async {
    final stocked = (await getAlwaysStocked()).map((s) => s.toLowerCase()).toSet();
    final pantry  = (await getPantryItems()).map((s) => s.toLowerCase()).toSet();
    final merged  = <String, _ShopItem>{};
    for (final r in widget.recipes) {
      for (final ing in r.ingredients) {
        final key = ing.name.toLowerCase();
        if (stocked.contains(key)) continue;
        if (merged.containsKey(key)) {
          merged[key] = _ShopItem(
            name: ing.name,
            amounts: [...merged[key]!.amounts, '${ing.amount} (${r.name})'],
            inPantry: pantry.contains(key),
          );
        } else {
          merged[key] = _ShopItem(
            name: ing.name,
            amounts: ['${ing.amount} (${r.name})'],
            inPantry: pantry.contains(key),
          );
        }
      }
    }
    if (mounted) setState(() { _items = merged; _loading = false; });
  }

  Future<void> _shopeeSearch(String item) async {
    final encoded = Uri.encodeComponent(item);
    final url = Uri.parse('https://shopee.ph/search?keyword=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    // Fallback: open in browser
    final webUrl = Uri.parse('https://shopee.ph/search?keyword=$encoded');
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.inAppBrowserView);
      return;
    }
    // Last resort: copy only THIS item name to clipboard
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: item));
    messenger.showSnackBar(SnackBar(
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
        .where((i) => !_checked.contains(i.name.toLowerCase()))
        .map((i) => '- ${i.name} — ${i.amounts.first.split(' (').first}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: 'Shopping List\n\n$lines'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('List copied to clipboard!', style: TextStyle(fontFamily: 'DM Sans')),
      backgroundColor: AppTheme.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    ));
  }

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
        Text('${widget.recipes.length} recipe${widget.recipes.length != 1 ? 's' : ''}',
          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11, fontFamily: 'DM Sans')),
      ])),
      if (!_loading)
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
  ).animate().fadeIn(duration: 280.ms);

  Widget _shimmer(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
    children: List.generate(6, (i) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 62,
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .shimmer(duration: 1200.ms, color: AppTheme.cardBg(context).withValues(alpha: 0.7))),
  );

  Widget _body(BuildContext context) {
    if (_items.isEmpty) {
      return Center(child: Text('All ingredients are already in your pantry!',
        style: TextStyle(color: AppTheme.textMuted(context), fontSize: 14, fontFamily: 'DM Sans'),
        textAlign: TextAlign.center));
    }

    final needToBuy  = _items.values.where((i) => !i.inPantry).toList();
    final haveAlready = _items.values.where((i) => i.inPantry).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Wrap(spacing: 8, runSpacing: 6, children: widget.recipes.map((r) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.scanGreen.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(r.name, style: const TextStyle(
            color: AppTheme.primaryDark, fontSize: 11,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
          )),
        )).toList()),
        const SizedBox(height: 20),
        if (needToBuy.isNotEmpty) ...[
          _sectionLabel(context, 'To Buy', needToBuy.length),
          const SizedBox(height: 10),
          ...needToBuy.map((item) => _itemRow(context, item)),
          const SizedBox(height: 20),
        ],
        if (haveAlready.isNotEmpty) ...[
          _sectionLabel(context, 'In Pantry (already have)', haveAlready.length),
          const SizedBox(height: 10),
          ...haveAlready.map((item) => _itemRow(context, item, dimmed: true)),
        ],
        const SizedBox(height: 24),
        _shopeeAllBtn(),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label, int count) => Row(children: [
    Text(label, style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 14,
        fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: done ? AppTheme.green : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: done ? AppTheme.green : AppTheme.border(context), width: 1.5),
            ),
            child: done ? const Icon(LucideIcons.check, color: Colors.white, size: 13) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: TextStyle(
              color: done || dimmed ? AppTheme.textMuted(context) : AppTheme.textPrimary(context),
              fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
              decoration: done ? TextDecoration.lineThrough : null,
            )),
            Text(item.amounts.first.split(' (').first,
              style: TextStyle(color: AppTheme.textMuted(context),
                  fontSize: 11, fontFamily: 'DM Sans')),
          ])),
          if (!done && !dimmed)
            TapScale(
              onTap: () => _shopeeSearch(item.name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEE4D2D).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEE4D2D).withValues(alpha: 0.2)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.shoppingCart, size: 11, color: Color(0xFFEE4D2D)),
                  SizedBox(width: 4),
                  Text('Shopee', style: TextStyle(
                    color: Color(0xFFEE4D2D), fontSize: 10,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                  )),
                ]),
              ),
            ),
        ]),
      ).animate().fadeIn(duration: 260.ms).slideX(begin: 0.04),
    );
  }

  Widget _shopeeAllBtn() {
    final remaining = _items.values
        .where((i) => !i.inPantry && !_checked.contains(i.name.toLowerCase()))
        .toList();
    if (remaining.isEmpty) return const SizedBox.shrink();
    return TapScale(
      onTap: () async {
        if (remaining.isNotEmpty) await _shopeeSearch(remaining.first.name);
      },
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFEE4D2D),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFFEE4D2D).withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(LucideIcons.shoppingCart, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Search on Shopee', style: TextStyle(
            color: Colors.white, fontSize: 15,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
          )),
        ]),
      ),
    );
  }
}

class _ShopItem {
  final String name;
  final List<String> amounts;
  final bool inPantry;
  const _ShopItem({required this.name, required this.amounts, required this.inPantry});
}
