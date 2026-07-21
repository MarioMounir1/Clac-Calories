// lib/features/premium/presentation/premium_upgrade_screen.dart

import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_client.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_event.dart';

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
      // Mock endpoint — we will implement this on the backend
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
            content: Text('Failed to upgrade: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  void _showMockPaymentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          bool processing = false;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF121824),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0xFF222B3F), width: 1.5)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Confirm Subscription Payment',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You are subscribing to Aura Premium for \$1.00 / month. Enter mock billing info to proceed.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Mock Card Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2232),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF222B3F)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, color: Color(0xFF00BCD4), size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '•••• •••• •••• 4242',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          'MOCK',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: processing ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF222B3F)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: processing ? null : () async {
                            setModalState(() => processing = true);
                            // Simulate payment processing time
                            await Future.delayed(const Duration(seconds: 2));
                            if (mounted) {
                              Navigator.pop(context); // Close sheet
                              _completeUpgradeBackend(); // Call backend to set premium flag
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981), // Green pay button
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: processing
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text('Pay \$1.00', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        title: '7 Daily Smart Scans',
                        subtitle: 'Instantly analyze meals with camera or gallery.',
                      ),
                      const SizedBox(height: 24),
                      _buildFeatureRow(
                        icon: Icons.fitness_center_rounded,
                        title: 'Full Workout Hub',
                        subtitle: 'Live session tracking & advanced analytics.',
                      ),
                      const SizedBox(height: 24),
                      _buildFeatureRow(
                        icon: Icons.block_rounded,
                        title: 'Ad-Free Experience',
                        subtitle: 'Focus entirely on your goals without distractions.',
                      ),
                      
                      const Spacer(),
                      
                      // Purchase Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isUpgrading ? null : _showMockPaymentDialog,
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
                              : const Text(
                                  'Subscribe for \$1',
                                  style: TextStyle(
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
