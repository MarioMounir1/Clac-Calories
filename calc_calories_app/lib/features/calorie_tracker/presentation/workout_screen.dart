// lib/features/calorie_tracker/presentation/workout_screen.dart
// The Teneen — Standalone Minimalist Workout Hub tab

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Zone ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'روتين التمرين' : 'Workout Hub',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildStreakBadge(isArabic),
                ],
              ),
            ),

            // ── Scrollable Content Area ──────────────────────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 90), // Spacing for custom bottom nav
                children: [
                  // AI Generator Micro-Card (Sleek Charcoal Capsule)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildAiGeneratorCapsule(isArabic),
                  ),

                  const SizedBox(height: 20),

                  // Today's Training Routine (Focused Card)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildTodayTrainingCard(isArabic),
                  ),

                  const SizedBox(height: 20),

                  // Recent Performance Quick-View Line
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildPerformanceQuickView(isArabic),
                  ),

                  const SizedBox(height: 28),

                  // Weekly Calendar Overview Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      isArabic ? 'الأيام المكتملة' : 'Weekly Overview',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Weekly Calendar Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildWeeklyCalendar(isArabic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header: Streak Badge ──────────────────────────────────────────
  Widget _buildStreakBadge(bool isArabic) {
    final streakText = isArabic ? 'تتابع ٥ أيام 🔥' : '5-Day Streak 🔥';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 1.2)),
      ),
      child: Text(
        streakText,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.orangeAccent,
        ),
      ),
    );
  }

  // ── AI Generator Capsule ──────────────────────────────────────────
  Widget _buildAiGeneratorCapsule(bool isArabic) {
    return GestureDetector(
      onTap: () {
        setState(() => _isGenerating = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() => _isGenerating = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isArabic ? 'تم تحديث خطتك' : 'AI Plan Generated',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              content: Text(
                isArabic
                    ? 'تم تصميم خطة تمرين دفع مخصصة جديدة لك استناداً إلى أهدافك.'
                    : 'A new custom Push session plan has been crafted based on your goals.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isArabic ? 'موافق' : 'Awesome',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        });
      },
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(30)),
          border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 1.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
              const SizedBox(width: 10),
              Text(
                isArabic ? 'هل تحتاج خطة جديدة؟ ولد بالذكاء الاصطناعي' : 'Need a new plan? Generate with AI',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Today's Training Card (Focused Card) ─────────────────────────
  Widget _buildTodayTrainingCard(bool isArabic) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 1.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'اليوم: دفع (أسلوب RPT)' : 'Today: Push Day (RPT Style)',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Text-only exercises preview line
            Text(
              isArabic
                  ? '١. بنش برس بالبار  |  ٢. ضغط كتف بالبار  |  ٣. تجميع رفرفة مائل'
                  : '1. Barbell Bench Press  |  2. Overhead Press  |  3. Incline Flyes',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            // Rounded teal action button
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/workout/active'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: Text(
                isArabic ? 'ابدأ التمرين الآن' : 'Start Workout',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent Performance Quick-View Line ────────────────────────────
  Widget _buildPerformanceQuickView(bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'الأسبوع الماضي بنش برس: ١٠٠ كجم × ٥ عدات ⚡'
                  : 'Last Week Bench Press Top Set: 100kg x 5 reps ⚡',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly Calendar Grid ──────────────────────────────────────────
  Widget _buildWeeklyCalendar(bool isArabic) {
    final List<Map<String, dynamic>> weekDays = [
      {'dayEn': 'M', 'dayAr': 'ن', 'completed': true},
      {'dayEn': 'T', 'dayAr': 'ث', 'completed': true},
      {'dayEn': 'W', 'dayAr': 'ر', 'completed': false},
      {'dayEn': 'T', 'dayAr': 'خ', 'completed': false}, // Today
      {'dayEn': 'F', 'dayAr': 'ج', 'completed': false},
      {'dayEn': 'S', 'dayAr': 'س', 'completed': false},
      {'dayEn': 'S', 'dayAr': 'ح', 'completed': false},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(weekDays.length, (index) {
        final day = weekDays[index];
        final label = isArabic ? day['dayAr']! : day['dayEn']!;
        final isCompleted = day['completed'] as bool;
        final isToday = index == 3; // Mock Thursday as today

        return Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isToday ? AppColors.surfaceVariant : AppColors.surface),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.primary
                      : (isToday ? AppColors.primary : AppColors.border),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                        size: 18,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      }),
    );
  }
}
