import 'package:shared_preferences/shared_preferences.dart';

/// Local CRUD for user profile, goals, and preferences.
class UserPrefsService {
  static const _kName        = 'user_name';
  static const _kEmail       = 'user_email';
  static const _kCalGoal     = 'cal_goal';
  static const _kProteinGoal = 'protein_goal';
  static const _kCalConsumed = 'cal_consumed';
  static const _kPrefVeg     = 'pref_veg';
  static const _kPrefGluten  = 'pref_gluten';
  static const _kPrefDairy   = 'pref_dairy';
  static const _kPrefHiPro   = 'pref_hi_pro';
  static const _kNotifCal    = 'notif_calorie';
  static const _kRecipeCount = 'recipe_count';
  static const _kStreak      = 'streak_days';
  static const _kProteinAvg  = 'protein_avg';

  // ── READ ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> load() async {
    final p = await SharedPreferences.getInstance();
    return {
      'name':          p.getString(_kName)     ?? 'Marc Manibog',
      'email':         p.getString(_kEmail)    ?? 'marc@plately.app',
      'cal_goal':      p.getInt(_kCalGoal)     ?? 2200,
      'protein_goal':  p.getInt(_kProteinGoal) ?? 120,
      'cal_consumed':  p.getInt(_kCalConsumed) ?? 0,
      'pref_veg':      p.getBool(_kPrefVeg)    ?? false,
      'pref_gluten':   p.getBool(_kPrefGluten) ?? false,
      'pref_dairy':    p.getBool(_kPrefDairy)  ?? false,
      'pref_hi_pro':   p.getBool(_kPrefHiPro)  ?? true,
      'notif_calorie': p.getBool(_kNotifCal)   ?? true,
      'recipe_count':  p.getInt(_kRecipeCount) ?? 0,
      'streak_days':   p.getInt(_kStreak)      ?? 0,
      'protein_avg':   p.getInt(_kProteinAvg)  ?? 0,
    };
  }

  // ── WRITE — profile ───────────────────────────────────────────────────────
  static Future<void> setName(String v)  async => (await _p()).setString(_kName, v);
  static Future<void> setEmail(String v) async => (await _p()).setString(_kEmail, v);

  // ── WRITE — goals ─────────────────────────────────────────────────────────
  static Future<void> setGoals({required int calGoal, required int proteinGoal}) async {
    final p = await _p();
    p.setInt(_kCalGoal, calGoal);
    p.setInt(_kProteinGoal, proteinGoal);
  }
  static Future<void> setCalConsumed(int v) async => (await _p()).setInt(_kCalConsumed, v);

  // ── WRITE — dietary prefs (generic key) ───────────────────────────────────
  static Future<void> setPref(String key, bool v) async => (await _p()).setBool(key, v);

  // ── WRITE — notifications ─────────────────────────────────────────────────
  static Future<void> setNotifCalorie(bool v) async => (await _p()).setBool(_kNotifCal, v);

  // ── WRITE — stats (called when user finishes a recipe) ────────────────────
  static Future<void> incrementRecipeCount() async {
    final p = await _p();
    p.setInt(_kRecipeCount, (p.getInt(_kRecipeCount) ?? 0) + 1);
  }
  static Future<void> setProteinAvg(int v)  async => (await _p()).setInt(_kProteinAvg, v);
  static Future<void> setStreak(int v)      async => (await _p()).setInt(_kStreak, v);

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<void> clearAll() async => (await _p()).clear();

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();
}
