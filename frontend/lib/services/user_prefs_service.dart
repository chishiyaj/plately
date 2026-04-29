import 'package:shared_preferences/shared_preferences.dart';

/// Local CRUD for user profile, goals, daily tracking, and preferences.
class UserPrefsService {
  static const _kName           = 'user_name';
  static const _kEmail          = 'user_email';
  static const _kCalGoal        = 'cal_goal';
  static const _kProteinGoal    = 'protein_goal';
  static const _kCalConsumed    = 'cal_consumed';
  static const _kProteinConsumed= 'protein_consumed'; // independent from cal
  static const _kPrefVeg        = 'pref_veg';
  static const _kPrefGluten     = 'pref_gluten';
  static const _kPrefDairy      = 'pref_dairy';
  static const _kPrefHiPro      = 'pref_hi_pro';
  static const _kNotifCal       = 'notif_calorie';
  static const _kRecipeCount    = 'recipe_count';
  static const _kStreak         = 'streak_days';
  static const _kSessionsWeek   = 'sessions_week';

  // ── READ ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> load() async {
    final p = await SharedPreferences.getInstance();
    return {
      'name':              p.getString(_kName)          ?? 'Marc Manibog',
      'email':             p.getString(_kEmail)         ?? 'marc@plately.app',
      'cal_goal':          p.getInt(_kCalGoal)          ?? 2200,
      'protein_goal':      p.getInt(_kProteinGoal)      ?? 120,
      'cal_consumed':      p.getInt(_kCalConsumed)      ?? 0,
      'protein_consumed':  p.getInt(_kProteinConsumed)  ?? 0,
      'pref_veg':          p.getBool(_kPrefVeg)         ?? false,
      'pref_gluten':       p.getBool(_kPrefGluten)      ?? false,
      'pref_dairy':        p.getBool(_kPrefDairy)       ?? false,
      'pref_hipro':        p.getBool(_kPrefHiPro)       ?? true,
      'notif_cal':         p.getBool(_kNotifCal)        ?? true,
      'recipe_count':      p.getInt(_kRecipeCount)      ?? 0,
      'streak':            p.getInt(_kStreak)           ?? 0,
      'sessions_week':     p.getInt(_kSessionsWeek)     ?? 0,
    };
  }

  // ── WRITE — profile ───────────────────────────────────────────────────────
  static Future<void> saveName(String v)  async => (await _p()).setString(_kName, v);
  static Future<void> saveEmail(String v) async => (await _p()).setString(_kEmail, v);

  // ── WRITE — goals ─────────────────────────────────────────────────────────
  static Future<void> saveCalGoal(int v)        async => (await _p()).setInt(_kCalGoal, v);
  static Future<void> saveProteinGoal(int v)    async => (await _p()).setInt(_kProteinGoal, v);

  // ── WRITE — daily tracking (independent — user logs each manually) ─────────
  static Future<void> saveCalConsumed(int v)     async => (await _p()).setInt(_kCalConsumed, v);
  static Future<void> saveProteinConsumed(int v) async => (await _p()).setInt(_kProteinConsumed, v);

  // ── WRITE — dietary prefs ─────────────────────────────────────────────────
  static Future<void> savePrefVeg(bool v)    async => (await _p()).setBool(_kPrefVeg, v);
  static Future<void> savePrefGluten(bool v) async => (await _p()).setBool(_kPrefGluten, v);
  static Future<void> savePrefDairy(bool v)  async => (await _p()).setBool(_kPrefDairy, v);
  static Future<void> savePrefHiPro(bool v)  async => (await _p()).setBool(_kPrefHiPro, v);

  // ── WRITE — notifications ─────────────────────────────────────────────────
  static Future<void> saveNotifCal(bool v) async => (await _p()).setBool(_kNotifCal, v);

  // ── WRITE — stats ─────────────────────────────────────────────────────────
  static Future<void> incrementRecipeCount() async {
    final p = await _p();
    p.setInt(_kRecipeCount, (p.getInt(_kRecipeCount) ?? 0) + 1);
  }
  static Future<void> incrementSessionsWeek() async {
    final p = await _p();
    p.setInt(_kSessionsWeek, (p.getInt(_kSessionsWeek) ?? 0) + 1);
  }
  static Future<void> setStreak(int v) async => (await _p()).setInt(_kStreak, v);

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<void> clearAll() async => (await _p()).clear();

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();
}
