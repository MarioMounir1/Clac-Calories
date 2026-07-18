// lib/features/profile/presentation/onboarding_screen.dart
// The Teneen — Cal AI-Style 6-Step Onboarding Wizard
//
// Steps:
//   0  Welcome + Language
//   1  Goal Selection (5 options)
//   2  Basic Info (Age + Gender)
//   3  Body Stats (Height + Weight + Target Weight)
//   4  Activity Level (5 frequency tiers)
//   5  Plan Preview (TDEE + Macro + Workout suggestion)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_event.dart';
import '../../profile/presentation/bloc/profile_state.dart';
import '../../../main.dart';

// ── Design Tokens ─────────────────────────────────────────────
class _T {
  _T._();
  static const Color bg       = Color(0xFF090C15);
  static const Color card     = Color(0xFF121824);
  static const Color cardElev = Color(0xFF1B2232);
  static const Color border   = Color(0xFF222B3F);
  static const Color cyan     = Color(0xFF00BCD4);
  static const Color cyanDark = Color(0xFF0097A7);
  static const Color green    = Color(0xFF4CAF50);
  static const Color amber    = Color(0xFFFFC107);
  static const Color red      = Color(0xFFEF5350);
  static const Color blue     = Color(0xFF2196F3);
  static const Color purple   = Color(0xFF7C4DFF);
  static const Color textPri  = Color(0xFFFFFFFF);
  static const Color textSec  = Color(0xFF8E929C);
  static const Color textMut  = Color(0xFF5D616B);
}

// ── Goal Model ────────────────────────────────────────────────
class _GoalOption {
  final String id;           // backend value: lose | maintain | gain
  final String label;
  final String subtitle;
  final String emoji;
  final Color accent;
  final int calorieAdjust;
  const _GoalOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.accent,
    required this.calorieAdjust,
  });
}

const _goals = [
  _GoalOption(
    id: 'lose',
    label: 'Lose Weight Fast',
    subtitle: '750 kcal deficit · rapid fat loss',
    emoji: '🔥',
    accent: Color(0xFFEF5350),
    calorieAdjust: -750,
  ),
  _GoalOption(
    id: 'lose',
    label: 'Lose Weight Slowly',
    subtitle: '300 kcal deficit · sustainable pace',
    emoji: '🌿',
    accent: Color(0xFF4CAF50),
    calorieAdjust: -300,
  ),
  _GoalOption(
    id: 'maintain',
    label: 'Maintain Weight',
    subtitle: 'Stay at your current weight',
    emoji: '⚖️',
    accent: Color(0xFF00BCD4),
    calorieAdjust: 0,
  ),
  _GoalOption(
    id: 'gain',
    label: 'Gain Muscle Slowly',
    subtitle: '200 kcal surplus · lean gains',
    emoji: '💪',
    accent: Color(0xFF2196F3),
    calorieAdjust: 200,
  ),
  _GoalOption(
    id: 'gain',
    label: 'Gain Weight Fast',
    subtitle: '500 kcal surplus · aggressive bulk',
    emoji: '🦁',
    accent: Color(0xFF7C4DFF),
    calorieAdjust: 500,
  ),
];

// ── Activity Model ─────────────────────────────────────────────
class _ActivityOption {
  final String id;          // backend: sedentary | lightly_active | moderate | very_active
  final String label;
  final String frequency;
  final String emoji;
  final double multiplier;
  const _ActivityOption({
    required this.id,
    required this.label,
    required this.frequency,
    required this.emoji,
    required this.multiplier,
  });
}

const _activities = [
  _ActivityOption(
    id: 'sedentary',
    label: 'Sedentary',
    frequency: 'Office job · little or no exercise',
    emoji: '🪑',
    multiplier: 1.2,
  ),
  _ActivityOption(
    id: 'lightly_active',
    label: 'Lightly Active',
    frequency: 'I train 1–2 times a week',
    emoji: '🚶',
    multiplier: 1.375,
  ),
  _ActivityOption(
    id: 'moderate',
    label: 'Moderately Active',
    frequency: 'I train 3–4 times a week',
    emoji: '🏃',
    multiplier: 1.55,
  ),
  _ActivityOption(
    id: 'very_active',
    label: 'Very Active',
    frequency: 'I train 5–6 times a week',
    emoji: '⚡',
    multiplier: 1.725,
  ),
  _ActivityOption(
    id: 'very_active',
    label: 'Athlete',
    frequency: 'Daily training or physical job',
    emoji: '🏆',
    multiplier: 1.9,
  ),
];

// ── Workout Suggestions by Activity ───────────────────────────
String _suggestWorkoutSplit(String activityId, int daysPerWeek) {
  if (activityId == 'sedentary') return 'Full Body · 2–3×/week';
  if (activityId == 'lightly_active') return 'Upper / Lower Split · 3×/week';
  if (activityId == 'moderate') return 'Push / Pull / Legs · 4×/week';
  if (activityId == 'very_active' && daysPerWeek >= 5) return 'PPL + Arms / Shoulders · 5–6×/week';
  return 'Push / Pull / Legs · 4×/week';
}

// ── TDEE Calculation (Mifflin-St Jeor) ───────────────────────
Map<String, int> _calcTdee({
  required double weight,
  required double height,
  required int age,
  required String gender,
  required double multiplier,
  required int calorieAdjust,
}) {
  final genderFactor = gender == 'male' ? 5.0 : -161.0;
  final bmr = (10 * weight + 6.25 * height - 5 * age + genderFactor);
  final tdee = (bmr * multiplier).round();
  final recommended = math.max(1200, tdee + calorieAdjust);
  final protein = ((recommended * 0.30) / 4).round();
  final carbs   = ((recommended * 0.40) / 4).round();
  final fats    = ((recommended * 0.30) / 9).round();
  return {
    'bmr': bmr.round(),
    'tdee': tdee,
    'calories': recommended,
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
  };
}

// ══════════════════════════════════════════════════════════════
// OnboardingScreen
// ══════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // ── Step 1: Goal ──────────────────────────────────────────
  int _selectedGoalIndex = 2; // default: maintain

  // ── Step 2: Basic Info ────────────────────────────────────
  final _ageController = TextEditingController(text: '');
  String _gender = 'male';

  // ── Step 3: Body Stats ────────────────────────────────────
  final _heightController     = TextEditingController(text: '');
  final _weightController     = TextEditingController(text: '');
  final _targetWeightController = TextEditingController(text: '');

  // ── Step 4: Activity ──────────────────────────────────────
  int _selectedActivityIndex = 2; // default: moderate

  // ── Animation ─────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────
  void _nextStep() {
    if (!_validateCurrent()) return;
    HapticFeedback.lightImpact();
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _validateCurrent() {
    switch (_currentStep) {
      case 2:
        if (_ageController.text.trim().isEmpty) {
          _showError('Please enter your age');
          return false;
        }
        final age = int.tryParse(_ageController.text.trim());
        if (age == null || age < 10 || age > 100) {
          _showError('Please enter a valid age (10–100)');
          return false;
        }
        return true;
      case 3:
        final h = double.tryParse(_heightController.text.trim());
        final w = double.tryParse(_weightController.text.trim());
        if (h == null || h < 100 || h > 250) {
          _showError('Please enter a valid height (100–250 cm)');
          return false;
        }
        if (w == null || w < 30 || w > 400) {
          _showError('Please enter a valid weight (30–400 kg)');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: _T.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _finish() {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final goal       = _goals[_selectedGoalIndex];
    final activity   = _activities[_selectedActivityIndex];
    final age        = int.tryParse(_ageController.text.trim()) ?? 25;
    final height     = double.tryParse(_heightController.text.trim()) ?? 170.0;
    final weight     = double.tryParse(_weightController.text.trim()) ?? 70.0;
    final isArabic   = Localizations.localeOf(context).languageCode == 'ar';

    // Mark onboarding complete + update profile
    context.read<ProfileBloc>().add(CompleteOnboardingEvent());
    context.read<ProfileBloc>().add(UpdateProfileEvent(
      age: age,
      weightKg: weight,
      heightCm: height,
      gender: _gender,
      activityLevel: activity.id,
      goal: goal.id,
      language: isArabic ? 'ar' : 'en',
    ));
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: BlocListener<ProfileBloc, ProfileState>(
        listener: (ctx, state) {
          if (state is ProfileLoaded && state.isOnboardingCompleted) {
            Navigator.pushReplacementNamed(ctx, '/');
          } else if (state is ProfileFailure) {
            setState(() => _isSubmitting = false);
            _showError(state.message);
          }
        },
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (p) => setState(() => _currentStep = p),
                    children: [
                      _buildStep0_Language(),
                      _buildStep1_Goal(),
                      _buildStep2_BasicInfo(),
                      _buildStep3_BodyStats(),
                      _buildStep4_Activity(),
                      _buildStep5_PlanPreview(),
                    ],
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header: Progress + Step label ─────────────────────────
  Widget _buildHeader() {
    const stepLabels = [
      'Language', 'Your Goal', 'About You',
      'Body Stats', 'Activity', 'Your Plan',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Row(
            children: List.generate(6, (i) {
              final done = i < _currentStep;
              final active = i == _currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.only(right: i < 5 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: (done || active)
                        ? const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
                          )
                        : null,
                    color: (done || active) ? null : _T.border,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of 6',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _T.textMut,
                  fontWeight: FontWeight.w500,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  stepLabels[_currentStep],
                  key: ValueKey(_currentStep),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _T.cyan,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom navigation bar ──────────────────────────────────
  Widget _buildBottomBar() {
    final isFirst = _currentStep == 0;
    final isLast  = _currentStep == 5;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: _T.bg,
        border: Border(top: BorderSide(color: _T.border, width: 1)),
      ),
      child: Row(
        children: [
          if (!isFirst)
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _T.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: _T.textSec,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            const Spacer(flex: 2),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: _GradientButton(
              label: isLast ? 'Start My Journey 🚀' : 'Continue',
              isLoading: _isSubmitting && isLast,
              onTap: _nextStep,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 0 — Language Selection
  // ══════════════════════════════════════════════════════════

  Widget _buildStep0_Language() {
    final currentLang = Localizations.localeOf(context).languageCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _StepTitle(
            emoji: '🌍',
            title: 'Choose Your Language',
            subtitle: 'You can change this anytime in Settings.',
          ),
          const SizedBox(height: 32),
          _ChoiceCard(
            isSelected: currentLang == 'en',
            onTap: () => context.read<LanguageCubit>().setLanguage('en'),
            child: Row(
              children: [
                const Text('🇺🇸', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('English', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _T.textPri)),
                      Text('US / UK', style: GoogleFonts.inter(fontSize: 13, color: _T.textSec)),
                    ],
                  ),
                ),
                if (currentLang == 'en') const Icon(Icons.check_circle_rounded, color: _T.cyan),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            isSelected: currentLang == 'ar',
            onTap: () => context.read<LanguageCubit>().setLanguage('ar'),
            child: Row(
              children: [
                const Text('🇪🇬', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('العربية', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: _T.textPri)),
                      Text('Egyptian Arabic', style: GoogleFonts.inter(fontSize: 13, color: _T.textSec)),
                    ],
                  ),
                ),
                if (currentLang == 'ar') const Icon(Icons.check_circle_rounded, color: _T.cyan),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 1 — Goal Selection
  // ══════════════════════════════════════════════════════════

  Widget _buildStep1_Goal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _StepTitle(
            emoji: '🎯',
            title: 'What\'s your main goal?',
            subtitle: 'We\'ll build your personal plan around this.',
          ),
          const SizedBox(height: 24),
          ...List.generate(_goals.length, (i) {
            final g = _goals[i];
            final isSelected = _selectedGoalIndex == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalCard(
                goal: g,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedGoalIndex = i),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 2 — Basic Info (Age + Gender)
  // ══════════════════════════════════════════════════════════

  Widget _buildStep2_BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _StepTitle(
            emoji: '👤',
            title: 'Tell us about yourself',
            subtitle: 'Your age and gender help calculate your calorie needs accurately.',
          ),
          const SizedBox(height: 32),

          // Age
          _FieldLabel('How old are you?'),
          const SizedBox(height: 10),
          _NumberField(
            controller: _ageController,
            hint: 'e.g. 25',
            suffix: 'years',
          ),
          const SizedBox(height: 28),

          // Gender
          _FieldLabel('Biological sex'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  label: 'Male',
                  emoji: '♂️',
                  isSelected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderCard(
                  label: 'Female',
                  emoji: '♀️',
                  isSelected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Used for calorie calculations only. Not shared.',
            style: GoogleFonts.inter(fontSize: 11, color: _T.textMut),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 3 — Body Stats
  // ══════════════════════════════════════════════════════════

  Widget _buildStep3_BodyStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _StepTitle(
            emoji: '📏',
            title: 'Your body stats',
            subtitle: 'Used to calculate your exact calorie needs using the Mifflin-St Jeor formula.',
          ),
          const SizedBox(height: 32),

          // Height + Weight
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Height'),
                    const SizedBox(height: 10),
                    _NumberField(
                      controller: _heightController,
                      hint: '175',
                      suffix: 'cm',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Current Weight'),
                    const SizedBox(height: 10),
                    _NumberField(
                      controller: _weightController,
                      hint: '75',
                      suffix: 'kg',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Target Weight (optional)
          _FieldLabel('Target Weight (optional)'),
          const SizedBox(height: 10),
          _NumberField(
            controller: _targetWeightController,
            hint: 'e.g. 70',
            suffix: 'kg',
          ),
          const SizedBox(height: 8),
          Text(
            'Helps us estimate how long your journey will take.',
            style: GoogleFonts.inter(fontSize: 11, color: _T.textMut),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 4 — Activity Level
  // ══════════════════════════════════════════════════════════

  Widget _buildStep4_Activity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _StepTitle(
            emoji: '🏋️',
            title: 'How active are you?',
            subtitle: 'Include all workouts and physical activity on a typical week.',
          ),
          const SizedBox(height: 24),
          ...List.generate(_activities.length, (i) {
            final a = _activities[i];
            final isSelected = _selectedActivityIndex == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActivityCard(
                activity: a,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedActivityIndex = i),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 5 — Plan Preview
  // ══════════════════════════════════════════════════════════

  Widget _buildStep5_PlanPreview() {
    final weight   = double.tryParse(_weightController.text.trim()) ?? 70.0;
    final height   = double.tryParse(_heightController.text.trim()) ?? 170.0;
    final age      = int.tryParse(_ageController.text.trim()) ?? 25;
    final goal     = _goals[_selectedGoalIndex];
    final activity = _activities[_selectedActivityIndex];

    final tdee = _calcTdee(
      weight: weight,
      height: height,
      age: age,
      gender: _gender,
      multiplier: activity.multiplier,
      calorieAdjust: goal.calorieAdjust,
    );

    final workoutSplit = _suggestWorkoutSplit(
      activity.id,
      _selectedActivityIndex >= 3 ? 5 : (_selectedActivityIndex >= 2 ? 4 : _selectedActivityIndex + 1),
    );

    final targetW = double.tryParse(_targetWeightController.text.trim());
    String? timelineText;
    if (targetW != null && targetW != weight && goal.calorieAdjust != 0) {
      final diff = (weight - targetW).abs();
      final weeklyLossKg = goal.calorieAdjust.abs() / 7700.0 * 7;
      final weeks = (diff / weeklyLossKg).round();
      timelineText = 'Estimated ${weeks} weeks to reach ${targetW.toStringAsFixed(0)} kg';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _StepTitle(
            emoji: '✨',
            title: 'Your Personal Plan',
            subtitle: 'Built with Mifflin-St Jeor formula · Same as MyFitnessPal',
          ),
          const SizedBox(height: 20),

          // Main calories card
          _PlanCalorieCard(
            calories: tdee['calories']!,
            goalLabel: goal.label,
            goalEmoji: goal.emoji,
            goalAccent: goal.accent,
          ),
          const SizedBox(height: 14),

          // Macros row
          Row(
            children: [
              Expanded(child: _MacroTile(label: 'Protein', value: tdee['protein']!, unit: 'g', color: const Color(0xFF2196F3))),
              const SizedBox(width: 10),
              Expanded(child: _MacroTile(label: 'Carbs',   value: tdee['carbs']!,   unit: 'g', color: const Color(0xFFFFC107))),
              const SizedBox(width: 10),
              Expanded(child: _MacroTile(label: 'Fats',    value: tdee['fats']!,    unit: 'g', color: const Color(0xFFFF5722))),
            ],
          ),
          const SizedBox(height: 14),

          // Workout suggestion card
          _WorkoutSuggestionCard(split: workoutSplit, activityLabel: activity.label),
          const SizedBox(height: 14),

          // Timeline (optional)
          if (timelineText != null) ...[
            _TimelineCard(text: timelineText),
            const SizedBox(height: 14),
          ],

          // TDEE info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _T.cyan, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'BMR: ${tdee['bmr']} kcal/day · TDEE: ${tdee['tdee']} kcal/day',
                    style: GoogleFonts.inter(fontSize: 12, color: _T.textSec),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These numbers are automatically saved to your account and update your daily targets.',
            style: GoogleFonts.inter(fontSize: 11, color: _T.textMut),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════

class _StepTitle extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const _StepTitle({required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: _T.textPri,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 14, color: _T.textSec, height: 1.5),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _T.textSec,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  const _NumberField({required this.controller, required this.hint, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.inter(
        color: _T.textPri,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _T.textMut, fontWeight: FontWeight.w500),
        suffixText: suffix,
        suffixStyle: GoogleFonts.inter(color: _T.cyan, fontWeight: FontWeight.w700, fontSize: 14),
        filled: true,
        fillColor: _T.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.cyan, width: 1.5),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;
  const _ChoiceCard({required this.isSelected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? _T.cyan.withOpacity(0.08) : _T.card,
          border: Border.all(
            color: isSelected ? _T.cyan : _T.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;
  const _GenderCard({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? _T.cyan.withOpacity(0.08) : _T.card,
          border: Border.all(
            color: isSelected ? _T.cyan : _T.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _T.cyan : _T.textPri,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final _GoalOption goal;
  final bool isSelected;
  final VoidCallback onTap;
  const _GoalCard({required this.goal, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? goal.accent.withOpacity(0.10) : _T.card,
          border: Border.all(
            color: isSelected ? goal.accent : _T.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: goal.accent.withOpacity(0.15), blurRadius: 12, spreadRadius: 0)]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: goal.accent.withOpacity(0.15),
              ),
              child: Center(child: Text(goal.emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? goal.accent : _T.textPri,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    goal.subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: _T.textSec),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? goal.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? goal.accent : _T.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _ActivityOption activity;
  final bool isSelected;
  final VoidCallback onTap;
  const _ActivityCard({required this.activity, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? _T.cyan.withOpacity(0.08) : _T.card,
          border: Border.all(
            color: isSelected ? _T.cyan : _T.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _T.cyan.withOpacity(0.12), blurRadius: 12)]
              : [],
        ),
        child: Row(
          children: [
            Text(activity.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _T.cyan : _T.textPri,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.frequency,
                    style: GoogleFonts.inter(fontSize: 12, color: _T.textSec),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _T.cyan : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _T.cyan : _T.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plan Preview Widgets ──────────────────────────────────────

class _PlanCalorieCard extends StatelessWidget {
  final int calories;
  final String goalLabel;
  final String goalEmoji;
  final Color goalAccent;
  const _PlanCalorieCard({
    required this.calories,
    required this.goalLabel,
    required this.goalEmoji,
    required this.goalAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00BCD4).withOpacity(0.15),
            const Color(0xFF0097A7).withOpacity(0.08),
          ],
        ),
        border: Border.all(color: _T.cyan.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goalEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                goalLabel,
                style: GoogleFonts.inter(fontSize: 13, color: _T.textSec, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$calories',
                style: GoogleFonts.inter(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: _T.cyan,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 6),
                child: Text(
                  'kcal/day',
                  style: GoogleFonts.inter(fontSize: 16, color: _T.textSec, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your personalised daily calorie target',
            style: GoogleFonts.inter(fontSize: 13, color: _T.textSec),
          ),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final Color color;
  const _MacroTile({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _T.card,
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _T.textPri,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: _T.textSec),
          ),
        ],
      ),
    );
  }
}

class _WorkoutSuggestionCard extends StatelessWidget {
  final String split;
  final String activityLabel;
  const _WorkoutSuggestionCard({required this.split, required this.activityLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _T.card,
        border: Border.all(color: _T.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFF3F51B5)],
              ),
            ),
            child: const Center(child: Text('🏋️', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested Workout Plan',
                  style: GoogleFonts.inter(fontSize: 12, color: _T.textSec, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  split,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _T.textPri,
                  ),
                ),
                Text(
                  activityLabel,
                  style: GoogleFonts.inter(fontSize: 12, color: _T.textSec),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: _T.textMut, size: 14),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final String text;
  const _TimelineCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF4CAF50).withOpacity(0.08),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timeline_rounded, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient CTA Button ────────────────────────────────────────
class _GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  const _GradientButton({required this.label, required this.onTap, this.isLoading = false});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BCD4).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
