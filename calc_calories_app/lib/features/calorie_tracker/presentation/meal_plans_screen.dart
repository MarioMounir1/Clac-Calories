// lib/features/calorie_tracker/presentation/meal_plans_screen.dart
// The Teneen — Weekly Meal Planner UI

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'bloc/meal_plan_bloc.dart';
import 'bloc/meal_plan_event.dart';
import 'bloc/meal_plan_state.dart';
import 'bloc/dashboard_bloc.dart';
import 'bloc/dashboard_event.dart';

class MealPlansScreen extends StatefulWidget {
  const MealPlansScreen({super.key});

  @override
  State<MealPlansScreen> createState() => _MealPlansScreenState();
}

class _MealPlansScreenState extends State<MealPlansScreen> {
  int _selectedDayOfWeek = 6; // Starts on Saturday (Dow 6 in Egyptian week)

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.mealPlanTitle),
        centerTitle: false,
      ),
      body: BlocListener<MealPlanBloc, MealPlanState>(
        listener: (context, state) {
          if (state is MealPlanOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.primary),
            );
            // Refresh main dashboard metrics
            context.read<DashboardBloc>().add(const RefreshDashboard());
          } else if (state is MealPlanFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        child: BlocBuilder<MealPlanBloc, MealPlanState>(
          builder: (context, state) {
            if (state is MealPlanInitial) {
              context.read<MealPlanBloc>().add(LoadWeeklyMealPlan());
              return const Center(child: CircularProgressIndicator());
            }
            if (state is MealPlanLoading && state is! MealPlanLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is MealPlanLoaded) {
              return _buildContent(context, state, l10n, isArabic);
            }
            if (state is MealPlanFailure) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<MealPlanBloc>().add(LoadWeeklyMealPlan()),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, MealPlanLoaded state, AppLocalizations l10n, bool isArabic) {
    if (!state.hasPlan) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_rounded, size: 72, color: AppColors.border),
              const SizedBox(height: 20),
              Text(
                l10n.mealPlanNoPlan,
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<MealPlanBloc>().add(GenerateWeeklyPlanEvent());
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(l10n.mealPlanGenerate),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Locate active selected day plan data
    final activeDayData = state.days.firstWhere(
      (d) => d['dayOfWeek'] == _selectedDayOfWeek,
      orElse: () => state.days.first,
    );

    final List<dynamic> entries = activeDayData['entries'] as List<dynamic>? ?? [];
    final double dayCalories = (activeDayData['totalCalories'] as num).toDouble();

    return Column(
      children: [
        // ── Horizontal Days Selector Row ────────────────────────────────────
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: AppColors.surface,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.days.length,
            itemBuilder: (context, index) {
              final day = state.days[index];
              final int dow = day['dayOfWeek'];
              final String label = isArabic ? day['dayLabel']['ar'] : day['dayLabel']['en'];
              final String miniLabel = label.substring(0, 3);
              final isSelected = dow == _selectedDayOfWeek;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDayOfWeek = dow;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      color: isSelected ? AppColors.primary.withOpacity(0.08) : AppColors.background,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          miniLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Day Summary & Meal Entries ─────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day calorie ring preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    color: AppColors.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: AppColors.accent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.homeCaloriesLeft.split(' ')[0],
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              '${dayCalories.round()} kcal',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Meal items
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(l10n.noDataYet, style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ...entries.map((entry) {
                    final String id = entry['id'];
                    final String mealType = entry['mealType'];
                    final bool isEaten = entry['isEaten'] == true;
                    final foodItem = entry['foodItem'];
                    final String name = isArabic ? foodItem['nameAr'] : foodItem['nameEn'];
                    final double calories = (foodItem['calories'] as num).toDouble();
                    final double servings = (entry['servings'] as num).toDouble();

                    String typeLabel = mealType;
                    if (mealType == 'breakfast') typeLabel = l10n.mealTypeBreakfast;
                    else if (mealType == 'lunch') typeLabel = l10n.mealTypeLunch;
                    else if (mealType == 'dinner') typeLabel = l10n.mealTypeDinner;
                    else if (mealType == 'snack') typeLabel = l10n.mealTypeSnack;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        color: AppColors.surface,
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: isEaten,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            context.read<MealPlanBloc>().add(
                                  ToggleMealEatenEvent(
                                    planEntryId: id,
                                    isEaten: val ?? false,
                                  ),
                                );
                          },
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            decoration: isEaten ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '$typeLabel · ${servings.toStringAsFixed(1)} servings',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Text(
                          l10n.foodCaloriesPer(calories),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 24),

                // Regenerate weekly plan button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<MealPlanBloc>().add(GenerateWeeklyPlanEvent());
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.mealPlanGenerate),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
