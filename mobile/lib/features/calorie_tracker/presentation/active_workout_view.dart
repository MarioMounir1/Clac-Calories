import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/workout_models.dart';
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

class ActiveWorkoutView extends StatelessWidget {
  final WorkoutSessionActive sessionState;
  final bool isArabic;
  final VoidCallback onFinish;

  const ActiveWorkoutView({
    super.key,
    required this.sessionState,
    required this.isArabic,
    required this.onFinish,
  });

  void _showAddExerciseSheet(BuildContext context) {
    if (sessionState.availableExercises == null) {
      context.read<WorkoutBloc>().add(const FetchAvailableExercises());
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExerciseSheet(isArabic: isArabic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = sessionState.currentLogs;
    final totalSets = logs.fold<int>(0, (sum, log) => sum + log.sets.length);
    final loggedSets = logs.fold<int>(0, (sum, log) => sum + log.loggedSetsCount);

    return Column(
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
                onTap: onFinish,
                child: const Icon(Icons.close_rounded, color: _C.textPri, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isArabic ? 'جلسة التمرين النشطة' : 'Active Workout Session',
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
                          isArabic ? 'إضافة تمرين' : 'Add Exercise',
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
              return _ExerciseCard(log: logs[index], isArabic: isArabic);
            },
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final WorkoutLog log;
  final bool isArabic;

  const _ExerciseCard({required this.log, required this.isArabic});

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
    }
    
    // Optimistic UI handled by Bloc now, but we can do a local haptic
    HapticFeedback.lightImpact();
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
                child: Text(
                  log.exerciseName,
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w900, color: _C.textPri),
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
            color: locked ? _C.cyan : _C.textMut,
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
