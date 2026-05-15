import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PlatelyLogoTheme { onDark, onLight }

class PlatelyLogo extends StatelessWidget {
  final double iconSize;
  final double wordmarkSize;
  final bool showWordmark;
  final PlatelyLogoTheme theme;

  const PlatelyLogo({
    super.key,
    this.iconSize = 44,
    this.wordmarkSize = 22,
    this.showWordmark = true,
    this.theme = PlatelyLogoTheme.onDark,
  });

  @override
  Widget build(BuildContext context) {
    final isOnDark = theme == PlatelyLogoTheme.onDark;
    final wordmarkColor = isOnDark ? Colors.white : AppTheme.primaryDark;
    const showBg = false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: CustomPaint(
              painter: _RingMarkPainter(
                  size: iconSize,
                  showBackground: showBg)),
        ),
        if (showWordmark) ...[
          SizedBox(width: iconSize * 0.22),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'plate',
                  style: TextStyle(
                    color: wordmarkColor,
                    fontSize: wordmarkSize,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'ly',
                  style: TextStyle(
                    color: AppTheme.green,
                    fontSize: wordmarkSize,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RingMarkPainter extends CustomPainter {
  final double size;
  final bool showBackground;
  const _RingMarkPainter({required this.size, this.showBackground = true});

  @override
  void paint(Canvas canvas, Size sz) {
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    final r = sz.width / 2;

    // ── Background tile (only for launcher icon) ──────────────────────────
    if (showBackground) {
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF031212), Color(0xFF043B3C)],
        ).createShader(Rect.fromLTWH(0, 0, sz.width, sz.height));
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, sz.width, sz.height),
        Radius.circular(r * 0.28),
      );
      canvas.drawRRect(rrect, bgPaint);
    }

    // ── Full 360deg ring — clean solid green, no accent gap ───────────────
    final trackR  = r * 0.72;
    final strokeW = size * 0.095; // slightly thicker = more premium

    // Single full circle — no white accent, no visible seam
    final ringPaint = Paint()
      ..color = const Color(0xFF76CC4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(Offset(cx, cy), trackR, ringPaint);

    // ── Centre target dot — white outer + green inner ─────────────────────
    // Outer dot: white (or teal on light backgrounds)
    final dotColor = showBackground
        ? Colors.white
        : const Color(0xFF043B3C);
    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.115,
      Paint()..color = dotColor,
    );
    // Inner dot: green core
    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.055,
      Paint()..color = const Color(0xFF76CC4F),
    );
  }

  @override
  bool shouldRepaint(_RingMarkPainter old) =>
      old.size != size || old.showBackground != showBackground;
}
