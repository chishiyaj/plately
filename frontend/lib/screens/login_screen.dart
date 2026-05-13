import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../widgets/plately_logo.dart';
import '../widgets/google_g_logo.dart';
import '../services/auth_service.dart';
import '../main_shell.dart';
import '../services/user_prefs_service.dart';
import 'signup_screen.dart';
import 'onboarding_goals_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();
  bool _passVisible  = false;
  bool _loading      = false;
  bool _emailFocused = false;
  bool _passFocused  = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _emailFocus.addListener(() => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passFocus.addListener(()  => setState(() => _passFocused  = _passFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose();
    _emailFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }

  void _login() async {
    FocusScope.of(context).unfocus();
    if (_loading) return;
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      _showSnack('Please enter your email and password.', isError: true);
      return;
    }
    setState(() => _loading = true);
    final result = await AuthService.signInWithEmail(email, pass);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      await _navigateAfterLogin();
    } else {
      _showSnack(result.error!, isError: true);
    }
  }

  void _googleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      await _navigateAfterLogin();
    } else {
      _showSnack(result.error!, isError: true);
    }
  }

  Future<void> _navigateAfterLogin() async {
    final prefs   = await UserPrefsService.load();
    final calGoal = (prefs['cal_goal'] as int?) ?? 2200;
    final goalsSet = calGoal != 2200;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      AppTheme.fadeScale(goalsSet ? const MainShell() : const OnboardingGoalsScreen()),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
      backgroundColor: isError ? AppTheme.red : AppTheme.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  void _forgotPassword() {
    final ctrl = TextEditingController();
    bool sent = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(ctx),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border(ctx), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              if (sent) ...[
                Center(child: Column(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.mailCheck, color: AppTheme.green, size: 32),
                  ),
                  const SizedBox(height: 18),
                  Text('Check your inbox', style: TextStyle(
                    color: AppTheme.textPrimary(ctx), fontSize: 20,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
                  )),
                  const SizedBox(height: 8),
                  Text('We sent a reset link to\n${ctrl.text.trim()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted(ctx), fontSize: 14, fontFamily: 'DM Sans', height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'This resets your Plately password only — your Google account is not affected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted(ctx), fontSize: 12, fontFamily: 'DM Sans', height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TapScale(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity, height: 54,
                      decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: Text('Done', style: TextStyle(
                        color: Colors.white, fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                      ))),
                    ),
                  ),
                ])),
              ] else ...[
                Text('Reset password', style: TextStyle(
                  color: AppTheme.textPrimary(ctx), fontSize: 22,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 6),
                Text("Enter your email — we'll send a reset link instantly.", style: TextStyle(
                  color: AppTheme.textMuted(ctx), fontSize: 14, fontFamily: 'DM Sans',
                )),
                const SizedBox(height: 24),
                _AuthField(
                  ctrl: ctrl, hint: 'Email address',
                  icon: LucideIcons.mail, keyboard: TextInputType.emailAddress,
                  focused: false, onTap: () {},
                ),
                const SizedBox(height: 20),
                TapScale(
                  onTap: () async {
                    if (ctrl.text.trim().isEmpty || !ctrl.text.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Enter a valid email', style: TextStyle(fontFamily: 'DM Sans')),
                        backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      ));
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await AuthService.sendPasswordReset(ctrl.text.trim());
                      if (ctx.mounted) setS(() => sent = true);
                    } catch (e) {
                      if (ctx.mounted) {
                        messenger.showSnackBar(SnackBar(
                          content: Text(e.toString().replaceAll('Exception: ', ''),
                              style: const TextStyle(fontFamily: 'DM Sans')),
                          backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        ));
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity, height: 54,
                    decoration: BoxDecoration(
                      gradient: AppTheme.tealGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x33043B3C), blurRadius: 14, offset: Offset(0, 4))],
                    ),
                    child: const Center(child: Text('Send Reset Link', style: TextStyle(
                      color: Colors.white, fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                    ))),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dark = AppTheme.isDark(context);
    return Scaffold(
      // FIX: scaffold bg adapts to dark mode
      backgroundColor: AppTheme.scaffoldBg(context),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Column(children: [
          _BrandPanel(height: size.height * 0.30),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 32, offset: Offset(0, 8))],
                ),
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Welcome back', style: TextStyle(
                    color: AppTheme.textPrimary(context), fontSize: 26,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w800, letterSpacing: -0.5,
                  )).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.06),
                  const SizedBox(height: 4),
                  Text('Sign in to continue cooking smarter.', style: TextStyle(
                    color: AppTheme.textMuted(context), fontSize: 14, fontFamily: 'DM Sans',
                  )).animate().fadeIn(duration: 400.ms, delay: 260.ms),
                  const SizedBox(height: 28),
                  _AuthField(
                    ctrl: _emailCtrl, hint: 'Email address',
                    icon: LucideIcons.mail, keyboard: TextInputType.emailAddress,
                    focused: _emailFocused, focusNode: _emailFocus,
                    onTap: () => _emailFocus.requestFocus(),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05),
                  const SizedBox(height: 12),
                  _AuthField(
                    ctrl: _passCtrl, hint: 'Password',
                    icon: LucideIcons.lockKeyhole,
                    focused: _passFocused, focusNode: _passFocus,
                    obscure: !_passVisible,
                    onTap: () => _passFocus.requestFocus(),
                    suffix: SizedBox(
                      width: 48, height: 48,
                      child: TapScale(
                        onTap: () => setState(() => _passVisible = !_passVisible),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Icon(_passVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                              size: 18, color: AppTheme.mutedText),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 350.ms).slideY(begin: 0.05),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TapScale(
                      onTap: _forgotPassword,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('Forgot password?', style: TextStyle(
                          color: AppTheme.primaryDark.withValues(alpha: 0.8),
                          fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 390.ms),
                  const SizedBox(height: 22),
                  TapScale(
                    onTap: _login,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity, height: 54,
                      decoration: BoxDecoration(
                        gradient: AppTheme.tealGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Color(0x50043B3C), blurRadius: 18, offset: Offset(0, 6))],
                      ),
                      child: Center(child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Sign In', style: TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontFamily: 'DM Sans', fontWeight: FontWeight.w800, letterSpacing: 0.2,
                          )),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 420.ms),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: Divider(color: AppTheme.border(context), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('or', style: TextStyle(
                        color: AppTheme.textMuted(context), fontSize: 12, fontFamily: 'DM Sans',
                      )),
                    ),
                    Expanded(child: Divider(color: AppTheme.border(context), thickness: 1)),
                  ]).animate().fadeIn(duration: 300.ms, delay: 460.ms),
                  const SizedBox(height: 18),
                  TapScale(
                    onTap: _googleLogin,
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        color: dark ? AppTheme.darkCardAlt : const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const GoogleGLogo(),
                        const SizedBox(width: 10),
                        Text('Continue with Google', style: TextStyle(
                          color: AppTheme.textPrimary(context), fontSize: 14,
                          fontFamily: 'DM Sans', fontWeight: FontWeight.w600,
                        )),
                      ]),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 490.ms),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("Don't have an account? ", style: TextStyle(
                      color: AppTheme.textMuted(context), fontSize: 14, fontFamily: 'DM Sans',
                    )),
                    TapScale(
                      onTap: () => Navigator.pushReplacement(context, AppTheme.slideRight(const SignupScreen())),
                      child: const Text('Sign up', style: TextStyle(
                        color: AppTheme.primaryDark, fontSize: 14,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
                      )),
                    ),
                  ]).animate().fadeIn(duration: 300.ms, delay: 520.ms),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── BRAND PANEL ────────────────────────────────────────────────────────────────
class _BrandPanel extends StatelessWidget {
  final double height;
  const _BrandPanel({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF021A1B), Color(0xFF043B3C), Color(0xFF065E60)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PlatelyLogo(
                theme: PlatelyLogoTheme.onDark, iconSize: 44, wordmarkSize: 22,
              ).animate().fadeIn(duration: 500.ms, delay: 50.ms).slideX(begin: -0.05),
              const SizedBox(height: 14),
              Text('Eat smarter.\nCook faster.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w400, height: 1.5,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 150.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AUTH FIELD — dark-mode-aware ──────────────────────────────────────────────
// Single implementation. Adapts fill color, text color, border color to theme.
class _AuthField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool focused, obscure;
  final Widget? suffix;
  final TextInputType keyboard;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const _AuthField({
    required this.ctrl, required this.hint, required this.icon,
    required this.focused, required this.onTap,
    this.obscure = false, this.suffix,
    this.keyboard = TextInputType.text, this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      decoration: BoxDecoration(
        color: focused
            ? AppTheme.cardBg(context)
            : dark ? AppTheme.darkCardAlt : const Color(0xFFF9F8F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AppTheme.primaryDark : AppTheme.border(context),
          width: focused ? 1.8 : 1.0,
        ),
        boxShadow: focused
            ? const [BoxShadow(color: Color(0x14043B3C), blurRadius: 12, offset: Offset(0, 3))]
            : [],
      ),
      child: TextField(
        controller: ctrl, obscureText: obscure,
        keyboardType: keyboard, focusNode: focusNode,
        style: TextStyle(
          fontSize: 14, fontFamily: 'DM Sans',
          color: AppTheme.textPrimary(context),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppTheme.textMuted(context),
            fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, size: 17,
              color: focused ? AppTheme.primaryDark : AppTheme.textMuted(context)),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          border: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}
