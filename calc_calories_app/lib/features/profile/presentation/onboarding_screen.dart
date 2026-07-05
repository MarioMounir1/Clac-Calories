// lib/features/profile/presentation/onboarding_screen.dart
// The Teneen — 4-Step Interactive Onboarding Wizard

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_event.dart';
import '../../profile/presentation/bloc/profile_state.dart';
import '../../../main.dart';
import '../../../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 2 variables
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'male';

  // Step 3 variables
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _activityLevel = 'moderate';

  // Step 4 variables
  String _goal = 'maintain';

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _nextStep(AppLocalizations l10n) {
    if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty || _ageController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorGeneric),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (_weightController.text.trim().isEmpty || _heightController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorGeneric),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 25;
    final weight = double.tryParse(_weightController.text.trim()) ?? 70.0;
    final height = double.tryParse(_heightController.text.trim()) ?? 170.0;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    context.read<ProfileBloc>().add(
          UpdateProfileEvent(
            name: name,
            age: age,
            weightKg: weight,
            heightCm: height,
            gender: _gender,
            activityLevel: _activityLevel,
            goal: _goal,
            language: isArabic ? 'ar' : 'en',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileUpdateSuccess) {
            context.read<ProfileBloc>().add(CompleteOnboardingEvent());
            Navigator.pushReplacementNamed(context, '/');
          } else if (state is ProfileFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              // ── Header Progress Indicator ─────────────────────────
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: List.generate(4, (index) {
                    final isActive = index <= _currentStep;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(
                          right: index < 3 && !isArabic ? 8 : 0,
                          left: index < 3 && isArabic ? 8 : 0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: isActive ? AppColors.primary : AppColors.border,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // ── Step Content (PageView) ───────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() {
                      _currentStep = page;
                    });
                  },
                  children: [
                    _buildLanguageStep(l10n),
                    _buildBasicInfoStep(l10n),
                    _buildPhysicalStep(l10n),
                    _buildGoalStep(l10n),
                  ],
                ),
              ),

              // ── Bottom Navigation ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      OutlinedButton(
                        onPressed: _prevStep,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          l10n.backButton,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => _nextStep(l10n),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _currentStep == 3 ? l10n.doneButton : l10n.continueButton,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 1: Language Selection ─────────────────────────────

  Widget _buildLanguageStep(AppLocalizations l10n) {
    final currentLang = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.language_rounded, size: 72, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            l10n.onboardingLanguageTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingLanguageSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 48),
          _buildLanguageCard(
            title: 'العربية (Egyptian Arabic)',
            langCode: 'ar',
            isActive: currentLang == 'ar',
          ),
          const SizedBox(height: 16),
          _buildLanguageCard(
            title: 'English (US/UK)',
            langCode: 'en',
            isActive: currentLang == 'en',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({required String title, required String langCode, required bool isActive}) {
    return InkWell(
      onTap: () {
        context.read<LanguageCubit>().setLanguage(langCode);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 2 : 1,
          ),
          color: isActive ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: Name, Gender, Age ──────────────────────────────

  Widget _buildBasicInfoStep(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              l10n.onboardingProfileTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.onboardingProfileSubtitle,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 36),
            Text(
              l10n.profileName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l10n.authName,
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.profileAge,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 25',
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.profileGender,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildGenderCard(
                    title: l10n.profileGenderMale,
                    genderCode: 'male',
                    icon: Icons.male_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGenderCard(
                    title: l10n.profileGenderFemale,
                    genderCode: 'female',
                    icon: Icons.female_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard({required String title, required String genderCode, required IconData icon}) {
    final isActive = _gender == genderCode;
    return InkWell(
      onTap: () => setState(() => _gender = genderCode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 2 : 1,
          ),
          color: isActive ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isActive ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 3: Weight, Height, Activity ───────────────────────

  Widget _buildPhysicalStep(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              l10n.onboardingBodyTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.onboardingBodySubtitle,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profileWeight,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'kg'),
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profileHeight,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'cm'),
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.profileActivity,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            _buildActivityOption(
              value: 'sedentary',
              title: l10n.onboardingActivitySedentary,
              desc: l10n.onboardingActivitySedentaryDesc,
            ),
            const SizedBox(height: 12),
            _buildActivityOption(
              value: 'lightly_active',
              title: l10n.onboardingActivityLight,
              desc: l10n.onboardingActivityLightDesc,
            ),
            const SizedBox(height: 12),
            _buildActivityOption(
              value: 'moderate',
              title: l10n.onboardingActivityModerate,
              desc: l10n.onboardingActivityModerateDesc,
            ),
            const SizedBox(height: 12),
            _buildActivityOption(
              value: 'very_active',
              title: l10n.onboardingActivityVeryActive,
              desc: l10n.onboardingActivityVeryActiveDesc,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityOption({required String value, required String title, required String desc}) {
    final isActive = _activityLevel == value;
    return InkWell(
      onTap: () => setState(() => _activityLevel = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 2 : 1,
          ),
          color: isActive ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary)
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── STEP 4: Goal Selection ─────────────────────────────────

  Widget _buildGoalStep(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            l10n.onboardingGoalTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingGoalSubtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 48),
          _buildGoalCard(
            value: 'lose',
            title: l10n.onboardingGoalLose,
            icon: Icons.trending_down_rounded,
          ),
          const SizedBox(height: 16),
          _buildGoalCard(
            value: 'maintain',
            title: l10n.onboardingGoalMaintain,
            icon: Icons.trending_flat_rounded,
          ),
          const SizedBox(height: 16),
          _buildGoalCard(
            value: 'gain',
            title: l10n.onboardingGoalGain,
            icon: Icons.trending_up_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard({required String value, required String title, required IconData icon}) {
    final isActive = _goal == value;
    return InkWell(
      onTap: () => setState(() => _goal = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 2 : 1,
          ),
          color: isActive ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: isActive ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
