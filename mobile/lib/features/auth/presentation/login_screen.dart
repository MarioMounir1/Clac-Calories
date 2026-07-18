// lib/features/auth/presentation/login_screen.dart
// Calc-Calories — Login Screen (Performance-Optimised & AURA Branded)

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'bloc/auth_state.dart';
import 'register_screen.dart';

// ── Pre-cached text styles (created once, not on every build) ─────────────
class _Styles {
  _Styles._();

  static final TextStyle brandTitle = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -0.8,
  );

  static final TextStyle brandSub = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static final TextStyle label = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  static final TextStyle input = GoogleFonts.inter(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle hint = GoogleFonts.inter(color: AppColors.textMuted);

  static final TextStyle buttonText = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static final TextStyle orLabel = GoogleFonts.inter(
    color: AppColors.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle googleBtnLabel = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle footerMuted = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static final TextStyle footerLink = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  static final TextStyle snackText = GoogleFonts.inter(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  late final AnimationController _btnAnim;

  @override
  void initState() {
    super.initState();
    _btnAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _btnAnim.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
          LoginSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );
  }

  void _toggleObscure() => setState(() => _obscurePassword = !_obscurePassword);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (_, cur) => cur is AuthFailure || cur is Authenticated,
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message, style: _Styles.snackText),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
          }
          if (state is Authenticated) {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        buildWhen: (prev, cur) => (prev is AuthLoading) != (cur is AuthLoading),
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          isLoading ? _btnAnim.forward() : _btnAnim.reverse();

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Brand Logo & Header ───────────────────────────
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface,
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.5),
                                  width: 1.6,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.25),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: CustomPaint(
                                  size: Size(44, 44),
                                  painter: _AuraLogoPainter(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text('AURA', style: _Styles.brandTitle),
                            const SizedBox(height: 8),
                            Text(
                              'Diet Planner',
                              style: _Styles.brandSub,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ── Card container for inputs ─────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Email ─────────────────────────────────
                            Text('Email Address', style: _Styles.label),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: _Styles.input,
                              decoration: InputDecoration(
                                hintText: 'e.g. ahmed@gmail.com',
                                hintStyle: _Styles.hint,
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Email is required';
                                if (!v.contains('@')) return 'Please enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // ── Password ──────────────────────────────
                            Text('Password', style: _Styles.label),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              style: _Styles.input,
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: _Styles.hint,
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  splashRadius: 20,
                                  onPressed: _toggleObscure,
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Password is required';
                                if (v.trim().length < 8) return 'Password must be at least 8 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // ── Submit Button (animated) ───────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: AppColors.primary.withOpacity(0.7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: isLoading
                                      ? const SizedBox(
                                          key: ValueKey('loading'),
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation(Colors.black),
                                          ),
                                        )
                                      : Text(
                                          'Login',
                                          key: const ValueKey('label'),
                                          style: _Styles.buttonText,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── OR divider ────────────────────────────
                            Row(
                              children: [
                                const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('OR', style: _Styles.orLabel),
                                ),
                                const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // ── Google Sign-In ────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () => context.read<AuthBloc>().add(GoogleSignInSubmitted()),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border, width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  foregroundColor: Colors.white,
                                ),
                                icon: Image.asset(
                                  'assets/icons/google.png',
                                  height: 20,
                                  width: 20,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                label: Text(
                                  'Continue with Google',
                                  style: _Styles.googleBtnLabel,
                                ),
                              ),
                            ),

                            // ── Apple Sign-In (iOS only) ───────────────
                            if (Platform.isIOS) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.read<AuthBloc>().add(AppleSignInSubmitted()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.apple_rounded, color: Colors.black, size: 22),
                                  label: Text(
                                    'Continue with Apple',
                                    style: _Styles.googleBtnLabel,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Switch to Register ────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: _Styles.footerMuted,
                          ),
                          InkWell(
                            onTap: isLoading
                                ? null
                                : () => Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, anim, __) => const RegisterScreen(),
                                        transitionsBuilder: (_, anim, __, child) => FadeTransition(
                                          opacity: anim,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.05, 0),
                                              end: Offset.zero,
                                            ).animate(CurvedAnimation(
                                              parent: anim,
                                              curve: Curves.easeOut,
                                            )),
                                            child: child,
                                          ),
                                        ),
                                        transitionDuration: const Duration(milliseconds: 280),
                                      ),
                                    ),
                            borderRadius: BorderRadius.circular(4),
                            child: Text('Register', style: _Styles.footerLink),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuraLogoPainter extends CustomPainter {
  final Color color;

  const _AuraLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Anchor points for the stylized A to match the AURA brand logo
    final apex = Offset(w * 0.50, h * 0.10);
    final bottomLeft = Offset(w * 0.12, h * 0.88);
    final bottomRight = Offset(w * 0.88, h * 0.88);
    
    // Dynamic sharp crossbar extending to the right
    final crossLeft = Offset(w * 0.28, h * 0.58);
    final crossRight = Offset(w * 0.95, h * 0.42);

    // Glow paint
    final glowPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Main sharp line paint
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..moveTo(crossLeft.dx, crossLeft.dy)
      ..lineTo(crossRight.dx, crossRight.dy);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
