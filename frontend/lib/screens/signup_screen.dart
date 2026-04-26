import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import 'home_screen.dart';
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
  bool _agreed = false;
  bool _loading = false;

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  void _createAccount() {
    if (!_agreed || _loading) return;
    setState(() => _loading = true);
    Future.delayed(900.ms, () {
      if (!mounted) return;
      Navigator.pushReplacement(context, AppTheme.fadeScale(const HomeScreen()));
    });
  }

  void _googleSignup() =>
      Navigator.pushReplacement(context, AppTheme.fadeScale(const HomeScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(16)),
                child: const Icon(LucideIcons.utensils, color: Colors.white, size: 24),
              )
              .animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              const Text('Create\naccount', style: TextStyle(color: AppTheme.darkText, fontSize: 36, fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.1))
              .animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.08),
              const SizedBox(height: 8),
              const Text('Join thousands cooking smarter.', style: TextStyle(color: AppTheme.mutedText, fontSize: 15, fontFamily: 'DM Sans'))
              .animate().fadeIn(duration: 400.ms, delay: 140.ms),
              const SizedBox(height: 36),

              Column(children: [
                _field(ctrl: _nameCtrl,  hint: 'Full name',       icon: LucideIcons.user),
                const SizedBox(height: 14),
                _field(ctrl: _emailCtrl, hint: 'Email address',   icon: LucideIcons.mail, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _field(
                  ctrl: _passCtrl, hint: 'Password', icon: LucideIcons.lockKeyhole, obscure: !_passVisible,
                  suffix: TapScale(
                    onTap: () => setState(() => _passVisible = !_passVisible),
                    child: Icon(_passVisible ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: AppTheme.mutedText),
                  ),
                ),
              ])
              .animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.06),
              const SizedBox(height: 18),

              // Terms row
              TapScale(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: 200.ms,
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _agreed ? AppTheme.primaryDark : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _agreed ? AppTheme.primaryDark : AppTheme.borderGray, width: 1.5),
                      ),
                      child: _agreed ? const Icon(LucideIcons.check, color: Colors.white, size: 13) : null,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(color: AppTheme.mutedText, fontSize: 13, fontFamily: 'DM Sans'),
                          children: [
                            TextSpan(text: 'Terms of Service', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
                            TextSpan(text: ' and '),
                            TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate().fadeIn(duration: 300.ms, delay: 260.ms),
              const SizedBox(height: 28),

              TapScale(
                onTap: _createAccount,
                child: AnimatedContainer(
                  duration: 250.ms,
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: _agreed ? AppTheme.tealGradient : null,
                    color: _agreed ? null : AppTheme.borderGray,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _agreed ? const [BoxShadow(color: Color(0x44043B3C), blurRadius: 20, offset: Offset(0, 6))] : [],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text('Create Account', style: TextStyle(color: _agreed ? Colors.white : AppTheme.mutedText, fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  ),
                ),
              )
              .animate().fadeIn(duration: 400.ms, delay: 300.ms),
              const SizedBox(height: 20),

              Row(children: [
                const Expanded(child: Divider(color: AppTheme.borderGray)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or', style: TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
                ),
                const Expanded(child: Divider(color: AppTheme.borderGray)),
              ])
              .animate().fadeIn(duration: 300.ms, delay: 340.ms),
              const SizedBox(height: 16),

              TapScale(
                onTap: _googleSignup,
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
                      Text('G', style: TextStyle(fontSize: 18, fontFamily: 'DM Sans', fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                      SizedBox(width: 10),
                      Text('Continue with Google', style: TextStyle(color: AppTheme.darkText, fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
              .animate().fadeIn(duration: 300.ms, delay: 380.ms),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ', style: TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans')),
                  TapScale(
                    onTap: () => Navigator.pushReplacement(context, AppTheme.slideRight(const LoginScreen())),
                    child: const Text('Sign in', style: TextStyle(color: AppTheme.primaryDark, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  ),
                ],
              )
              .animate().fadeIn(duration: 300.ms, delay: 420.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl, required String hint, required IconData icon,
    bool obscure = false, Widget? suffix, TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
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
          hintStyle: const TextStyle(color: AppTheme.mutedText, fontSize: 15, fontFamily: 'DM Sans'),
          prefixIcon: Icon(icon, size: 18, color: AppTheme.mutedText),
          suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 14), child: suffix) : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
