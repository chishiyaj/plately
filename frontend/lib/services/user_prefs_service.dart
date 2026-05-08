import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local CRUD for user profile, goals, daily tracking, and preferences.
/// ALL keys are prefixed with the Firebase UID so each account has isolated data.
class UserPrefsService {
  // ── Key builder — every key is namespaced per UID ─────────────────────────
  static String _uid() =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  static String _k(String key) => '${_uid()}:$key';

  // ── Raw key names (no prefix — prefix added via _k()) ─────────────────────
  static const _kName            = 'user_name';
  static const _kEmail           = 'user_email';
  static const _kCalGoal         = 'cal_goal';
  static const _kProteinGoal     = 'protein_goal';
  static const _kCalConsumed     = 'cal_consumed';
  static const _kProteinConsumed = 'protein_consumed';
  static const _kCalDate         = 'cal_date';   // tracks which day consumed values belong to
  static const _kPrefVeg         = 'pref_veg';
  static const _kPrefGluten      = 'pref_gluten';
  static const _kPrefDairy       = 'pref_dairy';
  static const _kPrefHiPro       = 'pref_hi_pro';
  static const _kGoal            = 'fitness_goal';
  static const _kNotifCal        = 'notif_calorie';
  static const _kRecipeCount     = 'recipe_count';
  static const _kStreak          = 'streak_days';
  static const _kSessionsWeek    = 'sessions_week';
  static const _kOnboardingDone  = 'onboarding_done';

  // ── READ ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> load() async {
    final p    = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final defaultName  = user?.displayName ?? 'User';
    final defaultEmail = user?.email ?? '';

    // Daily reset: if stored date != today, zero out consumed values
    final today      = _todayString();
    final storedDate = p.getString(_k(_kCalDate)) ?? '';
    if (storedDate != today) {
      await p.setString(_k(_kCalDate), today);
      await p.setInt(_k(_kCalConsumed), 0);
      await p.setInt(_k(_kProteinConsumed), 0);
    }

    return {
      'name':             p.getString(_k(_kName))           ?? defaultName,
      'email':            p.getString(_k(_kEmail))          ?? defaultEmail,
      'cal_goal':         p.getInt(_k(_kCalGoal))           ?? 2200,
      'protein_goal':     p.getInt(_k(_kProteinGoal))       ?? 120,
      'cal_consumed':     p.getInt(_k(_kCalConsumed))       ?? 0,
      'protein_consumed': p.getInt(_k(_kProteinConsumed))   ?? 0,
      'pref_veg':         p.getBool(_k(_kPrefVeg))          ?? false,
      'pref_gluten':      p.getBool(_k(_kPrefGluten))       ?? false,
      'pref_dairy':       p.getBool(_k(_kPrefDairy))        ?? false,
      'pref_hipro':       p.getBool(_k(_kPrefHiPro))        ?? true,
      'goal':             p.getString(_k(_kGoal))           ?? 'maintain',
      'notif_cal':        p.getBool(_k(_kNotifCal))         ?? true,
      'recipe_count':     p.getInt(_k(_kRecipeCount))       ?? 0,
      'streak':           p.getInt(_k(_kStreak))            ?? 0,
      'sessions_week':    p.getInt(_k(_kSessionsWeek))      ?? 0,
    };
  }

  // ── Today's date as 'YYYY-MM-DD' ─────────────────────────────────────────
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  // ── WRITE — profile ───────────────────────────────────────────────────────
  static Future<void> saveName(String v)  async => (await _p()).setString(_k(_kName), v);
  static Future<void> saveEmail(String v) async => (await _p()).setString(_k(_kEmail), v);

  // ── WRITE — goals ─────────────────────────────────────────────────────────
  static Future<void> saveCalGoal(int v)     async => (await _p()).setInt(_k(_kCalGoal), v);
  static Future<void> saveProteinGoal(int v) async => (await _p()).setInt(_k(_kProteinGoal), v);

  // ── WRITE — daily tracking ────────────────────────────────────────────────
  static Future<void> saveCalConsumed(int v)     async => (await _p()).setInt(_k(_kCalConsumed), v);
  static Future<void> saveProteinConsumed(int v) async => (await _p()).setInt(_k(_kProteinConsumed), v);

  // ── WRITE — dietary prefs ─────────────────────────────────────────────────
  static Future<void> savePrefVeg(bool v)    async => (await _p()).setBool(_k(_kPrefVeg), v);
  static Future<void> savePrefGluten(bool v) async => (await _p()).setBool(_k(_kPrefGluten), v);
  static Future<void> savePrefDairy(bool v)  async => (await _p()).setBool(_k(_kPrefDairy), v);
  static Future<void> savePrefHiPro(bool v)  async => (await _p()).setBool(_k(_kPrefHiPro), v);
  static Future<void> saveGoal(String v)     async => (await _p()).setString(_k(_kGoal), v);

  // ── WRITE — notifications ─────────────────────────────────────────────────
  static Future<void> saveNotifCal(bool v) async => (await _p()).setBool(_k(_kNotifCal), v);

  // ── WRITE — stats ─────────────────────────────────────────────────────────
  static Future<void> incrementRecipeCount() async {
    final p = await _p();
    p.setInt(_k(_kRecipeCount), (p.getInt(_k(_kRecipeCount)) ?? 0) + 1);
  }

  static Future<void> incrementSessionsWeek() async {
    final p = await _p();
    p.setInt(_k(_kSessionsWeek), (p.getInt(_k(_kSessionsWeek)) ?? 0) + 1);
  }

  static Future<void> setStreak(int v) async => (await _p()).setInt(_k(_kStreak), v);

  static Future<int> getStreak() async =>
      (await _p()).getInt(_k(_kStreak)) ?? 0;

  static const _kLastCookDate = 'last_cook_date';

  /// Increments streak if user hasn't cooked today yet.
  /// Resets to 1 if last cook was not yesterday.
  static Future<void> incrementStreak() async {
    final p = await _p();
    final today = _todayString();
    final lastCook = p.getString(_k(_kLastCookDate)) ?? '';
    if (lastCook == today) return; // already cooked today, no change
    final yesterday = () {
      final d = DateTime.now().subtract(const Duration(days: 1));
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }();
    final current = p.getInt(_k(_kStreak)) ?? 0;
    final newStreak = (lastCook == yesterday) ? current + 1 : 1;
    await p.setInt(_k(_kStreak), newStreak);
    await p.setString(_k(_kLastCookDate), today);
  }

  // ── WRITE — streak milestones ─────────────────────────────────────────────
  static Future<bool> hasSeenStreakMilestone(int n) async =>
      (await _p()).getBool(_k('streak_milestone_$n')) ?? false;

  static Future<void> markStreakMilestoneSeen(int n) async =>
      (await _p()).setBool(_k('streak_milestone_$n'), true);

  // ── WRITE — last cooked name (for notifications) ──────────────────────────
  static Future<String?> getLastCookedName() async =>
      (await _p()).getString(_k('last_cooked_name'));

  static Future<void> saveLastCookedName(String name) async =>
      (await _p()).setString(_k('last_cooked_name'), name);

  // ── WRITE — onboarding ────────────────────────────────────────────────────
  /// Call on BOTH skip and save in onboarding. Replaces the calGoal == 2200 sentinel.
  static Future<void> setOnboardingDone() async =>
      (await _p()).setBool(_k(_kOnboardingDone), true);

  static Future<bool> isOnboardingDone() async =>
      (await _p()).getBool(_k(_kOnboardingDone)) ?? false;

  // ── DELETE — only clears THIS user's keys ────────────────────────────────
  static Future<void> clearAll() async {
    final p      = await _p();
    final prefix = '${_uid()}:';
    final keys   = p.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      await p.remove(k);
    }
  }

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();
}
