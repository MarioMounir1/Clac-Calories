// lib/features/calorie_tracker/presentation/dashboard_screen.dart
// The Teneen — Home Dashboard: Today's Summary & Fast Actions

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_state.dart';
import 'bloc/dashboard_bloc.dart';
import 'bloc/dashboard_event.dart';
import 'bloc/dashboard_state.dart';
import '../domain/repositories/tracker_repository.dart';
import 'widgets/quick_log_bottom_sheet.dart';
import 'widgets/scan_meal_bottom_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardLoaded? _lastLoadedState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.appName, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<DashboardBloc>().add(const RefreshDashboard());
        },
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardLoaded) {
              _lastLoadedState = state;
            }

            if (state is DashboardInitial && _lastLoadedState == null) {
              context.read<DashboardBloc>().add(const LoadDashboard());
              return const Center(child: CircularProgressIndicator());
            }

            if (state is DashboardLoading && _lastLoadedState == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_lastLoadedState != null) {
              return Stack(
                children: [
                  _buildContent(context, _lastLoadedState!, l10n, isArabic),
                  if (state is DashboardLoading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                ],
              );
            }

            if (state is DashboardFailure) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<DashboardBloc>().add(const LoadDashboard()),
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

  Widget _buildContent(BuildContext context, DashboardLoaded state, AppLocalizations l10n, bool isArabic) {
    final totals = state.foodSummary['totals'] as Map<String, dynamic>;
    final goals = state.foodSummary['goals'] as Map<String, dynamic>;
    final remaining = state.foodSummary['remaining'] as Map<String, dynamic>;

    final double caloriesConsumed = (totals['calories'] as num).toDouble();
    final double calorieGoal = (goals['calories'] as num).toDouble();
    final double caloriesRemaining = (remaining['calories'] as num).toDouble();

    final double proteinConsumed = (totals['protein'] as num).toDouble();
    final double proteinGoal = (goals['protein'] as num).toDouble();

    final double carbsConsumed = (totals['carbs'] as num).toDouble();
    final double carbsGoal = (goals['carbs'] as num).toDouble();

    final double fatsConsumed = (totals['fats'] as num).toDouble();
    final double fatsGoal = (goals['fats'] as num).toDouble();

    final int waterConsumed = state.waterSummary['totalMl'] as int;
    final int waterGoal = state.waterSummary['goalMl'] as int;
    final double waterProgress = (waterConsumed / waterGoal).clamp(0.0, 1.0);

    final double currentWeight = (state.weightSummary['currentWeight'] as num).toDouble();
    final double weightDelta = state.weightSummary['stats'] != null
        ? (state.weightSummary['stats']['totalDelta'] as num).toDouble()
        : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting Header ─────────────────────────────────────────
          BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, profileState) {
              String name = '';
              if (profileState is ProfileLoaded) {
                name = profileState.user['name'] ?? '';
              }
              final hour = DateTime.now().hour;
              String greeting = l10n.homeGreetingEvening;
              if (hour < 12) {
                greeting = l10n.homeGreetingMorning;
              } else if (hour < 18) {
                greeting = l10n.homeGreetingAfternoon;
              }
              return Text(
                name.isNotEmpty ? '$greeting, $name!' : greeting,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Calorie balance ring ────────────────────────────────────
          _buildCalorieRingCard(caloriesConsumed, calorieGoal, caloriesRemaining, l10n),
          const SizedBox(height: 16),

          // ── Macros progress card ────────────────────────────────────
          _buildMacrosCard(
            proteinConsumed,
            proteinGoal,
            carbsConsumed,
            carbsGoal,
            fatsConsumed,
            fatsGoal,
            l10n,
          ),
          const SizedBox(height: 16),

          // ── Quick action buttons ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context: context,
                  title: l10n.foodSearchTitle,
                  icon: Icons.search_rounded,
                  color: AppColors.primary,
                  onTap: () => Navigator.pushNamed(context, '/foods/search'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionCard(
                  context: context,
                  title: 'Quick Log',
                  icon: Icons.edit_note_rounded,
                  color: AppColors.success,
                  onTap: () => showQuickLogSheet(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionCard(
                  context: context,
                  title: l10n.scanTitle,
                  icon: Icons.camera_enhance_rounded,
                  color: AppColors.accent,
                  onTap: () => showScanMealSheet(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Water progress card ─────────────────────────────────────
          _buildWaterCard(context, waterConsumed, waterGoal, waterProgress, l10n),
          const SizedBox(height: 16),

          // ── Weight progress card ────────────────────────────────────
          _buildWeightCard(context, currentWeight, weightDelta, l10n),
          const SizedBox(height: 16),

          // ── Today's Meal Plan preview ───────────────────────────────
          _buildMealPlanCard(context, state.mealPlanSummary, l10n),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCalorieRingCard(
    double consumed,
    double goal,
    double remaining,
    AppLocalizations l10n,
  ) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        gradient: AppColors.cardGradient,
      ),
      child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${remaining.round()}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      l10n.homeCaloriesLeft.split(' ')[0],
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCalorieStatRow(l10n.homeGoal, '${goal.round()}', AppColors.textPrimary),
                  const Divider(height: 16),
                  _buildCalorieStatRow(l10n.homeCaloriesConsumed, '${consumed.round()}', AppColors.primary),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildCalorieStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildMacrosCard(
    double pConsumed,
    double pGoal,
    double cConsumed,
    double cGoal,
    double fConsumed,
    double fGoal,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeMacros, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _buildMacroProgressRow(l10n.homeProtein, pConsumed, pGoal, AppColors.protein, l10n.unitG),
            const SizedBox(height: 12),
            _buildMacroProgressRow(l10n.homeCarbs, cConsumed, cGoal, AppColors.carbs, l10n.unitG),
            const SizedBox(height: 12),
            _buildMacroProgressRow(l10n.homeFats, fConsumed, fGoal, AppColors.fats, l10n.unitG),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroProgressRow(String label, double consumed, double goal, Color color, String unit) {
    final pct = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            Text(
              '${consumed.round()}$unit / ${goal.round()}$unit',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterCard(
    BuildContext context,
    int consumed,
    int goal,
    double progress,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.water_drop_rounded, color: AppColors.protein, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.homeWater, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.homeWaterGoal(consumed, goal),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.protein),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconButton.filledTonal(
              onPressed: () async {
                final trackerRepo = RepositoryProvider.of<TrackerRepository>(context);
                final res = await trackerRepo.logWater(amountMl: 250);
                res.fold(
                  (failure) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(failure.message), backgroundColor: AppColors.error),
                    );
                  },
                  (_) {
                    context.read<DashboardBloc>().add(const RefreshDashboard());
                  },
                );
              },
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.protein.withOpacity(0.15),
                foregroundColor: AppColors.protein,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard(
    BuildContext context,
    double current,
    double delta,
    AppLocalizations l10n,
  ) {
    String deltaText = l10n.weightStable;
    Color deltaColor = AppColors.textSecondary;
    if (delta < 0) {
      deltaText = l10n.weightDeltaLost(delta.abs());
      deltaColor = AppColors.primary;
    } else if (delta > 0) {
      deltaText = l10n.weightDeltaGained(delta);
      deltaColor = AppColors.accent;
    }

    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/weight/progress'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.scale_rounded, color: AppColors.accent, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.weightTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          l10n.weightKg(current),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: deltaColor.withOpacity(0.15),
                          ),
                          child: Text(
                            deltaText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: deltaColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealPlanCard(
    BuildContext context,
    Map<String, dynamic> mealPlan,
    AppLocalizations l10n,
  ) {
    final bool hasPlan = mealPlan['hasPlan'] == true;
    final List<dynamic> entries = mealPlan['entries'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.homeTodaysPlan,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (hasPlan)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/meal-plans'),
                    child: Text(l10n.editButton),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasPlan)
              Center(
                child: Column(
                  children: [
                    Text(l10n.homeNoMealPlan, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final trackerRepo = RepositoryProvider.of<TrackerRepository>(context);
                        final res = await trackerRepo.generateWeeklyMealPlan();
                        res.fold(
                          (failure) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(failure.message), backgroundColor: AppColors.error),
                            );
                          },
                          (_) {
                            context.read<DashboardBloc>().add(const RefreshDashboard());
                          },
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(l10n.homeGeneratePlan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: entries.map((entry) {
                  final String id = entry['id'];
                  final String mealType = entry['mealType'];
                  final bool isEaten = entry['isEaten'] == true;
                  final foodItem = entry['foodItem'];
                  final String nameEn = foodItem['nameEn'];
                  final String nameAr = foodItem['nameAr'];
                  final String name = Localizations.localeOf(context).languageCode == 'ar' ? nameAr : nameEn;
                  final double calories = (foodItem['calories'] as num).toDouble();

                  // Map mealType string to translation key
                  String typeLabel = mealType;
                  if (mealType == 'breakfast') typeLabel = l10n.mealTypeBreakfast;
                  else if (mealType == 'lunch') typeLabel = l10n.mealTypeLunch;
                  else if (mealType == 'dinner') typeLabel = l10n.mealTypeDinner;
                  else if (mealType == 'snack') typeLabel = l10n.mealTypeSnack;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.surfaceVariant,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isEaten,
                          activeColor: AppColors.primary,
                          onChanged: (val) async {
                            final trackerRepo = RepositoryProvider.of<TrackerRepository>(context);
                            final res = await trackerRepo.toggleMealPlanEaten(id: id, isEaten: val ?? false);
                            res.fold(
                              (failure) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(failure.message), backgroundColor: AppColors.error),
                                );
                              },
                              (_) {
                                context.read<DashboardBloc>().add(const RefreshDashboard());
                              },
                            );
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                typeLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  decoration: isEaten ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          l10n.foodCaloriesPer(calories),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
