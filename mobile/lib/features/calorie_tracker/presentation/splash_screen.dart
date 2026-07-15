// lib/features/calorie_tracker/presentation/splash_screen.dart
// Aura — Premium Animated Splash Screen
//
// Animation flow:
//   0ms  → background fades in immediately
//   200ms → logo + glow scale-up + fade-in
//   600ms → "AURA" text fades in with letter-spacing
//   900ms → loading indicator fades in
//   2400ms → auth check completes → navigate
//
// Auth logic:
//   Token found  → HomeShellScreen (main dashboard)
//   No token     → LoginScreen     (smooth fade route)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/constants.dart';
import 'home_shell_screen.dart';
import '../../auth/presentation/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation Controllers ──────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _loadingCtrl;
  late final AnimationController _glowCtrl;

  // ── Animations ─────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _loadingFade;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    // Logo: scale + fade (0 → 600ms)
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );

    // Text: fade in (600ms delay, 400ms duration)
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );

    // Loading bar: fade in (900ms delay)
    _loadingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingCtrl, curve: Curves.easeOut),
    );

    // Glow pulse: continuous (repeats)
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Step 1 — logo enters
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoCtrl.forward();

    // Step 2 — app name fades in
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _textCtrl.forward();

    // Step 3 — loading hint fades in
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _loadingCtrl.forward();

    // Step 4 — auth check (runs in parallel with animations)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.tokenKey);

    if (!mounted) return;

    final bool hasValidToken = token != null && token.isNotEmpty;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) =>
            hasValidToken ? const HomeShellScreen() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _loadingCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // 0xFF090C15
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // ── Logo Block ─────────────────────────────────
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: _buildLogo(),
              ),
            ),

            const SizedBox(height: 28),

            // ── App Name ───────────────────────────────────
            FadeTransition(
              opacity: _textFade,
              child: Text(
                'AURA',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary, // 0xFFFFFFFF
                  letterSpacing: 14,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Tagline ────────────────────────────────────
            FadeTransition(
              opacity: _textFade,
              child: Text(
                'Track · Perform · Evolve',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary, // 0xFF8E929C
                  letterSpacing: 2.5,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // ── Loading Indicator ──────────────────────────
            FadeTransition(
              opacity: _loadingFade,
              child: _buildLoadingSection(),
            ),

            const SizedBox(height: 52),
          ],
        ),
      ),
    );
  }

  // ── Abstract "A" Logo ──────────────────────────────────────
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _glowPulse,
      builder: (_, __) {
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow layer behind the icon
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withOpacity(0.35 * _glowPulse.value),
                      blurRadius: 60,
                      spreadRadius: 16,
                    ),
                    BoxShadow(
                      color: AppColors.primary
                          .withOpacity(0.15 * _glowPulse.value),
                      blurRadius: 100,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),

              // Outer ring
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary
                        .withOpacity(0.2 + 0.15 * _glowPulse.value),
                    width: 1.2,
                  ),
                ),
              ),

              // Icon container
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface, // 0xFF121824
                  border: Border.all(
                    color: AppColors.primary
                        .withOpacity(0.35 + 0.2 * _glowPulse.value),
                    width: 1.6,
                  ),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(46, 46),
                    painter: _AbstractAPainter(
                      color: AppColors.primary,
                      glowIntensity: _glowPulse.value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Loading Section ────────────────────────────────────────
  Widget _buildLoadingSection() {
    return Column(
      children: [
        // Minimal linear progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              backgroundColor: Color(0xFF1B2232),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 2,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Loading local engines...',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.primary.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Custom Painter — Abstract "A" ──────────────────────────────
// Draws a sharp, geometric letter A from three strokes:
//   - Left diagonal  (bottom-left → apex)
//   - Right diagonal (apex → bottom-right)
//   - Crossbar       (left mid → right mid)
class _AbstractAPainter extends CustomPainter {
  final Color color;
  final double glowIntensity;

  const _AbstractAPainter({
    required this.color,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Key anchor points
    final apex = Offset(w * 0.50, h * 0.04);
    final bottomLeft = Offset(w * 0.04, h * 0.96);
    final bottomRight = Offset(w * 0.96, h * 0.96);
    final crossLeft = Offset(w * 0.22, h * 0.60);
    final crossRight = Offset(w * 0.78, h * 0.60);

    // Glow paint (drawn first, wider)
    final glowPaint = Paint()
      ..color = color.withOpacity(0.25 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Main strokes paint
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ── Draw glow shadow first ─────────────────────────────
    final glowPath = Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..moveTo(crossLeft.dx, crossLeft.dy)
      ..lineTo(crossRight.dx, crossRight.dy);
    canvas.drawPath(glowPath, glowPaint);

    // ── Draw main crisp strokes ────────────────────────────
    // Left leg
    canvas.drawLine(bottomLeft, apex, linePaint);
    // Right leg
    canvas.drawLine(apex, bottomRight, linePaint);
    // Crossbar — slightly thinner for elegance
    final crossPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(crossLeft, crossRight, crossPaint);

    // Apex accent dot — premium finishing touch
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(apex, 2.5, dotPaint);

    // Subtle inner highlight at apex for depth
    final highlightPaint = Paint()
      ..color = color.withOpacity(0.4 * glowIntensity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(apex, 6, highlightPaint);
  }

  @override
  bool shouldRepaint(_AbstractAPainter old) =>
      old.glowIntensity != glowIntensity;
}
