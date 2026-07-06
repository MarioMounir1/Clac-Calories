// lib/features/calorie_tracker/presentation/analyze_meal_screen.dart
// Calc-Calories — Main Meal Analysis Screen

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/admob_mock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/constants.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../domain/repositories/meal_repository.dart';
import 'bloc/calorie_tracker_bloc.dart';
import 'bloc/calorie_tracker_event.dart';
import 'bloc/calorie_tracker_state.dart';
import 'bloc/dashboard_bloc.dart';
import 'bloc/dashboard_event.dart';
import 'widgets/macro_ring_card.dart';

class AnalyzeMealScreen extends StatefulWidget {
  const AnalyzeMealScreen({super.key});

  @override
  State<AnalyzeMealScreen> createState() => _AnalyzeMealScreenState();
}

class _AnalyzeMealScreenState extends State<AnalyzeMealScreen>
    with TickerProviderStateMixin {
  final _restaurantController = TextEditingController();
  final _mealController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late AnimationController _inputAnimController;
  late Animation<double> _inputFadeAnim;

  // AdMob and Marketplace Recommendations states
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  List<dynamic> _suggestions = [];
  Map<String, dynamic> _deficit = {};
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _inputAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _inputFadeAnim = CurvedAnimation(
      parent: _inputAnimController,
      curve: Curves.easeOut,
    );
    _inputAnimController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      final isPremium = authState is Authenticated ? authState.isPremium : false;
      if (!isPremium) {
        _loadBannerAd();
        _fetchSuggestions();
      }
    });
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Google's official test ad unit ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _fetchSuggestions() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSuggestions = true;
    });
    final result = await RepositoryProvider.of<MealRepository>(context).getSuggestions();
    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isLoadingSuggestions = false;
          });
        }
      },
      (data) {
        if (mounted) {
          setState(() {
            _deficit = data['deficit'] as Map<String, dynamic>? ?? {};
            _suggestions = data['recommendations'] as List<dynamic>? ?? [];
            _isLoadingSuggestions = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _restaurantController.dispose();
    _mealController.dispose();
    _inputAnimController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile != null && mounted) {
        context.read<CalorieTrackerBloc>().add(
              ImageSelected(
                imagePath: pickedFile.path,
                restaurantName: _restaurantController.text.trim().isEmpty
                    ? null
                    : _restaurantController.text.trim(),
              ),
            );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera/gallery.')),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Scan Your Meal',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Take a photo of your meal or pick from gallery',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      subtitle: 'Take a photo now',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      subtitle: 'Pick existing photo',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitTextAnalysis() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<CalorieTrackerBloc>().add(
          AnalyzeTextMealSubmitted(
            // Restaurant is optional — empty string falls back to 'Homemade' on backend
            restaurantName: _restaurantController.text.trim().isEmpty
                ? 'Homemade'
                : _restaurantController.text.trim(),
            mealDescription: _mealController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isPremium = authState is Authenticated ? authState.isPremium : false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                color: Colors.black,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Calc Calories',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'Meal History',
          ),
        ],
      ),
      bottomNavigationBar: (!isPremium && _isAdLoaded && _bannerAd != null)
          ? SafeArea(
              child: Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
      body: BlocConsumer<CalorieTrackerBloc, CalorieTrackerState>(
        listener: (context, state) {
          if (state is CalorieTrackerFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          if (state is CalorieTrackerAnalysisSuccess) {
            // Backend already saved the meal to DB — refresh daily totals
            context.read<DashboardBloc>().add(const RefreshDashboard());
            if (!isPremium) {
              _fetchSuggestions();
            }
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeTransition(
                      opacity: _inputFadeAnim,
                      child: _buildInputSection(state),
                    ),

                    if (state is CalorieTrackerAnalyzing)
                      _buildLoadingIndicator(state.isImageMode),

                    if (state is CalorieTrackerAnalysisSuccess)
                      _buildResultSection(state),

                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputSection(CalorieTrackerState state) {
    final isLoading = state is CalorieTrackerAnalyzing;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ───────────────────────────────
          Text(
            'Track Your Meal',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter a meal or scan a screenshot for instant macros',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // ── Restaurant Autocomplete ──────────────────────
          Text(
            'Restaurant',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Autocomplete<String>(
            optionsBuilder: (textValue) {
              if (textValue.text.length < 2) return const [];
              return AppConstants.popularRestaurants.where(
                (r) => r.toLowerCase().contains(
                      textValue.text.toLowerCase(),
                    ),
              );
            },
            onSelected: (value) {
              _restaurantController.text = value;
            },
            fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
              // Sync with controller
              ctrl.text = _restaurantController.text;
              ctrl.addListener(() => _restaurantController.text = ctrl.text);
              return TextFormField(
                controller: ctrl,
                focusNode: focusNode,
                onFieldSubmitted: (_) => onSubmit(),
                enabled: !isLoading,
                decoration: const InputDecoration(
                  hintText: 'e.g. Buffalo Burger (optional)',
                  prefixIcon: Icon(
                    Icons.storefront_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              );
            },
            optionsViewBuilder: (ctx, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final opt = options.elementAt(i);
                        return ListTile(
                          dense: true,
                          title: Text(
                            opt,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onTap: () => onSelected(opt),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Meal Description ─────────────────────────────
          Text(
            'Meal Description',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _mealController,
            enabled: !isLoading,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. Single Bacon Mushroom Jack with large fries',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(
                  Icons.fastfood_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'Please describe the meal'
                : null,
          ),
          const SizedBox(height: 20),

          // ── Action Buttons ───────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _submitTextAnalysis,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Analyze Meal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : _showImageSourceSheet,
                  icon: const Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    'Scan',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reset button
          if (state is CalorieTrackerAnalysisSuccess)
            Center(
              child: TextButton(
                onPressed: () {
                  context.read<CalorieTrackerBloc>().add(
                        const ResetCalorieTracker(),
                      );
                  _mealController.clear();
                  _restaurantController.clear();
                },
                child: Text(
                  'Analyze another meal',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isImageMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
                Icon(
                  isImageMode
                      ? Icons.image_search_rounded
                      : Icons.psychology_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isImageMode
                ? 'Scanning your screenshot…'
                : 'Analyzing with AI…',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Calculating exact macros for your meal',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(CalorieTrackerAnalysisSuccess state) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Analysis Complete',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // ✅ Logged badge — appears immediately since backend already saved
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Added to today',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MacroRingCard(meal: state.mealLog),
          const SizedBox(height: 12),
          // ── View on Dashboard nudge ────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.dashboard_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This meal has been logged to your daily macros. Check the Home tab to see your updated progress.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Smart Fuel Suggestions',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._suggestions.map((prod) => TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0.0, 50 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.surface,
                            AppColors.surfaceVariant.withOpacity(0.5),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: Image.network(
                                prod['imageUrl'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppColors.border,
                                    child: const Icon(
                                      Icons.fitness_center_rounded,
                                      color: AppColors.primary,
                                      size: 32,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod['name'] ?? 'Protein Bar',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Deficit Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.bolt_rounded,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Fills ${prod['proteinContent']}g of your deficit',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Promo Code & Buy Button
                                Row(
                                  children: [
                                    // Promo badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primary.withOpacity(0.5),
                                          width: 1,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Text(
                                        'Code: ${prod['promoCode'] ?? 'TENEEN'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Buy Now Button
                                    ElevatedButton(
                                      onPressed: () {
                                        final url = prod['purchaseUrl'] as String?;
                                        if (url != null && url.isNotEmpty) {
                                          _launchURL(url);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'Buy Now',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
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
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Graceful fallback for environments without custom browser schemes
    }
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
