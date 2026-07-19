// lib/features/calorie_tracker/presentation/home_shell_screen.dart
// The Teneen — Tabbed Navigation Shell

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_state.dart';
import 'bloc/dashboard_bloc.dart';
import 'bloc/dashboard_state.dart';
import 'bloc/dashboard_event.dart';
import 'meals_dashboard_screen.dart';
import 'gyms_screen.dart';
import 'market_screen.dart';
import 'workout_screen.dart';
import 'settings_screen.dart';
import 'widgets/quick_log_bottom_sheet.dart';

class DashboardTabWrapper extends StatelessWidget {
  const DashboardTabWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, profileState) {
        if (profileState is ProfileLoaded) {
          final dashboardState = context.read<DashboardBloc>().state;
          if (dashboardState is DashboardLoaded) {
            context.read<DashboardBloc>().add(const LoadDashboard());
          }
        }
      },
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardInitial) {
            context.read<DashboardBloc>().add(const LoadDashboard());
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }
        if (state is DashboardLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }
        if (state is DashboardLoaded) {
          return MealsDashboard(
            foodSummary: state.foodSummary,
            mealLogs: null,
          );
        }
        if (state is DashboardFailure) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<DashboardBloc>().add(const LoadDashboard()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        );
      },
    );
  }
}

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardTabWrapper(),
    const WorkoutScreen(),
    const MarketScreen(),
    const GymsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCustomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomNavBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.home_rounded, 0, false),
          _buildNavItem(Icons.fitness_center_rounded, 1, true),
          _buildNavItem(Icons.shopping_bag_rounded, 2, false),
          _buildNavItem(Icons.location_on_rounded, 3, false),
          _buildNavItem(Icons.person_rounded, 4, false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, bool hasHalo) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 70,
        child: Center(
          child: Container(
            decoration: isSelected && hasHalo
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: Icon(icon, color: color, size: 28),
          ),
        ),
      ),
    );
  }
}
