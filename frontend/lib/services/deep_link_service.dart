import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Handles Android App Links for Firebase email actions:
///   - verifyEmail  → applies the oobCode, marks email verified
///   - resetPassword → routes user to change-password (handled by Firebase UI flow)
///
/// Usage: call DeepLinkService.init(navigatorKey) once in main(), after Firebase.initializeApp().
/// The service listens for both cold-start links (getInitialAppLink) and foreground links (uriLinkStream).
///
/// Firebase email links look like:
///   https://chishiyaj.github.io/plately?mode=verifyEmail&oobCode=ABC&apiKey=...
///   https://chishiyaj.github.io/plately?mode=resetPassword&oobCode=ABC&apiKey=...
class DeepLinkService {
  static final _appLinks = AppLinks();
  static GlobalKey<NavigatorState>? _navKey;

  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navKey = navigatorKey;

    // Cold-start link (app opened via link tap)
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
    } catch (_) {}

    // Foreground links (app already open, user taps link in notification)
    _appLinks.uriLinkStream.listen((uri) async {
      await _handleUri(uri);
    }, onError: (_) {});
  }

  static Future<void> _handleUri(Uri uri) async {
    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) return;

    if (mode == 'verifyEmail') {
      await _handleVerifyEmail(oobCode);
    } else if (mode == 'resetPassword') {
      // Firebase handles password reset in the browser -- nothing extra needed.
      // If you want in-app handling, show a reset-password dialog here.
    }
  }

  static Future<void> _handleVerifyEmail(String oobCode) async {
    try {
      await FirebaseAuth.instance.applyActionCode(oobCode);
      await FirebaseAuth.instance.currentUser?.reload();
      // Show a success snack on the currently visible screen
      final ctx = _navKey?.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text(
            'Email verified! You can now log in.',
            style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF043B3C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          duration: const Duration(seconds: 4),
        ));
      }
    } on FirebaseAuthException catch (_) {
      // oobCode expired or already used -- silently ignore; user will see error on login
    } catch (_) {}
  }
}
