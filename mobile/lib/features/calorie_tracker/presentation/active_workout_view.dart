import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/workout_models.dart';
import '../domain/repositories/workout_repository.dart';
import 'bloc/workout_bloc.dart';
import 'bloc/workout_event.dart';
import 'bloc/workout_state.dart';

// ── Design Tokens ──────────────────────────────────────────────
class _C {
  _C._();
  static const Color bg        = Color(0xFF090C15);
  static const Color card      = Color(0xFF121824);
  static const Color cardElev  = Color(0xFF1B2232);
  static const Color border    = Color(0xFF222B3F);
  static const Color borderMid = Color(0xFF374151);
  static const Color cyan      = Color(0xFF00E5FF);
  static const Color textPri   = Color(0xFFF3F4F6);
  static const Color textSec   = Color(0xFF9CA3AF);
  static const Color textMut   = Color(0xFF6B7280);
  static const Color error     = Color(0xFFEF4444);
  static const Color success   = Color(0xFF10B981);
  static const Color amber     = Color(0xFFF59E0B);
}

// ═══════════════════════════════════════════════════════════════
// Active Workout View (Dynamic)
// ═══════════════════════════════════════════════════════════════

class ActiveWorkoutView extends StatefulWidget {
  final WorkoutSessionActive sessionState;
  final bool isArabic;
  final VoidCallback onFinish;

  const ActiveWorkoutView({
    super.key,
    required this.sessionState,
    required this.isArabic,
    required this.onFinish,
  });

  @override
  State<ActiveWorkoutView> createState() => _ActiveWorkoutViewState();
}

class _ActiveWorkoutViewState extends State<ActiveWorkoutView> {
  Timer? _timer;
  int _timerSeconds = 0;
  int _totalTimerSeconds = 90;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _timerSeconds = seconds;
      _totalTimerSeconds = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 1) {
        _stopTimer();
      } else {
        setState(() {
          _timerSeconds--;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _timerSeconds = 0;
    });
  }

  void _adjustTimer(int delta) {
    setState(() {
      _timerSeconds = (_timerSeconds + delta).clamp(0, 999);
      if (_timerSeconds > _totalTimerSeconds) {
        _totalTimerSeconds = _timerSeconds;
      }
    });
    if (_timerSeconds == 0) {
      _stopTimer();
    }
  }

  void _showAddExerciseSheet(BuildContext context) {
    if (widget.sessionState.availableExercises == null) {
      context.read<WorkoutBloc>().add(const FetchAvailableExercises());
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExerciseSheet(isArabic: widget.isArabic),
    );
  }

  Widget _buildTimerBanner() {
    final minutes = (_timerSeconds / 60).floor();
    final seconds = _timerSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final progress = _timerSeconds / _totalTimerSeconds;

    return Container(
      decoration: BoxDecoration(
        color: _C.card.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.cyan.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _C.cyan.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: _C.cyan, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    widget.isArabic ? 'وقت الراحة' : 'Rest Timer',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _C.textPri,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _C.cyan,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // -10s
                  TextButton(
                    onPressed: () => _adjustTimer(-10),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '-10s',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.textSec,
                      ),
                    ),
                  ),
                  // +10s
                  TextButton(
                    onPressed: () => _adjustTimer(10),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '+10s',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Skip
                  ElevatedButton(
                    onPressed: _stopTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.cardElev,
                      foregroundColor: _C.textPri,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      widget.isArabic ? 'تخطي' : 'Skip',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Progress Bar
            Container(
              height: 3,
              width: double.infinity,
              color: _C.border,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(color: _C.cyan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.sessionState.currentLogs;
    final totalSets = logs.fold<int>(0, (sum, log) => sum + log.sets.length);
    final loggedSets = logs.fold<int>(0, (sum, log) => sum + log.loggedSetsCount);

    return Stack(
      children: [
        Column(
          key: const ValueKey('activeWorkout'),
          children: [
            // AppBar-like header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: _C.card,
                border: Border(bottom: BorderSide(color: _C.border, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onFinish,
                    child: const Icon(Icons.close_rounded, color: _C.textPri, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.isArabic ? 'جلسة التمرين النشطة' : 'Active Workout Session',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700, color: _C.textPri),
                    ),
                  ),
                  // Logged set counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _C.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _C.cyan.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$loggedSets/$totalSets sets',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _C.cyan),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                itemCount: logs.length + 1,
                itemBuilder: (context, index) {
                  if (index == logs.length) {
                    // Add Exercise Button
                    return Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 40),
                      child: ElevatedButton(
                        onPressed: () => _showAddExerciseSheet(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.cardElev,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: _C.border, width: 1.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, color: _C.cyan),
                            const SizedBox(width: 8),
                            Text(
                              widget.isArabic ? 'إضافة تمرين' : 'Add Exercise',
                              style: GoogleFonts.inter(
                                color: _C.cyan,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return _ExerciseCard(
                    log: logs[index],
                    isArabic: widget.isArabic,
                    onSetCompleted: () => _startTimer(90),
                  );
                },
              ),
            ),
          ],
        ),
        if (_timerSeconds > 0)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: _buildTimerBanner(),
          ),
      ],
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final WorkoutLog log;
  final bool isArabic;
  final VoidCallback onSetCompleted;

  const _ExerciseCard({
    required this.log,
    required this.isArabic,
    required this.onSetCompleted,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late List<TextEditingController> _weightCtrl;
  late List<TextEditingController> _repsCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(_ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool needsReinit = oldWidget.log.sets.length != widget.log.sets.length;
    if (!needsReinit) {
      for (int i = 0; i < widget.log.sets.length; i++) {
        final os = oldWidget.log.sets[i];
        final ns = widget.log.sets[i];
        if (os.isLogged != ns.isLogged ||
            os.loggedWeightKg != ns.loggedWeightKg ||
            os.loggedReps != ns.loggedReps) {
          needsReinit = true;
          break;
        }
      }
    }
    if (needsReinit) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _initControllers() {
    _weightCtrl = widget.log.sets.map((s) => TextEditingController(
      text: s.loggedWeightKg?.toStringAsFixed(0) ?? '',
    )).toList();
    _repsCtrl = widget.log.sets.map((s) => TextEditingController(
      text: s.loggedReps?.toString() ?? '',
    )).toList();
  }

  void _disposeControllers() {
    for (final c in _weightCtrl) {
      c.dispose();
    }
    for (final c in _repsCtrl) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _logSet(int index) {
    final weightStr = _weightCtrl[index].text.trim();
    final repsStr   = _repsCtrl[index].text.trim();

    final weight = weightStr.isEmpty
        ? widget.log.sets[index].targetWeightKg
        : double.tryParse(weightStr);
    final reps = repsStr.isEmpty
        ? widget.log.sets[index].targetReps
        : int.tryParse(repsStr);

    if (weight == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter valid weight and reps.',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _C.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final s = widget.log.sets[index];
    final bool willLog = !s.isLogged;

    if (willLog) {
      context.read<WorkoutBloc>().add(
        LogSetEvent(
          setIndex: s.setIndex,
          weightKg: weight,
          reps: reps,
          workoutExerciseId: s.id ?? widget.log.exerciseName,
        ),
      );
      widget.onSetCompleted();
    }
    
    // Optimistic UI handled by Bloc now, but we can do a local haptic
    HapticFeedback.lightImpact();
  }

  Future<void> _showSwapAlternativesSheet(BuildContext context, WorkoutLog log) async {
    final workoutExerciseId = log.sets.isNotEmpty ? log.sets.first.id : null;
    if (workoutExerciseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isArabic ? 'لا يمكن تبديل هذا التمرين حالياً' : 'Cannot swap this exercise right now.',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _C.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _AlternativesBottomSheet(
          log: log,
          workoutExerciseId: workoutExerciseId,
          availableExercises: context.read<WorkoutBloc>().state is WorkoutSessionActive
              ? (context.read<WorkoutBloc>().state as WorkoutSessionActive).availableExercises
              : null,
          isArabic: widget.isArabic,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise name + muscle group
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.exerciseName,
                        style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w900, color: _C.textPri),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded, color: _C.cyan, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: widget.isArabic ? 'استبدال التمرين' : 'Swap Exercise',
                      onPressed: () => _showSwapAlternativesSheet(context, log),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.cardElev,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _C.border),
                ),
                child: Text(log.muscleGroup,
                    style: GoogleFonts.inter(fontSize: 11, color: _C.textSec)),
              ),
            ],
          ),
          if (log.lastWeekTopPerformance != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.isArabic
                  ? 'الأسبوع الماضي: ${log.lastWeekTopPerformance}'
                  : 'Last week: ${log.lastWeekTopPerformance}',
              style: GoogleFonts.inter(fontSize: 11, color: _C.cyan, fontWeight: FontWeight.w600),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              widget.isArabic ? 'الجلسة الأولى' : 'First Session',
              style: GoogleFonts.inter(fontSize: 11, color: _C.textMut, fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 22),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(flex: 4,
                  child: Text('SET',
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _C.textMut))),
              Expanded(flex: 3,
                  child: Text('WEIGHT (kg)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _C.textMut))),
              Expanded(flex: 3,
                  child: Text('REPS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _C.textMut))),
              const SizedBox(width: 46),
            ]),
          ),
          const SizedBox(height: 10),

          // Dynamic set rows
          ...List.generate(log.sets.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSetRow(i, log.sets[i]),
          )),
        ],
      ),
    );
  }

  Widget _buildSetRow(int index, ExerciseSet s) {
    final locked = s.isLogged;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: locked ? _C.cyan.withOpacity(0.07) : _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked ? _C.cyan : _C.border,
          width: locked ? 1.6 : 1.2,
        ),
      ),
      child: Row(children: [
        // Set label column
        Expanded(flex: 4, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (s.label == 'Top Set') ...[
                const Icon(Icons.star_rounded, color: _C.amber, size: 14),
                const SizedBox(width: 4),
              ],
              Text('Set ${s.setIndex}',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: s.label == 'Top Set' ? _C.amber : _C.textPri)),
            ]),
            const SizedBox(height: 2),
            Text(s.targetDisplayLabel,
                style: GoogleFonts.inter(fontSize: 10, color: _C.textMut)),
          ],
        )),

        // Weight input
        Expanded(flex: 3, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: SizedBox(height: 38, child: TextFormField(
            controller: _weightCtrl[index],
            enabled: !locked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: locked ? _C.textMut : _C.textPri),
            decoration: InputDecoration(
              hintText: s.targetWeightKg?.toStringAsFixed(0) ?? '—',
              hintStyle: GoogleFonts.inter(color: _C.textMut.withOpacity(0.5), fontSize: 13),
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: locked ? _C.cardElev.withOpacity(0.5) : _C.cardElev,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.borderMid)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.cyan, width: 1.5)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.borderMid)),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.border)),
            ),
          )),
        )),

        // Reps input
        Expanded(flex: 3, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: SizedBox(height: 38, child: TextFormField(
            controller: _repsCtrl[index],
            enabled: !locked,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: locked ? _C.textMut : _C.textPri),
            decoration: InputDecoration(
              hintText: s.targetReps?.toString() ?? '—',
              hintStyle: GoogleFonts.inter(color: _C.textMut.withOpacity(0.5), fontSize: 13),
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: locked ? _C.cardElev.withOpacity(0.5) : _C.cardElev,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.borderMid)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.cyan, width: 1.5)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.borderMid)),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _C.border)),
            ),
          )),
        )),

        // Checkmark lock button
        SizedBox(width: 46, child: IconButton(
          icon: Icon(
            locked ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
            color: locked ? _C.success : _C.textMut,
            size: 26,
          ),
          onPressed: () => _logSet(index),
          padding: EdgeInsets.zero,
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Add Exercise Sheet
// ═══════════════════════════════════════════════════════════════

class _AddExerciseSheet extends StatelessWidget {
  final bool isArabic;

  const _AddExerciseSheet({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutBloc, WorkoutState>(
      builder: (context, state) {
        if (state is! WorkoutSessionActive) return const SizedBox.shrink();

        final exercises = state.availableExercises;

        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _C.borderMid, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  isArabic ? 'اختر تمريناً' : 'Choose an Exercise',
                  style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _C.textPri,
                  ),
                ),
                const SizedBox(height: 20),
                if (exercises == null)
                  const Expanded(child: Center(child: CircularProgressIndicator(color: _C.cyan)))
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: exercises.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ex = exercises[index];
                        return InkWell(
                          onTap: () {
                            context.read<WorkoutBloc>().add(AddExerciseToSessionEvent(ex.id));
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: _C.cardElev,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _C.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fitness_center_rounded, color: _C.cyan, size: 24),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 15, fontWeight: FontWeight.w700, color: _C.textPri,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ex.muscleGroup,
                                        style: GoogleFonts.inter(
                                          fontSize: 12, color: _C.textSec,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.add_circle_outline_rounded, color: _C.cyan, size: 24),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Alternatives Bottom Sheet (Subtle swaps helper)
// ═══════════════════════════════════════════════════════════════

class _AlternativesBottomSheet extends StatefulWidget {
  final WorkoutLog log;
  final String workoutExerciseId;
  final List<Exercise>? availableExercises;
  final bool isArabic;

  const _AlternativesBottomSheet({
    required this.log,
    required this.workoutExerciseId,
    required this.availableExercises,
    required this.isArabic,
  });

  @override
  State<_AlternativesBottomSheet> createState() => _AlternativesBottomSheetState();
}

class _AlternativesBottomSheetState extends State<_AlternativesBottomSheet> {
  List<Exercise> _alternatives = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAlternatives();
  }

  Future<void> _fetchAlternatives() async {
    try {
      final available = widget.availableExercises;
      if (available == null) {
        setState(() {
          _error = widget.isArabic ? 'تأكد من تحميل قائمة التمارين أولاً' : 'Exercises catalog not loaded.';
          _isLoading = false;
        });
        return;
      }

      // Find the ID of the current exercise log
      final template = available.firstWhere(
        (e) => e.name.toLowerCase() == widget.log.exerciseName.toLowerCase(),
        orElse: () => Exercise(id: '', name: widget.log.exerciseName, muscleGroup: widget.log.muscleGroup),
      );

      if (template.id.isEmpty) {
        setState(() {
          _error = widget.isArabic ? 'لم يتم العثور على التمرين في الكتالوج' : 'Original exercise not found in catalog.';
          _isLoading = false;
        });
        return;
      }

      final repo = context.read<WorkoutRepository>();
      final data = await repo.getAlternatives(template.id);
      final list = data.map((e) => Exercise.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _alternatives = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _C.border, width: 1.5)),
      ),
      padding: const EdgeInsets.only(top: 14, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _C.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isArabic ? 'تمارين بديلة' : 'Alternative Movements',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _C.textPri,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isArabic 
                      ? 'استبدل "${widget.log.exerciseName}" بأحد هذه البدائل المقترحة:'
                      : 'Swap "${widget.log.exerciseName}" with one of these alternatives:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _C.textSec,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content body
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: CircularProgressIndicator(color: _C.cyan),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _error!,
            style: GoogleFonts.inter(color: _C.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_alternatives.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Text(
            widget.isArabic ? 'لا توجد بدائل مقترحة لهذا التمرين' : 'No alternative exercises found.',
            style: GoogleFonts.inter(color: _C.textSec, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _alternatives.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ex = _alternatives[index];
        return InkWell(
          onTap: () {
            context.read<WorkoutBloc>().add(
              SwapWorkoutExercise(
                workoutExerciseId: widget.workoutExerciseId,
                newExerciseId: ex.id,
              ),
            );
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _C.cardElev,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: _C.cyan, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _C.textPri,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ex.muscleGroup,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _C.textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  widget.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: _C.textSec,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
