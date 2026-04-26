import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _page = PageController();
  int _current = 0;

  static const _slides = [
    _Slide(
      icon: LucideIcons.scanLine,
      tag: 'SNAP',
      title: 'Scan Your\nIngredients',
      body: 'Point your camera at any ingredient and let AI identify what you have in seconds.',
      accent: Color(0xFF76CC4F),
    ),
    _Slide(
      icon: LucideIcons.bookOpen,
      tag: 'DISCOVER',
      title: 'Get Instant\nRecipes',
      body: 'High-protein meals tailored for students — fast, affordable, and actually delicious.',
      accent: Color(0xFF0A8183),
    ),
    _Slide(
      icon: LucideIcons.trendingUp,
      tag: 'TRACK',
      title: 'Eat Smarter\nEvery Day',
      body: 'Track macros, hit your protein goals, and build healthy cooking habits that stick.',
      accent: Color(0xFFBA5CCC),
    ),
  ];

  @override
  void dispose() { _page.dispose(); super.dispose(); }

  void _next() {
    if (_current < 2) {
      _page.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      Navigator.pushReplacement(context, AppTheme.fadeScale(const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen page view
          PageView.builder(
            controller: _page,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => _SlidePage(slide: _slides[i], isActive: _current == i),
          ),
          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomBar(current: _current, onNext: _next),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String tag, title, body;
  final Color accent;
  const _Slide({required this.icon, required this.tag, required this.title, required this.body, required this.accent});
}

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  final bool isActive;
  const _SlidePage({required this.slide, required this.isActive, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF032E2F), Color(0xFF043B3C), Color(0xFF054F50)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 60, 32, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Row(children: [
                const Icon(LucideIcons.utensils, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                const Text('Plately', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
              ])
              .animate().fadeIn(duration: 400.ms),
              const Spacer(),
              // Icon circle
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: slide.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: slide.accent.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(slide.icon, color: slide.accent, size: 38),
              )
              .animate(key: ValueKey(slide.tag))
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              const SizedBox(height: 28),
              // Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: slide.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: slide.accent.withValues(alpha: 0.3)),
                ),
                child: Text(slide.tag, style: TextStyle(color: slide.accent, fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              )
              .animate(key: ValueKey('tag_${slide.tag}'))
              .fadeIn(duration: 350.ms, delay: 180.ms),
              const SizedBox(height: 14),
              // Title
              Text(
                slide.title,
                style: const TextStyle(color: Colors.white, fontSize: 36, fontFamily: 'DM Sans', fontWeight: FontWeight.w800, height: 1.15),
              )
              .animate(key: ValueKey('title_${slide.tag}'))
              .fadeIn(duration: 400.ms, delay: 220.ms)
              .slideY(begin: 0.1, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              // Body
              Text(
                slide.body,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15, fontFamily: 'DM Sans', height: 1.6),
              )
              .animate(key: ValueKey('body_${slide.tag}'))
              .fadeIn(duration: 400.ms, delay: 280.ms),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int current;
  final VoidCallback onNext;
  const _BottomBar({required this.current, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF043B3C).withValues(alpha: 0), const Color(0xFF032E2F)],
        ),
      ),
      child: Row(
        children: [
          // Dots
          Row(
            children: List.generate(3, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.only(right: 6),
              width: i == current ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == current ? AppTheme.green : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
          const Spacer(),
          // Next / Get Started button
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: GestureDetector(
              onTap: onNext,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.greenGradient,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: const [BoxShadow(color: Color(0x5576CC4F), blurRadius: 20, offset: Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    Text(
                      current == 2 ? 'Get Started' : 'Next',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowRight, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
