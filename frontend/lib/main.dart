import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_goals_screen.dart';
import 'main_shell.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/keep_alive_service.dart';
import 'services/user_prefs_service.dart';

/// Top-level theme notifier — import and use from profile_screen to toggle.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode _themeModeFromString(String? s) {
  if (s == 'light') return ThemeMode.light;
  if (s == 'dark') return ThemeMode.dark;
  return ThemeMode.system;
}

String themeModeToString(ThemeMode m) {
  if (m == ThemeMode.light) return 'light';
  if (m == ThemeMode.dark) return 'dark';
  return 'system';
}

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

  KeepAliveService.start();

  // Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = _themeModeFromString(prefs.getString('app_theme_mode'));

  final user = FirebaseAuth.instance.currentUser;
  final bool alreadyLoggedIn = user != null && (user.emailVerified || _isGoogleUser(user));

  Widget home = const SplashScreen();
  if (alreadyLoggedIn) {
    final done = await UserPrefsService.isOnboardingDone();
    home = done ? const MainShell() : const OnboardingGoalsScreen();
  }

  runApp(PlatelyApp(home: home));
}

bool _isGoogleUser(User user) =>
    user.providerData.any((p) => p.providerId == 'google.com');

class PlatelyApp extends StatelessWidget {
  final Widget home;
  const PlatelyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Plately',
        theme: AppTheme.theme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: home,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
