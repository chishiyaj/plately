import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../services/api_service.dart';
import 'recipe_results_screen.dart';

// ─── IngredientEntryScreen ────────────────────────────────────────────────────
// THE unified ingredient input. One screen, two modes via pill switcher.
// Mode A — CAMERA: live viewfinder → shutter → AI scan → ingredient chips
// Mode B — TYPE:   keyboard-first, comma-separated, instant add
// UX: Hick's Law (1 entry point), Fitts's Law (big shutter), Jakob's Law

enum _Mode { camera, type }

class IngredientEntryScreen extends StatefulWidget {
  const IngredientEntryScreen({super.key});
  @override
  State<IngredientEntryScreen> createState() => _IngredientEntryScreenState();
}

class _IngredientEntryScreenState extends State<IngredientEntryScreen>
    with SingleTickerProviderStateMixin {
  _Mode _mode = _Mode.camera;

  CameraController? _cam;
  List<CameraDescription> _cameras = [];
  bool _camReady = false;
  bool _capturing = false;
  bool _torchOn = false;
  late AnimationController _pulse;

  List<String> _ingredients = [];
  bool _scanning = false;
  bool _scanFailed = false;
  String? _scanError;
  String? _capturedPath;

  final _typeCtrl  = TextEditingController();
  final _typeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _cam = CameraController(_cameras.first, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await _cam!.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (_) {
      if (mounted) setState(() => _mode = _Mode.type);
    }
  }

  Future<void> _capture() async {
    if (!_camReady || _capturing || _cam == null) return;
    HapticFeedback.mediumImpact();
    setState(() { _capturing = true; _scanning = true; _ingredients = []; _scanError = null; _scanFailed = false; });
    try {
      final file = await _cam!.takePicture();
      _capturedPath = file.path;
      final b64 = base64Encode(await File(file.path).readAsBytes());
      final result = await ApiService.scanImage(b64);
      if (mounted) {
        final empty = result.ingredients.isEmpty;
        setState(() {
          _ingredients = result.ingredients;
          _scanning = false;
          _scanFailed = empty;
          if (empty && result.message != null) {
            _scanError = result.message;
          }
        });
        // Show SnackBar feedback
        final count = result.ingredients.length;
        final msg = count > 0
            ? '$count ingredient${count == 1 ? '' : 's'} found'
            : 'No ingredients detected — try better lighting or add manually';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg, style: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
            backgroundColor: count > 0 ? AppTheme.primaryDark : AppTheme.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            duration: const Duration(seconds: 3),
          ));
        }
      }
    } catch (_) {
      if (mounted) setState(() { _scanning = false; _scanFailed = true; _scanError = 'Could not detect — add manually.'; });
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleTorch() async {
    if (_cam == null || !_camReady) return;
    _torchOn = !_torchOn;
    await _cam!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  static const _maxIngredients = 15;

  void _removeChip(String item) => setState(() => _ingredients.remove(item));

  void _clearAndRetry() {
    setState(() {
      _capturedPath = null;
      _ingredients = [];
      _scanError = null;
      _scanFailed = false;
    });
  }

  void _addManual() {
    final raw = _typeCtrl.text.trim();
    if (raw.isEmpty) return;
    final toAdd = raw.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    final remaining = _maxIngredients - _ingredients.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Maximum 15 ingredients — remove some first.',
            style: TextStyle(fontFamily: 'DM Sans')),
        backgroundColor: AppTheme.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      return;
    }
    setState(() {
      for (final p in toAdd.take(remaining)) {
        if (!_ingredients.contains(p)) _ingredients.add(p);
      }
    });
    _typeCtrl.clear();
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
    Navigator.pushReplacement(context, AppTheme.zoomIn(RecipeResultsScreen(ingredients: _ingredients)));
  }

  void _switchMode(_Mode m) {
    if (_mode == m) return;
    HapticFeedback.selectionClick();
    // Do NOT reset _ingredients — both tabs share the same list
    setState(() { _mode = m; _scanError = null; _scanFailed = false; _capturedPath = null; });
    if (m == _Mode.type) {
      WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(_typeFocus));
    } else {
      _typeFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _cam?.dispose();
    _typeCtrl.dispose();
    _typeFocus.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  bool get _isDark => _mode == _Mode.camera;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark ? Colors.black : AppTheme.creamBg,
      body: Stack(children: [
        // Camera layer — shows live feed OR frozen captured image
        if (_camReady && _cam != null)
          AnimatedOpacity(
            opacity: _isDark ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Positioned.fill(
              child: _capturedPath != null
                  // Freeze on captured image — no more live feed after shutter
                  ? Image.file(File(_capturedPath!), fit: BoxFit.cover)
                  : CameraPreview(_cam!),
            ),
          ),
        // Vignette
        if (_isDark)
          Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55), Colors.transparent,
                Colors.transparent, Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0.0, 0.22, 0.62, 1.0],
            )),
          )),
        // UI
        SafeArea(child: Column(children: [
          _topBar(),
          _modePill(),
          if (_isDark) ...[
            Expanded(child: _cameraContent()),
            _shutterBar(),
          ] else
            Expanded(child: _typeContent()),
        ])),
      ]),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Row(children: [
      TapScale(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: _isDark ? Colors.black.withValues(alpha: 0.4) : AppTheme.cardBg(context),
            shape: BoxShape.circle,
            border: Border.all(color: _isDark ? Colors.white.withValues(alpha: 0.15) : AppTheme.border(context)),
          ),
          child: Icon(LucideIcons.x, color: _isDark ? Colors.white : AppTheme.primaryDark, size: 18),
        ),
      ),
      const Spacer(),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          _isDark ? 'Add Ingredients' : 'Type Ingredients',
          key: ValueKey(_mode),
          style: TextStyle(color: _isDark ? Colors.white : AppTheme.darkText,
              fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
        ),
      ),
      const Spacer(),
      AnimatedOpacity(
        opacity: _isDark ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: TapScale(
          onTap: _toggleTorch,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _torchOn ? AppTheme.yellow.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: _torchOn ? AppTheme.yellow : Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(LucideIcons.zap, color: _torchOn ? AppTheme.yellow : Colors.white, size: 18),
          ),
        ),
      ),
    ]),
  ).animate().fadeIn(duration: 300.ms);

  Widget _modePill() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Container(
      height: 46, padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _isDark ? Colors.black.withValues(alpha: 0.35) : AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _isDark ? Colors.white.withValues(alpha: 0.12) : AppTheme.border(context)),
      ),
      child: Row(children: [
        _PillTab(label: 'Camera', icon: LucideIcons.camera,
            active: _isDark, darkBg: _isDark, onTap: () => _switchMode(_Mode.camera)),
        _PillTab(label: 'Type', icon: LucideIcons.pencilLine,
            active: !_isDark, darkBg: _isDark, onTap: () => _switchMode(_Mode.type)),
      ]),
    ),
  ).animate().fadeIn(duration: 350.ms, delay: 80.ms);

  Widget _cameraContent() => Column(children: [
    const Spacer(),
    if (!_scanning && _capturedPath == null)
      _ScanFrame(pulse: _pulse)
    else if (_scanning)
      const _ScanningIndicator(),
    const Spacer(),
    if (_ingredients.isNotEmpty || _scanError != null || _scanFailed) _chipPanel(),
    // _addRow only visible after scan — user can add more ingredients manually
    if (!_scanning && _capturedPath != null) ...[
      _addRow(dark: true),
      const SizedBox(height: 8),
    ],
    if (_capturedPath != null) ...[
      // Retake button — clears capture and restarts live viewfinder
      GestureDetector(
        onTap: () => setState(() {
          _capturedPath = null;
          _ingredients = [];
          _scanError = null;
        }),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(LucideIcons.refreshCw, color: Colors.white54, size: 13),
            const SizedBox(width: 6),
            Text('Retake', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
            )),
          ]),
        ),
      ),
    ],
    _findBtn(),
    const SizedBox(height: 8),
  ]);

  Widget _chipPanel() => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: _scanFailed && _ingredients.isEmpty
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.cameraOff, size: 40, color: Colors.white54),
            const SizedBox(height: 12),
            const Text('Nothing detected',
              style: TextStyle(color: Colors.white, fontSize: 14,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Try better lighting or a closer angle',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontFamily: 'DM Sans'),
              textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _clearAndRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () => _switchMode(_Mode.type),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  foregroundColor: AppTheme.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Type Instead', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
              )),
            ]),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(LucideIcons.sparkles, color: AppTheme.green, size: 14),
              const SizedBox(width: 6),
              Text(_scanError ?? '${_ingredients.length} detected — tap × to remove',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12, fontFamily: 'DM Sans')),
            ]),
            if (_ingredients.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6,
                  children: _ingredients.map((i) => _Chip(label: i, dark: true, onRemove: () => _removeChip(i))).toList()),
            ],
          ]),
  );

  Widget _typeContent() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x40043B3C), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.pencilLine, color: Colors.white, size: 18)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Type your ingredients', style: TextStyle(color: Colors.white, fontSize: 14,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('Separate with commas — e.g. chicken, garlic, rice',
                style: TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'DM Sans')),
          ])),
        ]),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
      const SizedBox(height: 20),
      _addRow(dark: false),
      const SizedBox(height: 20),
      if (_ingredients.isNotEmpty) ...[
        Text('${_ingredients.length} ingredient${_ingredients.length == 1 ? '' : 's'} added',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
            children: _ingredients.map((i) => _Chip(label: i, dark: false, onRemove: () => _removeChip(i))).toList()),
        const SizedBox(height: 24),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Column(children: [
            Container(width: 64, height: 64,
              decoration: BoxDecoration(color: AppTheme.scanGreen.withValues(alpha: 0.4), shape: BoxShape.circle),
              child: const Icon(LucideIcons.leafyGreen, color: AppTheme.primaryDark, size: 26)),
            const SizedBox(height: 14),
            const Text('No ingredients yet', style: TextStyle(color: AppTheme.darkText,
                fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Type above or switch to Camera',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
          ])).animate().fadeIn(duration: 400.ms),
        ),
      const SizedBox(height: 16),
      _findBtn(),
      const SizedBox(height: 32),
    ]),
  );

  Widget _shutterBar() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(40, 4, 40, 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 62),
        TapScale(
          onTap: _capture,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: _capturing ? 70 : 78, height: _capturing ? 70 : 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.white,
              border: Border.all(color: AppTheme.green, width: _capturing ? 5 : 4),
              boxShadow: [BoxShadow(color: AppTheme.green.withValues(alpha: 0.55), blurRadius: 28, spreadRadius: 2)],
            ),
            child: _capturing
                ? const Center(child: SizedBox(width: 26, height: 26,
                    child: CircularProgressIndicator(color: AppTheme.primaryDark, strokeWidth: 2.5)))
                : const Center(child: Icon(LucideIcons.camera, color: AppTheme.primaryDark, size: 28)),
          ),
        ),
        const SizedBox(width: 16),
        TapScale(
          onTap: () async {
            if (_cameras.length < 2 || !_camReady) return;
            final nd = _cam!.description == _cameras.first ? _cameras.last : _cameras.first;
            await _cam!.dispose();
            _cam = CameraController(nd, ResolutionPreset.high, enableAudio: false);
            await _cam!.initialize();
            if (mounted) setState(() {});
          },
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
            child: const Icon(LucideIcons.refreshCw, color: Colors.white, size: 18),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
  );

  Widget _addRow({required bool dark}) => Row(children: [
    Expanded(
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: dark ? Colors.black.withValues(alpha: 0.35) : AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.15) : AppTheme.border(context)),
        ),
        child: TextField(
          controller: _typeCtrl,
          focusNode: !_isDark ? _typeFocus : null,
          onSubmitted: (_) => _addManual(),
          style: TextStyle(fontSize: 14, fontFamily: 'DM Sans', color: dark ? Colors.white : AppTheme.textPrimary(context)),
          decoration: InputDecoration(
            hintText: 'Add ingredient (e.g. garlic, rice)',
            hintStyle: TextStyle(color: dark ? Colors.white38 : AppTheme.textMuted(context), fontSize: 14, fontFamily: 'DM Sans'),
            prefixIcon: Icon(LucideIcons.plus, size: 16, color: dark ? Colors.white38 : AppTheme.textMuted(context)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    ),
    const SizedBox(width: 8),
    TapScale(
      onTap: _addManual,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(16)),
        child: const Icon(LucideIcons.arrowRight, color: Colors.white, size: 20),
      ),
    ),
  ]).animate().fadeIn(duration: 300.ms, delay: 100.ms);

  Widget _findBtn() => TapScale(
    onTap: _findRecipes,
    child: Container(
      width: double.infinity, height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _ingredients.isEmpty
            ? [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.1)]
            : [AppTheme.green, AppTheme.greenDark]),
        borderRadius: BorderRadius.circular(18),
        border: _ingredients.isEmpty ? Border.all(color: Colors.white.withValues(alpha: 0.12)) : null,
        boxShadow: _ingredients.isEmpty ? [] : const [BoxShadow(color: Color(0x6076CC4F), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.chefHat, size: 20,
            color: _ingredients.isEmpty ? Colors.white.withValues(alpha: 0.3) : Colors.white),
        const SizedBox(width: 10),
        Text(
          _ingredients.isEmpty ? 'Add ingredients first' : 'Find Recipes (${_ingredients.length})',
          style: TextStyle(
            color: _ingredients.isEmpty ? Colors.white.withValues(alpha: 0.3) : Colors.white,
            fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    ),
  );
}

// ── Scanning indicator (non-const safe) ───────────────────────────────────────
class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator();
  @override
  Widget build(BuildContext context) => Column(children: [
    const SizedBox(width: 52, height: 52,
        child: CircularProgressIndicator(color: AppTheme.green, strokeWidth: 2.5)),
    const SizedBox(height: 16),
    Text('Identifying ingredients...', style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontFamily: 'DM Sans')),
  ]);
}

// ── Pill Tab ───────────────────────────────────────────────────────────────────
class _PillTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active, darkBg;
  final VoidCallback onTap;
  const _PillTab({required this.label, required this.icon, required this.active,
      required this.darkBg, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
        height: 38,
        decoration: BoxDecoration(
          gradient: active ? AppTheme.tealGradient : null,
          borderRadius: BorderRadius.circular(50),
          boxShadow: active ? const [BoxShadow(color: Color(0x40043B3C), blurRadius: 10, offset: Offset(0, 3))] : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: active ? Colors.white : (darkBg ? Colors.white54 : AppTheme.mutedText)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            color: active ? Colors.white : (darkBg ? Colors.white54 : AppTheme.mutedText),
            fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
          )),
        ]),
      ),
    ),
  );
}

// ── Scan Frame ─────────────────────────────────────────────────────────────────
class _ScanFrame extends StatelessWidget {
  final AnimationController pulse;
  const _ScanFrame({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.68;
    return SizedBox(
      width: w, height: w,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) => CustomPaint(painter: _FramePainter(
          color: AppTheme.green.withValues(alpha: 0.3 + pulse.value * 0.5),
          cornerLength: 26, strokeWidth: 3.5,
        )),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.88, 0.88));
  }
}

class _FramePainter extends CustomPainter {
  final Color color;
  final double cornerLength, strokeWidth;
  const _FramePainter({required this.color, required this.cornerLength, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const r = 10.0; final cl = cornerLength; final w = s.width; final h = s.height;
    canvas.drawLine(const Offset(r, 0), Offset(cl, 0), p);
    canvas.drawLine(const Offset(0, r), Offset(0, cl), p);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), -3.14159, 3.14159 / 2, false, p);
    canvas.drawLine(Offset(w - cl, 0), Offset(w - r, 0), p);
    canvas.drawLine(Offset(w, r), Offset(w, cl), p);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2), -3.14159 / 2, 3.14159 / 2, false, p);
    canvas.drawLine(Offset(0, h - cl), Offset(0, h - r), p);
    canvas.drawLine(Offset(r, h), Offset(cl, h), p);
    canvas.drawArc(Rect.fromLTWH(0, h - r * 2, r * 2, r * 2), 3.14159 / 2, 3.14159 / 2, false, p);
    canvas.drawLine(Offset(w, h - cl), Offset(w, h - r), p);
    canvas.drawLine(Offset(w - cl, h), Offset(w - r, h), p);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2), 0, 3.14159 / 2, false, p);
  }

  @override
  bool shouldRepaint(_FramePainter o) => o.color != color;
}

// ── Ingredient Chip ────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool dark;
  final VoidCallback onRemove;
  const _Chip({required this.label, required this.dark, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
    decoration: BoxDecoration(
      color: dark ? Colors.white.withValues(alpha: 0.1) : AppTheme.primaryDark.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.2) : AppTheme.primaryDark.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: dark ? Colors.white : AppTheme.darkText,
          fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      TapScale(
        onTap: onRemove,
        child: Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.12) : AppTheme.primaryDark.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(LucideIcons.x, size: 10, color: dark ? Colors.white : AppTheme.darkText),
        ),
      ),
    ]),
  ).animate().fadeIn(duration: 180.ms).scale(begin: const Offset(0.85, 0.85));
}
