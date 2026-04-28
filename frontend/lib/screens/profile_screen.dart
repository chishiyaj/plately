import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../services/user_prefs_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await UserPrefsService.load();
    if (mounted) setState(() { _data = d; _loading = false; });
  }

  String get _name  => _data['name']  ?? 'Plately User';
  String get _email => _data['email'] ?? '';
  int get _calGoal      => _data['cal_goal']     ?? 2200;
  int get _proteinGoal  => _data['protein_goal'] ?? 120;
  int get _calConsumed  => _data['cal_consumed'] ?? 0;
  int get _recipeCount  => _data['recipe_count'] ?? 0;
  int get _streakDays   => _data['streak_days']  ?? 0;
  int get _proteinAvg   => _data['protein_avg']  ?? 0;
  bool get _notifCal    => _data['notif_calorie'] ?? true;
  bool get _prefVeg     => _data['pref_veg']    ?? false;
  bool get _prefGluten  => _data['pref_gluten'] ?? false;
  bool get _prefDairy   => _data['pref_dairy']  ?? false;
  bool get _prefHiPro   => _data['pref_hi_pro'] ?? true;

  String get _initials {
    final parts = _name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  // Scan is handled by MainShell's FAB — no action needed here

  // ── EDIT PROFILE BOTTOM SHEET ─────────────────────────────────────────────
  void _showEditProfile() {
    final nameCtrl  = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Edit Profile',
        icon: LucideIcons.userPen,
        children: [
          _SheetField(ctrl: nameCtrl,  label: 'Display name', icon: LucideIcons.user),
          const SizedBox(height: 12),
          _SheetField(ctrl: emailCtrl, label: 'Email address', icon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 24),
          _SheetBtn(
            label: 'Save Changes',
            onTap: () async {
              await UserPrefsService.setName(nameCtrl.text.trim());
              await UserPrefsService.setEmail(emailCtrl.text.trim());
              if (mounted) { Navigator.pop(context); _load(); }
            },
          ),
        ],
      ),
    );
  }

  // ── EDIT GOALS BOTTOM SHEET ───────────────────────────────────────────────
  void _showEditGoals() {
    final calCtrl  = TextEditingController(text: _calGoal.toString());
    final proCtrl  = TextEditingController(text: _proteinGoal.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Daily Goals',
        icon: LucideIcons.target,
        children: [
          _SheetField(ctrl: calCtrl, label: 'Calorie goal (kcal)', icon: LucideIcons.flame,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 12),
          _SheetField(ctrl: proCtrl, label: 'Protein goal (g)', icon: LucideIcons.dumbbell,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 8),
          Text('Based on Mifflin-St Jeor for your profile.',
              style: AppTheme.bodySmall.copyWith(fontSize: 12)),
          const SizedBox(height: 24),
          _SheetBtn(
            label: 'Save Goals',
            onTap: () async {
              final cal = int.tryParse(calCtrl.text) ?? _calGoal;
              final pro = int.tryParse(proCtrl.text) ?? _proteinGoal;
              await UserPrefsService.setGoals(calGoal: cal, proteinGoal: pro);
              if (mounted) { Navigator.pop(context); _load(); }
            },
          ),
        ],
      ),
    );
  }

  // ── LOG CALORIES BOTTOM SHEET ─────────────────────────────────────────────
  void _showLogCalories() {
    final calCtrl = TextEditingController(text: _calConsumed.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Log Today\'s Calories',
        icon: LucideIcons.clipboardList,
        children: [
          _SheetField(ctrl: calCtrl, label: 'Calories consumed today (kcal)', icon: LucideIcons.flame,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 4),
          Text('Current: $_calConsumed / $_calGoal kcal', style: AppTheme.bodySmall.copyWith(fontSize: 12)),
          const SizedBox(height: 24),
          _SheetBtn(
            label: 'Update',
            onTap: () async {
              final cal = int.tryParse(calCtrl.text) ?? _calConsumed;
              await UserPrefsService.setCalConsumed(cal);
              if (mounted) { Navigator.pop(context); _load(); }
            },
          ),
        ],
      ),
    );
  }

  // ── CHANGE PASSWORD ───────────────────────────────────────────────────────
  void _showChangePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final conCtrl = TextEditingController();
    bool obs1 = true, obs2 = true, obs3 = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => _BottomSheet(
        title: 'Change Password',
        icon: LucideIcons.lockKeyhole,
        children: [
          _SheetField(ctrl: oldCtrl, label: 'Current password', icon: LucideIcons.lock,
              obscure: obs1, suffixIcon: IconButton(
                icon: Icon(obs1 ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: AppTheme.mutedText),
                onPressed: () => setS(() => obs1 = !obs1),
              )),
          const SizedBox(height: 12),
          _SheetField(ctrl: newCtrl, label: 'New password', icon: LucideIcons.lockOpen,
              obscure: obs2, suffixIcon: IconButton(
                icon: Icon(obs2 ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: AppTheme.mutedText),
                onPressed: () => setS(() => obs2 = !obs2),
              )),
          const SizedBox(height: 12),
          _SheetField(ctrl: conCtrl, label: 'Confirm new password', icon: LucideIcons.shieldCheck,
              obscure: obs3, suffixIcon: IconButton(
                icon: Icon(obs3 ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: AppTheme.mutedText),
                onPressed: () => setS(() => obs3 = !obs3),
              )),
          const SizedBox(height: 24),
          _SheetBtn(
            label: 'Update Password',
            onTap: () {
              if (newCtrl.text != conCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Passwords do not match', style: TextStyle(fontFamily: 'DM Sans')),
                  backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Password updated successfully', style: TextStyle(fontFamily: 'DM Sans')),
                backgroundColor: AppTheme.green, behavior: SnackBarBehavior.floating,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ));
            },
          ),
        ],
      )),
    );
  }

  // ── HELP & SUPPORT ────────────────────────────────────────────────────────
  void _showHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Help & Support',
        icon: LucideIcons.info,
        children: const [
          _FaqItem(q: 'How does ingredient scanning work?',
              a: 'Point your camera at any ingredients on your table or in your fridge. The AI identifies them automatically using Google Vision.'),
          _FaqItem(q: 'Why is my calorie goal wrong?',
              a: 'Tap "Daily Goals" in your profile to manually set your calorie and protein targets to match your specific needs.'),
          _FaqItem(q: 'Can I use Plately offline?',
              a: 'Browsing saved favorites works offline. Scanning, AI chat, and recipe generation require an internet connection.'),
          _FaqItem(q: 'How do I reset all my data?',
              a: 'Go to Settings > Clear App Data on your Android device, or uninstall and reinstall the app.'),
          _FaqItem(q: 'How do I contact support?',
              a: 'Email us at support@plately.app — we typically respond within 24 hours on weekdays.'),
        ],
      ),
    );
  }

  // ── NOTIFICATIONS TOGGLE ──────────────────────────────────────────────────
  Future<void> _toggleNotif(bool val) async {
    await UserPrefsService.setNotifCalorie(val);
    _load();
  }

  // ── DIETARY PREFS ─────────────────────────────────────────────────────────
  Future<void> _togglePref(String key, bool val) async {
    await UserPrefsService.setPref(key, val);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.creamBg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryDark)),
      );
    }

    final calPct = (_calGoal > 0 ? _calConsumed / _calGoal : 0.0).clamp(0.0, 1.0);
    final proPct = (_proteinGoal > 0 ? _proteinAvg / _proteinGoal : 0.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      extendBody: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildStats(),
          const SizedBox(height: 16),
          _buildProgressCard(calPct, proPct),
          const SizedBox(height: 16),
          _buildDietaryPrefs(),
          const SizedBox(height: 16),
          _buildSettingsSection(),
        ]),
      ),
      bottomNavigationBar: null, // MainShell owns the nav
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.tealGradient,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(children: [
            Row(children: [
              const Spacer(),
              TapScale(
                onTap: _showEditProfile,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.pencil, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: Center(
                child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            Text(_name, style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_email, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontFamily: 'DM Sans')),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── STATS ROW ──────────────────────────────────────────────────────────────
  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _StatBox(value: '$_recipeCount', label: 'Recipes\nCooked', icon: LucideIcons.chefHat, color: AppTheme.green),
        const SizedBox(width: 12),
        _StatBox(value: '${_streakDays}d', label: 'Current\nStreak', icon: LucideIcons.flame, color: AppTheme.orange),
        const SizedBox(width: 12),
        _StatBox(value: '${_proteinAvg}g', label: 'Avg Daily\nProtein', icon: LucideIcons.dumbbell, color: AppTheme.purple),
      ]),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.06);
  }

  // ── PROGRESS CARD ──────────────────────────────────────────────────────────
  Widget _buildProgressCard(double calPct, double proPct) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(LucideIcons.target, size: 18, color: AppTheme.primaryDark),
            const SizedBox(width: 8),
            const Text('Today\'s Progress', style: TextStyle(color: AppTheme.darkText, fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
            const Spacer(),
            TapScale(
              onTap: _showEditGoals,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.settings2, size: 12, color: AppTheme.primaryDark),
                  SizedBox(width: 4),
                  Text('Goals', style: TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          _ProgressRow(
            label: 'Calories',
            current: _calConsumed,
            goal: _calGoal,
            unit: 'kcal',
            pct: calPct,
            color: AppTheme.orange,
            onTap: _showLogCalories,
          ),
          const SizedBox(height: 14),
          _ProgressRow(
            label: 'Protein',
            current: _proteinAvg,
            goal: _proteinGoal,
            unit: 'g',
            pct: proPct,
            color: AppTheme.green,
            onTap: _showEditGoals,
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.06);
  }

  // ── DIETARY PREFS ──────────────────────────────────────────────────────────
  Widget _buildDietaryPrefs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(LucideIcons.leaf, size: 18, color: AppTheme.green),
            SizedBox(width: 8),
            Text('Dietary Preferences', style: TextStyle(color: AppTheme.darkText, fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text('These filter your recipe suggestions.', style: AppTheme.bodySmall.copyWith(fontSize: 12)),
          const SizedBox(height: 14),
          _PrefToggle(label: 'Vegetarian',    value: _prefVeg,    color: AppTheme.green,  onChanged: (v) => _togglePref('pref_veg', v)),
          _PrefToggle(label: 'Gluten-Free',   value: _prefGluten, color: AppTheme.orange, onChanged: (v) => _togglePref('pref_gluten', v)),
          _PrefToggle(label: 'Dairy-Free',    value: _prefDairy,  color: AppTheme.yellow, onChanged: (v) => _togglePref('pref_dairy', v)),
          _PrefToggle(label: 'High-Protein',  value: _prefHiPro,  color: AppTheme.purple, onChanged: (v) => _togglePref('pref_hi_pro', v), isLast: true),
        ]),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.06);
  }

  // ── SETTINGS SECTION ───────────────────────────────────────────────────────
  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Column(children: [
          _SettingRow(
            icon: LucideIcons.bell,
            label: 'Calorie Notifications',
            color: AppTheme.orange,
            trailing: Switch(
              value: _notifCal,
              onChanged: _toggleNotif,
              activeColor: AppTheme.primaryDark,
            ),
          ),
          _SettingRow(
            icon: LucideIcons.lockKeyhole,
            label: 'Change Password',
            color: AppTheme.primaryDark,
            onTap: _showChangePassword,
          ),
          _SettingRow(
            icon: LucideIcons.info,
            label: 'Help & Support',
            color: AppTheme.purple,
            onTap: _showHelp,
          ),
          _SettingRow(
            icon: LucideIcons.logOut,
            label: 'Sign Out',
            color: AppTheme.red,
            isLast: true,
            isDestructive: true,
            onTap: () {
              showDialog(context: context, builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Sign out?', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700, color: AppTheme.darkText)),
                content: const Text('You\'ll need to log in again to access Plately.', style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText, fontSize: 14)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.mutedText)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context, AppTheme.crossFade(const LoginScreen()), (_) => false),
                    child: const Text('Sign Out', style: TextStyle(fontFamily: 'DM Sans', color: AppTheme.red, fontWeight: FontWeight.w700)),
                  ),
                ],
              ));
            },
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.06);
  }
}

// ─── REUSABLE SUB-WIDGETS ─────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatBox({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans', height: 1.3)),
      ]),
    ),
  );
}

class _ProgressRow extends StatelessWidget {
  final String label, unit;
  final int current, goal;
  final double pct;
  final Color color;
  final VoidCallback onTap;
  const _ProgressRow({required this.label, required this.current, required this.goal, required this.unit, required this.pct, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text(label, style: const TextStyle(color: AppTheme.darkText, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
      const Spacer(),
      TapScale(
        onTap: onTap,
        child: Text('$current / $goal $unit', style: TextStyle(color: color, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
      ),
    ]),
    const SizedBox(height: 8),
    ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: 8,
        backgroundColor: AppTheme.lightGray,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    ),
  ]);
}

class _PrefToggle extends StatelessWidget {
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  final bool isLast;
  const _PrefToggle({required this.label, required this.value, required this.color, required this.onChanged, this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: AppTheme.darkText, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
      const Spacer(),
      Switch(value: value, onChanged: onChanged, activeColor: color),
    ]),
    if (!isLast) const Divider(height: 1, color: Color(0xFFF0EEE9)),
  ]);
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast, isDestructive;
  const _SettingRow({required this.icon, required this.label, required this.color, this.trailing, this.onTap, this.isLast = false, this.isDestructive = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    TapScale(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(
            color: isDestructive ? AppTheme.red : AppTheme.darkText,
            fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
          )),
          const Spacer(),
          trailing ?? (onTap != null
              ? Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.mutedText)
              : const SizedBox.shrink()),
        ]),
      ),
    ),
    if (!isLast) const Divider(height: 1, thickness: 1, color: Color(0xFFF5F3EF), indent: 20, endIndent: 20),
  ]);
}

// ── BOTTOM SHEET SHELL ────────────────────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _BottomSheet({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: AppTheme.darkText, fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 24),
        ...children,
      ]),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final bool obscure;
  final Widget? suffixIcon;
  const _SheetField({required this.ctrl, required this.label, required this.icon,
    this.keyboardType = TextInputType.text, this.inputFormatters = const [],
    this.obscure = false, this.suffixIcon});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(14)),
    child: TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.darkText, fontSize: 14, fontFamily: 'DM Sans'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.bodySmall,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryDark),
        suffixIcon: suffixIcon,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );
}

class _SheetBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SheetBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => TapScale(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(14)),
      child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
    ),
  );
}

class _FaqItem extends StatefulWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});
  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Column(children: [
    TapScale(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Text(widget.q, style: const TextStyle(color: AppTheme.darkText, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Icon(_open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16, color: AppTheme.mutedText),
        ]),
      ),
    ),
    if (_open) Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(widget.a, style: AppTheme.bodySmall.copyWith(fontSize: 13, height: 1.5)),
    ),
    const Divider(height: 1, color: Color(0xFFF0EEE9)),
  ]);
}
