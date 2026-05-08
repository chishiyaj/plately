import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class AppTheme {
  // ── Light mode colors ──────────────────────────────────────────────────────
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

  // ── Dark mode colors ───────────────────────────────────────────────────────
  static const Color darkBg          = Color(0xFF0A1414);
  static const Color darkCard        = Color(0xFF152020);
  static const Color darkCardAlt     = Color(0xFF1C2B2B);
  static const Color darkBorder      = Color(0xFF2C4040);
  static const Color darkTextPrimary = Color(0xFFF0EEE9);
  static const Color darkTextMuted   = Color(0xFF8AABAB);

  // ── Context-aware helpers ──────────────────────────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? darkBg : creamBg;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? darkCard : Colors.white;

  static Color cardAltBg(BuildContext context) =>
      isDark(context) ? darkCardAlt : creamBg;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : darkText;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : mutedText;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : borderGray;

  static Color iconColor(BuildContext context) =>
      isDark(context) ? darkTextPrimary : primaryDark;

  // ── Dynamic text styles (use these in screens — they respect dark mode) ──
  static TextStyle headingLargeStyle(BuildContext context) => TextStyle(
    color: textPrimary(context), fontSize: 24,
    fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
  );

  static TextStyle headingMediumStyle(BuildContext context) => TextStyle(
    color: textPrimary(context), fontSize: 20,
    fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
  );

  static TextStyle bodyMediumStyle(BuildContext context) => TextStyle(
    color: textPrimary(context), fontSize: 15,
    fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
  );

  static TextStyle bodySmallStyle(BuildContext context) => TextStyle(
    color: textMuted(context), fontSize: 13,
    fontFamily: 'DM Sans', fontWeight: FontWeight.w400,
  );

  static TextStyle captionStyle(BuildContext context) => TextStyle(
    color: textMuted(context), fontSize: 11,
    fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
  );

  // ── Static text styles (light-mode only — use on dark backgrounds, teal cards)
  static const TextStyle logoStyle = TextStyle(
    color: primaryDark, fontSize: 24, fontFamily: 'Nunito', fontWeight: FontWeight.w800,
  );
  // Keep these for backward compat — screens should migrate to dynamic versions above
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

  // ── Gradients ──────────────────────────────────────────────────────────────
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

  // ── Page transitions ───────────────────────────────────────────────────────
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
              child: child,
            ),
      );

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

  // ── Themes ─────────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryDark),
    scaffoldBackgroundColor: creamBg,
    fontFamily: 'DM Sans',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: darkText,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(color: Colors.white),
    dividerColor: borderGray,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: creamBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderGray),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryDark,
      brightness: Brightness.dark,
      surface: darkCard,
      onSurface: darkTextPrimary,
    ),
    scaffoldBackgroundColor: darkBg,
    fontFamily: 'DM Sans',
    cardColor: darkCard,
    dividerColor: darkBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkCard,
      foregroundColor: darkTextPrimary,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCardAlt,
      labelStyle: const TextStyle(color: darkTextMuted),
      hintStyle: const TextStyle(color: darkTextMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryDark, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? primaryDark : darkTextMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? primaryDark.withValues(alpha: 0.4)
              : darkBorder),
    ),
  );
}
