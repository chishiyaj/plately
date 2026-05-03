import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../services/user_prefs_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

// ── Input formatter: digits only, no spaces, no letters ──────────────────────
class _DigitsOnly extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue newVal) {
    final digits = newVal.text.replaceAll(RegExp(r'[^0-9]'), '');
    return newVal.copyWith(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _data = {};
  bool _loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final d = await UserPrefsService.load();
    if (mounted) setState(() { _data = d; _loaded = true; });
  }

  String get _initials {
    final parts = (_data['name'] as String? ?? 'P U').trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primaryDark)),
    );
    }
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
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
              const SizedBox(height: 14),
              _goalsCard().animate().fadeIn(delay: 120.ms, duration: 350.ms),
              const SizedBox(height: 14),
              _dietaryPrefs().animate().fadeIn(delay: 180.ms, duration: 350.ms),
              const SizedBox(height: 14),
              _settingsSection().animate().fadeIn(delay: 240.ms, duration: 350.ms),
              const SizedBox(height: 14),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _header() {
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(children: [
        if (canPop)
          TapScale(
            onTap: () => Navigator.pop(context),
            child: Container(width: 42, height: 42,
              decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGray)),
              child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18)),
          )
        else
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderGray)),
            child: const Icon(LucideIcons.circleUser, color: AppTheme.primaryDark, size: 20)),
        const SizedBox(width: 12),
        const Text('My Profile', style: TextStyle(color: AppTheme.darkText, fontSize: 18,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        const Spacer(),
        TapScale(onTap: _showEditProfile,
          child: Container(width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderGray)),
            child: const Icon(LucideIcons.penLine, color: AppTheme.primaryDark, size: 18)),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }

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
        Text((_data['name'] as String?) ?? 'User', style: const TextStyle(color: Colors.white, fontSize: 18,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
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

  Widget _statsRow() {
    final count    = (_data['recipe_count']  as int?) ?? 0;
    final streak   = (_data['streak']        as int?) ?? 0;
    final sessions = (_data['sessions_week'] as int?) ?? 0;
    final stats  = [
      {'label': 'Cooked',   'value': '$count',      'icon': LucideIcons.utensils,    'color': AppTheme.scanGreen},
      {'label': 'Streak',   'value': '${streak}d',  'icon': LucideIcons.flame,       'color': AppTheme.browseYellow},
      {'label': 'This Week','value': '$sessions',   'icon': LucideIcons.calendarDays,'color': AppTheme.typeBlue},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: stats.asMap().entries.map((e) {
        final s = e.value;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderGray),
                boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))]),
            child: Column(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: s['color'] as Color, borderRadius: BorderRadius.circular(10)),
                child: Icon(s['icon'] as IconData, color: AppTheme.primaryDark, size: 17)),
              const SizedBox(height: 8),
              Text(s['value'] as String, style: const TextStyle(color: AppTheme.darkText,
                  fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
              Text(s['label'] as String, style: const TextStyle(color: AppTheme.mutedText,
                  fontSize: 10, fontFamily: 'DM Sans'), textAlign: TextAlign.center),
            ]),
          ),
        ));
      }).toList()),
    );
  }

  Widget _goalsCard() {
    final calGoal      = (_data['cal_goal']         as int?) ?? 2000;
    final protGoal     = (_data['protein_goal']     as int?) ?? 120;
    final calConsumed  = (_data['cal_consumed']     as int?) ?? 0;
    final protConsumed = (_data['protein_consumed'] as int?) ?? 0;
    final calPct  = (calConsumed  / calGoal.clamp(1, 99999)).clamp(0.0, 1.0);
    final protPct = (protConsumed / protGoal.clamp(1, 99999)).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Daily Goals', style: TextStyle(color: AppTheme.darkText, fontSize: 15,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          const Spacer(),
          TapScale(onTap: _showGoalsDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(LucideIcons.target, color: AppTheme.primaryDark, size: 13),
                SizedBox(width: 5),
                Text('Edit', style: TextStyle(color: AppTheme.primaryDark, fontSize: 12,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _GoalBar(
          label: 'Calories', consumed: calConsumed, goal: calGoal,
          unit: 'kcal', color: AppTheme.orange, pct: calPct,
          onLog: () => _showLogDialog(
            title: 'Log Calories',
            hint: 'Calories consumed today (kcal)',
            icon: LucideIcons.flame,
            current: calConsumed,
            onSave: (v) async {
              await UserPrefsService.saveCalConsumed(v);
              setState(() => _data['cal_consumed'] = v);
            },
          ),
        ),
        const SizedBox(height: 16),
        _GoalBar(
          label: 'Protein', consumed: protConsumed, goal: protGoal,
          unit: 'g', color: AppTheme.green, pct: protPct,
          onLog: () => _showLogDialog(
            title: 'Log Protein',
            hint: 'Protein consumed today (g)',
            icon: LucideIcons.dumbbell,
            current: protConsumed,
            onSave: (v) async {
              await UserPrefsService.saveProteinConsumed(v);
              setState(() => _data['protein_consumed'] = v);
            },
          ),
        ),
      ]),
    );
  }

  Widget _dietaryPrefs() {
    final prefs = [
      {'key': 'pref_veg',    'label': 'Vegetarian',   'icon': LucideIcons.leaf,     'fn': UserPrefsService.savePrefVeg},
      {'key': 'pref_gluten', 'label': 'Gluten-Free',  'icon': LucideIcons.wheatOff, 'fn': UserPrefsService.savePrefGluten},
      {'key': 'pref_dairy',  'label': 'Dairy-Free',   'icon': LucideIcons.milkOff,  'fn': UserPrefsService.savePrefDairy},
      {'key': 'pref_hipro',  'label': 'High Protein', 'icon': LucideIcons.dumbbell, 'fn': UserPrefsService.savePrefHiPro},
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dietary Preferences', style: TextStyle(color: AppTheme.darkText, fontSize: 15,
            fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        ...prefs.map((p) {
          final val = (_data[p['key'] as String] as bool?) ?? false;
          return _PrefRow(
            label: p['label'] as String, icon: p['icon'] as IconData, value: val,
            onChanged: (v) async {
              await (p['fn'] as Function(bool))(v);
              setState(() => _data[p['key'] as String] = v);
            },
          );
        }),
      ]),
    );
  }

  Widget _settingsSection() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderGray),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))]),
    child: Column(children: [
      _Tile(icon: LucideIcons.bell,   label: 'Calorie Notifications',
        trailing: Switch(
          value: (_data['notif_cal'] as bool?) ?? true,
          onChanged: (v) async {
            await UserPrefsService.saveNotifCal(v);
            setState(() => _data['notif_cal'] = v);
            if (v) {
              await NotificationService.enableMealReminders();
            } else {
              await NotificationService.disableMealReminders();
            }
          },
          activeColor: AppTheme.primaryDark, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () {},
      ),
      _Tile(icon: LucideIcons.lockKeyhole, label: 'Change Password', onTap: _showChangePassword),
      _Tile(icon: LucideIcons.messageCircle, label: 'Help & Support', onTap: _showHelp),
      _Tile(icon: LucideIcons.logOut, label: 'Log Out', textColor: AppTheme.red, showDivider: false,
        onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Out', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w800, color: AppTheme.darkText)),
          content: const Text('Are you sure you want to log out?', style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText))),
            TextButton(onPressed: () async {
              Navigator.pop(context); // close dialog
              await AuthService.signOut(); // sign out Firebase + Google
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  AppTheme.fadeScale(const LoginScreen()), (_) => false);
              }
            }, child: const Text('Log Out', style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.red, fontWeight: FontWeight.w700))),
          ],
        )),
      ),
    ]),
  );

  // ── LOG CALORIES / PROTEIN DIALOG ─────────────────────────────────────────
  // Called from GoalBar "Log" button — lets user set today's consumed amount.
  // Protein and calories are tracked independently (user may eat outside Plately).
  void _showLogDialog({
    required String title,
    required String hint,
    required IconData icon,
    required int current,
    required Future<void> Function(int) onSave,
  }) {
    final ctrl = TextEditingController(text: current > 0 ? '$current' : '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, _) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(color: AppTheme.darkText, fontSize: 20,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Enter your total for today. You can update this anytime.',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
            const SizedBox(height: 20),
            _SheetField(ctrl: ctrl, hint: hint, icon: icon, keyboard: TextInputType.number,
                formatters: [_DigitsOnly(), LengthLimitingTextInputFormatter(5)]),
            const SizedBox(height: 24),
            TapScale(onTap: () async {
              final nav = Navigator.of(ctx);
              final val = int.tryParse(ctrl.text.trim()) ?? current;
              await onSave(val);
              nav.pop();
            }, child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x33043B3C), blurRadius: 14, offset: Offset(0, 4))]),
              child: const Center(child: Text('Save', style: TextStyle(color: Colors.white,
                  fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
            )),
          ]),
        )),
      )),
    );
  }

  // ── EDIT PROFILE SHEET ─────────────────────────────────────────────────────
  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: (_data['name'] as String?) ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, _) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Edit Profile', style: TextStyle(color: AppTheme.darkText, fontSize: 20,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _SheetField(ctrl: nameCtrl,  hint: 'Full name',     icon: LucideIcons.user),
            const SizedBox(height: 12),
            // Email shown read-only — tied to Google/auth account
            _ReadOnlyField(value: (_data['email'] as String?) ?? '', icon: LucideIcons.mail),
            const SizedBox(height: 24),
            TapScale(onTap: () async {
              final nav = Navigator.of(ctx);
              await UserPrefsService.saveName(nameCtrl.text.trim());
              // email is read-only (tied to auth account) — do NOT save it
              if (mounted) {
                setState(() => _data['name'] = nameCtrl.text.trim());
                nav.pop();
              }
            }, child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x33043B3C), blurRadius: 14, offset: Offset(0, 4))]),
              child: const Center(child: Text('Save Changes', style: TextStyle(color: Colors.white,
                  fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
            )),
          ]),
        )),
      )),
    );
  }

  void _showGoalsDialog() {
    final calCtrl    = TextEditingController(text: '${_data['cal_goal']}');
    final proCtrl    = TextEditingController(text: '${_data['protein_goal']}');
    final weightCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final ageCtrl    = TextEditingController();
    String sex       = 'male';
    String goal      = 'maintain';
    bool   calcMode  = false;
    bool   calcLoading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Daily Goals', style: TextStyle(color: AppTheme.darkText, fontSize: 20,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Set manually or auto-calculate from your body stats.',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
            const SizedBox(height: 20),

            // ── Manual fields (always shown) ─────────────────────────────
            _SheetField(ctrl: calCtrl, hint: 'Daily calorie goal (kcal)',
                icon: LucideIcons.flame, keyboard: TextInputType.number,
                formatters: [_DigitsOnly(), LengthLimitingTextInputFormatter(5)]),
            const SizedBox(height: 12),
            _SheetField(ctrl: proCtrl, hint: 'Daily protein goal (g)',
                icon: LucideIcons.dumbbell, keyboard: TextInputType.number,
                formatters: [_DigitsOnly(), LengthLimitingTextInputFormatter(4)]),
            const SizedBox(height: 16),

            // ── Auto-calculate toggle ─────────────────────────────────────
            GestureDetector(
              onTap: () => setS(() => calcMode = !calcMode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: calcMode ? AppTheme.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: calcMode ? AppTheme.primaryDark : AppTheme.borderGray,
                    width: calcMode ? 0 : 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: calcMode ? Colors.white.withValues(alpha: 0.15) : AppTheme.creamBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.calculator, size: 15,
                        color: calcMode ? Colors.white : AppTheme.mutedText),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Auto-calculate', style: TextStyle(
                      fontFamily: 'DM Sans', fontSize: 13, fontWeight: FontWeight.w700,
                      color: calcMode ? Colors.white : AppTheme.darkText,
                    )),
                    Text('Mifflin-St Jeor TDEE formula', style: TextStyle(
                      fontFamily: 'DM Sans', fontSize: 11,
                      color: calcMode ? Colors.white60 : AppTheme.mutedText,
                    )),
                  ])),
                  Icon(
                    calcMode ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16, color: calcMode ? Colors.white60 : AppTheme.mutedText,
                  ),
                ]),
              ),
            ),

            // ── Body stats form (collapsible) ─────────────────────────────
            if (calcMode) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderGray),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Body Stats', style: TextStyle(color: AppTheme.darkText,
                      fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _SheetField(ctrl: weightCtrl, hint: 'Weight (kg)',
                        icon: LucideIcons.scale, keyboard: TextInputType.number,
                        formatters: [_DigitsOnly(), LengthLimitingTextInputFormatter(3)])),
                    const SizedBox(width: 10),
                    Expanded(child: _SheetField(ctrl: heightCtrl, hint: 'Height (cm)',
                        icon: LucideIcons.ruler, keyboard: TextInputType.number,
                        formatters: [_DigitsOnly(), LengthLimitingTextInputFormatter(3)])),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _SheetField(ctrl: ageCtrl, hint: 'Age',
                        icon: LucideIcons.cake, keyboard: TextInputType.number,
                        formatters: [_DigitsOnly(), LengthLimitingTextInputFormatter(3)])),
                    const SizedBox(width: 10),
                    Expanded(child: Container(
                      height: 52,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderGray)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                        value: sex,
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: AppTheme.darkText),
                        items: const [
                          DropdownMenuItem(value: 'male',   child: Text('Male')),
                          DropdownMenuItem(value: 'female', child: Text('Female')),
                        ],
                        onChanged: (v) => setS(() => sex = v!),
                      )),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  const Text('Goal', style: TextStyle(color: AppTheme.darkText,
                      fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: ['lose', 'maintain', 'gain'].map((g) {
                    final labels = {'lose': 'Lose weight', 'maintain': 'Maintain', 'gain': 'Gain weight'};
                    final colors = {'lose': AppTheme.red, 'maintain': AppTheme.primaryDark, 'gain': AppTheme.green};
                    final isSelected = goal == g;
                    return Expanded(child: Padding(
                      padding: EdgeInsets.only(right: g != 'gain' ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setS(() => goal = g),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? (colors[g]!).withValues(alpha: 0.12) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? colors[g]! : AppTheme.borderGray,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(child: Text(labels[g]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'DM Sans', fontSize: 11, fontWeight: FontWeight.w600,
                                color: isSelected ? colors[g]! : AppTheme.mutedText))),
                        ),
                      ),
                    ));
                  }).toList()),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: calcLoading ? null : () async {
                      final w = double.tryParse(weightCtrl.text.trim());
                      final h = double.tryParse(heightCtrl.text.trim());
                      final a = int.tryParse(ageCtrl.text.trim());

                      // Range validation
                      String? error;
                      if (w == null || h == null || a == null) {
                        error = 'Fill in all body stats fields.';
                      } else if (w < 20 || w > 300) {
                        error = 'Weight must be between 20–300 kg.';
                      } else if (h < 100 || h > 250) {
                        error = 'Height must be between 100–250 cm.';
                      } else if (a < 10 || a > 100) {
                        error = 'Age must be between 10–100.';
                      }
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(error, style: const TextStyle(fontFamily: 'DM Sans')),
                          backgroundColor: AppTheme.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        ));
                        return;
                      }
                      setS(() => calcLoading = true);
                      final result = await ApiService.setGoals(
                        weight: w!, height: h!, age: a!, goal: goal, sex: sex,
                      );
                      if (!ctx.mounted) { setS(() => calcLoading = false); return; }
                      if (result != null) {
                        calCtrl.text = '${result['calorie_target']}';
                        proCtrl.text = '${result['protein_target']}';
                      }
                      setS(() => calcLoading = false);
                    },
                    child: Container(
                      width: double.infinity, height: 48,
                      decoration: BoxDecoration(
                        gradient: calcLoading ? null : AppTheme.tealGradient,
                        color: calcLoading ? AppTheme.borderGray : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: calcLoading ? [] : const [
                          BoxShadow(color: Color(0x33043B3C), blurRadius: 12, offset: Offset(0, 4))
                        ],
                      ),
                      child: Center(child: calcLoading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LucideIcons.zap, size: 15, color: Colors.white),
                            SizedBox(width: 7),
                            Text('Calculate My Targets', style: TextStyle(fontFamily: 'DM Sans',
                                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 20),
            TapScale(onTap: () async {
              final nav = Navigator.of(ctx);
              final cal = int.tryParse(calCtrl.text.trim()) ?? (_data['cal_goal'] as int? ?? 2000);
              final pro = int.tryParse(proCtrl.text.trim()) ?? (_data['protein_goal'] as int? ?? 120);
              await UserPrefsService.saveCalGoal(cal);
              await UserPrefsService.saveProteinGoal(pro);
              await UserPrefsService.saveGoal(goal);
              if (!ctx.mounted) return; // BUG #8 fix — guard after async
              if (mounted) {
                setState(() { _data['cal_goal'] = cal; _data['protein_goal'] = pro; _data['goal'] = goal; });
              }
              nav.pop();
            }, child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x33043B3C), blurRadius: 14, offset: Offset(0, 4))]),
              child: const Center(child: Text('Save Goals', style: TextStyle(color: Colors.white,
                  fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
            )),
          ]),
        )),
      )),
    );
  }

  // ── CHANGE PASSWORD SHEET ──────────────────────────────────────────────────
  // Re-authenticates the user with their current password, then updates to new.
  // Firebase requires recent auth before sensitive operations — this is correct.
  void _showChangePassword() {
    // Block Google Sign-In users — they can't change their password here
    final user = FirebaseAuth.instance.currentUser;
    final isGoogle = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    if (isGoogle) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Your account uses Google Sign-In. To change your password, visit myaccount.google.com',
            style: TextStyle(fontFamily: 'DM Sans')),
        backgroundColor: AppTheme.primaryDark, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        duration: const Duration(seconds: 4),
      ));
      return;
    }
    final currCtrl = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    bool showCurr = false, showNew = false, showConf = false;
    bool loading = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Change Password', style: TextStyle(color: AppTheme.darkText, fontSize: 20,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Enter your current password to verify, then set a new one.',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans')),
            const SizedBox(height: 20),
            _SheetField(ctrl: currCtrl, hint: 'Current password', icon: LucideIcons.lockKeyhole,
                obscure: !showCurr, suffix: _EyeBtn(show: showCurr, onTap: () => setS(() => showCurr = !showCurr))),
            const SizedBox(height: 12),
            _SheetField(ctrl: newCtrl, hint: 'New password (min. 6 chars)', icon: LucideIcons.lockKeyhole,
                obscure: !showNew, suffix: _EyeBtn(show: showNew, onTap: () => setS(() => showNew = !showNew))),
            const SizedBox(height: 12),
            _SheetField(ctrl: confCtrl, hint: 'Confirm new password', icon: LucideIcons.lockKeyhole,
                obscure: !showConf, suffix: _EyeBtn(show: showConf, onTap: () => setS(() => showConf = !showConf))),
            const SizedBox(height: 24),
            TapScale(onTap: loading ? null : () async {
              // Client-side validation
              if (currCtrl.text.isEmpty || newCtrl.text.isEmpty || confCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Fill in all fields.', style: TextStyle(fontFamily: 'DM Sans')),
                  backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                ));
                return;
              }
              if (newCtrl.text != confCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text("Passwords don't match.", style: TextStyle(fontFamily: 'DM Sans')),
                  backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                ));
                return;
              }
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('New password must be at least 6 characters.', style: TextStyle(fontFamily: 'DM Sans')),
                  backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                ));
                return;
              }
              setS(() => loading = true);
              final email = (_data['email'] as String?) ?? '';
              // Capture messenger + nav before async gap
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              final result = await AuthService.changePassword(
                email: email,
                currentPassword: currCtrl.text,
                newPassword: newCtrl.text,
              );
              if (!mounted) return;
              setS(() => loading = false);
              if (result.success) {
                nav.pop();
                messenger.showSnackBar(SnackBar(
                  content: const Text('Password updated successfully.', style: TextStyle(fontFamily: 'DM Sans')),
                  backgroundColor: AppTheme.green, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ));
              } else {
                messenger.showSnackBar(SnackBar(
                  content: Text(result.error ?? 'Failed to update password.', style: const TextStyle(fontFamily: 'DM Sans')),
                  backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                ));
              }
            }, child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(
                gradient: loading ? null : AppTheme.tealGradient,
                color: loading ? AppTheme.borderGray : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Update Password', style: TextStyle(color: Colors.white,
                    fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
            )),
          ]),
        )),
      )),
    );
  }

  // ── HELP & SUPPORT SHEET ───────────────────────────────────────────────────
  void _showHelp() {
    final faqs = [
      ('How does scanning work?', 'Tap the Scan FAB → point camera at ingredients → AI identifies them. Add or remove detected items before generating recipes.'),
      ('Why are my recipes not showing?', 'Make sure the backend server is running on your machine and that your device is on the same network. Check the README for setup steps.'),
      ('Can I add my own recipes?', 'Not in this version — the MVP uses a seeded database. Recipe submission is planned for V3.'),
      ('How are calories calculated?', 'Calories and macros are pulled from the database per recipe. Your daily goal uses the Mifflin-St Jeor TDEE formula.'),
      ('How do I reset my data?', 'Go to Profile → scroll down → tap Log Out. Your preferences and goals reset when you clear app data from device settings.'),
    ];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(24, 12, 24, 36), children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Row(children: [
              Icon(LucideIcons.messageCircle, color: AppTheme.primaryDark, size: 22),
              SizedBox(width: 10),
              Text('Help & Support', style: TextStyle(color: AppTheme.darkText, fontSize: 20,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            const Text('Frequently asked questions', style: TextStyle(color: AppTheme.mutedText,
                fontSize: 13, fontFamily: 'DM Sans')),
            const SizedBox(height: 20),
            ...faqs.map((f) => _FaqTile(q: f.$1, a: f.$2)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(18)),
              child: const Row(children: [
                Icon(LucideIcons.mail, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Contact us', style: TextStyle(color: Colors.white, fontSize: 14,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  Text('plately@umak.edu.ph', style: TextStyle(color: Colors.white70,
                      fontSize: 12, fontFamily: 'DM Sans')),
                ])),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _GoalBar extends StatelessWidget {
  final String label, unit;
  final int consumed, goal;
  final Color color;
  final double pct;
  final VoidCallback onLog; // tap to manually log today's intake
  const _GoalBar({required this.label, required this.consumed, required this.goal,
      required this.unit, required this.color, required this.pct, required this.onLog});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text(label, style: const TextStyle(color: AppTheme.darkText, fontSize: 13,
          fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
      const Spacer(),
      TapScale(
        onTap: onLog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.pencil, size: 10, color: color),
            const SizedBox(width: 4),
            Text('$consumed / $goal $unit', style: TextStyle(
              color: color, fontSize: 11,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
            )),
          ]),
        ),
      ),
    ]),
    const SizedBox(height: 8),
    TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: pct), duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Stack(children: [
        Container(height: 11,
            decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(8))),
        FractionallySizedBox(widthFactor: v, child: Container(height: 11,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(8),
            ))),
      ]),
    ),
    const SizedBox(height: 5),
    Row(children: [
      Text('${(pct * 100).toStringAsFixed(0)}% of goal',
          style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans')),
      const Spacer(),
      Text('${(goal - consumed).clamp(0, 99999)} $unit remaining',
          style: TextStyle(color: consumed >= goal ? AppTheme.green : AppTheme.primaryDark,
              fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
    ]),
  ]);
}

class _PrefRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefRow({required this.label, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: value ? AppTheme.primaryDark.withValues(alpha: 0.08) : AppTheme.creamBg,
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: value ? AppTheme.primaryDark : AppTheme.mutedText, size: 17)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(
          color: value ? AppTheme.primaryDark : AppTheme.darkText, fontSize: 14,
          fontFamily: 'DM Sans', fontWeight: value ? FontWeight.w600 : FontWeight.w400))),
      Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primaryDark,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  final bool showDivider;
  final Widget? trailing;
  const _Tile({required this.icon, required this.label, required this.onTap,
      this.textColor, this.showDivider = true, this.trailing});

  @override
  Widget build(BuildContext context) => TapScale(
    onTap: onTap,
    child: Container(
      decoration: showDivider ? const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.8))) : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
              color: (textColor ?? AppTheme.primaryDark).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: textColor ?? AppTheme.primaryDark, size: 17)),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: TextStyle(color: textColor ?? AppTheme.darkText,
            fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w500))),
        trailing ?? Icon(LucideIcons.chevronRight, color: textColor ?? AppTheme.mutedText, size: 18),
      ]),
    ),
  );
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType keyboard;
  final List<TextInputFormatter>? formatters;
  const _SheetField({required this.ctrl, required this.hint, required this.icon,
      this.obscure = false, this.suffix, this.keyboard = TextInputType.text,
      this.formatters});

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGray)),
    child: TextField(
      controller: ctrl, obscureText: obscure, keyboardType: keyboard,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 14, fontFamily: 'DM Sans', color: AppTheme.darkText),
      decoration: InputDecoration(
        hintText: hint, border: InputBorder.none,
        hintStyle: const TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans'),
        prefixIcon: Icon(icon, size: 17, color: AppTheme.mutedText),
        suffixIcon: suffix, contentPadding: const EdgeInsets.symmetric(vertical: 17),
      ),
    ),
  );
}

class _EyeBtn extends StatelessWidget {
  final bool show;
  final VoidCallback onTap;
  const _EyeBtn({required this.show, required this.onTap});

  @override
  Widget build(BuildContext context) => TapScale(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Icon(show ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: AppTheme.mutedText),
    ),
  );
}

class _ReadOnlyField extends StatelessWidget {
  final String value;
  final IconData icon;
  const _ReadOnlyField({required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    decoration: BoxDecoration(
      color: AppTheme.lightGray.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.borderGray),
    ),
    child: Row(children: [
      const SizedBox(width: 12),
      Icon(icon, size: 17, color: AppTheme.mutedText),
      const SizedBox(width: 10),
      Expanded(child: Text(value, style: const TextStyle(
        color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans',
      ))),
      const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(LucideIcons.lock, size: 13, color: AppTheme.mutedText),
      ),
    ]),
  );
}

class _FaqTile extends StatefulWidget {
  final String q, a;
  const _FaqTile({required this.q, required this.a});
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => TapScale(
    onTap: () { HapticFeedback.selectionClick(); setState(() => _open = !_open); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _open ? AppTheme.primaryDark.withValues(alpha: 0.04) : AppTheme.creamBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _open ? AppTheme.primaryDark.withValues(alpha: 0.2) : AppTheme.borderGray),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.q, style: TextStyle(
              color: _open ? AppTheme.primaryDark : AppTheme.darkText, fontSize: 13,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
          Icon(_open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              color: AppTheme.mutedText, size: 16),
        ]),
        if (_open) ...[
          const SizedBox(height: 10),
          Text(widget.a, style: const TextStyle(color: AppTheme.mutedText, fontSize: 13,
              fontFamily: 'DM Sans', height: 1.5)),
        ],
      ]),
    ),
  );
}
