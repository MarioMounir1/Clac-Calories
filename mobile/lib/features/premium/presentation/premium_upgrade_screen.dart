// lib/features/premium/presentation/premium_upgrade_screen.dart

import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/network/api_client.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_event.dart';
import '../data/services/purchase_service.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  Offerings? _offerings;
  bool _loadingOfferings = true;
  String? _offeringsError;
  bool _isUpgrading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeUpgradeBackend() async {
    setState(() => _isUpgrading = true);
    
    try {
      final dio = ApiClient().dio;
      // Tell backend user is now premium. (Backend verification step next)
      await dio.post('/users/me/upgrade');
      
      // Refresh profile to pull the new isPremium status
      if (mounted) {
        context.read<ProfileBloc>().add(LoadProfile());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Aura Premium!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context); // Close the screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync profile: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  Future<void> _handleSubscribe(Package? package) async {
    setState(() => _isUpgrading = true);
    try {
      if (package != null) {
        // Perform RevenueCat Purchase
        final success = await PurchaseService.instance.purchaseSubPackage(package);
        if (success && mounted) {
          await _completeUpgradeBackend(); // Sync subscription to DB
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Subscription purchase was not completed.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // Fallback mock checkout since package is null (RevenueCat not configured yet)
        await Future.delayed(const Duration(seconds: 1));
        PurchaseService.instance.setMockPremiumStatus(true);
        if (mounted) {
          await _completeUpgradeBackend();
        }
      }
    } catch (e) {
      if (mounted) {
        // Graceful error handling (no raw system dialogs)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFF44336),
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

    return Scaffold(
      backgroundColor: const Color(0xFF090C15), // Deep dark bg
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFBBF24).withOpacity(0.15), // Amber glow
                // ignore: prefer_const_constructors
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      
                      // Premium Icon/Badge
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFBBF24).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 64,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      const Text(
                        'Unlock Aura Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      const Text(
                        'Get the ultimate AI-powered nutrition and fitness experience for just \$1/month.',
                        style: TextStyle(
                          color: Color(0xFF8E929C),
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Features List
                      _buildFeatureRow(
                        icon: Icons.auto_awesome,
                        title: 'Offline AI Meal Scanner',
                        subtitle: 'Instantly analyze meals with camera or gallery.',
                      ),
                      const SizedBox(height: 18),
                      _buildFeatureRow(
                        icon: Icons.fitness_center_rounded,
                        title: 'Smart Set Tracker & Progressive Overload',
                        subtitle: 'Live session tracking & advanced analytics.',
                      ),
                      const SizedBox(height: 18),
                      _buildFeatureRow(
                        icon: Icons.repeat_rounded,
                        title: 'Unlimited Workout Splits',
                        subtitle: 'Design and customize your ultimate routines.',
                      ),
                      const SizedBox(height: 18),
                      _buildFeatureRow(
                        icon: Icons.block_rounded,
                        title: '100% Ad-Free',
                        subtitle: 'Focus entirely on your goals without distractions.',
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Pricing Option (ONLY ONE)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121824).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFBBF24).withOpacity(0.3),
                            width: 1.5,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1B2232).withOpacity(0.6),
                              const Color(0xFF121824).withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFBBF24).withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBBF24).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
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
                                    'Monthly Premium Access',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cancel anytime, no commitment.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8E929C),
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
                                  package?.storeProduct.priceString ?? '\$1.00',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.extrabold,
                                    fontSize: 20,
                                  ),
                                ),
                                Text(
                                  '/mo',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8E929C),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Purchase Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
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
                                  backgroundColor: const Color(0xFFFBBF24), // Amber primary
                                  foregroundColor: Colors.black, // Dark text
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isUpgrading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black54,
                                        ),
                                      )
                                    : Text(
                                        'Subscribe Now — ${package?.storeProduct.priceString ?? "\$1.00"}/mo',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Cancel anytime. Subscription auto-renews monthly.',
                        style: TextStyle(
                          color: Color(0xFF5D616B),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF222B3F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF00BCD4), size: 24), // Cyan icon
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8E929C),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
