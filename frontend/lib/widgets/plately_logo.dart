import 'dart:math' as math;
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: CustomPaint(painter: _RingMarkPainter(size: iconSize)),
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
  const _RingMarkPainter({required this.size});

  @override
  void paint(Canvas canvas, Size sz) {
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    final r = sz.width / 2;

    // ── Background tile ──────────────────────────────────────────────────
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

    // ── Outer track ring ─────────────────────────────────────────────────
    final trackR = r * 0.72;
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), trackR, trackPaint);

    // ── White arc — short segment (top-right quarter, ~25%) ──────────────
    final whiteArcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.07
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: trackR);
    // top = -π/2, white covers top-right ~25%
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 0.5, false, whiteArcPaint);

    // ── Green arc — majority ~75% ─────────────────────────────────────────
    final greenArcPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF76CC4F), Color(0xFF3D7B20)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: trackR + size * 0.07))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.07
      ..strokeCap = StrokeCap.round;

    // green starts where white ends (top-right) and sweeps the remaining 75%
    canvas.drawArc(arcRect, -math.pi / 2 + math.pi * 0.5, math.pi * 1.5, false, greenArcPaint);

    // ── Centre white dot ──────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.115,
      Paint()..color = Colors.white,
    );

    // ── Centre green dot ─────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.055,
      Paint()..color = const Color(0xFF76CC4F),
    );
  }

  @override
  bool shouldRepaint(_RingMarkPainter old) => old.size != size;
}
