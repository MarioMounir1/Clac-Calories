// lib/features/calorie_tracker/presentation/home_shell_screen.dart
// The Teneen — Tabbed Navigation Shell

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

import 'dashboard_screen.dart';
import 'analyze_meal_screen.dart';
import 'food_search_screen.dart';
import 'meal_plans_screen.dart';
import 'settings_screen.dart';
import 'widgets/quick_log_bottom_sheet.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const FoodSearchScreen(),
    const AnalyzeMealScreen(),
    const MealPlansScreen(),
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
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Background Bar
        Container(
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
              _buildNavItem(Icons.home_rounded, 0, true),
              _buildNavItem(Icons.search_rounded, 1, false),
              _buildNavItem(Icons.camera_enhance_rounded, 2, false),
              _buildNavItem(Icons.calendar_month_rounded, 3, false),
              _buildNavItem(Icons.person_rounded, 4, false),
            ],
          ),
        ),
        // Floating Action Button (above center)
        Positioned(
          top: -30,
          child: GestureDetector(
            onTap: () => showQuickLogSheet(context),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
            ),
          ),
        ),
      ],
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
