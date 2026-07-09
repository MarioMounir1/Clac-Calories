// lib/features/calorie_tracker/presentation/gyms_screen.dart
// The Teneen — Gyms Exploration & Check-In screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class GymsScreen extends StatefulWidget {
  const GymsScreen({super.key});

  @override
  State<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends State<GymsScreen> with SingleTickerProviderStateMixin {
  int _activeCategoryIndex = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Pulse animation for the green location indicator and the QR code check-in button glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
                    isArabic ? 'الصالات الشريكة' : 'Partner Gyms',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildLocationIndicator(isArabic),
                ],
              ),
            ),

            // ── Scrollable Body Area ──────────────────────────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 90), // Spacing for custom bottom nav
                children: [
                  // Check-In Hero Widget
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _buildCheckInHeroCard(isArabic),
                  ),

                  const SizedBox(height: 16),

                  // Gym Categories (Filters)
                  _buildCategoriesSection(isArabic),

                  const SizedBox(height: 20),

                  // Section Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      isArabic ? 'الصالات المتاحة بالقرب منك' : 'Gyms Nearby',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Gym Cards List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildGymCardsList(isArabic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header: Location Indicator ────────────────────────────────────
  Widget _buildLocationIndicator(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Opacity(
                opacity: 0.5 + (_pulseController.value * 0.5),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent,
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            isArabic ? 'القاهرة، مصر' : 'Cairo, Egypt',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Check-In Hero Widget ──────────────────────────────────────────
  Widget _buildCheckInHeroCard(bool isArabic) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'أنت بالقرب من صالة H2O الرياضية! 🏋️‍♂️'
                        : 'You are near H2O Gym & Spa! 🏋️‍♂️',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Large glowing scan QR button
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double glowVal = _pulseController.value;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2 + (glowVal * 0.2)),
                        blurRadius: 12 + (glowVal * 6),
                        spreadRadius: 1 + (glowVal * 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      // Trigger scan callback mock
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            isArabic ? 'جاري فتح الكاميرا للمسح...' : 'Opening camera to scan...',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isArabic
                              ? 'امسح الرمز لتسجيل الحضور (+٢٠ نقطة)'
                              : 'Scan QR to Check-In (+20 Pts)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Categories Filters Pill list ──────────────────────────────────
  Widget _buildCategoriesSection(bool isArabic) {
    final List<Map<String, String>> categories = [
      {'en': 'Premium', 'ar': 'ممتازة'},
      {'en': 'Ladies Only', 'ar': 'سيدات فقط'},
      {'en': 'CrossFit', 'ar': 'كروس فت'},
      {'en': 'Powerlifting Friendly', 'ar': 'رفع أثقال'},
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
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Gym Cards list builder ────────────────────────────────────────
  Widget _buildGymCardsList(bool isArabic) {
    final List<Map<String, dynamic>> gyms = _getGymDataForCategory(_activeCategoryIndex, isArabic);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: gyms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final gym = gyms[index];
        return _buildGymCard(gym, isArabic);
      },
    );
  }

  // ── Single Gym Card Builder ───────────────────────────────────────
  Widget _buildGymCard(Map<String, dynamic> gym, bool isArabic) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphic header image area
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceVariant,
                  AppColors.surface,
                  AppColors.surfaceVariant,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Gym themed icon graphic representation
                Center(
                  child: Icon(
                    Icons.store_mall_directory_rounded,
                    color: AppColors.primary.withValues(alpha: 0.35),
                    size: 60,
                  ),
                ),

                // Sponsored / Distance badge
                Positioned(
                  top: 12,
                  left: isArabic ? null : 12,
                  right: isArabic ? 12 : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Text(
                      '${gym['distance']} km',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),

                // Special Deal Badge overlay
                Positioned(
                  bottom: 12,
                  left: isArabic ? null : 12,
                  right: isArabic ? 12 : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: Text(
                      gym['badge'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gym['name'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic ? 'صالة لياقة بدنية ممتازة' : 'High Performance Fitness',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  gym['price'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          'badge': isArabic ? 'خصم ١٠٪ عبر التنين' : '10% OFF Memberships via Teneen',
          'price': isArabic ? '١,٢٠٠ ج.م/شهرياً' : 'EGP 1,200/Month',
        },
        {
          'name': 'Gold’s Gym Cairo',
          'distance': 1.8,
          'badge': isArabic ? 'حصة تجريبية مجانية' : 'Free Trial Pass via Teneen',
          'price': isArabic ? '١,٨٠٠ ج.م/شهرياً' : 'EGP 1,800/Month',
        },
      ];
    } else if (categoryIndex == 1) {
      // Ladies Only
      return [
        {
          'name': 'Hers Fitness Studio',
          'distance': 0.9,
          'badge': isArabic ? 'ساعة مجانية استشارة' : 'Free 1h Consultation',
          'price': isArabic ? '١,١٠٠ ج.م/شهرياً' : 'EGP 1,100/Month',
        },
      ];
    } else if (categoryIndex == 2) {
      // CrossFit
      return [
        {
          'name': 'BeFit 360 Box',
          'distance': 2.4,
          'badge': isArabic ? 'تحدي تمرين مجاني' : '1 Free Challenge Access',
          'price': isArabic ? '١,٤٠0 ج.م/شهرياً' : 'EGP 1,400/Month',
        },
      ];
    } else {
      // Powerlifting Friendly
      return [
        {
          'name': 'Iron House Gym',
          'distance': 1.2,
          'badge': isArabic ? 'تذكرة يومية: ١٥٠ ج.م' : 'Teneen Day Pass: EGP 150',
          'price': isArabic ? '١٥٠ ج.م/يومياً' : 'EGP 150/Day',
        },
      ];
    }
  }
}
