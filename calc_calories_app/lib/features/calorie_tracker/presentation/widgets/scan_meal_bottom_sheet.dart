// lib/features/calorie_tracker/presentation/widgets/scan_meal_bottom_sheet.dart
// The Teneen — Inline Camera Scan → AI Result → Apply & Log bottom sheet

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/meal_repository.dart';
import '../../domain/repositories/tracker_repository.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';

/// Opens the image picker, sends image to AI, shows a result sheet,
/// and lets the user confirm to log the meal to their daily totals.
Future<void> showScanMealSheet(BuildContext context) async {
  final picker = ImagePicker();

  // Step 1 — Pick image source
  final ImageSource? source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SourcePickerSheet(),
  );

  if (source == null || !context.mounted) return;

  // Step 2 — Pick image
  final XFile? file = await picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1920,
    maxHeight: 1920,
  );

  if (file == null || !context.mounted) return;

  // Step 3 — Show loading + call AI
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AnalyzingDialog(),
  );

  final mealRepo = context.read<MealRepository>();
  final result = await mealRepo.analyzeImageMeal(
    imagePath: file.path,
    restaurantName: null,
  );

  if (!context.mounted) return;
  Navigator.of(context).pop(); // close loading dialog

  result.fold(
    (failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    (mealLog) {
      // Step 4 — Show result sheet with Apply & Log
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<DashboardBloc>()),
          ],
          child: RepositoryProvider.value(
            value: context.read<TrackerRepository>(),
            child: _ScanResultSheet(mealLog: mealLog),
          ),
        ),
      );
    },
  );
}

// ── Source Picker ──────────────────────────────────────────

class _SourcePickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Scan Your Meal',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'AI will calculate the macros from your photo',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    subtitle: 'Take a photo now',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    subtitle: 'Pick existing photo',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Analyzing Dialog ───────────────────────────────────────

class _AnalyzingDialog extends StatelessWidget {
  const _AnalyzingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  Icon(Icons.image_search_rounded, color: AppColors.primary, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Analyzing your meal…',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'AI is calculating macros from your photo',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan Result Sheet ──────────────────────────────────────

class _ScanResultSheet extends StatelessWidget {
  final dynamic mealLog; // MealLogEntity

  const _ScanResultSheet({required this.mealLog});

  @override
  Widget build(BuildContext context) {
    final calories = mealLog.calories.round();
    final protein = mealLog.protein.round();
    final carbs = mealLog.carbs.round();
    final fats = mealLog.fats.round();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      'AI Analysis Complete',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Meal name
          Text(
            mealLog.mealName,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Macro pills row
          Row(
            children: [
              _MacroPill(value: calories, label: 'kcal', color: AppColors.accent),
              const SizedBox(width: 8),
              _MacroPill(value: protein, label: 'P (g)', color: AppColors.protein),
              const SizedBox(width: 8),
              _MacroPill(value: carbs, label: 'C (g)', color: AppColors.carbs),
              const SizedBox(width: 8),
              _MacroPill(value: fats, label: 'F (g)', color: AppColors.fats),
            ],
          ),
          const SizedBox(height: 24),

          // Apply & Log button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Already logged to DB by the AI endpoint —
                // just refresh dashboard and close.
                context.read<DashboardBloc>().add(const RefreshDashboard());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Meal added to today\'s totals!',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: const Icon(Icons.add_task_rounded, size: 20),
              label: Text(
                'Apply & Log Meal',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dismiss
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Discard',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _MacroPill({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
