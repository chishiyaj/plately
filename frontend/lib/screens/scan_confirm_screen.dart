import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../services/api_service.dart';
import 'recipe_results_screen.dart';

// ─── ScanConfirmScreen ────────────────────────────────────────────────────────
// Two modes:
//   manualMode: false (default) — shows captured photo, runs AI scan
//   manualMode: true            — no photo, keyboard focused, pure manual entry
// Both modes share the same editable ingredient chips + Find Recipes CTA.

class ScanConfirmScreen extends StatefulWidget {
  final String imagePath;
  final bool manualMode;
  const ScanConfirmScreen({required this.imagePath, this.manualMode = false, super.key});
  @override
  State<ScanConfirmScreen> createState() => _ScanConfirmScreenState();
}

class _ScanConfirmScreenState extends State<ScanConfirmScreen> {
  final _addCtrl  = TextEditingController();
  final _addFocus = FocusNode();
  List<String> _ingredients = [];
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.manualMode && widget.imagePath.isNotEmpty) {
      _scanning = true;
      _runScan();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_addFocus);
      });
    }
  }

  Future<void> _runScan() async {
    try {
      final bytes     = await File(widget.imagePath).readAsBytes();
      final base64Img = base64Encode(bytes);
      final detected  = await ApiService.scanImage(base64Img);
      if (mounted) {
        setState(() { _ingredients = detected; _scanning = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _error = 'AI scan failed — add ingredients manually below.';
        });
      }
    }
  }

  void _removeChip(String item) => setState(() => _ingredients.remove(item));

  void _addIngredient() {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    final parts = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    setState(() {
      for (final p in parts) {
        if (!_ingredients.contains(p.toLowerCase())) {
          _ingredients.add(p.toLowerCase());
        }
      }
    });
    _addCtrl.clear();
    _addFocus.unfocus();
  }

  void _findRecipes() {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Add at least one ingredient first.',
            style: TextStyle(fontFamily: 'DM Sans')),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      return;
    }
    Navigator.pushReplacement(
      context,
      AppTheme.zoomIn(RecipeResultsScreen(ingredients: _ingredients)),
    );
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.manualMode ? _buildManualLayout() : _buildScanLayout();
  }

  Widget _buildManualLayout() {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              TapScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderGray),
                    boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Type Ingredients', style: TextStyle(
                    color: AppTheme.darkText, fontSize: 18,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
                  )),
                  Text('Add ingredients, then find recipes',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
                ]),
              ),
            ]),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(LucideIcons.pencilLine, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _ingredients.isEmpty
                        ? 'Start typing below to add ingredients'
                        : '${_ingredients.length} ingredient${_ingredients.length == 1 ? '' : 's'} added — tap × to remove',
                    style: const TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans'),
                  ),
                ]),
                const SizedBox(height: 16),
                if (_ingredients.isNotEmpty)
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _ingredients.map((ing) => _IngredientChip(
                      label: ing, onRemove: () => _removeChip(ing),
                    )).toList(),
                  ),
                const SizedBox(height: 20),
                _buildAddRow(),
              ]),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
            child: _buildFindRecipesBtn(),
          ),
        ]),
      ),
    );
  }

  Widget _buildScanLayout() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        Expanded(
          flex: 4,
          child: Stack(children: [
            Positioned.fill(child: Image.file(File(widget.imagePath), fit: BoxFit.cover)),
            const Positioned(
              bottom: 0, left: 0, right: 0, height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black, Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              top: kToolbarHeight, left: 16,
              child: TapScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24)),
                  child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 18),
                ),
              ),
            ),
            Positioned(
              top: kToolbarHeight, right: 16,
              child: TapScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.camera, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text('Retake', style: TextStyle(color: Colors.white, fontSize: 12,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: 18, left: 20,
              child: Text(
                _scanning ? 'Scanning...' : 'Photo captured',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'DM Sans'),
              ),
            ),
          ]),
        ),
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.creamBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              const SizedBox(height: 10),
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('AI Detected', style: TextStyle(color: AppTheme.darkText, fontSize: 16,
                          fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                      Text(
                        _scanning ? 'Identifying ingredients...'
                            : _error ?? '${_ingredients.length} ingredient${_ingredients.length == 1 ? '' : 's'} found — tap × to remove',
                        style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans'),
                      ),
                    ]),
                  ),
                ]),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_scanning)
                      _ScanningPlaceholder()
                    else if (_ingredients.isEmpty && _error == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Row(children: [
                          Icon(LucideIcons.info, size: 16, color: AppTheme.mutedText),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                              'Nothing detected — try better lighting or add manually.',
                              style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans'))),
                        ]),
                      )
                    else
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _ingredients.map((ing) => _IngredientChip(
                          label: ing, onRemove: () => _removeChip(ing),
                        )).toList(),
                      ),
                    const SizedBox(height: 16),
                    _buildAddRow(),
                  ]),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
                child: _buildFindRecipesBtn(),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildAddRow() {
    return Row(children: [
      Expanded(
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderGray),
          ),
          child: TextField(
            controller: _addCtrl,
            focusNode: _addFocus,
            onSubmitted: (_) => _addIngredient(),
            style: const TextStyle(fontSize: 14, fontFamily: 'DM Sans', color: AppTheme.darkText),
            decoration: const InputDecoration(
              hintText: 'Add ingredient (e.g. garlic, rice)',
              hintStyle: TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans'),
              prefixIcon: Icon(LucideIcons.plus, size: 16, color: AppTheme.mutedText),
              contentPadding: EdgeInsets.symmetric(vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      TapScale(
        onTap: _addIngredient,
        child: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(14)),
          child: const Icon(LucideIcons.arrowRight, color: Colors.white, size: 18),
        ),
      ),
    ]);
  }

  Widget _buildFindRecipesBtn() {
    return TapScale(
      onTap: _findRecipes,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _ingredients.isEmpty
                ? [AppTheme.lightGray, AppTheme.lightGray]
                : [AppTheme.green, AppTheme.greenDark],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: _ingredients.isEmpty ? [] : const [
            BoxShadow(color: Color(0x5576CC4F), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(LucideIcons.chefHat,
              color: _ingredients.isEmpty ? AppTheme.mutedText : Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            _ingredients.isEmpty ? 'Add ingredients first'
                : 'Find Recipes (${_ingredients.length})',
            style: TextStyle(
              color: _ingredients.isEmpty ? AppTheme.mutedText : Colors.white,
              fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Ingredient chip ────────────────────────────────────────────────────────────
class _IngredientChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _IngredientChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
    decoration: BoxDecoration(
      color: AppTheme.primaryDark.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.18)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: AppTheme.darkText, fontSize: 13,
          fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      TapScale(
        onTap: onRemove,
        child: Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(LucideIcons.x, size: 10, color: AppTheme.darkText),
        ),
      ),
    ]),
  ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.85, 0.85));
}

// ── Scanning placeholder shimmer ───────────────────────────────────────────────
class _ScanningPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: List.generate(4, (i) => AnimatedContainer(
      duration: Duration(milliseconds: 600 + i * 120),
      width: [80.0, 100.0, 72.0, 90.0][i],
      height: 34,
      decoration: BoxDecoration(
          color: AppTheme.lightGray.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24)),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white38)),
  );
}
