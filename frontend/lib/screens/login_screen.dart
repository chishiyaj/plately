import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _passVisible = false;
  bool _loading = false;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  void _login() {
    if (_loading) return;
    setState(() => _loading = true);
    Future.delayed(900.ms, () {
      if (!mounted) return;
      Navigator.pushReplacement(context, AppTheme.fadeScale(const HomeScreen()));
    });
  }

  void _googleLogin() =>
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
              // Logo mark
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.tealGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.utensils, color: Colors.white, size: 24),
              )
              .animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              const Text('Welcome\nback', style: TextStyle(color: AppTheme.darkText, fontSize: 36, fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.1))
              .animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.08),
              const SizedBox(height: 8),
              const Text('Sign in to continue cooking smarter.', style: TextStyle(color: AppTheme.mutedText, fontSize: 15, fontFamily: 'DM Sans'))
              .animate().fadeIn(duration: 400.ms, delay: 140.ms),
              const SizedBox(height: 40),

              // Fields
              Column(children: [
                _field(ctrl: _emailCtrl, hint: 'Email address', icon: LucideIcons.mail, keyboard: TextInputType.emailAddress),
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
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TapScale(
                  onTap: () {},
                  child: const Text('Forgot password?', style: TextStyle(color: AppTheme.primaryDark, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 28),

              // Primary button
              TapScale(
                onTap: _login,
                child: AnimatedContainer(
                  duration: 250.ms,
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x44043B3C), blurRadius: 20, offset: Offset(0, 6))],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  ),
                ),
              )
              .animate().fadeIn(duration: 400.ms, delay: 280.ms),
              const SizedBox(height: 24),

              // Divider
              Row(children: [
                const Expanded(child: Divider(color: AppTheme.borderGray)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or', style: TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
                ),
                const Expanded(child: Divider(color: AppTheme.borderGray)),
              ])
              .animate().fadeIn(duration: 300.ms, delay: 320.ms),
              const SizedBox(height: 20),

              // Google button
              TapScale(
                onTap: _googleLogin,
                child: Container(
                  width: double.infinity, height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
              .animate().fadeIn(duration: 300.ms, delay: 360.ms),
              const SizedBox(height: 36),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans')),
                  TapScale(
                    onTap: () => Navigator.pushReplacement(context, AppTheme.slideRight(const SignupScreen())),
                    child: const Text('Sign up', style: TextStyle(color: AppTheme.primaryDark, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                  ),
                ],
              )
              .animate().fadeIn(duration: 300.ms, delay: 400.ms),
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
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
