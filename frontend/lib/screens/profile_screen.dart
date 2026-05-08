import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
        const Expanded(
          child: Text(
            'Set your personal goals for better recommendations',
            style: TextStyle(color: AppTheme.darkText, fontSize: 12,
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
        const Text('My Profile', style: TextStyle(color: AppTheme.darkText, fontSize: 18,
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
        _statChip(label: 'Recipes', value: _statsLoaded ? '$recipes' : '—', icon: LucideIcons.chefHat),
        const SizedBox(width: 10),
        _statChip(label: 'This Week', value: _statsLoaded ? '$sessions' : '—', icon: LucideIcons.calendarDays),
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
          Text(value, style: const TextStyle(color: AppTheme.darkText,
              fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.mutedText,
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
          const Text('Daily Goals', style: TextStyle(color: AppTheme.darkText,
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
        Text(label, style: const TextStyle(color: AppTheme.darkText,
            fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$consumed / $goal $unit', style: const TextStyle(color: AppTheme.mutedText,
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
    // Derive the active set from the actual boolean flags stored by UserPrefsService
    final activePrefs = <String>{
      if ((_data['pref_veg']    as bool?) == true) 'Vegetarian',
      if ((_data['pref_hipro']  as bool?) == true) 'High-Protein',
      if ((_data['pref_gluten'] as bool?) == false) 'Gluten-Free',  // stored as pref_gluten=false means gluten-free
      if ((_data['pref_dairy']  as bool?) == false) 'Dairy-Free',   // stored as pref_dairy=false means dairy-free
    };
    const options = ['Vegetarian', 'High-Protein', 'Gluten-Free', 'Dairy-Free'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(LucideIcons.leafyGreen, color: AppTheme.primaryDark, size: 18),
          SizedBox(width: 8),
          Text('Dietary Preferences', style: TextStyle(color: AppTheme.darkText,
              fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: options.map((opt) {
          final on = activePrefs.contains(opt);
          return TapScale(
            onTap: () async {
              // Toggle the correct boolean flag
              switch (opt) {
                case 'Vegetarian':
                  await UserPrefsService.savePrefVeg(!on);
                  setState(() => _data['pref_veg'] = !on);
                case 'High-Protein':
                  await UserPrefsService.savePrefHiPro(!on);
                  setState(() => _data['pref_hipro'] = !on);
                case 'Gluten-Free':
                  // pref_gluten=false means gluten-free is ON
                  await UserPrefsService.savePrefGluten(on); // toggling: if currently on (gluten-free), turn off → set true
                  setState(() => _data['pref_gluten'] = on);
                case 'Dairy-Free':
                  await UserPrefsService.savePrefDairy(on);
                  setState(() => _data['pref_dairy'] = on);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: on ? AppTheme.primaryDark : AppTheme.cardAltBg(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? AppTheme.primaryDark : AppTheme.border(context)),
              ),
              child: Text(opt, style: TextStyle(
                color: on ? Colors.white : AppTheme.darkText,
                fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            ),
          );
        }).toList()),
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
            value: (_data['notifications'] as bool?) ?? true,
            activeColor: AppTheme.primaryDark,
            onChanged: (v) async {
              await UserPrefsService.saveNotifCal(v);
              setState(() => _data['notifications'] = v);
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
              color: danger ? const Color(0xFFD14444) : AppTheme.darkText,
              fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600))),
          trailing ?? const Icon(LucideIcons.chevronRight, color: AppTheme.mutedText, size: 16),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            const Expanded(
              child: Text('Display', style: TextStyle(
                  color: AppTheme.darkText, fontSize: 14,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            ),
            _themeSegment(label: 'Light', value: ThemeMode.light, current: mode),
            const SizedBox(width: 6),
            _themeSegment(label: 'Dark', value: ThemeMode.dark, current: mode),
            const SizedBox(width: 6),
            _themeSegment(label: 'System', value: ThemeMode.system, current: mode),
          ]),
        );
      },
    );
  }

  Widget _themeSegment({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primaryDark : AppTheme.border(context),
          ),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : AppTheme.mutedText,
          fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
        )),
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
        const Icon(LucideIcons.info, size: 14, color: AppTheme.mutedText),
        const SizedBox(width: 8),
        Text('Plately v$_appVersion',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 13,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
        const SizedBox(width: 6),
        const Text('·', style: TextStyle(color: AppTheme.mutedText, fontSize: 13)),
        const SizedBox(width: 6),
        const Text("Chishiya's Dogs",
            style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
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
                const Text('Privacy Policy', style: TextStyle(color: AppTheme.darkText,
                    fontSize: 17, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                const Spacer(),
                TapScale(onTap: () => Navigator.pop(context),
                  child: Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: AppTheme.cardAltBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border(context))),
                    child: const Icon(LucideIcons.x, size: 16, color: AppTheme.mutedText))),
              ]),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                children: const [
                  _PolicySection(
                    icon: LucideIcons.database,
                    title: 'What We Store',
                    body: 'Plately stores your Firebase UID, cooking history, macro goals, '
                        'dietary preferences, and pantry items. All data is stored locally '
                        'on your device (SharedPreferences) or in our secure database. '
                        'We do not sell or share your personal data with third parties.',
                  ),
                  SizedBox(height: 16),
                  _PolicySection(
                    icon: LucideIcons.bot,
                    title: 'AI & Data Processing',
                    body: 'Recipe generation and chat are powered by OpenRouter '
                        '(google/gemma-3-27b-it). Ingredient scan uses Gemma Vision. '
                        'Only your ingredient list and preferences are sent — no personally '
                        'identifiable information is included in AI requests.',
                  ),
                  SizedBox(height: 16),
                  _PolicySection(
                    icon: LucideIcons.shieldOff,
                    title: 'What We Don\'t Do',
                    body: 'We do not display ads. We do not sell your data. We do not '
                        'track your location. We do not share your information with '
                        'advertisers or analytics platforms.',
                  ),
                  SizedBox(height: 16),
                  _PolicySection(
                    icon: LucideIcons.mail,
                    title: 'Contact Us',
                    body: 'Questions or concerns? Reach us at marcdarylle5@gmail.com. '
                        'We respond within 3 business days.',
                  ),
                  SizedBox(height: 16),
                  Text('Last updated: May 2026',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 11,
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
              const Text('Change Password', style: TextStyle(color: AppTheme.darkText,
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
    );
  }

  Widget _pwField({required TextEditingController ctrl, required String label}) =>
    TextField(
      controller: ctrl,
      obscureText: true,
      style: const TextStyle(fontFamily: 'DM Sans', color: AppTheme.darkText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText, fontSize: 13),
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
              const Text('Edit Profile', style: TextStyle(color: AppTheme.darkText,
                  fontSize: 17, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontFamily: 'DM Sans', color: AppTheme.darkText, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: const TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText, fontSize: 13),
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
                  const Icon(LucideIcons.mail, color: AppTheme.mutedText, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    (_data['email'] as String?) ?? '',
                    style: const TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans'),
                  )),
                  const Text('(read-only)', style: TextStyle(color: AppTheme.mutedText,
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
        Text(title, style: const TextStyle(color: AppTheme.darkText,
            fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      Text(body, style: const TextStyle(color: AppTheme.mutedText,
          fontSize: 13, fontFamily: 'DM Sans', height: 1.6)),
    ]);
  }
}
