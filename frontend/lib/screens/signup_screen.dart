import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../widgets/google_g_logo.dart';
import '../widgets/plately_logo.dart';
import '../services/auth_service.dart';
import '../main_shell.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _passVisible = false;
  bool _agreed      = false;
  bool _loading     = false;

  // After successful signup, show the verify-email screen
  bool _verificationSent = false;
  String _sentToEmail    = '';

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
      backgroundColor: AppTheme.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _createAccount() async {
    if (_loading) return;

    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;

    if (name.isEmpty)                        { _showError('Enter your full name.'); return; }
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) { _showError('Enter a valid email address.'); return; }
    if (pass.length < 6)                     { _showError('Password must be at least 6 characters.'); return; }
    if (!_agreed)                            { _showError('Please agree to the Terms of Service to continue.'); return; }

    setState(() => _loading = true);
    final result = await AuthService.createWithEmail(name, email, pass);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      // Show "check your email" screen — do NOT enter the app yet
      setState(() {
        _verificationSent = true;
        _sentToEmail      = email;
      });
    } else {
      _showError(result.error ?? 'Sign-up failed. Try again.');
    }
  }

  Future<void> _googleSignup() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      // Google accounts are auto-verified — go straight to app
      Navigator.pushReplacement(context, AppTheme.fadeScale(const MainShell()));
    } else {
      _showError(result.error ?? 'Google sign-up failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificationSent) return _VerifyEmailView(email: _sentToEmail);

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const PlatelyLogo(
                theme: PlatelyLogoTheme.onLight,
                iconSize: 44, wordmarkSize: 22,
              ).animate().fadeIn(duration: 400.ms).scale(
                  begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              const Text('Create\naccount',
                style: TextStyle(color: AppTheme.darkText, fontSize: 36,
                    fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.1),
              ).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.08),
              const SizedBox(height: 8),
              const Text('Join thousands cooking smarter.',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 15, fontFamily: 'DM Sans'),
              ).animate().fadeIn(duration: 400.ms, delay: 140.ms),
              const SizedBox(height: 36),

              Column(children: [
                _field(ctrl: _nameCtrl,  hint: 'Full name',     icon: LucideIcons.user),
                const SizedBox(height: 14),
                _field(ctrl: _emailCtrl, hint: 'Email address', icon: LucideIcons.mail,
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _field(
                  ctrl: _passCtrl,
                  hint: 'Create a Plately password (min. 6 chars)',
                  icon: LucideIcons.lockKeyhole,
                  obscure: !_passVisible,
                  suffix: TapScale(
                    onTap: () => setState(() => _passVisible = !_passVisible),
                    child: Icon(_passVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 18, color: AppTheme.mutedText),
                  ),
                ),
                // Password info note
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.scanGreen.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.info, size: 14, color: Color(0xFF2E6B29)),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'This password is for Plately only — it\'s separate from your email account password.',
                        style: TextStyle(
                          color: Color(0xFF2E6B29), fontSize: 12,
                          fontFamily: 'DM Sans', height: 1.4,
                        ),
                      )),
                    ],
                  ),
                ),
              ]).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.06),
              const SizedBox(height: 18),

              // Terms checkbox
              TapScale(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(children: [
                  AnimatedContainer(
                    duration: 200.ms,
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: _agreed ? AppTheme.primaryDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _agreed ? AppTheme.primaryDark : AppTheme.borderGray,
                        width: 1.5,
                      ),
                    ),
                    child: _agreed
                        ? const Icon(LucideIcons.check, color: Colors.white, size: 13)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text.rich(TextSpan(
                      text: 'I agree to the ',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans'),
                      children: [
                        TextSpan(text: 'Terms of Service',
                            style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
                        TextSpan(text: ' and '),
                        TextSpan(text: 'Privacy Policy',
                            style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
                      ],
                    )),
                  ),
                ]),
              ).animate().fadeIn(duration: 300.ms, delay: 260.ms),
              const SizedBox(height: 28),

              // Create account button
              TapScale(
                onTap: _agreed && !_loading ? _createAccount : null,
                child: AnimatedContainer(
                  duration: 250.ms,
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: _agreed ? AppTheme.tealGradient : null,
                    color: _agreed ? null : AppTheme.borderGray,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _agreed
                        ? const [BoxShadow(color: Color(0x44043B3C), blurRadius: 20, offset: Offset(0, 6))]
                        : [],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text('Create Account',
                            style: TextStyle(
                              color: _agreed ? Colors.white : AppTheme.mutedText,
                              fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                            )),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              const SizedBox(height: 20),

              const Row(children: [
                Expanded(child: Divider(color: AppTheme.borderGray)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or', style: TextStyle(color: AppTheme.mutedText,
                      fontSize: 12, fontFamily: 'DM Sans')),
                ),
                Expanded(child: Divider(color: AppTheme.borderGray)),
              ]).animate().fadeIn(duration: 300.ms, delay: 340.ms),
              const SizedBox(height: 16),

              // Google sign-up
              TapScale(
                onTap: _loading ? null : _googleSignup,
                child: Container(
                  width: double.infinity, height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderGray),
                    boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GoogleGLogo(),
                      SizedBox(width: 10),
                      Text('Continue with Google',
                          style: TextStyle(color: AppTheme.darkText, fontSize: 15,
                              fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 380.ms),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans')),
                  TapScale(
                    onTap: () => Navigator.pushReplacement(
                        context, AppTheme.slideRight(const LoginScreen())),
                    child: const Text('Sign in',
                        style: TextStyle(color: AppTheme.primaryDark, fontSize: 14,
                            fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms, delay: 420.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboard = TextInputType.text,
  }) => Container(
    height: 56,
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderGray),
      boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: TextField(
      controller: ctrl, obscureText: obscure, keyboardType: keyboard,
      style: const TextStyle(fontSize: 15, fontFamily: 'DM Sans', color: AppTheme.darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans'),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.mutedText),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 14), child: suffix)
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: InputBorder.none,
      ),
    ),
  );
}

// ── Email Verification Screen ─────────────────────────────────────────────────
// Shown after successful sign-up. User must verify email before logging in.
class _VerifyEmailView extends StatelessWidget {
  final String email;
  const _VerifyEmailView({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.mailCheck, color: AppTheme.green, size: 48),
              ).animate().scale(
                  begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              const Text('Check your email!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkText, fontSize: 28,
                  fontFamily: 'DM Sans', fontWeight: FontWeight.w800,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.08),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to\n$email\n\nClick the link in the email to activate your account, then come back and log in.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.mutedText, fontSize: 15,
                  fontFamily: 'DM Sans', height: 1.6,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.scanGreen.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.info, size: 16, color: Color(0xFF2E6B29)),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'Check your spam folder if you don\'t see it within a minute.',
                      style: TextStyle(
                        color: Color(0xFF2E6B29), fontSize: 13,
                        fontFamily: 'DM Sans', height: 1.4,
                      ),
                    )),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 380.ms),
              const SizedBox(height: 40),
              // Go to login
              TapScale(
                onTap: () => Navigator.pushReplacement(
                    context, AppTheme.slideRight(const LoginScreen())),
                child: Container(
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(
                      color: Color(0x44043B3C), blurRadius: 18, offset: Offset(0, 6),
                    )],
                  ),
                  child: const Center(child: Text('Go to Login',
                    style: TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w700,
                    ),
                  )),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 460.ms),
            ],
          ),
        ),
      ),
    );
  }
}
