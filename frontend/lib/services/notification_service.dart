import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Handles all local phone notifications for Plately.
///
/// NOTIFICATIONS (5 dynamic, data-driven):
///   1. Morning Fuel Check     -- 8:00 AM daily
///   2. Midday Macro Check     -- 1:00 PM daily
///   3. Streak Protection      -- 6:30 PM daily (skip if already cooked today)
///   4. Weekend Cook Inspo     -- Saturday 11:00 AM
///   5. Cook Done              -- one-shot on recipe finish
///
/// All messages are personalised using real user data (name, streak, macros,
/// pantry items). Cancel + reschedule on every app open so copy stays fresh.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Notification IDs
  static const _idMorning  = 1001;
  static const _idMidday   = 1002;
  static const _idStreak   = 1003;
  static const _idWeekend  = 1004;
  static const _idCookDone = 1005;
  static const _idTimerDone = 1006;

  // Android channels
  static const _chReminders = 'plately_reminders';
  static const _chCooking   = 'plately_cooking';

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    const android  = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: _onTap);

    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await ap?.createNotificationChannel(const AndroidNotificationChannel(
      _chReminders, 'Meal Reminders',
      description: 'Daily reminders to cook and hit your goals.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    await ap?.createNotificationChannel(const AndroidNotificationChannel(
      _chCooking, 'Cooking Alerts',
      description: 'Fired when you finish cooking a recipe.',
      importance: Importance.defaultImportance,
      playSound: true,
    ));
    _initialized = true;
  }

  static void _onTap(NotificationResponse _) {}

  // ── Permission ────────────────────────────────────────────────────────────

  static Future<bool> requestPermission() async {
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await ap?.requestNotificationsPermission() ?? false;
  }

  // ── Personalised scheduling ───────────────────────────────────────────────

  /// Call after _loadPrefs() in HomeScreen so messages always use fresh data.
  /// Cancels all existing reminders first, then reschedules with current values.
  /// [pantryItems] -- top items from the user's pantry (used in morning/midday copy).
  static Future<void> schedulePersonalized({
    required String name,
    required int proteinGoal,
    required int proteinConsumed,
    required int streak,
    required String lastCookedName,
    List<String> pantryItems = const [],
  }) async {
    await _ensureInit();

    // Cancel stale scheduled notifications before rescheduling
    await _plugin.cancel(_idMorning);
    await _plugin.cancel(_idMidday);
    await _plugin.cancel(_idStreak);
    await _plugin.cancel(_idWeekend);

    final firstName = name.split(' ').first;
    final rng       = Random(DateTime.now().day); // consistent within a day

    // Build pantry hint string -- pick up to 2 items for copy
    final pantryHint = _buildPantryHint(pantryItems);

    // 1. Morning Fuel Check -- 8:00 AM
    final List<_Notif> morningPool;
    if (pantryHint.isNotEmpty) {
      morningPool = [
        _Notif(
          'gm $firstName -- ${pantryHint.split(' ')[0]} is waiting',
          'you have $pantryHint in your fridge. ${proteinGoal}g protein won\'t cook itself.',
        ),
        _Notif(
          'gm $firstName, rise and cook',
          '$pantryHint in the pantry. open plately and turn that into ${proteinGoal}g protein.',
        ),
        _Notif(
          'breakfast era, $firstName',
          'you\'ve got $pantryHint. quick cook = better macros = better day.',
        ),
        _Notif(
          'ur protein goal won\'t hit itself',
          '$pantryHint + plately = ${proteinGoal}g protein incoming. let\'s go.',
        ),
      ];
    } else {
      morningPool = [
        _Notif(
          'gm $firstName, rise and cook',
          'hitting ${proteinGoal}g protein doesn\'t happen on vibes alone. let\'s go.',
        ),
        _Notif(
          'ur protein goal won\'t hit itself',
          '${proteinGoal}g target. the main character arc starts in the kitchen.',
        ),
        _Notif(
          'good morning, $firstName',
          'today\'s mission: ${proteinGoal}g protein. plately\'s ready when you are.',
        ),
        _Notif(
          'breakfast era, $firstName',
          'quick cook = better macros = better day. what\'s in your fridge?',
        ),
      ];
    }
    final morning = morningPool[rng.nextInt(morningPool.length)];
    await _scheduleDailyAt(
      id: _idMorning, hour: 8, minute: 0,
      title: morning.title, body: morning.body, channel: _chReminders,
    );

    // 2. Midday Macro Check -- 1:00 PM
    final remaining = (proteinGoal - proteinConsumed).clamp(0, proteinGoal);
    final _Notif midday;
    if (remaining <= 0) {
      midday = _Notif(
        'W behavior, $firstName',
        'protein goal already cleared. you\'re built different today.',
      );
    } else if (pantryHint.isNotEmpty) {
      midday = _Notif(
        '${remaining}g protein left, $firstName',
        'you\'ve got $pantryHint at home. lunch = done. open plately.',
      );
    } else {
      midday = _Notif(
        '${remaining}g protein left, $firstName',
        'lunch time. open plately, cook something. don\'t fumble the bag.',
      );
    }
    await _scheduleDailyAt(
      id: _idMidday, hour: 13, minute: 0,
      title: midday.title, body: midday.body, channel: _chReminders,
    );

    // 3. Streak Protection -- 6:30 PM
    final _Notif streakNotif;
    if (streak >= 7) {
      streakNotif = _Notif(
        '$streak days straight, $firstName. that\'s insane.',
        'one more cook tonight keeps the arc alive. open plately.',
      );
    } else if (streak >= 3) {
      streakNotif = _Notif(
        'don\'t fumble the $streak-day streak',
        'one recipe. 15 mins. protect the bag.',
      );
    } else if (streak == 2) {
      streakNotif = const _Notif(
        '2 days in a row. momentum is building.',
        'don\'t let day 3 be the one that kills the vibe.',
      );
    } else if (streak == 1) {
      streakNotif = const _Notif(
        'yesterday was day 1. today is day 2.',
        'cook something. any recipe. just don\'t break the chain.',
      );
    } else {
      streakNotif = const _Notif(
        'no streak yet? tonight\'s the night.',
        'even a 5-min garlic fried rice counts. open plately.',
      );
    }
    await _scheduleDailyAt(
      id: _idStreak, hour: 18, minute: 30,
      title: streakNotif.title, body: streakNotif.body, channel: _chReminders,
    );

    // 4. Weekend Cook Inspo -- Saturday 11:00 AM
    final weekendBody = lastCookedName.isNotEmpty
        ? 'last time: $lastCookedName. level up today. 500+ recipes to explore.'
        : 'it\'s the weekend. no class, no excuse. open plately and cook something real.';
    await _scheduleWeeklyOnSaturday(
      id: _idWeekend, hour: 11, minute: 0,
      title: 'weekend is the looksmaxx arc era',
      body: weekendBody,
      channel: _chReminders,
    );
  }

  // ── One-shot: Step Timer Done ─────────────────────────────────────────────

  /// Fire immediately when a step countdown timer hits zero.
  static Future<void> notifyStepTimerDone(int stepNumber) async {
    await _ensureInit();
    final messages = [
      ('timer\'s up! check step $stepNumber.', 'don\'t let it burn.'),
      ('step $stepNumber done.', 'move to the next one.'),
      ('ding! step $stepNumber.', 'you\'re on a roll.'),
    ];
    final pick = messages[stepNumber % messages.length];
    await _plugin.show(
      _idTimerDone,
      pick.$1,
      pick.$2,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _chCooking, 'Cooking Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // ── One-shot: Cook Done ───────────────────────────────────────────────────

  /// Fire immediately when user finishes cooking.
  static Future<void> notifyCookingDone(
    String recipeName, {
    int cal = 0,
    int protein = 0,
    int streak = 0,
    String userName = 'chef',
  }) async {
    await _ensureInit();
    final firstName = userName.split(' ').first;
    final streakLine = streak >= 7
        ? ' $streak-day streak. you\'re actually built different.'
        : streak >= 3
            ? ' $streak days running. don\'t stop now.'
            : streak == 2
                ? ' 2 days in a row. keep it.'
                : streak == 1
                    ? ' day 1 locked in.'
                    : '';
    final title = streak >= 7
        ? '$firstName cooked again. $streak days. unreal.'
        : streak >= 3
            ? 'W cook, $firstName -- $streak-day streak'
            : 'W cook, $firstName';
    final body  = '+${cal}kcal · +${protein}g protein logged.$streakLine';
    final big   = 'just cooked $recipeName -- +${cal}kcal · +${protein}g protein.$streakLine';
    await _plugin.show(
      _idCookDone,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chCooking, 'Cooking Alerts',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(big),
        ),
      ),
    );
  }

  // ── Legacy: kept for Profile toggle ──────────────────────────────────────

  /// Simple static reminders (used when scheduling without user data).
  static Future<void> enableMealReminders() async {
    await schedulePersonalized(
      name: 'chef',
      proteinGoal: 120,
      proteinConsumed: 0,
      streak: 0,
      lastCookedName: '',
    );
  }

  static Future<void> disableMealReminders() async {
    await Future.wait([
      _plugin.cancel(_idMorning),
      _plugin.cancel(_idMidday),
      _plugin.cancel(_idStreak),
      _plugin.cancel(_idWeekend),
    ]);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Returns a readable list of up to 2 pantry items, e.g. "eggs + chicken".
  /// Returns empty string if pantry is empty.
  static String _buildPantryHint(List<String> items) {
    if (items.isEmpty) return '';
    final top = items.take(2).map((s) => s.toLowerCase()).toList();
    return top.length == 1 ? top[0] : '${top[0]} + ${top[1]}';
  }

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
    final now       = tz.TZDateTime.now(tz.local);
    var   scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id, title, body, scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == _chReminders ? 'Meal Reminders' : 'Cooking Alerts',
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

  static Future<void> _scheduleWeeklyOnSaturday({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channel,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != DateTime.saturday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id, title, body, scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == _chReminders ? 'Meal Reminders' : 'Cooking Alerts',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

// ── Internal data class ───────────────────────────────────────────────────────
class _Notif {
  final String title;
  final String body;
  const _Notif(this.title, this.body);
}
