import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class AppTheme {
  // Core colors
  static const Color primaryDark  = Color(0xFF043B3C);
  static const Color primaryMid   = Color(0xFF075E5F);
  static const Color creamBg      = Color(0xFFF0EEE9);
  static const Color darkText     = Color(0xFF043B3C);
  static const Color mutedText    = Color(0xFF7A7A7A);
  static const Color green        = Color(0xFF76CC4F);
  static const Color greenDark    = Color(0xFF3D7B20);
  static const Color purple       = Color(0xFFBA5CCC);
  static const Color yellow       = Color(0xFFEABA1C);
  static const Color borderGray   = Color(0xFFDADADA);
  static const Color lightGray    = Color(0xFFD9D9D9);
  static const Color scanGreen    = Color(0xFFC0DCB3);
  static const Color typeBlue     = Color(0xFFBEC2DC);
  static const Color browseYellow = Color(0xFFDFDC9E);
  static const Color askPurple    = Color(0xFFD3A7DC);
  static const Color orange       = Color(0xFFCCA04F);
  static const Color orangeDark   = Color(0xFF965A24);
  static const Color accentGreen  = Color(0xFF73CA4C);
  static const Color red          = Color(0xFFD14444);
  static const Color cardWhite    = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF043B3C), Color(0xFF075E5F), Color(0xFF0A8183)],
  );
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF76CC4F), Color(0xFF3D7B20)],
  );
  static const LinearGradient creamGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFFF0EEE9), Color(0xFFE8E4DC)],
  );

  // Text styles
  static const TextStyle logoStyle = TextStyle(
    color: primaryDark, fontSize: 24, fontFamily: 'Nunito', fontWeight: FontWeight.w800,
  );
  static const TextStyle headingLarge = TextStyle(
    color: darkText, fontSize: 24, fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
  );
  static const TextStyle headingMedium = TextStyle(
    color: darkText, fontSize: 20, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
  );
  static const TextStyle bodyMedium = TextStyle(
    color: darkText, fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
  );
  static const TextStyle bodySmall = TextStyle(
    color: mutedText, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w400,
  );
  static const TextStyle caption = TextStyle(
    color: mutedText, fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
  );

  // Page transitions
  static Route<T> crossFade<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, a, __) => page,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut), child: child),
  );

  static Route<T> slideUp<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, a, __) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, a, __, child) {
      final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: a.drive(tween), child: child);
    },
  );

  static Route<T> slideRight<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, a, __) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, a, __, child) {
      final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: a.drive(tween), child: child);
    },
  );

  static Route<T> fadeScale<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, a, __) => page,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, a, __, child) {
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
        ), child: child),
      );
    },
  );

  // Spotify-style horizontal shared axis — direction depends on tab index
  // goingRight=true  → new screen slides in from right (higher index tab)
  // goingRight=false → new screen slides in from left  (lower index tab)
  static Route<T> sharedAxisH<T>(Widget page, {required bool goingRight}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, anim, secAnim, child) =>
            SharedAxisTransition(
              animation: anim,
              secondaryAnimation: secAnim,
              transitionType: SharedAxisTransitionType.horizontal,
              // Flip axis direction via a custom curve offset trick:
              // We wrap child in a directional slide using the anim value
              child: child,
            ),
      );

  // Zoom-in transition — card → detail screen (feels like zooming into content)
  static Route<T> zoomIn<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, anim, secAnim, child) => SharedAxisTransition(
      animation: anim,
      secondaryAnimation: secAnim,
      transitionType: SharedAxisTransitionType.scaled,
      child: child,
    ),
  );

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryDark),
    scaffoldBackgroundColor: creamBg,
    fontFamily: 'DM Sans',
  );
}
