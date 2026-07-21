// lib/features/premium/presentation/custom_paywall_sheet.dart

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_event.dart';
import '../data/services/purchase_service.dart';

class CustomPaywallSheet extends StatefulWidget {
  const CustomPaywallSheet({super.key});

  @override
  State<CustomPaywallSheet> createState() => _CustomPaywallSheetState();
}

class _CustomPaywallSheetState extends State<CustomPaywallSheet> {
  Offerings? _offerings;
  bool _loadingOfferings = true;
  String? _offeringsError;
  bool _isUpgrading = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await PurchaseService.instance.fetchOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _loadingOfferings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _offeringsError = e.toString();
          _loadingOfferings = false;
        });
      }
    }
  }

  Future<void> _handleSubscribe(Package? package) async {
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active RevenueCat subscription package loaded. Please check offerings setup.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isUpgrading = true);
    try {
      final bool success = await PurchaseService.instance.purchasePackage(package);

      if (success) {
        final dio = ApiClient().dio;
        final response = await dio.post('/users/subscribe');
        
        final data = response.data;
        final bool isBackendSuccess = response.statusCode == 200 || 
                                      response.statusCode == 201 ||
                                      (data != null && data['success'] == true);

        if (isBackendSuccess) {
          PurchaseService.instance.setMockPremiumStatus(true);
          if (mounted) {
            context.read<ProfileBloc>().add(const UpdatePremiumStatus(true));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Welcome to Aura Premium!'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          throw Exception('Backend failed to confirm premium subscription.');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase was not completed or entitlement is not active.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpgrading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = _offerings?.current?.monthly;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Top Drag Handle
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            // Close Button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 24),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Premium Icon Badge
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFBBF24).withOpacity(0.12),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFBBF24).withOpacity(0.2),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          size: 42,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Unlock Aura Premium',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Get unlimited AI nutrition analysis, progressive workout tracking & an ad-free experience.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Features Section
                    _buildFeatureItem(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppColors.primary,
                      title: 'Smart AI Meal Scanner',
                      subtitle: 'Offline, private and instant meal analysis.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.fitness_center_rounded,
                      iconColor: const Color(0xFF2196F3),
                      title: 'Pro Workout Tracker',
                      subtitle: 'Live session tracking with progressive overload analytics.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.repeat_rounded,
                      iconColor: const Color(0xFF9C27B0),
                      title: 'Unlimited Training Splits',
                      subtitle: 'Custom routine builder with zero caps.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.block_rounded,
                      iconColor: const Color(0xFFFBBF24),
                      title: '100% Ad-Free Experience',
                      subtitle: 'Focus entirely on your health without interruptions.',
                    ),
                    const SizedBox(height: 24),
                    // Pricing Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withOpacity(0.4),
                          width: 1.5,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.surfaceVariant.withOpacity(0.8),
                            AppColors.surface.withOpacity(0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.stars_rounded,
                              color: Color(0xFFFBBF24),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monthly Membership',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cancel anytime, no commitment',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$1.00',
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                              Text(
                                '/month',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Subscribe Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: _loadingOfferings
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFBBF24),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _isUpgrading
                                  ? null
                                  : () => _handleSubscribe(package),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFBBF24),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isUpgrading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black87,
                                      ),
                                    )
                                  : Text(
                                      'Join Premium — \$1.00/mo',
                                      style: GoogleFonts.inter(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Auto-renews monthly. Manage or cancel anytime.',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
