// lib/features/calorie_tracker/presentation/active_workout_screen.dart
// Calc-Calories — Ultra-Fast Weight & Set Tracker logging screen
//
// Architecture: StatefulWidget driven by WorkoutLog and ExerciseSet models.
// Features a clean set-logging table with numeric inputs and lock buttons.
// Rest timer popup starts automatically on set logged.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/workout_models.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  // ── Active Session State ─────────────────────────────────────
  late final WorkoutLog _workoutLog;
  final List<TextEditingController> _weightControllers = [];
  final List<TextEditingController> _repsControllers = [];

  // Stopwatch timer state
  late Timer _stopwatchTimer;
  int _secondsElapsed = 1455; // starts at 00:24:15

  // Rest timer state
  bool _showRestTimer = false;
  int _restSecondsLeft = 105; // 1:45 rest time
  Timer? _restTimer;

  // Design tokens aligned with dashboard colors
  static const Color bgColor = Color(0xFF090C15);
  static const Color cardColor = Color(0xFF121824);
  static const Color cardElevColor = Color(0xFF1B2232);
  static const Color borderDimColor = Color(0xFF222B3F);
  static const Color borderMidColor = Color(0xFF374151);
  static const Color cyanColor = Color(0xFF00BCD4);
  static const Color textPriColor = Color(0xFFFFFFFF);
  static const Color textSecColor = Color(0xFF8E929C);
  static const Color textMutedColor = Color(0xFF5D616B);

  @override
  void initState() {
    super.initState();
    // Initialize our WorkoutLog model
    _workoutLog = WorkoutLog.defaultPushDay();

    // Initialize controllers for each set
    for (var setItem in _workoutLog.sets) {
      _weightControllers.add(
        TextEditingController(
          text: setItem.loggedWeightKg != null
              ? setItem.loggedWeightKg!.toStringAsFixed(0)
              : '',
        ),
      );
      _repsControllers.add(
        TextEditingController(
          text: setItem.loggedReps != null ? setItem.loggedReps.toString() : '',
        ),
      );
    }

    // Start active workout stopwatch timer
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  @override
  void dispose() {
    _stopwatchTimer.cancel();
    _restTimer?.cancel();
    for (var controller in _weightControllers) {
      controller.dispose();
    }
    for (var controller in _repsControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _showRestTimer = true;
      _restSecondsLeft = 105; // reset to 1:45
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsLeft > 0) {
        setState(() {
          _restSecondsLeft--;
        });
      } else {
        setState(() {
          _showRestTimer = false;
        });
        _restTimer?.cancel();
      }
    });
  }

  void _logSet(int index) {
    final setItem = _workoutLog.sets[index];
    final weightText = _weightControllers[index].text.trim();
    final repsText = _repsControllers[index].text.trim();

    final double? weight = double.tryParse(weightText);
    final int? reps = int.tryParse(repsText);

    if (weight == null || reps == null) {
      // Local error boundary handling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter valid weight and reps values.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      setItem.loggedWeightKg = weight;
      setItem.loggedReps = reps;
      setItem.isLogged = !setItem.isLogged;
      setItem.loggedAt = setItem.isLogged ? DateTime.now() : null;

      if (setItem.isLogged) {
        _startRestTimer();
      }
    });
  }

  String _formatStopwatch(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String hStr = hours.toString().padLeft(2, '0');
    final String mStr = minutes.toString().padLeft(2, '0');
    final String sStr = seconds.toString().padLeft(2, '0');

    return '$hStr:$mStr:$sStr';
  }

  String _formatRestTimer(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String sStr = seconds.toString().padLeft(2, '0');
    return '$minutes:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textPriColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isArabic ? 'اليوم ١: دفع (RPT)' : 'Day 1: Push Day (RPT)',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPriColor,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: cyanColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _formatStopwatch(_secondsElapsed),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cyanColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              // Exercise Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'بنش برس بالبار' : _workoutLog.exerciseName,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPriColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardElevColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderDimColor, width: 1),
                    ),
                    child: Text(
                      isArabic ? 'الصدر / الأكتاف' : _workoutLog.muscleGroup,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Last week performance badge shown directly below exercise title
              if (_workoutLog.lastWeekTopPerformance != null)
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 14, color: textMutedColor),
                    const SizedBox(width: 6),
                    Text(
                      isArabic
                          ? 'أفضل أداء للأسبوع الماضي: ${_workoutLog.lastWeekTopPerformance}'
                          : "Last week's top performance: ${_workoutLog.lastWeekTopPerformance}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textMutedColor,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Exercise Form Demo Card Graphic
              _buildFormPreviewCard(isArabic),
              const SizedBox(height: 24),

              // RPT logging table header
              _buildTableHeader(isArabic),
              const SizedBox(height: 8),

              // Set rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _workoutLog.sets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final setItem = _workoutLog.sets[index];
                  return _buildSetItemRow(
                    index: index,
                    setItem: setItem,
                    isArabic: isArabic,
                  );
                },
              ),
            ],
          ),

          // Floating rest timer widget
          if (_showRestTimer)
            Positioned(
              bottom: 94,
              left: 20,
              right: 20,
              child: _buildRestTimerPopup(isArabic),
            ),

          // Bottom CTA button fixed
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildFinishWorkoutButton(isArabic),
          ),
        ],
      ),
    );
  }

  // ── Exercise Preview Card ──────────────────────────────────────────
  Widget _buildFormPreviewCard(bool isArabic) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderDimColor, width: 1.2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cardElevColor, cardColor],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.15,
            child: Icon(
              Icons.fitness_center_rounded,
              size: 70,
              color: cyanColor,
            ),
          ),
          Positioned(
            bottom: 12,
            right: isArabic ? null : 12,
            left: isArabic ? 12 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.loop_rounded, color: cyanColor, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'دليل الأداء الحي' : 'FORM DEMO LOOP',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: textPriColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Table Header labels ────────────────────────────────────────────
  Widget _buildTableHeader(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              isArabic ? 'المجموعة والهدف' : 'SET & TARGET',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMutedColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              isArabic ? 'الوزن (كجم)' : 'WEIGHT (kg)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMutedColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              isArabic ? 'العدات' : 'REPS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMutedColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Space matching the lock checkmark
        ],
      ),
    );
  }

  // ── Set Logging Row Widget ──────────────────────────────────────────
  Widget _buildSetItemRow({
    required int index,
    required ExerciseSet setItem,
    required bool isArabic,
  }) {
    final bool isChecked = setItem.isLogged;
    final bool hasGoldStar = setItem.label == 'Top Set';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isChecked ? cyanColor.withOpacity(0.08) : cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isChecked ? cyanColor : borderDimColor,
          width: isChecked ? 1.6 : 1.2,
        ),
      ),
      child: Row(
        children: [
          // Set description & target
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasGoldStar) ...[
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isArabic ? 'مجموعة ${setItem.setIndex}' : 'Set ${setItem.setIndex}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: hasGoldStar ? Colors.amber : textPriColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  setItem.targetDisplayLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: textSecColor,
                  ),
                ),
              ],
            ),
          ),

          // Weight Input Field
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _weightControllers[index],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  enabled: !isChecked,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isChecked ? textSecColor : textPriColor,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: isChecked ? bgColor.withOpacity(0.5) : bgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderMidColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: cyanColor),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Reps Input Field
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _repsControllers[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  enabled: !isChecked,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isChecked ? textSecColor : textPriColor,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: isChecked ? bgColor.withOpacity(0.5) : bgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderMidColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: cyanColor),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Checkmark Lock/Unlock Button
          SizedBox(
            width: 48,
            child: IconButton(
              icon: Icon(
                isChecked ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                color: isChecked ? cyanColor : textMutedColor,
                size: 24,
              ),
              onPressed: () => _logSet(index),
            ),
          ),
        ],
      ),
    );
  }

  // ── Auto Rest-Timer Widget ─────────────────────────────────────────
  Widget _buildRestTimerPopup(bool isArabic) {
    final double pct = _restSecondsLeft / 105;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cyanColor.withOpacity(0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 3,
                  backgroundColor: cardElevColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(cyanColor),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'وقت الراحة التلقائي' : 'Rest Timer Active',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textPriColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? 'متبقي ${_formatRestTimer(_restSecondsLeft)} د'
                        : 'Remaining: ${_formatRestTimer(_restSecondsLeft)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: textSecColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: cyanColor, size: 22),
                onPressed: () {
                  setState(() {
                    _showRestTimer = false;
                    _restTimer?.cancel();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                onPressed: () {
                  setState(() {
                    _showRestTimer = false;
                    _restTimer?.cancel();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Finish Workout Button Action ──────────────────────────────────
  Widget _buildFinishWorkoutButton(bool isArabic) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cyanColor.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isArabic ? 'أحسنت يا بطل! 🚀' : 'Great Job! 🚀',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: textPriColor),
              ),
              content: Text(
                isArabic
                    ? 'تم تسجيل تمرينك بنجاح وكسبت +٣٠ نقطة مكافأة.'
                    : 'Workout successfully logged. You earned +30 reward points.',
                style: GoogleFonts.inter(color: textSecColor),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to dashboard
                  },
                  child: Text(
                    isArabic ? 'حسناً' : 'Awesome',
                    style: const TextStyle(color: cyanColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: cyanColor,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          isArabic ? 'إنهاء التمرين والمطالبة بـ +٣٠ نقطة' : 'Finish Workout & Claim +30 Pts',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
