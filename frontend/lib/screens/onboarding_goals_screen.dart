import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/user_prefs_service.dart';
import '../services/api_service.dart';
import '../main_shell.dart';
import '../widgets/tap_scale.dart';

class OnboardingGoalsScreen extends StatefulWidget {
  const OnboardingGoalsScreen({super.key});
  @override
  State<OnboardingGoalsScreen> createState() => _OnboardingGoalsScreenState();
}

class _OnboardingGoalsScreenState extends State<OnboardingGoalsScreen> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl    = TextEditingController();

  String _sex  = 'male';
  String _goal = 'maintain';
  bool   _saving  = false;
  bool   _loading = false;
  bool   _tdeeCalculated = false;

  int _calGoal     = 2200;
  int _proteinGoal = 120;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final d = await UserPrefsService.load();
    final w = d['weight_kg'];
    final h = d['height_cm'];
    final a = d['age'];
    if (mounted) {
      setState(() {
        _calGoal     = (d['cal_goal']     as int?) ?? 2200;
        _proteinGoal = (d['protein_goal'] as int?) ?? 120;
        _goal        = (d['goal']         as String?) ?? 'maintain';
        _sex         = (d['sex']          as String?) ?? 'male';
        if (w != null) _weightCtrl.text = w.toString();
        if (h != null) _heightCtrl.text = h.toString();
        if (a != null) _ageCtrl.text    = a.toString();
      });
    }
  }

  Future<void> _calculate() async {
    final weight = double.tryParse(_weightCtrl.text.trim());
    final height = double.tryParse(_heightCtrl.text.trim());
    final age    = int.tryParse(_ageCtrl.text.trim());
    if (weight == null || height == null || age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill in weight, height, and age to calculate.',
              style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
          backgroundColor: Color(0xFFD14444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ApiService.setGoals(
        weight: weight,
        height: height,
        age: age,
        sex: _sex,
        goal: _goal,
      );
      if (mounted) {
        setState(() {
          if (result != null) {
            _calGoal         = (result['calorie_target'] as num?)?.toInt() ?? _calGoal;
            _proteinGoal     = (result['protein_target'] as num?)?.toInt() ?? _proteinGoal;
            _tdeeCalculated  = true;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
            'Could not calculate TDEE. Check your connection and try again.',
            style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await UserPrefsService.saveCalGoal(_calGoal);
    await UserPrefsService.saveProteinGoal(_proteinGoal);
    await UserPrefsService.saveGoal(_goal);
    final age    = int.tryParse(_ageCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final height = double.tryParse(_heightCtrl.text.trim());
    if (age    != null) await UserPrefsService.saveAge(age);
    if (weight != null) await UserPrefsService.saveWeight(weight);
    if (height != null) await UserPrefsService.saveHeight(height);
    await UserPrefsService.saveSex(_sex);
    await UserPrefsService.setOnboardingDone();
    if (!mounted) return;
    // P0 FIX: pop() leads to black screen when this is the root screen.
    // Use pushAndRemoveUntil to always land on MainShell.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        AppTheme.fadeScale(const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionLabel('Your Goal'),
                const SizedBox(height: 10),
                _goalSelector().animate().fadeIn(delay: 60.ms, duration: 300.ms),
                const SizedBox(height: 20),
                _sectionLabel('Body Stats'),
                const SizedBox(height: 10),
                _bodyStatsCard().animate().fadeIn(delay: 120.ms, duration: 300.ms),
                const SizedBox(height: 16),
                _calculateButton().animate().fadeIn(delay: 180.ms, duration: 300.ms),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _tdeeCalculated
                    ? Container(
                        key: const ValueKey('tdee_result'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          const Icon(LucideIcons.circleCheck, color: AppTheme.green, size: 16),
                          const SizedBox(width: 10),
                          Text(
                            'Target set: $_calGoal kcal · ${_proteinGoal}g protein/day',
                            style: const TextStyle(
                              color: AppTheme.green, fontSize: 13,
                              fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1)
                    : const SizedBox.shrink(key: ValueKey('tdee_empty')),
                ),
                const SizedBox(height: 8),
                _sectionLabel('Daily Targets'),
                const SizedBox(height: 10),
                _targetsCard().animate().fadeIn(delay: 240.ms, duration: 300.ms),
                const SizedBox(height: 28),
                _saveButton().animate().fadeIn(delay: 300.ms, duration: 300.ms),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: AppTheme.cardBg(context),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(children: [
        if (canPop)
          TapScale(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppTheme.cardAltBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
            ),
          )
        else
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.target, color: AppTheme.primaryDark, size: 20),
          ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            canPop ? 'Edit Goals' : 'Set Your Goals',
            style: TextStyle(
              color: AppTheme.textPrimary(context), fontSize: 18,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
            ),
          ),
          if (!canPop)
            Text(
              'Personalize your nutrition targets',
              style: TextStyle(
                color: AppTheme.textMuted(context),
                fontSize: 12,
                fontFamily: 'DM Sans',
              ),
            ),
        ]),
        const Spacer(),
        if (!canPop)
          TapScale(
            onTap: () async {
              await UserPrefsService.setOnboardingDone();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                AppTheme.fadeScale(const MainShell()),
                (route) => false,
              );
            },
            child: Text(
              'Skip',
              style: TextStyle(
                color: AppTheme.textMuted(context),
                fontSize: 13,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _sectionLabel(String label) => Text(
    label,
    style: TextStyle(
      color: AppTheme.textPrimary(context), fontSize: 13,
      fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
    ),
  );

  // ── Goal selector ──────────────────────────────────────────────────────────
  Widget _goalSelector() {
    const options = [
      ('lose',     'Lose Weight',    LucideIcons.trendingDown),
      ('maintain', 'Maintain',       LucideIcons.minus),
      ('gain',     'Gain Muscle',    LucideIcons.trendingUp),
    ];
    return Row(children: options.map((opt) {
      final (val, label, icon) = opt;
      final active = _goal == val;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: val == 'gain' ? 0 : 8),
          child: TapScale(
            onTap: () => setState(() => _goal = val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryDark : AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? AppTheme.primaryDark : AppTheme.border(context),
                ),
              ),
              child: Column(children: [
                Icon(icon, size: 20,
                    color: active ? Colors.white : AppTheme.primaryDark),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(
                  color: active ? Colors.white : AppTheme.textPrimary(context),
                  fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                )),
              ]),
            ),
          ),
        ),
      );
    }).toList());
  }

  // ── Body stats card ────────────────────────────────────────────────────────
  Widget _bodyStatsCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.cardBg(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Column(children: [
      Row(children: [
        Expanded(child: _numField(ctrl: _weightCtrl, label: 'Weight (kg)', hint: '70')),
        const SizedBox(width: 12),
        Expanded(child: _numField(ctrl: _heightCtrl, label: 'Height (cm)', hint: '170')),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _numField(ctrl: _ageCtrl, label: 'Age', hint: '22')),
        const SizedBox(width: 12),
        Expanded(child: _sexSelector()),
      ]),
    ]),
  );

  Widget _numField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
  }) => TextField(
    controller: ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: TextStyle(
      fontFamily: 'DM Sans', color: AppTheme.textPrimary(context), fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
          fontFamily: 'DM Sans', color: AppTheme.textMuted(context), fontSize: 13),
      hintStyle: TextStyle(
          fontFamily: 'DM Sans', color: AppTheme.textMuted(context), fontSize: 13),
      filled: true,
      fillColor: AppTheme.cardAltBg(context),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border(context))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border(context))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryDark, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );

  Widget _sexSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sex', style: TextStyle(
          fontFamily: 'DM Sans', color: AppTheme.textMuted(context), fontSize: 13)),
      const SizedBox(height: 8),
      SizedBox(
        height: 44,
        child: Row(children: [
          Expanded(child: _sexChip('male',   'Male')),
          const SizedBox(width: 8),
          Expanded(child: _sexChip('female', 'Female')),
        ]),
      ),
    ]);
  }

  Widget _sexChip(String val, String label) {
    final active = _sex == val;
    return TapScale(
      onTap: () => setState(() => _sex = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryDark : AppTheme.cardAltBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppTheme.primaryDark : AppTheme.border(context),
          ),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            color: active ? Colors.white : AppTheme.textPrimary(context),
            fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
          )),
        ),
      ),
    );
  }

  // ── Calculate button ───────────────────────────────────────────────────────
  Widget _calculateButton() => TapScale(
    onTap: _loading ? null : _calculate,
    child: Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? AppTheme.green
            : AppTheme.primaryDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.isDark(context)
              ? AppTheme.green
              : AppTheme.primaryDark.withValues(alpha: 0.3),
        ),
        boxShadow: AppTheme.isDark(context)
            ? [BoxShadow(color: AppTheme.green.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]
            : null,
      ),
      child: Center(
        child: _loading
          ? SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                color: AppTheme.isDark(context) ? AppTheme.primaryDark : AppTheme.primaryDark,
                strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.calculator,
                color: AppTheme.isDark(context) ? AppTheme.primaryDark : AppTheme.primaryDark,
                size: 16),
              const SizedBox(width: 8),
              Text('Calculate TDEE', style: TextStyle(
                color: AppTheme.isDark(context) ? AppTheme.primaryDark : AppTheme.primaryDark,
                fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
              )),
            ]),
      ),
    ),
  );

  // ── Targets card ───────────────────────────────────────────────────────────
  Widget _targetsCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.cardBg(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Column(children: [
      _targetRow(
        icon: LucideIcons.flame,
        label: 'Daily Calories',
        value: _calGoal,
        unit: 'kcal',
        color: const Color(0xFFEABA1C),
        onEdit: () => _showTargetEditor(
          title: 'Daily Calories',
          current: _calGoal,
          unit: 'kcal',
          onSave: (v) => setState(() => _calGoal = v),
        ),
      ),
      Divider(height: 20, color: AppTheme.border(context)),
      _targetRow(
        icon: LucideIcons.dumbbell,
        label: 'Daily Protein',
        value: _proteinGoal,
        unit: 'g',
        color: AppTheme.primaryDark,
        onEdit: () => _showTargetEditor(
          title: 'Daily Protein',
          current: _proteinGoal,
          unit: 'g',
          onSave: (v) => setState(() => _proteinGoal = v),
        ),
      ),
    ]),
  );

  Widget _targetRow({
    required IconData icon,
    required String label,
    required int value,
    required String unit,
    required Color color,
    required VoidCallback onEdit,
  }) => Row(children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 17),
    ),
    const SizedBox(width: 12),
    Expanded(child: Text(label, style: TextStyle(
      color: AppTheme.textPrimary(context), fontSize: 14,
      fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
    ))),
    Text('$value $unit', style: TextStyle(
      color: color, fontSize: 16,
      fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
    )),
    const SizedBox(width: 10),
    TapScale(
      onTap: onEdit,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppTheme.cardAltBg(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: const Icon(LucideIcons.penLine, size: 14, color: AppTheme.primaryDark),
      ),
    ),
  ]);

  void _showTargetEditor({
    required String title,
    required int current,
    required String unit,
    required ValueChanged<int> onSave,
  }) {
    final ctrl = TextEditingController(text: '$current');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
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
            const SizedBox(height: 16),
            Text(title, style: TextStyle(
              color: AppTheme.textPrimary(context), fontSize: 17,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 18),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(
                  fontFamily: 'DM Sans', color: AppTheme.textPrimary(context),
                  fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                suffixText: unit,
                suffixStyle: TextStyle(
                    fontFamily: 'DM Sans', color: AppTheme.textMuted(context)),
                filled: true,
                fillColor: AppTheme.cardAltBg(context),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border(context))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border(context))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryDark, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            TapScale(
              onTap: () {
                final v = int.tryParse(ctrl.text.trim());
                if (v != null && v > 0) {
                  onSave(v);
                  Navigator.pop(ctx);
                }
              },
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient,
                    borderRadius: BorderRadius.circular(14)),
                child: const Center(
                  child: Text('Save', style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                  )),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────────
  Widget _saveButton() => TapScale(
    onTap: _saving ? null : _save,
    child: Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.tealGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x55043B3C), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Center(
        child: _saving
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : const Text('Save Goals', style: TextStyle(
              color: Colors.white, fontSize: 16,
              fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
            )),
      ),
    ),
  );
}
