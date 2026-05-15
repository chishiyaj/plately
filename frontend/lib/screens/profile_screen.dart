import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../main.dart' show themeNotifier, themeModeToString;
import '../widgets/tap_scale.dart';
import '../services/user_prefs_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'onboarding_goals_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _data = {};
  bool _loaded = false;
  bool _statsLoaded = false;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _load();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  Future<void> _load() async {
    final d = await UserPrefsService.load();
    if (mounted) setState(() { _data = d; _loaded = true; });
    try {
      final stats = await ApiService.getHistoryStats();
      if (mounted) {
        setState(() {
          _data['recipe_count']  = stats['total_recipes']      ?? _data['recipe_count'];
          _data['sessions_week'] = stats['sessions_this_week'] ?? _data['sessions_week'];
          _statsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  String get _initials {
    final parts = (_data['name'] as String? ?? 'P U').trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  bool get _goalsAreDefault {
    final cal = (_data['cal_goal'] as int?) ?? 2200;
    return cal == 2200;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg(context),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryDark)),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(children: [
              const SizedBox(height: 4),
              _avatarCard().animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),
              const SizedBox(height: 14),
              _statsRow().animate().fadeIn(delay: 60.ms, duration: 350.ms),
              if (_goalsAreDefault) ...[
                const SizedBox(height: 10),
                _goalsBanner().animate().fadeIn(delay: 80.ms, duration: 300.ms),
              ],
              const SizedBox(height: 14),
              _goalsCard().animate().fadeIn(delay: 120.ms, duration: 350.ms),
              const SizedBox(height: 14),
              _dietaryPrefs().animate().fadeIn(delay: 180.ms, duration: 350.ms),
              const SizedBox(height: 14),
              _settingsSection().animate().fadeIn(delay: 240.ms, duration: 350.ms),
              const SizedBox(height: 20),
              _versionFooter().animate().fadeIn(delay: 300.ms, duration: 350.ms),
              const SizedBox(height: 14),
            ]),
          )),
        ]),
      ),
    );
  }

  // ── Onboarding re-trigger banner ───────────────────────────────────────────
  Widget _goalsBanner() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryDark.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(LucideIcons.target, color: AppTheme.primaryDark, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Set your personal goals for better recommendations',
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        TapScale(
          onTap: () => Navigator.push(context,
              AppTheme.slideUp(const OnboardingGoalsScreen())).then((_) => _load()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: AppTheme.tealGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Set Now', style: TextStyle(color: Colors.white,
                fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ),
  );

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() {
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: AppTheme.cardBg(context),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(children: [
        if (canPop)
          TapScale(
            onTap: () => Navigator.pop(context),
            child: Container(width: 42, height: 42,
              decoration: BoxDecoration(color: AppTheme.cardAltBg(context), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context))),
              child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18)),
          )
        else
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.cardAltBg(context), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context))),
            child: const Icon(LucideIcons.circleUser, color: AppTheme.primaryDark, size: 20)),
        const SizedBox(width: 12),
        Text('My Profile', style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 18,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        const Spacer(),
        TapScale(onTap: _showEditProfile,
          child: Container(width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.cardAltBg(context), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context))),
            child: const Icon(LucideIcons.penLine, color: AppTheme.primaryDark, size: 18)),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ── Avatar card ────────────────────────────────────────────────────────────
  Widget _avatarCard() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x44043B3C), blurRadius: 20, offset: Offset(0, 8))]),
    child: Row(children: [
      TapScale(onTap: _showEditProfile,
        child: Container(width: 70, height: 70,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
          child: Center(child: Text(_initials, style: const TextStyle(color: Colors.white,
              fontSize: 26, fontFamily: 'DM Sans', fontWeight: FontWeight.w800))),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((_data['name'] as String?) ?? 'User', style: const TextStyle(color: Colors.white,
            fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text((_data['email'] as String?) ?? '', style: const TextStyle(color: Colors.white60,
            fontSize: 12, fontFamily: 'DM Sans')),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 7, height: 7,
            decoration: const BoxDecoration(color: Color(0xFF76CC4F), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('Active', style: TextStyle(color: Colors.white60,
              fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
        ]),
      ])),
    ]),
  );

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _statsRow() {
    final recipes = (_data['recipe_count'] as int?) ?? 0;
    final sessions = (_data['sessions_week'] as int?) ?? 0;
    final streak = (_data['streak'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _statChip(label: 'Recipes', value: _statsLoaded ? '$recipes' : '--', icon: LucideIcons.chefHat),
        const SizedBox(width: 10),
        _statChip(label: 'This Week', value: _statsLoaded ? '$sessions' : '--', icon: LucideIcons.calendarDays),
        const SizedBox(width: 10),
        _statChip(label: 'Streak', value: '$streak d', icon: LucideIcons.flame),
      ]),
    );
  }

  Widget _statChip({required String label, required String value, required IconData icon}) =>
    Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(children: [
          Icon(icon, color: AppTheme.primaryDark, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: AppTheme.textPrimary(context),
              fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppTheme.textMuted(context),
              fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
        ]),
      ),
    );

  // ── Goals card ─────────────────────────────────────────────────────────────
  Widget _goalsCard() {
    final cal = (_data['cal_goal'] as int?) ?? 2200;
    final protein = (_data['protein_goal'] as int?) ?? 120;
    final calConsumed = (_data['cal_consumed'] as int?) ?? 0;
    final proteinConsumed = (_data['protein_consumed'] as int?) ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(LucideIcons.target, color: AppTheme.primaryDark, size: 18),
          const SizedBox(width: 8),
          Text('Daily Goals', style: TextStyle(color: AppTheme.textPrimary(context),
              fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          const Spacer(),
          TapScale(
            onTap: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.push(context,
                AppTheme.slideUp(const OnboardingGoalsScreen())).then((_) {
              _load();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Goals updated!',
                      style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                  backgroundColor: AppTheme.primaryDark,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.2)),
              ),
              child: const Text('Edit Goals', style: TextStyle(color: AppTheme.primaryDark,
                  fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _goalBar(
          label: 'Calories',
          consumed: calConsumed,
          goal: cal,
          unit: 'kcal',
          color: const Color(0xFFEABA1C),
        ),
        const SizedBox(height: 12),
        _goalBar(
          label: 'Protein',
          consumed: proteinConsumed,
          goal: protein,
          unit: 'g',
          color: AppTheme.primaryDark,
        ),
      ]),
    );
  }

  Widget _goalBar({required String label, required int consumed, required int goal,
      required String unit, required Color color}) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(color: AppTheme.textPrimary(context),
          fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$consumed / $goal $unit', style: TextStyle(color: AppTheme.textMuted(context),
            fontSize: 11, fontFamily: 'DM Sans')),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }

  // ── Dietary prefs ──────────────────────────────────────────────────────────
  Widget _dietaryPrefs() {
    final isVeg        = (_data['pref_veg']    as bool?) == true;
    final isHiPro      = (_data['pref_hipro']  as bool?) == true;
    final isGlutenFree = (_data['pref_gluten'] as bool?) == false;
    final isDairyFree  = (_data['pref_dairy']  as bool?) == false;

    void toggle(String opt) async {
      HapticFeedback.selectionClick();
      switch (opt) {
        case 'Vegetarian':
          final next = !isVeg;
          await UserPrefsService.savePrefVeg(next);
          setState(() => _data['pref_veg'] = next);
        case 'High-Protein':
          final next = !isHiPro;
          await UserPrefsService.savePrefHiPro(next);
          setState(() => _data['pref_hipro'] = next);
        case 'Gluten-Free':
          final nextPrefVal = isGlutenFree;
          await UserPrefsService.savePrefGluten(nextPrefVal);
          setState(() => _data['pref_gluten'] = nextPrefVal);
        case 'Dairy-Free':
          final nextPrefVal = isDairyFree;
          await UserPrefsService.savePrefDairy(nextPrefVal);
          setState(() => _data['pref_dairy'] = nextPrefVal);
      }
    }

    final prefs = <(String, bool, String, IconData)>[
      ('Vegetarian',   isVeg,        'No meat or fish',                      LucideIcons.leafyGreen),
      ('High-Protein', isHiPro,      'Prioritise 30g+ protein per meal',     LucideIcons.dumbbell),
      ('Gluten-Free',  isGlutenFree, 'Exclude gluten-containing ingredients', LucideIcons.wheatOff),
      ('Dairy-Free',   isDairyFree,  'Exclude dairy products',               LucideIcons.milkOff),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: Row(children: [
            const Icon(LucideIcons.leafyGreen, color: AppTheme.primaryDark, size: 18),
            const SizedBox(width: 8),
            Text('Dietary Preferences', style: TextStyle(color: AppTheme.textPrimary(context),
                fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          ]),
        ),
        ...prefs.asMap().entries.map((e) {
          final i   = e.key;
          final opt = e.value.$1;
          final on  = e.value.$2;
          final sub = e.value.$3;
          final ico = e.value.$4;
          return Column(children: [
            if (i > 0) Divider(height: 1, color: AppTheme.border(context), indent: 18, endIndent: 18),
            TapScale(
              onTap: () => toggle(opt),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: on
                          ? AppTheme.primaryDark.withValues(alpha: 0.10)
                          : AppTheme.cardAltBg(context),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: on
                          ? AppTheme.primaryDark.withValues(alpha: 0.25)
                          : AppTheme.border(context)),
                    ),
                    child: Icon(ico,
                        size: 17,
                        color: on ? AppTheme.primaryDark : AppTheme.textMuted(context)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(opt, style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(
                      color: AppTheme.textMuted(context),
                      fontSize: 12, fontFamily: 'DM Sans')),
                  ])),
                  const SizedBox(width: 12),
                  // Animated pill toggle
                  GestureDetector(
                    onTap: () => toggle(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48, height: 26,
                      decoration: BoxDecoration(
                        color: on ? AppTheme.primaryDark : AppTheme.border(context),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 20, height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        }),
        // High Protein explanation when active
        if (isHiPro)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.14)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(LucideIcons.info, size: 13, color: AppTheme.primaryDark),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Recipes will prioritize options above your protein goal per serving.',
                  style: TextStyle(color: AppTheme.textMuted(context),
                      fontSize: 12, fontFamily: 'DM Sans', height: 1.45),
                )),
              ]),
            ),
          )
        else
          const SizedBox(height: 4),
      ]),
    );
  }

  // ── Settings section ───────────────────────────────────────────────────────
  Widget _settingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(children: [
        _themeTile(),
        _divider(),
        _settingsTile(
          icon: LucideIcons.keyRound,
          label: 'Change Password',
          onTap: _showChangePassword,
        ),
        _divider(),
        _settingsTile(
          icon: LucideIcons.shieldCheck,
          label: 'Privacy Policy',
          onTap: _showPrivacyPolicy,
        ),
        _divider(),
        _settingsTile(
          icon: LucideIcons.bell,
          label: 'Notifications',
          onTap: () {},
          trailing: Switch(
            value: (_data['notif_cal'] as bool?) ?? true,
            activeColor: AppTheme.primaryDark,
            onChanged: (v) async {
              await UserPrefsService.saveNotifCal(v);
              setState(() => _data['notif_cal'] = v);
              if (v) {
                await NotificationService.schedulePersonalized(
                  name:             (_data['name']     as String?) ?? 'chef',
                  proteinGoal:      (_data['protein_goal'] as int?) ?? 120,
                  proteinConsumed:  (_data['protein_consumed'] as int?) ?? 0,
                  streak:           (_data['streak']   as int?) ?? 0,
                  lastCookedName:   (_data['last_cooked_name'] as String?) ?? '',
                );
              } else {
                await NotificationService.disableMealReminders();
              }
            },
          ),
        ),
        _divider(),
        _settingsTile(
          icon: LucideIcons.logOut,
          label: 'Sign Out',
          danger: true,
          onTap: () async {
            await AuthService.signOut();
            if (mounted) {
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false);
            }
          },
        ),
        _divider(),
        _settingsTile(
          icon: LucideIcons.trash2,
          label: 'Delete Account',
          danger: true,
          onTap: _showDeleteAccount,
        ),
      ]),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
    Widget? trailing,
  }) {
    final color = danger ? const Color(0xFFD14444) : AppTheme.primaryDark;
    return TapScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(
              color: danger ? const Color(0xFFD14444) : AppTheme.textPrimary(context),
              fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600))),
          trailing ?? Icon(LucideIcons.chevronRight, color: AppTheme.textMuted(context), size: 16),
        ]),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: AppTheme.border(context), indent: 18, endIndent: 18);

  // ── Theme toggle tile ──────────────────────────────────────────────────────
  Widget _themeTile() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.sunMoon, color: AppTheme.primaryDark, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Display', style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            ),
            // Compact segmented control -- Light / Dark / System
            Container(
              height: 36,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.cardAltBg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _themeSegment(icon: LucideIcons.sun,     label: 'Light',  value: ThemeMode.light,  current: mode),
                _themeSegment(icon: LucideIcons.moon,    label: 'Dark',   value: ThemeMode.dark,   current: mode),
                _themeSegment(icon: LucideIcons.monitor, label: 'System', value: ThemeMode.system, current: mode),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _themeSegment({
    required IconData icon,
    required String label,
    required ThemeMode value,
    required ThemeMode current,
  }) {
    final active = current == value;
    return TapScale(
      onTap: () async {
        themeNotifier.value = value;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_theme_mode', themeModeToString(value));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13,
              color: active ? Colors.white : AppTheme.textMuted(context)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            color: active ? Colors.white : AppTheme.textMuted(context),
            fontSize: 12, fontFamily: 'DM Sans',
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }

  Widget _versionFooter() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.info, size: 14, color: AppTheme.textMuted(context)),
        const SizedBox(width: 8),
        Text('Plately v$_appVersion',
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
        const SizedBox(width: 6),
        Text('·', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13)),
        const SizedBox(width: 6),
        Text("Chishiya's Dogs",
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans')),
      ]),
    ),
  );

  // ── Privacy Policy bottom sheet ────────────────────────────────────────────
  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.shieldCheck, color: AppTheme.primaryDark, size: 18)),
                const SizedBox(width: 12),
                Text('Privacy Policy', style: TextStyle(color: AppTheme.textPrimary(context),
                    fontSize: 17, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                const Spacer(),
                TapScale(onTap: () => Navigator.pop(context),
                  child: Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: AppTheme.cardAltBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border(context))),
                    child: Icon(LucideIcons.x, size: 16, color: AppTheme.textMuted(context)))),
              ]),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                children: [
                  const _PolicySection(
                    icon: LucideIcons.database,
                    title: 'What We Store',
                    body: 'Plately stores your Firebase UID, cooking history, macro goals, '
                        'dietary preferences, and pantry items. All data is stored locally '
                        'on your device (SharedPreferences) or in our secure database. '
                        'We do not sell or share your personal data with third parties.',
                  ),
                  const SizedBox(height: 16),
                  const _PolicySection(
                    icon: LucideIcons.bot,
                    title: 'AI & Data Processing',
                    body: 'Recipe generation and chat are powered by OpenRouter '
                        '(google/gemma-3-27b-it). Ingredient scan uses Gemma Vision. '
                        'Only your ingredient list and preferences are sent -- no personally '
                        'identifiable information is included in AI requests.',
                  ),
                  const SizedBox(height: 16),
                  const _PolicySection(
                    icon: LucideIcons.shieldOff,
                    title: 'What We Don\'t Do',
                    body: 'We do not display ads. We do not sell your data. We do not '
                        'track your location. We do not share your information with '
                        'advertisers or analytics platforms.',
                  ),
                  const SizedBox(height: 16),
                  const _PolicySection(
                    icon: LucideIcons.mail,
                    title: 'Contact Us',
                    body: 'Questions or concerns? Reach us at marcdarylle5@gmail.com. '
                        'We respond within 3 business days.',
                  ),
                  const SizedBox(height: 16),
                  Text('Last updated: May 2026',
                      style: TextStyle(color: AppTheme.textMuted(context),
                          fontSize: 11,
                          fontFamily: 'DM Sans')),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Change Password bottom sheet ───────────────────────────────────────────
  void _showChangePassword() {
    final currCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.border(context),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              Text('Change Password', style: TextStyle(color: AppTheme.textPrimary(context),
                  fontSize: 17, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              _pwField(ctrl: currCtrl, label: 'Current Password'),
              const SizedBox(height: 12),
              _pwField(ctrl: newCtrl, label: 'New Password'),
              const SizedBox(height: 12),
              _pwField(ctrl: confCtrl, label: 'Confirm New Password'),
              const SizedBox(height: 20),
              TapScale(
                onTap: loading ? null : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  if (newCtrl.text != confCtrl.text) {
                    messenger.showSnackBar(const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Color(0xFFD14444),
                      behavior: SnackBarBehavior.floating,
                    ));
                    return;
                  }
                  setSt(() => loading = true);
                  try {
                    final email = (_data['email'] as String?) ?? '';
                    await AuthService.changePassword(
                      email: email,
                      currentPassword: currCtrl.text,
                      newPassword: newCtrl.text,
                    );
                    if (!mounted) return;
                    nav.pop();
                    messenger.showSnackBar(const SnackBar(
                      content: Text('Password updated!',
                          style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                      backgroundColor: AppTheme.primaryDark,
                      behavior: SnackBarBehavior.floating,
                    ));
                  } catch (e) {
                    setSt(() => loading = false);
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', ''),
                          style: const TextStyle(fontFamily: 'DM Sans')),
                      backgroundColor: const Color(0xFFD14444),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(gradient: AppTheme.tealGradient,
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(child: loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Update Password', style: TextStyle(color: Colors.white,
                        fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
                ),
              ),
            ]),
          ),
        );
      }),
    ).then((_) {
      currCtrl.dispose();
      newCtrl.dispose();
      confCtrl.dispose();
    });
  }

  Widget _pwField({required TextEditingController ctrl, required String label}) =>
    TextField(
      controller: ctrl,
      obscureText: true,
      style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.textPrimary(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'DM Sans', color: AppTheme.textMuted(context), fontSize: 13),
        filled: true,
        fillColor: AppTheme.cardAltBg(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.border(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.border(context))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryDark, width: 1.5)),
      ),
    );

  // ── Edit profile bottom sheet ──────────────────────────────────────────────
  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: (_data['name'] as String?) ?? '');
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.border(context),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              Text('Edit Profile', style: TextStyle(color: AppTheme.textPrimary(context),
                  fontSize: 17, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.textPrimary(context), fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                labelStyle: TextStyle(fontFamily: 'DM Sans', color: AppTheme.textMuted(context), fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.cardAltBg(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border(context))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border(context))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryDark, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardAltBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(children: [
                  Icon(LucideIcons.mail, color: AppTheme.textMuted(context), size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    (_data['email'] as String?) ?? '',
                    style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13, fontFamily: 'DM Sans'),
                  )),
                  Text('(read-only)', style: TextStyle(color: AppTheme.textMuted(context),
                      fontSize: 11, fontFamily: 'DM Sans')),
                ]),
              ),
              const SizedBox(height: 20),
              TapScale(
                onTap: loading ? null : () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  setSt(() => loading = true);
                  await UserPrefsService.saveName(name);
                  try {
                    await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
                  } catch (_) {}
                  if (!mounted) return;
                  setState(() => _data = {..._data, 'name': name});
                  nav.pop();
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Profile updated!',
                        style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                    backgroundColor: AppTheme.primaryDark,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(gradient: AppTheme.tealGradient,
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(child: loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white,
                        fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── Delete Account ─────────────────────────────────────────────────────────
  void _showDeleteAccount() {
    final pwCtrl = TextEditingController();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.border(context),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFD14444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.trash2, color: Color(0xFFD14444), size: 22),
              ),
              const SizedBox(height: 14),
              Text('Delete Account', style: TextStyle(color: AppTheme.textPrimary(context),
                  fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'This permanently deletes your history, favorites, and all data. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted(context),
                    fontSize: 13, fontFamily: 'DM Sans', height: 1.5),
              ),
              const SizedBox(height: 20),
              _pwField(ctrl: pwCtrl, label: 'Confirm your password'),
              const SizedBox(height: 20),
              TapScale(
                onTap: loading ? null : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  final rootNav = Navigator.of(context);
                  if (pwCtrl.text.isEmpty) {
                    messenger.showSnackBar(const SnackBar(
                      content: Text('Enter your password to confirm'),
                      backgroundColor: Color(0xFFD14444),
                      behavior: SnackBarBehavior.floating,
                    ));
                    return;
                  }
                  setSt(() => loading = true);
                  try {
                    final email = (_data['email'] as String?) ?? '';
                    await AuthService.changePassword(
                      email: email,
                      currentPassword: pwCtrl.text,
                      newPassword: pwCtrl.text,
                    );
                    await ApiService.deleteAllUserData();
                    await UserPrefsService.clearAll();
                    await FirebaseAuth.instance.currentUser?.delete();
                    if (!mounted) return;
                    nav.pop();
                    rootNav.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  } catch (e) {
                    setSt(() => loading = false);
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', ''),
                          style: const TextStyle(fontFamily: 'DM Sans')),
                      backgroundColor: const Color(0xFFD14444),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD14444),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Delete My Account', style: TextStyle(color: Colors.white,
                        fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
                ),
              ),
              const SizedBox(height: 10),
              TapScale(
                onTap: () => Navigator.pop(ctx),
                child: SizedBox(
                  width: double.infinity, height: 44,
                  child: Center(child: Text('Cancel',
                      style: TextStyle(color: AppTheme.textMuted(context),
                          fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600))),
                ),
              ),
            ]),
          ),
        );
      }),
    ).then((_) => pwCtrl.dispose());
  }
}

// ── Privacy Policy section widget ─────────────────────────────────────────────
class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PolicySection({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AppTheme.primaryDark, size: 16),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: AppTheme.textPrimary(context),
            fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      Text(body, style: TextStyle(color: AppTheme.textMuted(context),
          fontSize: 13, fontFamily: 'DM Sans', height: 1.6)),
    ]);
  }
}
