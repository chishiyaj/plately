import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import 'scan_confirm_screen.dart';

// ─── ScanScreen ───────────────────────────────────────────────────────────────
// Full-screen live camera viewfinder — like Google Lens.
// User sees their ingredients through the camera, taps the shutter,
// then gets taken to ScanConfirmScreen to review + edit AI detections.

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _ctrl;
  List<CameraDescription> _cameras = [];
  bool _ready = false;
  bool _capturing = false;
  bool _torchOn = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _ctrl = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _ctrl!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Camera error: $e',
              style: const TextStyle(fontFamily: 'DM Sans')),
          backgroundColor: AppTheme.red,
        ));
      }
    }
  }

  Future<void> _capture() async {
    if (!_ready || _capturing || _ctrl == null) return;
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();
    try {
      final file = await _ctrl!.takePicture();
      if (!mounted) return;
      await Navigator.push(
        context,
        AppTheme.slideUp(ScanConfirmScreen(imagePath: file.path)),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleTorch() async {
    if (_ctrl == null || !_ready) return;
    _torchOn = !_torchOn;
    await _ctrl!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ctrl?.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Camera preview ──────────────────────────────────────────────────
        if (_ready && _ctrl != null)
          Positioned.fill(
            child: CameraPreview(_ctrl!),
          )
        else
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFF0A0A0A)),
          ),

        // ── Dark vignette top + bottom ──────────────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.2, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // ── Scan frame overlay ──────────────────────────────────────────────
        Center(
          child: _ScanFrame(pulseCtrl: _pulseCtrl),
        ),

        // ── Top bar ─────────────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              // Close
              TapScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(LucideIcons.x, color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
              // Title
              const Text(
                'Scan Ingredients',
                style: TextStyle(
                  color: Colors.white, fontSize: 15,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              // Torch
              TapScale(
                onTap: _toggleTorch,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _torchOn
                        ? AppTheme.yellow.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _torchOn
                            ? AppTheme.yellow
                            : Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Icon(LucideIcons.zap,
                      color: _torchOn ? AppTheme.yellow : Colors.white, size: 18),
                ),
              ),
            ]),
          ).animate().fadeIn(duration: 400.ms),
        ),

        // ── Hint label ──────────────────────────────────────────────────────
        Positioned(
          left: 0, right: 0,
          bottom: MediaQuery.of(context).size.height * 0.28,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Text(
                'Point at your ingredients and tap capture',
                style: TextStyle(
                  color: Colors.white70, fontSize: 13,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
        ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

        // ── Bottom shutter area ──────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gallery hint (future: pick from gallery)
                  const SizedBox(width: 56),

                  // Shutter button
                  TapScale(
                    onTap: _capture,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _capturing ? 70 : 78,
                      height: _capturing ? 70 : 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: AppTheme.green,
                          width: _capturing ? 5 : 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.green.withValues(alpha: 0.5),
                            blurRadius: 24, spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _capturing
                          ? const Center(
                              child: SizedBox(
                                width: 28, height: 28,
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryDark,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(LucideIcons.camera,
                                  color: AppTheme.primaryDark, size: 28),
                            ),
                    ),
                  ),

                  // Switch camera (if multiple cameras exist)
                  TapScale(
                    onTap: () async {
                      if (_cameras.length < 2 || !_ready) return;
                      final newDesc = _ctrl!.description == _cameras.first
                          ? _cameras.last
                          : _cameras.first;
                      await _ctrl!.dispose();
                      _ctrl = CameraController(newDesc, ResolutionPreset.high, enableAudio: false);
                      await _ctrl!.initialize();
                      if (mounted) setState(() {});
                    },
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Icon(LucideIcons.refreshCw,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        ),
      ]),
    );
  }
}

// ─── Scan Frame Overlay ───────────────────────────────────────────────────────
class _ScanFrame extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _ScanFrame({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = size.width * 0.72;
    return SizedBox(
      width: frameSize, height: frameSize,
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, __) {
          final glow = 0.3 + pulseCtrl.value * 0.5;
          return CustomPaint(
            painter: _FramePainter(
              color: AppTheme.green.withValues(alpha: glow),
              cornerLength: 28,
              strokeWidth: 3.5,
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).scale(begin: const Offset(0.9, 0.9));
  }
}

class _FramePainter extends CustomPainter {
  final Color color;
  final double cornerLength, strokeWidth;
  const _FramePainter({required this.color, required this.cornerLength, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const r = 10.0; // corner radius
    final w = size.width;
    final h = size.height;
    final cl = cornerLength;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(cl, 0), p);
    canvas.drawLine(Offset(0, r), Offset(0, cl), p);
    canvas.drawArc(Rect.fromLTWH(0, 0, r * 2, r * 2), -3.14, 3.14 / 2, false, p);

    // Top-right
    canvas.drawLine(Offset(w - cl, 0), Offset(w - r, 0), p);
    canvas.drawLine(Offset(w, r), Offset(w, cl), p);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2), -3.14 / 2, 3.14 / 2, false, p);

    // Bottom-left
    canvas.drawLine(Offset(0, h - cl), Offset(0, h - r), p);
    canvas.drawLine(Offset(r, h), Offset(cl, h), p);
    canvas.drawArc(Rect.fromLTWH(0, h - r * 2, r * 2, r * 2), 3.14 / 2, 3.14 / 2, false, p);

    // Bottom-right
    canvas.drawLine(Offset(w, h - cl), Offset(w, h - r), p);
    canvas.drawLine(Offset(w - cl, h), Offset(w - r, h), p);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2), 0, 3.14 / 2, false, p);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color;
}
