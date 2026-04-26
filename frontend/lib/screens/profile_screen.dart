import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/tap_scale.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String _name  = 'Marco Darylle';
  final String _email = 'marcd@umak.edu.ph';
  final int _calorieGoal      = 2200;
  final int _caloriesConsumed = 1450;

  bool _vegetarian  = false;
  bool _glutenFree  = false;
  bool _dairyFree   = false;
  bool _highProtein = true;

  String get _initials {
    final parts = _name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    _buildAvatarCard()
                        .animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
                    const SizedBox(height: 16),
                    _buildStatsRow()
                        .animate().fadeIn(delay: 80.ms, duration: 350.ms),
                    const SizedBox(height: 16),
                    _buildCalorieProgress()
                        .animate().fadeIn(delay: 140.ms, duration: 350.ms),
                    const SizedBox(height: 16),
                    _buildDietaryPrefs()
                        .animate().fadeIn(delay: 200.ms, duration: 350.ms),
                    const SizedBox(height: 16),
                    _buildSettingsSection(context)
                        .animate().fadeIn(delay: 260.ms, duration: 350.ms),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PlatelyBottomNav(currentIndex: 4, onTap: (_) {}, onScanTap: () {}),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 24, 14),
      child: Row(
        children: [
          TapScale(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGray)),
              child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('My Profile',
                  style: TextStyle(color: AppTheme.darkText, fontSize: 18,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            ),
          ),
          TapScale(
            onTap: () {},
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGray)),
              child: const Icon(LucideIcons.penLine, color: AppTheme.primaryDark, size: 18),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildAvatarCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.tealGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x44043B3C), blurRadius: 18, offset: Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
            child: Center(
              child: Text(_initials,
                  style: const TextStyle(color: Colors.white, fontSize: 26,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name,
                    style: const TextStyle(color: Colors.white, fontSize: 19,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(_email,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'DM Sans')),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0x4D76CC4F),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.green)),
                  child: const Text('Student Plan',
                      style: TextStyle(color: Colors.white, fontSize: 10,
                          fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          TapScale(
            onTap: () {},
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              child: const Icon(LucideIcons.penLine, color: Colors.white, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      {'label': 'Recipes Cooked', 'value': '34',  'icon': LucideIcons.utensils,    'color': AppTheme.scanGreen},
      {'label': 'Streak',         'value': '7d',  'icon': LucideIcons.flame,       'color': AppTheme.browseYellow},
      {'label': 'Protein Avg',    'value': '38g', 'icon': LucideIcons.dumbbell,    'color': AppTheme.typeBlue},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: stats.asMap().entries.map((e) {
          final s = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: e.key < stats.length - 1 ? 10 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderGray),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))
                    ]),
                child: Column(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: s['color'] as Color,
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(s['icon'] as IconData, color: AppTheme.primaryDark, size: 17),
                    ),
                    const SizedBox(height: 8),
                    Text(s['value'] as String,
                        style: const TextStyle(color: AppTheme.darkText, fontSize: 18,
                            fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
                    Text(s['label'] as String,
                        style: const TextStyle(color: AppTheme.mutedText, fontSize: 9,
                            fontFamily: 'DM Sans'),
                        textAlign: TextAlign.center,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalorieProgress() {
    final pct = (_caloriesConsumed / _calorieGoal).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Calorie Goal',
                  style: TextStyle(color: AppTheme.darkText, fontSize: 15,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
              Text('$_caloriesConsumed / $_calorieGoal kcal',
                  style: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: pct),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Stack(
              children: [
                Container(height: 13,
                    decoration: BoxDecoration(color: AppTheme.lightGray, borderRadius: BorderRadius.circular(10))),
                FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    height: 13,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.green, AppTheme.greenDark]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(pct * 100).toStringAsFixed(0)}% of daily goal',
                  style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans')),
              Text('${_calorieGoal - _caloriesConsumed} kcal remaining',
                  style: const TextStyle(color: AppTheme.primaryDark, fontSize: 11,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPrefs() {
    final prefs = [
      {'label': 'Vegetarian',   'icon': LucideIcons.leaf,       'val': _vegetarian,  'fn': (v) => setState(() => _vegetarian  = v)},
      {'label': 'Gluten-Free',  'icon': LucideIcons.wheatOff,   'val': _glutenFree,  'fn': (v) => setState(() => _glutenFree  = v)},
      {'label': 'Dairy-Free',   'icon': LucideIcons.milkOff,    'val': _dairyFree,   'fn': (v) => setState(() => _dairyFree   = v)},
      {'label': 'High Protein', 'icon': LucideIcons.dumbbell,   'val': _highProtein, 'fn': (v) => setState(() => _highProtein = v)},
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dietary Preferences',
              style: TextStyle(color: AppTheme.darkText, fontSize: 15,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...prefs.map((p) => _PrefRow(
            label: p['label'] as String,
            icon: p['icon'] as IconData,
            value: p['val'] as bool,
            onChanged: p['fn'] as ValueChanged<bool>,
          )),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))
          ]),
      child: Column(
        children: [
          _Tile(icon: LucideIcons.target,        label: 'Calorie & Protein Goals', onTap: () {}),
          _Tile(icon: LucideIcons.bell,           label: 'Notifications',           onTap: () {}),
          _Tile(icon: LucideIcons.lockKeyhole,    label: 'Change Password',         onTap: () {}),
          _Tile(icon: LucideIcons.messageCircleQuestionMark,     label: 'Help & Support',          onTap: () {}),
          _Tile(
            icon: LucideIcons.logOut,
            label: 'Log Out',
            textColor: AppTheme.red,
            showDivider: false,
            onTap: () => Navigator.pushAndRemoveUntil(
                context, AppTheme.fadeScale(const LoginScreen()), (_) => false),
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefRow({required this.label, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: value ? AppTheme.primaryDark.withValues(alpha: 0.08) : AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon,
                  color: value ? AppTheme.primaryDark : AppTheme.mutedText, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: value ? AppTheme.primaryDark : AppTheme.darkText,
                      fontSize: 14, fontFamily: 'DM Sans',
                      fontWeight: value ? FontWeight.w600 : FontWeight.w400)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryDark,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  final bool showDivider;
  const _Tile({required this.icon, required this.label, required this.onTap,
    this.textColor, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.8)))
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: (textColor ?? AppTheme.primaryDark).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: textColor ?? AppTheme.primaryDark, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: textColor ?? AppTheme.darkText, fontSize: 14,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
            ),
            Icon(LucideIcons.chevronRight, color: textColor ?? AppTheme.mutedText, size: 18),
          ],
        ),
      ),
    );
  }
}

