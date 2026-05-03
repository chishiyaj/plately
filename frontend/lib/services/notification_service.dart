import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Handles all local phone notifications for Plately.
///
/// NOTIFICATIONS USED:
///   - Daily meal log reminder  (8:00 PM) — "Don't forget to log today!"
///   - Protein goal reminder    (1:00 PM) — mid-day protein check
///   - Cook streak alert        (6:00 PM) — only if no recipe cooked today
///
/// Android: notifications appear in system tray, can vibrate/sound.
/// No internet needed — fully local.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Notification IDs — stable across app sessions
  static const _idDailyMeal    = 1001;
  static const _idProtein      = 1002;
  static const _idStreak       = 1003;
  static const _idCookDone     = 1004; // one-shot on recipe finish

  // Android notification channel IDs
  static const _channelReminders = 'plately_reminders';
  static const _channelCooking   = 'plately_cooking';

  // ── Init ─────────────────────────────────────────────────────────────────

  /// Call once in main() before runApp.
  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Philippines timezone
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create Android notification channels (v17 API — singular per call)
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelReminders, 'Meal Reminders',
      description: 'Daily reminders to log your meals and reach your goals.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelCooking, 'Cooking Alerts',
      description: 'Notifications when you finish cooking a recipe.',
      importance: Importance.defaultImportance,
      playSound: true,
    ));

    _initialized = true;
  }

  static void _onTap(NotificationResponse response) {
    // Deep-link handling can be added here (e.g. open AI chat, open history)
  }

  // ── Permission ───────────────────────────────────────────────────────────

  /// Request Android 13+ notification permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  // ── Schedule / Cancel ────────────────────────────────────────────────────

  /// Enable all daily meal reminders.
  /// Called when user turns on "Calorie Notifications" toggle in Profile.
  static Future<void> enableMealReminders() async {
    await _ensureInit();
    await Future.wait([
      _scheduleDailyAt(
        id: _idDailyMeal,
        hour: 20, minute: 0, // 8:00 PM
        title: '🍳 Log your meals!',
        body: 'Don\'t forget to track today\'s calories and protein in Plately.',
        channel: _channelReminders,
      ),
      _scheduleDailyAt(
        id: _idProtein,
        hour: 13, minute: 0, // 1:00 PM
        title: '💪 Protein check-in',
        body: 'Halfway through the day — hit your protein goal yet?',
        channel: _channelReminders,
      ),
      _scheduleDailyAt(
        id: _idStreak,
        hour: 18, minute: 0, // 6:00 PM
        title: '🔥 Keep your streak alive!',
        body: 'You haven\'t cooked today. Open Plately and find something quick to make.',
        channel: _channelReminders,
      ),
    ]);
  }

  /// Disable all meal reminders.
  /// Called when user turns off "Calorie Notifications" toggle.
  static Future<void> disableMealReminders() async {
    await Future.wait([
      _plugin.cancel(_idDailyMeal),
      _plugin.cancel(_idProtein),
      _plugin.cancel(_idStreak),
    ]);
  }

  /// One-shot notification shown immediately when user finishes cooking.
  static Future<void> notifyCookingDone(String recipeName) async {
    await _ensureInit();
    await _plugin.show(
      _idCookDone,
      '✅ Recipe complete!',
      'Great job cooking $recipeName. Your macros have been logged.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelCooking, 'Cooking Alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(
            'Great job cooking $recipeName! Your macros have been logged to today\'s total.',
          ),
        ),
      ),
    );
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  static Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }

  static Future<void> _scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channel,
  }) async {
    final now    = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // If the time has already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel, channel == _channelReminders ? 'Meal Reminders' : 'Cooking Alerts',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
