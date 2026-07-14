// lib/features/calorie_tracker/presentation/workout_screen.dart
// Calc-Calories — Workout Hub (Rebuilt)
//
// Architecture: StatefulWidget with WorkoutHubState enum
//   - WorkoutHubState.hub           → Landing view with streak, training card, calendar
//   - WorkoutHubState.questionnaire → Smart Routine Planner 2-step PageView flow
//
// All "AI" terminology removed. No external packages beyond google_fonts.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/workout_models.dart';

// ── Hub State Enum ────────────────────────────────────────────

enum WorkoutHubState { hub, questionnaire }

// ── Extended Colors (matching Meals Dashboard palette) ────────

class _C {
  _C._();
  static const Color bg         = Color(0xFF030712);
  static const Color card       = Color(0xFF0D1117);
  static const Color cardElev   = Color(0xFF111827);
  static const Color borderDim  = Color(0xFF1F2937);
  static const Color borderMid  = Color(0xFF374151);
  static const Color cyan       = Color(0xFF00B4D8);
  static const Color cyanGlow   = Color(0xFF0EA5E9);
  static const Color textPri    = Color(0xFFF9FAFB);
  static const Color textSec    = Color(0xFF9CA3AF);
  static const Color textMuted  = Color(0xFF6B7280);
  static const Color amber      = Color(0xFFFBBF24);
}

// ── WorkoutScreen ─────────────────────────────────────────────

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  // ── State machine ──────────────────────────────────────────
  WorkoutHubState _hubState = WorkoutHubState.hub;

  // ── Questionnaire state ────────────────────────────────────
  final PageController _pageController = PageController();
  int _questStep = 0;
  int? _selectedDays;
  int? _selectedRoutineIndex;

  // ── Animation controller for page transitions ──────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────

  void _enterQuestionnaire() {
    setState(() {
      _hubState = WorkoutHubState.questionnaire;
      _questStep = 0;
      _selectedDays = null;
      _selectedRoutineIndex = null;
    });
    _fadeCtrl
      ..reset()
      ..forward();
  }

  void _exitQuestionnaire() {
    setState(() => _hubState = WorkoutHubState.hub);
    _fadeCtrl
      ..reset()
      ..forward();
  }

  void _nextStep() {
    if (_questStep == 0 && _selectedDays != null) {
      setState(() {
        _questStep = 1;
        _selectedRoutineIndex = null;
      });
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_questStep == 1) {
      setState(() => _questStep = 0);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _exitQuestionnaire();
    }
  }

  void _finalizePlan() {
    if (_selectedDays == null || _selectedRoutineIndex == null) return;
    final suggestions = RoutineCatalogue.forDays(_selectedDays!);
    final chosen = suggestions[_selectedRoutineIndex!];

    _exitQuestionnaire();

    // Show success confirmation
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _buildPlanConfirmSheet(ctx, chosen),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: _hubState == WorkoutHubState.hub
              ? _buildHubView(isArabic)
              : _buildQuestionnaireView(isArabic),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HUB VIEW
  // ══════════════════════════════════════════════════════════════

  Widget _buildHubView(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'روتين التمرين' : 'Workout Hub',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _C.textPri,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic ? 'يوم الدفع اليوم' : 'Push Day scheduled today',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _C.textMuted,
                    ),
                  ),
                ],
              ),
              _buildStreakBadge(isArabic),
            ],
          ),
        ),

        // ── Scrollable Content ──────────────────────────────
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Setup Routine Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSetupRoutineButton(isArabic),
              ),

              const SizedBox(height: 20),

              // Today's Training Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTodayTrainingCard(isArabic),
              ),

              const SizedBox(height: 16),

              // Performance Quick-View
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPerformanceQuickView(isArabic),
              ),

              const SizedBox(height: 28),

              // Weekly Overview Label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'الأيام المكتملة' : 'Weekly Overview',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.textPri,
                      ),
                    ),
                    Text(
                      isArabic ? '٢ / ٧ أيام' : '2 / 7 days',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Weekly Calendar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildWeeklyCalendar(isArabic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Streak Badge ──────────────────────────────────────────

  Widget _buildStreakBadge(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _C.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.amber.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            isArabic ? 'تتابع ٥ أيام' : '5-Day Streak',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _C.amber,
            ),
          ),
        ],
      ),
    );
  }

  // ── Setup Routine Button ──────────────────────────────────

  Widget _buildSetupRoutineButton(bool isArabic) {
    return GestureDetector(
      onTap: _enterQuestionnaire,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _C.cyan.withValues(alpha: 0.15),
              _C.cyanGlow.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.cyan.withValues(alpha: 0.35), width: 1.4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _C.cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: _C.cyan, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'إعداد خطة التدريب' : 'Setup Your Routine Plan',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _C.textPri,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? 'اختر تردد التمرين والبرنامج المناسب'
                        : 'Pick your frequency & configure a training split',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _C.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _C.cyan, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Today's Training Card ─────────────────────────────────

  Widget _buildTodayTrainingCard(bool isArabic) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.borderDim, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session label badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _C.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _C.cyan.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(
                isArabic ? 'جلسة اليوم' : "TODAY'S SESSION",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _C.cyan,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Text(
              isArabic ? 'يوم الدفع — أسلوب RPT' : 'Push Day — RPT Style',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _C.textPri,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Exercise list
            _buildExercisePreviewRow(
              icon: Icons.fitness_center_rounded,
              text: isArabic
                  ? 'بنش برس  |  ضغط كتف  |  رفرفة مائل'
                  : 'Barbell Bench Press  ·  OHP  ·  Incline Flyes',
            ),
            const SizedBox(height: 4),
            _buildExercisePreviewRow(
              icon: Icons.access_time_rounded,
              text: isArabic ? 'المدة المتوقعة: ٥٥–٦٥ دقيقة' : 'Est. duration: 55–65 min',
            ),

            const SizedBox(height: 18),

            // Divider
            Divider(color: _C.borderDim, height: 1),
            const SizedBox(height: 16),

            // Start Workout CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/workout/active'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.cyan,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: _C.cyan.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'ابدأ التمرين الآن' : 'Start Workout',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisePreviewRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _C.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _C.textSec,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ── Performance Quick-View ────────────────────────────────

  Widget _buildPerformanceQuickView(bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.borderDim, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _C.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt_rounded, color: _C.cyan, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'أفضل أداء الأسبوع الماضي' : 'Last week top performance',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _C.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic ? 'بنش برس: ١٠٠ كجم × ٥ عدات' : 'Bench Press: 100kg × 5 reps',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.textPri,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isArabic ? '↑ ٢.٥ كجم' : '↑ 2.5 kg',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly Calendar ───────────────────────────────────────

  Widget _buildWeeklyCalendar(bool isArabic) {
    final List<Map<String, dynamic>> weekDays = [
      {'dayEn': 'M', 'dayAr': 'ن', 'completed': true, 'label': 'Push'},
      {'dayEn': 'T', 'dayAr': 'ث', 'completed': true, 'label': 'Pull'},
      {'dayEn': 'W', 'dayAr': 'ر', 'completed': false, 'label': 'Legs'},
      {'dayEn': 'T', 'dayAr': 'خ', 'completed': false, 'label': 'Push'},
      {'dayEn': 'F', 'dayAr': 'ج', 'completed': false, 'label': 'Pull'},
      {'dayEn': 'S', 'dayAr': 'س', 'completed': false, 'label': 'Rest'},
      {'dayEn': 'S', 'dayAr': 'ح', 'completed': false, 'label': 'Rest'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(weekDays.length, (index) {
        final day = weekDays[index];
        final label = isArabic ? day['dayAr']! : day['dayEn']!;
        final isCompleted = day['completed'] as bool;
        final isToday = index == 3;

        return Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? _C.cyan : _C.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isCompleted
                    ? _C.cyan.withValues(alpha: 0.15)
                    : (isToday ? _C.cardElev : _C.card),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? _C.cyan
                      : (isToday ? _C.cyan : _C.borderDim),
                  width: isToday ? 2 : 1.2,
                ),
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: _C.cyan.withValues(alpha: 0.25),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_rounded, color: _C.cyan, size: 18)
                    : (isToday
                        ? Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _C.cyan,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // QUESTIONNAIRE VIEW
  // ══════════════════════════════════════════════════════════════

  Widget _buildQuestionnaireView(bool isArabic) {
    return Column(
      children: [
        // ── Questionnaire Header ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: _C.textPri, size: 18),
                padding: const EdgeInsets.all(8),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'مخطط الروتين' : 'Smart Routine Planner',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _C.textPri,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      isArabic
                          ? 'الخطوة ${_questStep + 1} من 2'
                          : 'Step ${_questStep + 1} of 2',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Step Indicator Bar ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              _buildStepDot(active: true, isArabic: isArabic),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: _questStep >= 1
                        ? _C.cyan
                        : _C.borderDim,
                  ),
                ),
              ),
              _buildStepDot(active: _questStep >= 1, isArabic: isArabic),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── PageView ──────────────────────────────────
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1Frequency(isArabic),
              _buildStep2Recommendations(isArabic),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepDot({required bool active, required bool isArabic}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active ? _C.cyan : _C.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? _C.cyan : _C.borderMid,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          active ? Icons.check_rounded : Icons.circle,
          size: active ? 14 : 6,
          color: active ? Colors.black : _C.borderMid,
        ),
      ),
    );
  }

  // ── Step 1: Frequency Selection ─────────────────────────

  Widget _buildStep1Frequency(bool isArabic) {
    const dayOptions = [3, 4, 5, 6];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic
                ? 'كم يومًا في الأسبوع تتمرن؟'
                : 'How many days per week do you train?',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _C.textPri,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'اختر العدد الأنسب لأسبوعك الحالي'
                : 'Choose what fits your current schedule',
            style: GoogleFonts.inter(fontSize: 13, color: _C.textMuted),
          ),

          const SizedBox(height: 28),

          // Frequency chips grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: dayOptions.map((days) {
              final isSelected = _selectedDays == days;
              return GestureDetector(
                onTap: () => setState(() => _selectedDays = days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _C.cyan.withValues(alpha: 0.15)
                        : _C.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _C.cyan : _C.borderMid,
                      width: isSelected ? 2 : 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _C.cyan.withValues(alpha: 0.2),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isArabic ? '$days أيام' : '$days Days',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? _C.cyan : _C.textPri,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic ? 'في الأسبوع' : 'per week',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isSelected ? _C.cyan.withValues(alpha: 0.8) : _C.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const Spacer(),

          // Next CTA
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _selectedDays != null ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.cyan,
                disabledBackgroundColor: _C.borderDim,
                foregroundColor: Colors.black,
                disabledForegroundColor: _C.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isArabic ? 'التالي' : 'Next',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Step 2: Routine Recommendations ─────────────────────

  Widget _buildStep2Recommendations(bool isArabic) {
    if (_selectedDays == null) return const SizedBox.shrink();
    final suggestions = RoutineCatalogue.forDays(_selectedDays!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _C.textPri,
                height: 1.3,
                letterSpacing: -0.3,
              ),
              children: [
                TextSpan(
                  text: isArabic
                      ? 'البرامج الموصى بها\n'
                      : 'Recommended Programs\n',
                ),
                TextSpan(
                  text: isArabic
                      ? 'لـ $_selectedDays أيام في الأسبوع'
                      : 'for $_selectedDays days/week',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _C.cyan,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Routine cards
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, index) {
                final s = suggestions[index];
                final isSelected = _selectedRoutineIndex == index;
                return _buildRoutineCard(
                  suggestion: s,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedRoutineIndex = index),
                  isArabic: isArabic,
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Configure Training Plan CTA
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _selectedRoutineIndex != null ? _finalizePlan : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.cyan,
                disabledBackgroundColor: _C.borderDim,
                foregroundColor: Colors.black,
                disabledForegroundColor: _C.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'تكوين خطة التدريب' : 'Configure Training Plan',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRoutineCard({
    required RoutineSuggestion suggestion,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isArabic,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: isSelected ? _C.cyan.withValues(alpha: 0.1) : _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _C.cyan : _C.borderDim,
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _C.cyan.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? _C.cyan : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _C.cyan : _C.borderMid,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 13, color: Colors.black)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    suggestion.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? _C.cyan : _C.textPri,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.tagline,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _C.textSec,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Breakdown pills
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suggestion.breakdown.map((day) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _C.cyan.withValues(alpha: 0.12)
                        : _C.cardElev,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? _C.cyan.withValues(alpha: 0.3)
                          : _C.borderDim,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    day,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _C.cyan : _C.textSec,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PLAN CONFIRM BOTTOM SHEET
  // ══════════════════════════════════════════════════════════════

  Widget _buildPlanConfirmSheet(BuildContext ctx, RoutineSuggestion chosen) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _C.borderMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Success icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _C.cyan.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: _C.cyan.withValues(alpha: 0.4), width: 1.5),
            ),
            child: const Icon(Icons.check_circle_rounded, color: _C.cyan, size: 28),
          ),
          const SizedBox(height: 16),

          Text(
            'Training Plan Configured!',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.textPri,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"${chosen.name}" has been set as your active program.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: _C.textMuted),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.cyan,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Let\'s Go!',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
