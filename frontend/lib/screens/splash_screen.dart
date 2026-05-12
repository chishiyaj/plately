import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../widgets/plately_logo.dart';
import 'login_screen.dart';

// ─── SPLASH SCREEN ────────────────────────────────────────────────────────────
// Single branded splash → auto-routes after 1.8s.
// - Returning users (onboarding_done=true): → LoginScreen
// - First-time users: → OnboardingCarousel (carousel)
// Industry standard: one splash, not three.

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _route();
  }

  Future<void> _route() async {
    // Run timer + prefs check in parallel — whichever is longer wins
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      SharedPreferences.getInstance(),
    ]);
    if (!mounted) return;
    final prefs = results[1] as SharedPreferences;
    final seen = prefs.getBool('onboarding_done') ?? false;
    if (seen) {
      // Returning user → Login directly
      Navigator.pushReplacement(context, AppTheme.fadeScale(const LoginScreen()));
    } else {
      // First-time user → show the onboarding carousel
      Navigator.pushReplacement(context, AppTheme.fadeScale(const OnboardingCarousel()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021A1B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo mark
            const PlatelyLogo(
              theme: PlatelyLogoTheme.onDark,
              iconSize: 72,
              wordmarkSize: 32,
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 200.ms)
                .scale(
                    begin: const Offset(0.85, 0.85),
                    duration: 600.ms,
                    delay: 200.ms,
                    curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            // Tagline
            Text(
              'Eat smarter. Cook faster.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 15,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 600.ms),
          ],
        ),
      ),
    );
  }
}

// ─── ONBOARDING CAROUSEL ──────────────────────────────────────────────────────
// Shown ONLY for first-time users. 3 editorial slides.
// After "Get Started" or "Skip" → marks onboarding done → LoginScreen.

class OnboardingCarousel extends StatefulWidget {
  const OnboardingCarousel({super.key});
  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  final _page = PageController();
  int _current = 0;

  static const _slides = [
    _Slide(
      index: 0,
      tag: 'INSTANT SCAN',
      headline: 'Snap your\nfridge.',
      accentA: Color(0xFF76CC4F),
      accentB: Color(0xFF3D7B20),
      bg: Color(0xFF021A1B),
    ),
    _Slide(
      index: 1,
      tag: 'AI RECIPES',
      headline: 'Ready in\n15 minutes.',
      accentA: Color(0xFF0FCCCE),
      accentB: Color(0xFF047A7C),
      bg: Color(0xFF011820),
    ),
    _Slide(
      index: 2,
      tag: 'MACRO TRACKING',
      headline: 'Hit your\nprotein goal.',
      accentA: Color(0xFFBA5CCC),
      accentB: Color(0xFF7B2E8A),
      bg: Color(0xFF0E0618),
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  void _next() {
    if (_current < 2) {
      _page.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await _markDone();
    if (!mounted) return;
    Navigator.pushReplacement(context, AppTheme.fadeScale(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        PageView.builder(
          controller: _page,
          physics: const BouncingScrollPhysics(),
          itemCount: _slides.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
        ),
        // Skip button
        if (_current < 2)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 24,
            child: TapScale(
              onTap: _finish,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Text('Skip',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    )),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
          ),
        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _BottomControls(
            current: _current,
            onNext: _next,
            slide: _slides[_current],
          ),
        ),
      ]),
    );
  }
}

// ── DATA MODEL ─────────────────────────────────────────────────────────────────
class _Slide {
  final int index;
  final String tag, headline;
  final Color accentA, accentB, bg;
  const _Slide({
    required this.index,
    required this.tag,
    required this.headline,
    required this.accentA,
    required this.accentB,
    required this.bg,
  });
}

// ── CATEGORY TAG ───────────────────────────────────────────────────────────────
class _CategoryTag extends StatelessWidget {
  final _Slide slide;
  const _CategoryTag({required this.slide});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: slide.accentA, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(slide.tag,
              style: TextStyle(
                color: slide.accentA,
                fontSize: 11,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
              )),
        ],
      );
}

// ── SLIDE PAGE ─────────────────────────────────────────────────────────────────
class _SlidePage extends StatelessWidget {
  final _Slide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: slide.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PlatelyLogo(
                theme: PlatelyLogoTheme.onDark,
                iconSize: 36,
                wordmarkSize: 18,
              ).animate().fadeIn(duration: 500.ms, delay: 80.ms),
              const SizedBox(height: 44),
              _CategoryTag(slide: slide)
                  .animate(key: ValueKey('tag_${slide.index}'))
                  .fadeIn(duration: 380.ms, delay: 120.ms)
                  .slideX(begin: -0.08, curve: Curves.easeOutCubic),
              const SizedBox(height: 14),
              Text(
                slide.headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -1.5,
                ),
              )
                  .animate(key: ValueKey('h_${slide.index}'))
                  .fadeIn(duration: 450.ms, delay: 180.ms)
                  .slideY(begin: 0.06, curve: Curves.easeOutCubic),
              const SizedBox(height: 36),
              _buildPreview(slide)
                  .animate(key: ValueKey('p_${slide.index}'))
                  .fadeIn(duration: 500.ms, delay: 280.ms)
                  .slideY(begin: 0.06, curve: Curves.easeOutCubic),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(_Slide slide) {
    switch (slide.index) {
      case 0:
        return _IngredientChipsPreview(accent: slide.accentA);
      case 1:
        return _RecipeCardPreview(
            accentA: slide.accentA, accentB: slide.accentB);
      default:
        return _MacroBarPreview(accent: slide.accentA);
    }
  }
}

// ── SLIDE 1 PREVIEW: Ingredient chips ─────────────────────────────────────────
class _IngredientChipsPreview extends StatelessWidget {
  final Color accent;
  const _IngredientChipsPreview({required this.accent});

  static const _chips = ['Chicken', 'Garlic', 'Rice', 'Onion'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.scanLine, color: accent, size: 13),
            const SizedBox(width: 7),
            Text('Detected in your fridge',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                )),
            const Spacer(),
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: accent, shape: BoxShape.circle),
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 600.ms)
                .then()
                .fadeOut(duration: 600.ms),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _chips
                .asMap()
                .entries
                .map((e) => _IngredientChip(
                    label: e.value, accent: accent, delay: e.key * 70))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  final String label;
  final Color accent;
  final int delay;
  const _IngredientChip(
      {required this.label, required this.accent, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: accent, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w600,
            )),
      ]),
    ).animate().fadeIn(duration: 350.ms, delay: (280 + delay).ms).slideX(begin: 0.08);
  }
}

// ── SLIDE 2 PREVIEW: Recipe card ───────────────────────────────────────────────
class _RecipeCardPreview extends StatelessWidget {
  final Color accentA, accentB;
  const _RecipeCardPreview(
      {required this.accentA, required this.accentB});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.10), width: 1.0),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentA, accentB],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              const Icon(LucideIcons.chefHat, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Chicken Stir Fry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 8),
              Row(children: [
                _Badge(
                    icon: LucideIcons.clock3,
                    label: '15 min',
                    color: accentA),
                const SizedBox(width: 8),
                _Badge(
                    icon: LucideIcons.dumbbell,
                    label: '38g protein',
                    color: accentA),
              ]),
            ])),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
              )),
        ]),
      );
}

// ── SLIDE 3 PREVIEW: Macro progress bar ────────────────────────────────────────
class _MacroBarPreview extends StatelessWidget {
  final Color accent;
  const _MacroBarPreview({required this.accent});

  @override
  Widget build(BuildContext context) {
    const current = 87;
    const goal = 120;
    const pct = current / goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.10), width: 1.0),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(LucideIcons.dumbbell, size: 15, color: accent),
            const SizedBox(width: 7),
            const Text('Protein',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w600,
                )),
          ]),
          RichText(
              text: TextSpan(children: [
            TextSpan(
                text: '${current}g',
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w800,
                )),
            const TextSpan(
                text: ' / ${goal}g',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  fontFamily: 'DM Sans',
                )),
          ])),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(children: [
            Container(
                height: 10,
                color: Colors.white.withValues(alpha: 0.08)),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Text(
          '${((pct) * 100).round()}% of daily goal',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontFamily: 'DM Sans',
          ),
        ),
      ]),
    );
  }
}

// ── BOTTOM CONTROLS ────────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final int current;
  final VoidCallback onNext;
  final _Slide slide;
  const _BottomControls(
      {required this.current,
      required this.onNext,
      required this.slide});

  @override
  Widget build(BuildContext context) {
    final isLast = current == 2;
    return Container(
      padding: EdgeInsets.fromLTRB(
          28, 24, 28, MediaQuery.of(context).padding.bottom + 32),
      child: Row(children: [
        Row(
            children: List.generate(3, (i) {
          final active = i == current;
          final past = i < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 8),
            width: active ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active
                  ? slide.accentA
                  : past
                      ? slide.accentA.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        })),
        const Spacer(),
        TapScale(
          onTap: onNext,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: EdgeInsets.symmetric(
              horizontal: isLast ? 32 : 26,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [slide.accentA, slide.accentB]),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: slide.accentA.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                isLast ? 'Get Started' : 'Continue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.arrowRight,
                  color: Colors.white, size: 16),
            ]),
          ),
        ),
      ]),
    );
  }
}
