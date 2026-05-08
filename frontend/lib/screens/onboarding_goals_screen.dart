import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../services/api_service.dart';
import '../services/user_prefs_service.dart';
import '../main_shell.dart';

class OnboardingGoalsScreen extends StatefulWidget {
  const OnboardingGoalsScreen({super.key});
  @override
  State<OnboardingGoalsScreen> createState() => _OnboardingGoalsScreenState();
}

class _OnboardingGoalsScreenState extends State<OnboardingGoalsScreen> {
  // ── Manual inputs ─────────────────────────────────────────────────────────
  final _calCtrl     = TextEditingController(text: '2000');
  final _proteinCtrl = TextEditingController(text: '120');

  // ── Auto-calc inputs ──────────────────────────────────────────────────────
  final _ageCtrl    = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _sex       = 'male';
  String _goal      = 'maintain';
  bool   _autoCalc  = false;
  bool   _saving    = false;

  static const _goals = [
    ('lose',     'Lose Weight',    LucideIcons.trendingDown),
    ('maintain', 'Stay Healthy',   LucideIcons.activity),
    ('gain',     'Gain Muscle',    LucideIcons.trendingUp),
  ];

  static const _goalColors = {
    'lose':     AppTheme.purple,
    'maintain': AppTheme.primaryDark,
    'gain':     AppTheme.green,
  };

  @override
  void dispose() {
    _calCtrl.dispose(); _proteinCtrl.dispose();
    _ageCtrl.dispose(); _weightCtrl.dispose(); _heightCtrl.dispose();
    super.dispose();
  }

  // ── Mifflin-St Jeor TDEE ─────────────────────────────────────────────────
  Future<void> _calcTDEE() async {
    final age    = int.tryParse(_ageCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final height = double.tryParse(_heightCtrl.text.trim());
    if (age == null || weight == null || height == null) return;

    final result = await ApiService.setGoals(
      weight: weight, height: height, age: age,
      goal: _goal, sex: _sex,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _calCtrl.text     = (result['calorie_target'] ?? result['calories'] ?? 2000).toString();
        _proteinCtrl.text = (result['protein_target'] ?? result['protein'] ?? 120).toString();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final cal     = int.tryParse(_calCtrl.text.trim())     ?? 2000;
    final protein = int.tryParse(_proteinCtrl.text.trim()) ?? 120;
    setState(() => _saving = true);
    await UserPrefsService.saveCalGoal(cal);
    await UserPrefsService.saveProteinGoal(protein);
    await UserPrefsService.saveGoal(_goal);
    await UserPrefsService.setOnboardingDone(); // mark done so main.dart never re-shows this
    if (!mounted) return;
    Navigator.pushReplacement(context, AppTheme.fadeScale(const MainShell()));
  }

  Future<void> _skip() async {
    await UserPrefsService.setOnboardingDone(); // mark done even on skip
    if (!mounted) return;
    Navigator.pushReplacement(context, AppTheme.fadeScale(const MainShell()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.scaffoldBg(context),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 32),
          _header(),
          const SizedBox(height: 32),
          _goalPicker(),
          const SizedBox(height: 24),
          _autoToggle(),
          const SizedBox(height: 20),
          if (_autoCalc) ...[
            _autoInputs(),
            const SizedBox(height: 20),
          ],
          _manualInputs(),
          const SizedBox(height: 32),
          _saveBtn(),
          const SizedBox(height: 16),
          _skipBtn(),
        ]),
      ),
    ),
  );

  Widget _header() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 56, height: 56,
      decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(16)),
      child: const Icon(LucideIcons.target, color: Colors.white, size: 24),
    ).animate().scale(begin: const Offset(0.7, 0.7), duration: 450.ms, curve: Curves.easeOutBack),
    const SizedBox(height: 20),
    const Text('Set your goals',
      style: TextStyle(color: AppTheme.darkText, fontSize: 30,
          fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.1),
    ).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.08),
    const SizedBox(height: 8),
    const Text('Tell Plately your targets so we can personalise your experience.',
      style: TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans', height: 1.5),
    ).animate().fadeIn(duration: 400.ms, delay: 140.ms),
  ]);

  Widget _goalPicker() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('What\'s your main goal?',
      style: TextStyle(color: AppTheme.darkText, fontSize: 14,
          fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),
    Row(children: _goals.map((g) {
      final (id, label, icon) = g;
      final sel = _goal == id;
      final col = _goalColors[id]!;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _goal = id);
            if (_autoCalc) _calcTDEE();
          },
          child: AnimatedContainer(
            duration: 200.ms,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: sel ? col.withValues(alpha: 0.1) : AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? col : AppTheme.border(context), width: sel ? 2 : 1),
            ),
            child: Column(children: [
              Icon(icon, color: sel ? col : AppTheme.mutedText, size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                color: sel ? col : AppTheme.textMuted(context),
                fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }).toList()),
  ]).animate().fadeIn(duration: 350.ms, delay: 180.ms);

  Widget _autoToggle() => TapScale(
    onTap: () {
      HapticFeedback.selectionClick();
      setState(() => _autoCalc = !_autoCalc);
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: _autoCalc ? AppTheme.primaryDark : AppTheme.cardAltBg(context),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(LucideIcons.calculator,
              color: _autoCalc ? Colors.white : AppTheme.mutedText, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Auto-calculate with Mifflin-St Jeor',
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13,
                fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Enter your stats to get a precise TDEE estimate',
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11, fontFamily: 'DM Sans')),
        ])),
        AnimatedContainer(
          duration: 200.ms,
          width: 44, height: 26,
          decoration: BoxDecoration(
            color: _autoCalc ? AppTheme.primaryDark : AppTheme.borderGray,
            borderRadius: BorderRadius.circular(13),
          ),
          child: AnimatedAlign(
            duration: 200.ms,
            alignment: _autoCalc ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20, height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ]),
    ),
  ).animate().fadeIn(duration: 350.ms, delay: 220.ms);

  Widget _autoInputs() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardBg(context), borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Column(children: [
      Row(children: [
        Expanded(child: _numField(_ageCtrl,    'Age (yrs)',    LucideIcons.cake)),
        const SizedBox(width: 10),
        Expanded(child: _numField(_weightCtrl, 'Weight (kg)',  LucideIcons.weight)),
        const SizedBox(width: 10),
        Expanded(child: _numField(_heightCtrl, 'Height (cm)', LucideIcons.ruler)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        _sexBtn('male',   'Male',   LucideIcons.mars),
        const SizedBox(width: 10),
        _sexBtn('female', 'Female', LucideIcons.venus),
      ]),
      const SizedBox(height: 14),
      TapScale(
        onTap: _calcTDEE,
        child: Container(
          width: double.infinity, height: 46,
          decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.calculator, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Calculate my targets', style: TextStyle(color: Colors.white,
                fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          ])),
        ),
      ),
    ]),
  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04);

  Widget _sexBtn(String id, String label, IconData icon) => Expanded(
    child: TapScale(
      onTap: () => setState(() { _sex = id; if (_autoCalc) _calcTDEE(); }),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _sex == id ? AppTheme.primaryDark.withValues(alpha: 0.1) : AppTheme.cardAltBg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _sex == id ? AppTheme.primaryDark : AppTheme.border(context)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: _sex == id ? AppTheme.primaryDark : AppTheme.mutedText),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: _sex == id ? AppTheme.primaryDark : AppTheme.mutedText,
            fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );

  Widget _numField(TextEditingController ctrl, String hint, IconData icon) => Container(
    height: 52,
    decoration: BoxDecoration(
      color: AppTheme.cardAltBg(context), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _calcTDEE(),
      style: TextStyle(fontSize: 13, fontFamily: 'DM Sans', color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 11, fontFamily: 'DM Sans'),
        prefixIcon: Icon(icon, size: 14, color: AppTheme.mutedText),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _manualInputs() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(_autoCalc ? 'Calculated targets (edit if needed)' : 'Set your daily targets',
      style: const TextStyle(color: AppTheme.darkText, fontSize: 14,
          fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _goalField(_calCtrl,     'Calories (kcal)', LucideIcons.flame,   AppTheme.yellow)),
      const SizedBox(width: 12),
      Expanded(child: _goalField(_proteinCtrl, 'Protein (g)',     LucideIcons.dumbbell, AppTheme.green)),
    ]),
  ]).animate().fadeIn(duration: 350.ms, delay: 260.ms);

  Widget _goalField(TextEditingController ctrl, String hint, IconData icon, Color accent) => Container(
    height: 64,
    decoration: BoxDecoration(
      color: AppTheme.cardBg(context), borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border(context)),
      boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 20, fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans'),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
          child: Icon(icon, size: 18, color: accent),
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 20, 14, 0),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _saveBtn() => TapScale(
    onTap: _save,
    child: Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x44043B3C), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Center(child: _saving
        ? const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
        : const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.check, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Save & Start Cooking', style: TextStyle(color: Colors.white,
                fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
          ]),
      ),
    ),
  ).animate().fadeIn(duration: 350.ms, delay: 300.ms);

  Widget _skipBtn() => Center(
    child: TapScale(
      onTap: _skip,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Skip for now',
          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 14,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline)),
      ),
    ),
  ).animate().fadeIn(duration: 300.ms, delay: 360.ms);
}
