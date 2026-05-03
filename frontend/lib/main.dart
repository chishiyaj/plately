import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'main_shell.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.init();
  await NotificationService.requestPermission();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Skip splash/login if user is already signed in and verified
  final user = FirebaseAuth.instance.currentUser;
  final bool alreadyLoggedIn = user != null && (user.emailVerified || _isGoogleUser(user));

  runApp(PlatelyApp(startAtHome: alreadyLoggedIn));
}

/// Google accounts are always considered verified (no email step).
bool _isGoogleUser(User user) =>
    user.providerData.any((p) => p.providerId == 'google.com');

class PlatelyApp extends StatelessWidget {
  final bool startAtHome;
  const PlatelyApp({super.key, required this.startAtHome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plately',
      theme: AppTheme.theme,
      home: startAtHome ? const MainShell() : const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
