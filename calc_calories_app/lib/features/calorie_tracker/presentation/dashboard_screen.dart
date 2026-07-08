// lib/features/calorie_tracker/presentation/dashboard_screen.dart
// The Teneen — Home Dashboard Redesign

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_state.dart';
import 'bloc/dashboard_bloc.dart';
import 'bloc/dashboard_event.dart';
import 'bloc/dashboard_state.dart';
import '../domain/repositories/tracker_repository.dart';
import 'widgets/scan_meal_bottom_sheet.dart';
import 'widgets/quick_log_bottom_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardLoaded? _lastLoadedState;
  bool _showSmartSuggestion = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
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
                    if (_showSmartSuggestion) ...[
                      // Blurred background
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showSmartSuggestion = false;
                            });
                          },
                          child: ui.BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              color: Colors.black.withOpacity(0.65),
                            ),
                          ),
                        ),
                      ),
                      // Glassmorphism Card Modal
                      Center(
                        child: _buildSmartSuggestionModal(context),
                      ),
                    ],
                  ],
                );
              }

              if (state is DashboardFailure) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(state.message, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () => context.read<DashboardBloc>().add(const LoadDashboard()),
                        child: Text(l10n.retryButton, style: const TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardLoaded state, AppLocalizations l10n, bool isArabic) {
    final totals = state.foodSummary['totals'] as Map<String, dynamic>;
    final goals = state.foodSummary['goals'] as Map<String, dynamic>;
    
    final double caloriesConsumed = (totals['calories'] as num).toDouble();
    final double calorieGoal = (goals['calories'] as num).toDouble();

    final double proteinConsumed = (totals['protein'] as num).toDouble();
    final double proteinGoal = (goals['protein'] as num).toDouble();
    final double carbsConsumed = (totals['carbs'] as num).toDouble();
    final double carbsGoal = (goals['carbs'] as num).toDouble();
    final double fatsConsumed = (totals['fats'] as num).toDouble();
    final double fatsGoal = (goals['fats'] as num).toDouble();


    final double currentWeight = (state.weightSummary['currentWeight'] as num).toDouble();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Bar ───────────────────────────────────────────────
          _buildTopBar(context),
          const SizedBox(height: 24),

          // ── Greeting Header ─────────────────────────────────────────
          _buildGreeting(l10n),
          const SizedBox(height: 24),

          // ── AI Smart Suggestion Banner ──────────────────────────────
          _buildSmartSuggestionBanner(proteinConsumed, proteinGoal),

          // ── Enhanced Calories (Donut + Sparkline) ─────────────────
          _buildEnhancedCaloriesCard(caloriesConsumed, calorieGoal),
          const SizedBox(height: 16),

          // ── Integrated Macros ───────────────────────────────────────
          _buildIntegratedMacrosCard(proteinConsumed, proteinGoal, carbsConsumed, carbsGoal, fatsConsumed, fatsGoal),
          const SizedBox(height: 16),

          // ── Simplified Actions (3 Squares) ──────────────────────────
          _buildSimplifiedActions(context),
          const SizedBox(height: 16),

          // ── Weight Progress ──────────────────────────────────────────
          _buildWeightCard(currentWeight),
          const SizedBox(height: 24),

          // ── Today's Insights (Carousel) ─────────────────────────────
          const Text(
            "Today's Insights",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildInsightsCarousel(),
          const SizedBox(height: 40), // Padding for bottom nav
        ],
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left space for symmetry
        const SizedBox(width: 48), 
        // Center logo + title
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nightlight_round, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              "The Teneen",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        // Right settings gear
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  Widget _buildGreeting(AppLocalizations l10n) {
    return BlocBuilder<ProfileBloc, ProfileState>(
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
        return Center(
          child: Text(
            name.isNotEmpty ? '$greeting, $name!' : greeting,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedCaloriesCard(double consumed, double goal) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    // Mock sparkline data for UI overhaul
    final sparklineSpots = const [
      FlSpot(0, 2800), FlSpot(1, 3000), FlSpot(2, 3200),
      FlSpot(3, 2500), FlSpot(4, 3100), FlSpot(5, 2900), FlSpot(6, 3053),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Donut Chart
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 45,
                    startDegreeOffset: 270,
                    sections: [
                      PieChartSectionData(
                        value: progress,
                        color: AppColors.primary,
                        radius: 12,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 1 - progress,
                        color: AppColors.surfaceVariant,
                        radius: 12,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${consumed.round()}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Calories',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Sparkline + Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Goal', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('${goal.round()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Consumed', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('${consumed.round()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: sparklineSpots,
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegratedMacrosCard(double pC, double pG, double cC, double cG, double fC, double fG) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMacroRow(Icons.science_outlined, 'Protein', pC, pG, AppColors.protein),
          const SizedBox(height: 16),
          _buildMacroRow(Icons.grass_outlined, 'Carbs', cC, cG, AppColors.carbs),
          const SizedBox(height: 16),
          _buildMacroRow(Icons.opacity_outlined, 'Fats', fC, fG, AppColors.fats),
        ],
      ),
    );
  }

  Widget _buildMacroRow(IconData icon, String name, double consumed, double goal, Color color) {
    final pct = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: () => _showAddDialog(
        context: context,
        title: 'Add $name',
        unit: 'g',
        color: color,
        onSubmit: (val) {
          final repo = RepositoryProvider.of<TrackerRepository>(context);
          final cal = name == 'Protein' || name == 'Carbs' ? val * 4 : val * 9;
          repo.logManualMeal(
            mealName: name,
            calories: cal,
            protein: name == 'Protein' ? val : 0,
            carbs: name == 'Carbs' ? val : 0,
            fats: name == 'Fats' ? val : 0,
          ).then((_) => context.read<DashboardBloc>().add(const RefreshDashboard()));
        },
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${consumed.round()}g / ${goal.round()}g',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSquareAction(Icons.search_rounded, () => Navigator.pushNamed(context, '/foods/search')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSquareAction(Icons.camera_enhance_rounded, () => showScanMealSheet(context)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSquareAction(Icons.add_rounded, () => showQuickLogSheet(context), iconColor: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildSquareAction(IconData icon, VoidCallback onTap, {Color iconColor = AppColors.textPrimary}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: 28),
        ),
      ),
    );
  }

  Widget _buildWeightCard(double weight) {
    final spots = const [
      FlSpot(0, 82.5), FlSpot(1, 82.0), FlSpot(2, 81.8), FlSpot(3, 81.5), FlSpot(4, 81.0)
    ];
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/weight/progress'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            SizedBox(
              height: 80,
              width: double.infinity,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.warning,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppColors.warning.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.monitor_weight_outlined, size: 24, color: AppColors.warning),
                const SizedBox(height: 8),
                Text('${weight} kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Text('Current Weight', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCarousel() {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Card 1: Challenge
          Container(
            width: 240,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Challenge', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Text('10k Steps!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    SizedBox(width: 6),
                    Icon(Icons.sync_rounded, size: 14, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: 0.75,
                            backgroundColor: AppColors.surfaceVariant,
                            color: AppColors.primary,
                            strokeWidth: 6,
                          ),
                        ),
                        const Text('7.5k', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Card 2: Recipe
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              image: const DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&q=80'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Recipe Idea', style: TextStyle(fontSize: 12, color: Colors.white70)),
                SizedBox(height: 4),
                Text('Lemon Herb Quinoa Salad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog({
    required BuildContext context,
    required String title,
    required String unit,
    required Color color,
    required void Function(double) onSubmit,
  }) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            suffixText: unit,
            suffixStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          onSubmitted: (_) {
            final val = double.tryParse(ctrl.text);
            if (val != null && val > 0) {
              Navigator.pop(ctx);
              onSubmit(val);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                onSubmit(val);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSuggestionBanner(double proteinConsumed, double proteinGoal) {
    final double deficit = (proteinGoal - proteinConsumed).clamp(0.0, double.infinity);
    if (deficit <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        setState(() {
          _showSmartSuggestion = true;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.15),
              AppColors.primary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.tips_and_updates_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "💡 AI Suggestion Available",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "You're short of your protein goal. Complete your meal now & get +50 points!",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartSuggestionModal(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.88,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24), // For symmetry
              const Text(
                "Complete Your Meal!",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showSmartSuggestion = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Meal scanning context (Row)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Food Thumbnail
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                    width: 1.5,
                  ),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=200&q=80',
                    ),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // AI Text description
              const Expanded(
                child: Text(
                  "You're 20g short of your Protein goal for this meal! 💡",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Product Showcase
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SPONSORED RECOMMENDATION",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Product image
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1607349913338-fca6f7fc42d0?w=200&q=80',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Product Details
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Teneen Max Protein Bar",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "22g Protein  •  190 kcal",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Organic, Gluten-Free",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Get it Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shadowColor: AppColors.primary.withOpacity(0.3),
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: () {
                setState(() {
                  _showSmartSuggestion = false;
                });
                _showRewardSuccessDialog(context);
              },
              child: const Text(
                "Get it (+50 Points)",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRewardSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.stars_rounded, color: AppColors.primary, size: 60),
            SizedBox(height: 12),
            Text(
              'Points Claimed!',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You earned +50 Points for choosing a healthy option!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROMO CODE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('TENEEN50', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: 'TENEEN50'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                    label: const Text('Copy', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Awesome!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
