import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
class PantryItem {
  final String name;
  final double quantity;
  final String unit;
  final bool alwaysStocked;

  const PantryItem({
    required this.name,
    this.quantity = 1,
    this.unit = 'pcs',
    this.alwaysStocked = false,
  });

  String get displayQty {
    final q = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return unit.isEmpty ? q : '$q $unit';
  }

  Map<String, dynamic> toJson() =>
      {'name': name, 'qty': quantity, 'unit': unit, 'always': alwaysStocked};

  factory PantryItem.fromJson(Map<String, dynamic> j) => PantryItem(
        name: j['name'] as String,
        quantity: (j['qty'] as num?)?.toDouble() ?? 1.0,
        unit: j['unit'] as String? ?? 'pcs',
        alwaysStocked: j['always'] as bool? ?? false,
      );

  PantryItem copyWith(
          {String? name, double? quantity, String? unit, bool? alwaysStocked}) =>
      PantryItem(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        alwaysStocked: alwaysStocked ?? this.alwaysStocked,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});
  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  List<PantryItem> _items = [];
  final _nameCtrl  = TextEditingController();
  final _qtyCtrl   = TextEditingController(text: '1');
  final _nameFocus = FocusNode();
  String _unit    = 'pcs';
  bool   _loading = true;

  static const _kKey = 'pantry_items_v2';
  static const _units = ['pcs', 'g', 'kg', 'ml', 'L', 'cups', 'tbsp', 'tsp', ''];
  static const _suggestions = [
    'eggs', 'rice', 'chicken', 'garlic', 'onion', 'soy sauce',
    'cooking oil', 'butter', 'salt', 'pepper', 'sugar', 'vinegar',
    'fish sauce', 'milk', 'noodles', 'bread', 'pasta', 'tomato',
  ];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _qtyCtrl.dispose(); _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    String raw = p.getString(_kKey) ?? '';
    if (raw.isEmpty) {
      final oldRaw = p.getString('pantry_items') ?? '[]';
      final old = (jsonDecode(oldRaw) as List).map((e) {
        final m = e as Map<String, dynamic>;
        return PantryItem(name: m['name'] as String, alwaysStocked: m['always'] as bool? ?? false);
      }).toList();
      raw = jsonEncode(old.map((i) => i.toJson()).toList());
    }
    final list = (jsonDecode(raw) as List)
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>)).toList();
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  void _add(String name) {
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return;
    if (_items.any((i) => i.name == trimmed)) {
      _showSnack('$trimmed is already in your fridge');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
    HapticFeedback.selectionClick();
    setState(() => _items.insert(0, PantryItem(name: trimmed, quantity: qty, unit: _unit)));
    _save();
    _nameCtrl.clear();
    _qtyCtrl.text = '1';
  }

  void _remove(int idx) {
    HapticFeedback.mediumImpact();
    setState(() => _items.removeAt(idx));
    _save();
  }

  void _toggleAlways(int idx) {
    HapticFeedback.selectionClick();
    setState(() => _items[idx] = _items[idx].copyWith(alwaysStocked: !_items[idx].alwaysStocked));
    _save();
  }

  void _showEditDialog(int idx) {
    final item = _items[idx];
    final qCtrl = TextEditingController(
        text: item.quantity == item.quantity.roundToDouble()
            ? item.quantity.toInt().toString()
            : item.quantity.toString());
    String unit = item.unit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(ctx),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.border(ctx),
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.refrigerator, color: AppTheme.primaryDark, size: 16)),
                const SizedBox(width: 12),
                Text(item.name, style: TextStyle(fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary(ctx), fontSize: 17)),
              ]),
              const SizedBox(height: 22),
              Text('Quantity', style: TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                  color: AppTheme.textMuted(ctx), fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _stepBtn(ctx, LucideIcons.minus, () {
                  final v = double.tryParse(qCtrl.text) ?? 1;
                  if (v > 1) qCtrl.text = (v - 1).toInt().toString();
                  setD(() {});
                }),
                const SizedBox(width: 16),
                SizedBox(width: 64, child: TextField(
                  controller: qCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 22,
                      fontWeight: FontWeight.w800, color: AppTheme.textPrimary(ctx)),
                  decoration: const InputDecoration(border: InputBorder.none),
                )),
                const SizedBox(width: 16),
                _stepBtn(ctx, LucideIcons.plus, () {
                  final v = double.tryParse(qCtrl.text) ?? 1;
                  qCtrl.text = (v + 1).toInt().toString();
                  setD(() {});
                }),
              ]),
              const SizedBox(height: 20),
              Text('Unit', style: TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                  color: AppTheme.textMuted(ctx), fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: _units.map((u) {
                final label = u.isEmpty ? 'none' : u;
                final sel   = u == unit;
                return TapScale(
                  onTap: () => setD(() => unit = u),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primaryDark : AppTheme.cardAltBg(ctx),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? AppTheme.primaryDark : AppTheme.border(ctx)),
                    ),
                    child: Text(label, style: TextStyle(
                      fontFamily: 'DM Sans', fontSize: 13, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppTheme.textMuted(ctx),
                    )),
                  ),
                );
              }).toList()),
              const SizedBox(height: 28),
              SizedBox(width: double.infinity,
                child: TapScale(
                  onTap: () {
                    final newQty = double.tryParse(qCtrl.text) ?? item.quantity;
                    setState(() => _items[idx] = item.copyWith(quantity: newQty, unit: unit));
                    _save();
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: AppTheme.tealGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('Save Changes',
                        style: TextStyle(fontFamily: 'DM Sans', color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 15))),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(BuildContext ctx, IconData icon, VoidCallback onTap) => TapScale(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: AppTheme.cardAltBg(ctx),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(ctx)),
      ),
      child: Icon(icon, size: 16, color: AppTheme.primaryDark),
    ),
  );

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'DM Sans')),
      backgroundColor: AppTheme.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(seconds: 2),
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
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(10)),
        child: const Icon(LucideIcons.refrigerator, color: Colors.white, size: 17),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('My Fridge', style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 18,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        Text('Track what you have at home',
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11, fontFamily: 'DM Sans')),
      ])),
      if (!_loading) Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('${_items.length} items',
            style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
      ),
    ]),
  ).animate().fadeIn(duration: 280.ms);

  Widget _shimmer(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
    children: List.generate(5, (i) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 66,
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .shimmer(duration: 1200.ms, color: AppTheme.cardBg(context).withValues(alpha: 0.7))),
  );

  Widget _body(BuildContext context) {
    final always  = _items.where((i) => i.alwaysStocked).toList();
    final regular = _items.where((i) => !i.alwaysStocked).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _inputCard(context),
        const SizedBox(height: 12),
        _quickAdds(context),
        if (always.isNotEmpty) ...[
          const SizedBox(height: 28),
          _sectionLabel('Always Stocked', LucideIcons.infinity, AppTheme.orange, count: always.length),
          const SizedBox(height: 10),
          ..._items.asMap().entries
              .where((e) => e.value.alwaysStocked)
              .map((e) => _itemCard(context, e.key, e.value)),
        ],
        const SizedBox(height: 28),
        _sectionLabel('In Fridge', LucideIcons.refrigerator, AppTheme.primaryDark, count: regular.length),
        const SizedBox(height: 10),
        if (regular.isEmpty)
          _emptyState()
        else
          ..._items.asMap().entries
              .where((e) => !e.value.alwaysStocked)
              .map((e) => _itemCard(context, e.key, e.value)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(LucideIcons.info, size: 12, color: AppTheme.mutedText),
          const SizedBox(width: 6),
          Text('Ingredients auto-deduct after you finish cooking.',
              style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11, fontFamily: 'DM Sans')),
        ]),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _inputCard(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.cardBg(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border(context)),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(children: [
          Icon(LucideIcons.search, color: AppTheme.textMuted(context), size: 16),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: AppTheme.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'What\'s in your fridge?',
              hintStyle: TextStyle(fontFamily: 'DM Sans', color: AppTheme.textMuted(context), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            textCapitalization: TextCapitalization.none,
            onSubmitted: _add,
          )),
        ]),
      ),
      Container(height: 1, color: AppTheme.border(context)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 10, 10),
        child: Row(children: [
          _miniStepBtn(context, LucideIcons.minus, () {
            final v = double.tryParse(_qtyCtrl.text) ?? 1;
            if (v > 1) setState(() => _qtyCtrl.text = (v - 1).toInt().toString());
          }),
          const SizedBox(width: 6),
          SizedBox(width: 32, child: TextField(
            controller: _qtyCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                fontWeight: FontWeight.w700, color: AppTheme.textPrimary(context)),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
          )),
          const SizedBox(width: 6),
          _miniStepBtn(context, LucideIcons.plus, () {
            final v = double.tryParse(_qtyCtrl.text) ?? 1;
            setState(() => _qtyCtrl.text = (v + 1).toInt().toString());
          }),
          const SizedBox(width: 10),
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardAltBg(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _unit,
              isDense: true,
              dropdownColor: AppTheme.cardBg(context),
              style: TextStyle(fontFamily: 'DM Sans', fontSize: 12, color: AppTheme.textPrimary(context)),
              items: _units.map((u) => DropdownMenuItem(
                value: u, child: Text(u.isEmpty ? 'none' : u),
              )).toList(),
              onChanged: (v) => setState(() => _unit = v!),
            )),
          ),
          const Spacer(),
          TapScale(
            onTap: () => _add(_nameCtrl.text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(11)),
              child: const Text('Add', style: TextStyle(color: Colors.white,
                  fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ]),
  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);

  Widget _miniStepBtn(BuildContext context, IconData icon, VoidCallback onTap) => TapScale(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: AppTheme.cardAltBg(context),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Icon(icon, size: 12, color: AppTheme.textMuted(context)),
    ),
  );

  Widget _quickAdds(BuildContext context) {
    final existing  = _items.map((i) => i.name).toSet();
    final available = _suggestions.where((s) => !existing.contains(s)).take(8).toList();
    if (available.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text('Quick add', style: TextStyle(color: AppTheme.textMuted(context),
            fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: available.map((s) => TapScale(
        onTap: () { _nameCtrl.text = s; _add(s); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.plus, size: 11, color: AppTheme.primaryDark),
            const SizedBox(width: 5),
            Text(s, style: TextStyle(color: AppTheme.textPrimary(context),
                fontSize: 12, fontFamily: 'DM Sans')),
          ]),
        ),
      )).toList()),
    ]);
  }

  Widget _sectionLabel(String title, IconData icon, Color color, {int count = 0}) =>
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: color, fontSize: 14,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count', style: TextStyle(color: color, fontSize: 11,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
        ),
      ]);

  Widget _itemCard(BuildContext context, int idx, PantryItem item) => Dismissible(
    key: Key('pantry_${item.name}_$idx'),
    direction: DismissDirection.endToStart,
    background: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      child: const Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.trash2, color: AppTheme.red, size: 18),
        SizedBox(height: 3),
        Text('Remove', style: TextStyle(color: AppTheme.red, fontSize: 10,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
      ]),
    ),
    onDismissed: (_) => _remove(idx),
    child: TapScale(
      onTap: () => _showEditDialog(idx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: item.alwaysStocked
              ? AppTheme.orange.withValues(alpha: 0.05)
              : AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.alwaysStocked
                ? AppTheme.orange.withValues(alpha: 0.22)
                : AppTheme.border(context),
          ),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: item.alwaysStocked
                  ? AppTheme.orange.withValues(alpha: 0.12)
                  : AppTheme.primaryDark.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              item.alwaysStocked ? LucideIcons.infinity : LucideIcons.refrigerator,
              size: 16,
              color: item.alwaysStocked ? AppTheme.orange : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: TextStyle(color: AppTheme.textPrimary(context),
                fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cardAltBg(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item.displayQty,
                    style: const TextStyle(color: AppTheme.primaryDark, fontSize: 11,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
              ),
              if (item.alwaysStocked) ...[
                const SizedBox(width: 6),
                Text('· never deducted', style: TextStyle(color: AppTheme.textMuted(context),
                    fontSize: 11, fontFamily: 'DM Sans')),
              ],
            ]),
          ])),
          TapScale(
            onTap: () => _toggleAlways(idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: item.alwaysStocked
                    ? AppTheme.orange.withValues(alpha: 0.12)
                    : AppTheme.cardAltBg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: item.alwaysStocked ? AppTheme.orange : AppTheme.border(context),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.infinity, size: 12,
                    color: item.alwaysStocked ? AppTheme.orange : AppTheme.textMuted(context)),
                const SizedBox(width: 4),
                Text(
                  item.alwaysStocked ? '∞' : 'pin',
                  style: TextStyle(
                    color: item.alwaysStocked ? AppTheme.orange : AppTheme.textMuted(context),
                    fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          Icon(LucideIcons.chevronRight, size: 14, color: AppTheme.textMuted(context)),
        ]),
      ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.03),
    ),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppTheme.primaryDark.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.refrigerator, size: 30, color: AppTheme.primaryDark),
      ),
      const SizedBox(height: 16),
      const Text('Your fridge is empty',
          style: TextStyle(color: AppTheme.darkText, fontSize: 16,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Add ingredients you have at home',
          style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
    ]).animate().fadeIn(duration: 300.ms),
  );
}

// ── Public helpers (used by recipe_detail + shopping_list) ───────────────────

Future<List<String>> getPantryItems() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString('pantry_items_v2') ?? '[]';
  final list = (jsonDecode(raw) as List)
      .map((e) => PantryItem.fromJson(e as Map<String, dynamic>)).toList();
  return list.map((i) => i.name).toList();
}

Future<List<PantryItem>> getPantryItemsFull() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString('pantry_items_v2') ?? '[]';
  return (jsonDecode(raw) as List)
      .map((e) => PantryItem.fromJson(e as Map<String, dynamic>)).toList();
}

Future<List<String>> getAlwaysStocked() async {
  final items = await getPantryItemsFull();
  return items.where((i) => i.alwaysStocked).map((i) => i.name).toList();
}

/// Deduct 1 unit per ingredient after cooking. Skips always-stocked. Removes at 0.
Future<void> deductPantryIngredients(List<String> ingredientNames) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString('pantry_items_v2') ?? '[]';
  final items = (jsonDecode(raw) as List)
      .map((e) => PantryItem.fromJson(e as Map<String, dynamic>)).toList();

  for (final ing in ingredientNames) {
    final normalized = ing.trim().toLowerCase();
    final idx = items.indexWhere((i) =>
        i.name == normalized ||
        normalized.contains(i.name) ||
        i.name.contains(normalized));
    if (idx == -1) continue;
    final item = items[idx];
    if (item.alwaysStocked) continue;
    final newQty = item.quantity - 1;
    if (newQty <= 0) {
      items.removeAt(idx);
    } else {
      items[idx] = item.copyWith(quantity: newQty);
    }
  }
  await p.setString('pantry_items_v2', jsonEncode(items.map((i) => i.toJson()).toList()));
}
