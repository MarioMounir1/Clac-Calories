// lib/features/calorie_tracker/presentation/widgets/quick_log_bottom_sheet.dart
// The Teneen — Manual Macro Quick-Log Bottom Sheet

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/tracker_repository.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows a modal bottom sheet where the user can type Calories / Protein /
/// Carbs / Fats directly and log them to the daily totals.
Future<void> showQuickLogSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<DashboardBloc>(),
      child: RepositoryProvider.value(
        value: context.read<TrackerRepository>(),
        child: const _QuickLogSheet(),
      ),
    ),
  );
}

class _QuickLogSheet extends StatefulWidget {
  const _QuickLogSheet();

  @override
  State<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<_QuickLogSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Custom meal');
  final _calCtrl = TextEditingController();
  final _proCtrl = TextEditingController();
  final _carCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  String _mealType = 'lunch';
  bool _isLoading = false;

  late AnimationController _anim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _anim.forward();
    // Live-update calorie field from macros
    _proCtrl.addListener(_estimateCalories);
    _carCtrl.addListener(_estimateCalories);
    _fatCtrl.addListener(_estimateCalories);
  }

  void _estimateCalories() {
    final p = double.tryParse(_proCtrl.text) ?? 0;
    final c = double.tryParse(_carCtrl.text) ?? 0;
    final f = double.tryParse(_fatCtrl.text) ?? 0;
    final estimated = (p * 4 + c * 4 + f * 9).round();
    if (estimated > 0 && _calCtrl.text.isEmpty) {
      setState(() => _calCtrl.text = '$estimated');
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    _carCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final repo = context.read<TrackerRepository>();
    final result = await repo.logManualMeal(
      mealName: _nameCtrl.text.trim(),
      calories: double.parse(_calCtrl.text),
      protein: double.tryParse(_proCtrl.text) ?? 0,
      carbs: double.tryParse(_carCtrl.text) ?? 0,
      fats: double.tryParse(_fatCtrl.text) ?? 0,
      mealType: _mealType,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

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
      (_) {
        context.read<DashboardBloc>().add(const RefreshDashboard());
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black, size: 18),
                const SizedBox(width: 8),
                Text('Meal logged to today\'s totals!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black)),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(_slideAnim),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ──
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

              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Quick Log Meal',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter macros directly — dashboard updates instantly',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // ── Meal Name ──
              _buildField(
                controller: _nameCtrl,
                label: 'Meal name',
                icon: Icons.restaurant_menu_rounded,
                isRequired: false,
                isDecimal: false,
              ),
              const SizedBox(height: 12),

              // ── Calories (big) ──
              _buildField(
                controller: _calCtrl,
                label: 'Calories (kcal)',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.accent,
                isRequired: true,
              ),
              const SizedBox(height: 12),

              // ── Macros row ──
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _proCtrl,
                      label: 'Protein (g)',
                      icon: Icons.circle,
                      color: AppColors.protein,
                      isRequired: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      controller: _carCtrl,
                      label: 'Carbs (g)',
                      icon: Icons.circle,
                      color: AppColors.carbs,
                      isRequired: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      controller: _fatCtrl,
                      label: 'Fats (g)',
                      icon: Icons.circle,
                      color: AppColors.fats,
                      isRequired: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Meal type chips ──
              Text('Meal type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: ['breakfast', 'lunch', 'dinner', 'snack'].map((type) {
                  final isActive = _mealType == type;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _mealType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            type[0].toUpperCase() + type.substring(1),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.add_circle_rounded, size: 20),
                  label: Text(
                    _isLoading ? 'Logging…' : 'Log Meal',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color color = AppColors.textMuted,
    bool isRequired = true,
    bool isDecimal = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isDecimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: color),
        prefixIcon: Icon(icon, size: 16, color: color),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: isRequired
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (double.tryParse(v) == null) return 'Invalid';
              return null;
            }
          : null,
    );
  }
}
