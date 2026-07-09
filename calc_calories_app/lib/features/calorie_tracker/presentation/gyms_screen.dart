// lib/features/calorie_tracker/presentation/gyms_screen.dart
// The Teneen — Minimalist Gyms Exploration & Check-In screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class GymsScreen extends StatefulWidget {
  const GymsScreen({super.key});

  @override
  State<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends State<GymsScreen> {
  int _activeCategoryIndex = 0;

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'الصالات الشريكة' : 'Partner Gyms',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildCairoTag(isArabic),
                ],
              ),
            ),

            // ── Minimal Smart Check-In Alert (No Large Box) ─────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildCheckInAlert(isArabic),
            ),

            const SizedBox(height: 12),

            // ── Micro-Filter Tabs ────────────────────────────────────
            _buildMicroFilters(isArabic),

            const SizedBox(height: 20),

            // ── Gym Cards List (Compact Minimalist Grid) ──────────────
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 90), // Spacing for bottom nav
                itemCount: _getGymDataForCategory(_activeCategoryIndex, isArabic).length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final gym = _getGymDataForCategory(_activeCategoryIndex, isArabic)[index];
                  return _buildMinimalistGymCard(gym, isArabic);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header: Cairo Capsule Tag ─────────────────────────────────────
  Widget _buildCairoTag(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        isArabic ? 'القاهرة' : 'Cairo',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // ── Minimal Smart Check-In Alert ──────────────────────────────────
  Widget _buildCheckInAlert(bool isArabic) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              isArabic ? 'جاري التحقق من الموقع لتسجيل الحضور...' : 'Verifying location for check-in...',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.flash_on_rounded,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isArabic
                    ? '✨ بالقرب من H2O Gym! اضغط لتسجيل الحضور (+٢٠ ن)'
                    : '✨ Near H2O Gym! Tap to Check-In (+20 Pts)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Micro-Filter Tabs ─────────────────────────────────────────────
  Widget _buildMicroFilters(bool isArabic) {
    final List<Map<String, String>> categories = [
      {'en': 'Premium', 'ar': 'ممتازة'},
      {'en': 'Ladies', 'ar': 'سيدات'},
      {'en': 'CrossFit', 'ar': 'كروس فت'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(categories.length, (index) {
          final isSelected = _activeCategoryIndex == index;
          final label = isArabic ? categories[index]['ar']! : categories[index]['en']!;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _activeCategoryIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.transparent : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Compact Minimalist Gym Card Builder ───────────────────────────
  Widget _buildMinimalistGymCard(Map<String, dynamic> gym, bool isArabic) {
    return Container(
      width: double.infinity,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        child: Stack(
          children: [
            // Dark graphic layout background representing a blurred gym photo
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      AppColors.surface.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
            // Background vector weights icon decoration
            Positioned(
              right: isArabic ? null : 16,
              left: isArabic ? 16 : null,
              top: 0,
              bottom: 0,
              child: const Opacity(
                opacity: 0.08,
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Line: Gym Name left, distance right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        gym['name'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${gym['distance']} km',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),

                  // Bottom Line: Price left, teal discount badge right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        gym['price'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          gym['badge'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mock Gyms Database ────────────────────────────────────────────
  List<Map<String, dynamic>> _getGymDataForCategory(int categoryIndex, bool isArabic) {
    if (categoryIndex == 0) {
      // Premium Category
      return [
        {
          'name': 'H2O Gym & Spa',
          'distance': 0.5,
          'badge': '10% OFF',
          'price': isArabic ? '١,٢٠٠ ج.م/شهرياً' : 'EGP 1,200/mo',
        },
        {
          'name': 'Gold’s Gym Cairo',
          'distance': 1.8,
          'badge': 'FREE PASS',
          'price': isArabic ? '١,٨٠٠ ج.م/شهرياً' : 'EGP 1,800/mo',
        },
      ];
    } else if (categoryIndex == 1) {
      // Ladies Only
      return [
        {
          'name': 'Hers Fitness Studio',
          'distance': 0.9,
          'badge': '15% OFF',
          'price': isArabic ? '١,١٠٠ ج.م/شهرياً' : 'EGP 1,100/mo',
        },
      ];
    } else {
      // CrossFit
      return [
        {
          'name': 'BeFit 360 Box',
          'distance': 2.4,
          'badge': '1 FREE SESSION',
          'price': isArabic ? '١,٤٠0 ج.م/شهرياً' : 'EGP 1,400/mo',
        },
      ];
    }
  }
}
