// lib/features/calorie_tracker/presentation/workout_screen.dart
// Aura — Workout Hub (Full Dynamic Refactor)
//
// State Machine:
//   unconfigured → loading → ready → activeWorkout
//
// Flow:
//   1. onInit: GET /workouts/routine → unconfigured | ready
//   2. Setup tapped → questionnaire sheet (step 1: frequency, step 2: split dialog)
//   3. Confirm → POST /workouts/setup → state = ready
//   4. Start Workout → state = activeWorkout (inline tracker)
//   5. Finish → state = ready, sets cleared

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/ad_banner.dart';
import '../../premium/presentation/premium_upgrade_screen.dart';
import '../../premium/data/services/purchase_service.dart';
import '../../profile/presentation/bloc/profile_bloc.dart';
import '../../profile/presentation/bloc/profile_state.dart';
import '../data/models/workout_models.dart';
import 'bloc/workout_bloc.dart';
import 'bloc/workout_event.dart';
import 'bloc/workout_state.dart';
import 'active_workout_view.dart';

// ── State Machine ─────────────────────────────────────────────
enum WorkoutHubState { unconfigured, loading, ready, activeWorkout }

// ── Design Tokens ──────────────────────────────────────────────
class _C {
  _C._();
  static const Color bg        = Color(0xFF090C15);
  static const Color card      = Color(0xFF121824);
  static const Color cardElev  = Color(0xFF1B2232);
  static const Color border    = Color(0xFF222B3F);
  static const Color borderMid = Color(0xFF374151);
  static const Color cyan      = Color(0xFF00BCD4);
  static const Color textPri   = Color(0xFFFFFFFF);
  static const Color textSec   = Color(0xFF8E929C);
  static const Color textMut   = Color(0xFF5D616B);
  static const Color amber     = Color(0xFFFBBF24);
  static const Color success   = Color(0xFF4CAF50);
  static const Color error     = Color(0xFFF44336);
}

// ═══════════════════════════════════════════════════════════════
// WorkoutScreen
// ═══════════════════════════════════════════════════════════════

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────
  WorkoutHubState _state = WorkoutHubState.loading;
  int _activeDays = 0;
  RoutineSuggestion? _activeRoutine;
  CurrentSession? _currentSession;
  String? _errorMessage;


  // ── Streak (mock — replace with backend data) ──────────────
  final int _streakDays = 5;

  // ── Dio ───────────────────────────────────────────────────
  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = ApiClient().dio;
    _loadRoutine();
  }

  // ── Load existing routine from backend ─────────────────────
  Future<void> _loadRoutine() async {
    setState(() => _state = WorkoutHubState.loading);
    try {
      final resp = await _dio.get('/workouts/routine');
      final data = resp.data['data']['routine'];
      final sessionData = resp.data['data']['currentSession'];
      if (data != null) {
        // Backend returned a saved routine
        final splitType = data['splitType'] as String;
        final splitName = data['splitName'] as String? ?? data['splitType'] as String;
        final days      = data['daysPerWeek'] as int? ?? 4;
        final suggestions = RoutineCatalogue.forDays(days);
        final found = suggestions.where((s) => s.splitType == splitType).toList();
        setState(() {
          _activeDays   = days;
          _activeRoutine = found.isNotEmpty
              ? found.first
              : RoutineSuggestion(
                  name: splitName,
                  splitType: splitType,
                  tagline: data['description'] as String? ?? '',
                  breakdown: (data['weekSchedule'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [],
                );
          _currentSession = sessionData != null
              ? CurrentSession.fromJson(sessionData as Map<String, dynamic>)
              : null;
          _state = WorkoutHubState.ready;
        });
      } else {
        setState(() => _state = WorkoutHubState.unconfigured);
      }
    } on DioException catch (e) {
      // 401 → probably not set up yet, treat as unconfigured
      if (e.response?.statusCode == 404 || e.response?.statusCode == 401) {
        setState(() => _state = WorkoutHubState.unconfigured);
      } else {
        setState(() {
          _state = WorkoutHubState.unconfigured;
          _errorMessage = 'Could not load routine. Please try again.';
        });
      }
    } catch (_) {
      setState(() => _state = WorkoutHubState.unconfigured);
    }
  }

  // ── POST setup to backend ──────────────────────────────────
  Future<void> _submitRoutine(int days, RoutineSuggestion split) async {
    setState(() => _state = WorkoutHubState.loading);
    try {
      final resp = await _dio.post('/workouts/setup', data: {
        'daysPerWeek': days,
        'splitType':   split.splitType,
        'splitName':   split.name,
      });
      final sessionData = resp.data['data']?['currentSession'];
      setState(() {
        _activeDays    = days;
        _activeRoutine = split;
        _currentSession = sessionData != null
            ? CurrentSession.fromJson(sessionData as Map<String, dynamic>)
            : null;
        _state         = WorkoutHubState.ready;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${split.name} configured successfully!',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: _C.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map
              ? e.response?.data['error']
              : null) as String? ??
          'Failed to save routine. Please try again.';
      setState(() => _state = WorkoutHubState.unconfigured);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: _C.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      setState(() => _state = WorkoutHubState.unconfigured);
    }
  }

  // ── Launch Setup Sheet ─────────────────────────────────────
  void _openSetupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionnaireSheet(
        onComplete: (int days, RoutineSuggestion split) {
          Navigator.pop(context);
          _submitRoutine(days, split);
        },
      ),
    );
  }

  // ── Launch Active Workout ──────────────────────────────────
  void _startWorkout() {
    final profileState = context.read<ProfileBloc>().state;
    final isPremium = profileState is ProfileLoaded && profileState.isPremium;

    if (!isPremium) {
      PurchaseService.instance.presentPaywall(context);
      return;
    }

    context.read<WorkoutBloc>().add(StartWorkoutSession(
      _currentSession != null ? _currentSession!.routineName : 'Custom Session',
      initialExercises: _currentSession?.exercises,
    ));

    setState(() {
      _state = WorkoutHubState.activeWorkout;
    });
  }

  void _finishWorkout() {
    context.read<WorkoutBloc>().add(const FinishWorkoutSession());

    setState(() {
      _state = WorkoutHubState.ready;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Workout complete! +30 pts 🎉',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _C.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return MultiBlocListener(
      listeners: [
        BlocListener<ProfileBloc, ProfileState>(
          listener: (context, profileState) {
            if (profileState is ProfileLoaded) {
              _loadRoutine();
            }
          },
        ),
        BlocListener<WorkoutBloc, WorkoutState>(
          listener: (context, workoutState) {
            if (workoutState is WorkoutError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(workoutState.message, style: const TextStyle(color: Colors.white)),
                  backgroundColor: _C.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _buildCurrentView(isArabic),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(bool isArabic) {
    switch (_state) {
      case WorkoutHubState.loading:
        return _buildLoadingView(isArabic);
      case WorkoutHubState.activeWorkout:
        return BlocBuilder<WorkoutBloc, WorkoutState>(
          builder: (context, workoutState) {
            if (workoutState is WorkoutSessionActive) {
              return ActiveWorkoutView(
                key: const ValueKey('activeWorkout'),
                sessionState: workoutState,
                isArabic: isArabic,
                onFinish: _finishWorkout,
              );
            }
            return _buildLoadingView(isArabic);
          },
        );
      case WorkoutHubState.unconfigured:
      case WorkoutHubState.ready:
        return _buildHubView(isArabic);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // LOADING VIEW
  // ══════════════════════════════════════════════════════════════

  Widget _buildLoadingView(bool isArabic) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(_C.cyan),
        strokeWidth: 2.5,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HUB VIEW  (unconfigured + ready)
  // ══════════════════════════════════════════════════════════════

  Widget _buildHubView(bool isArabic) {
    return Column(
      key: const ValueKey('hub'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'مركز التمرين' : 'Workout Hub',
                    style: GoogleFonts.inter(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: _C.textPri, letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _state == WorkoutHubState.ready
                        ? (isArabic ? 'روتينك نشط' : 'Your routine is active')
                        : (isArabic ? 'لا يوجد روتين نشط' : 'No routine configured'),
                    style: GoogleFonts.inter(fontSize: 12, color: _C.textMut),
                  ),
                ],
              ),
              _buildStreakBadge(),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            children: [

              // ── Setup Routine Button (always visible) ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSetupButton(isArabic),
              ),
              const SizedBox(height: 20),

              // ── Error banner ──────────────────────────────
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.error.withOpacity(0.3)),
                    ),
                    child: Text(_errorMessage!,
                        style: GoogleFonts.inter(fontSize: 12, color: _C.error)),
                  ),
                ),

              // ── UNCONFIGURED: empty state ─────────────────
              if (_state == WorkoutHubState.unconfigured)
                _buildEmptyState(isArabic),

              // ── READY: full hub content ───────────────────
              if (_state == WorkoutHubState.ready) ...[

                // Today's Session card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildTodayCard(isArabic),
                ),
                const SizedBox(height: 16),

                // Last week performance
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildPerformanceBadge(isArabic),
                ),
                const SizedBox(height: 28),

                // Weekly overview label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'نظرة أسبوعية' : 'Weekly Overview',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _C.textPri),
                      ),
                      Text(
                        isArabic ? '$_activeDays أيام/أسبوع' : '$_activeDays days/week',
                        style: GoogleFonts.inter(fontSize: 12, color: _C.textMut),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // READ-ONLY weekly circles (dynamic, matches routine)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildWeeklyCalendar(isArabic),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // ── Ads Banner for Free Users ──────────────
              Builder(builder: (context) {
                final profileState = context.read<ProfileBloc>().state;
                final isPremium = profileState is ProfileLoaded && profileState.isPremium;
                if (!isPremium) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: AdBanner(),
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _C.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.amber.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            '$_streakDays-Day Streak',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _C.amber),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupButton(bool isArabic) {
    return GestureDetector(
      onTap: _openSetupSheet,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.cyan.withOpacity(0.14), _C.cyan.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.cyan.withOpacity(0.35), width: 1.4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _C.cyan.withOpacity(0.15),
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
                    _state == WorkoutHubState.ready
                        ? (isArabic ? 'تعديل خطة التدريب' : 'Reconfigure Routine Plan')
                        : (isArabic ? 'إعداد خطة التدريب' : 'Setup Your Routine Plan'),
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPri),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? 'اختر تكرارك وخطة التقسيم'
                        : 'Choose your frequency and training split',
                    style: GoogleFonts.inter(fontSize: 11, color: _C.textMut),
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

  Widget _buildEmptyState(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _C.card,
              shape: BoxShape.circle,
              border: Border.all(color: _C.border, width: 1.2),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: _C.textMut, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            isArabic ? 'لا يوجد روتين نشط' : 'No Active Routine',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: _C.textPri),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'اضغط على الإعداد أعلاه لتهيئة برنامج التدريب الخاص بك.'
                : 'No active routine. Tap Setup above to initialize your training split.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: _C.textSec, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard(bool isArabic) {
    final routine = _activeRoutine!;
    final session = _currentSession;

    // Derive today label from session (authoritative) or local schedule fallback
    final todayLabel = session?.todayDayName
        ?? (() {
          final idx = DateTime.now().weekday - 1;
          final sched = routine.breakdown;
          return sched.isNotEmpty ? sched[idx % sched.length] : 'Training Day';
        })();

    final exercises = session?.exercises ?? [];
    final isRestDay = exercises.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border, width: 1.2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.cyan.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              isArabic ? 'جلسة اليوم' : "TODAY'S SESSION",
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: _C.cyan, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 10),

          // Routine name + today label
          Text(
            '${routine.name} — $todayLabel',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: _C.textPri, letterSpacing: -0.3),
          ),
          const SizedBox(height: 16),
          Divider(color: _C.border, height: 1),
          const SizedBox(height: 14),

          // ── Exercise List ──────────────────────────────
          if (isRestDay)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                const Icon(Icons.hotel_rounded, color: _C.textMut, size: 16),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'يوم راحة — استرح واستعد' : 'Rest Day — Recover & recharge',
                  style: GoogleFonts.inter(fontSize: 13, color: _C.textMut),
                ),
              ]),
            )
          else
            ...List.generate(exercises.length, (i) {
              final ex = exercises[i];
              final isFirst = i == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Index badge
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: isFirst
                            ? _C.cyan.withValues(alpha: 0.15)
                            : _C.cardElev,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFirst ? _C.cyan : _C.borderMid,
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: isFirst ? _C.cyan : _C.textMut,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Exercise name + muscle group
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isFirst ? FontWeight.w700 : FontWeight.w600,
                              color: isFirst ? _C.textPri : _C.textSec,
                            ),
                          ),
                          Text(
                            ex.muscleGroup,
                            style: GoogleFonts.inter(fontSize: 10, color: _C.textMut),
                          ),
                        ],
                      ),
                    ),

                    // Sets badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.cardElev,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _C.border),
                      ),
                      child: Text(
                        '${ex.targetSets} sets',
                        style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600, color: _C.textMut),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 16),
          Divider(color: _C.border, height: 1),
          const SizedBox(height: 14),

          // Start Workout CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isRestDay ? null : _startWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.cyan,
                disabledBackgroundColor: _C.cardElev,
                foregroundColor: Colors.black,
                disabledForegroundColor: _C.textMut,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isRestDay ? Icons.hotel_rounded : Icons.play_arrow_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isRestDay
                        ? (isArabic ? 'يوم راحة' : 'Rest Day')
                        : (isArabic ? 'ابدأ التمرين الآن' : 'Start Workout'),
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBadge(bool isArabic) {
    // Contextually reads from the FIRST exercise in today's session
    final top = _currentSession?.topHistoricalSet;
    final label = top?.displayLabel ?? '— No data yet';
    final delta = top?.progressionDelta ?? '';
    final hasData = top != null && top.weight > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _C.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.bolt_rounded, color: _C.cyan, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isArabic ? 'أفضل أداء الأسبوع الماضي' : 'Last week top performance',
                style: GoogleFonts.inter(fontSize: 11, color: _C.textMut),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _C.textPri),
              ),
            ]),
          ),
          if (hasData && delta.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _C.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '↑ $delta',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _C.success),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendar(bool isArabic) {
    // Build exactly _activeDays filled circles + (7 - _activeDays) rest circles
    const weekDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isActive  = i < _activeDays;
        final isToday   = i == todayIndex;
        final label     = weekDayLabels[i];
        // READ-ONLY: no GestureDetector, no onTap
        return Column(children: [
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? _C.cyan : _C.textMut,
              )),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? (isToday ? _C.cyan.withOpacity(0.25) : _C.cyan.withOpacity(0.12))
                  : _C.cardElev,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? _C.cyan : _C.border,
                width: isToday ? 2 : 1.2,
              ),
              boxShadow: isToday
                  ? [BoxShadow(color: _C.cyan.withOpacity(0.3), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: isActive
                  ? const Icon(Icons.check_rounded, color: _C.cyan, size: 16)
                  : const SizedBox.shrink(),
            ),
          ),
        ]);
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ACTIVE WORKOUT VIEW
  // ══════════════════════════════════════════════════════════════
}

// ═══════════════════════════════════════════════════════════════
// Questionnaire Sheet (bottom sheet)
// ═══════════════════════════════════════════════════════════════

class _QuestionnaireSheet extends StatefulWidget {
  final void Function(int days, RoutineSuggestion split) onComplete;
  const _QuestionnaireSheet({required this.onComplete});

  @override
  State<_QuestionnaireSheet> createState() => _QuestionnaireSheetState();
}

class _QuestionnaireSheetState extends State<_QuestionnaireSheet> {
  int _step            = 0;
  int? _selectedFreq;
  int? _selectedIdx;

  List<RoutineSuggestion> get _suggestions =>
      _selectedFreq != null ? RoutineCatalogue.forDays(_selectedFreq!) : [];

  @override
  Widget build(BuildContext context) {
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
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _C.borderMid, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildStepIndicator(),
            ),
            const SizedBox(height: 20),

            // Page content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _step == 0 ? _buildStep1() : _buildStep2(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(active: true),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _step >= 1 ? _C.cyan : _C.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _stepDot(active: _step >= 1),
      ],
    );
  }

  Widget _stepDot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: active ? _C.cyan : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: active ? _C.cyan : _C.borderMid, width: 1.5),
      ),
      child: active
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.black)
          : null,
    );
  }

  // ── Step 1: Frequency ──────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Smart Routine Planner',
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: _C.textPri, letterSpacing: -0.4)),
        const SizedBox(height: 6),
        Text('Step 1 of 2',
            style: GoogleFonts.inter(fontSize: 12, color: _C.textMut)),
        const SizedBox(height: 24),
        Text('How many days per week do you train?',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w700, color: _C.textPri)),
        const SizedBox(height: 6),
        Text('Choose what fits your current schedule',
            style: GoogleFonts.inter(fontSize: 13, color: _C.textMut)),
        const SizedBox(height: 24),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [3, 4, 5, 6].map((days) {
            final sel = _selectedFreq == days;
            return GestureDetector(
              onTap: () => setState(() => _selectedFreq = days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: sel ? _C.cyan.withOpacity(0.15) : _C.cardElev,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: sel ? _C.cyan : _C.borderMid, width: sel ? 2 : 1.2),
                  boxShadow: sel
                      ? [BoxShadow(color: _C.cyan.withOpacity(0.2), blurRadius: 12)]
                      : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$days Days',
                      style: GoogleFonts.inter(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: sel ? _C.cyan : _C.textPri)),
                  Text('per week',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: sel ? _C.cyan.withOpacity(0.8) : _C.textMut)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selectedFreq != null
                ? () => setState(() => _step = 1)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.cyan,
              disabledBackgroundColor: _C.border,
              foregroundColor: Colors.black,
              disabledForegroundColor: _C.textMut,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Next',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 2: Recommendation dialog-style ───────────────────
  Widget _buildStep2() {
    final freq = _selectedFreq!;
    final suggestions = _suggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _step = 0),
            child: const Icon(Icons.arrow_back_ios_rounded, color: _C.textPri, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Smart Routine Planner',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w900, color: _C.textPri)),
        ]),
        const SizedBox(height: 6),
        Text('Step 2 of 2',
            style: GoogleFonts.inter(fontSize: 12, color: _C.textMut)),
        const SizedBox(height: 20),

        // Conversation-style recommendation card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.cardElev,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.cyan.withOpacity(0.25), width: 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: _C.cyan.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.psychology_rounded, color: _C.cyan, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Offline Engine',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _C.cyan)),
            ]),
            const SizedBox(height: 10),
            Text(
              'Based on your choice of $freq training days, '
              'our secure offline engine recommends the following splits. '
              'Which one fits your goals?',
              style: GoogleFonts.inter(
                  fontSize: 13, color: _C.textSec, height: 1.5),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Routine option cards
        ...List.generate(suggestions.length, (i) {
          final s   = suggestions[i];
          final sel = _selectedIdx == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIdx = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: sel ? _C.cyan.withOpacity(0.1) : _C.cardElev,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? _C.cyan : _C.border, width: sel ? 2 : 1.2),
                  boxShadow: sel
                      ? [BoxShadow(color: _C.cyan.withOpacity(0.15), blurRadius: 16)]
                      : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: sel ? _C.cyan : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: sel ? _C.cyan : _C.borderMid, width: 2),
                      ),
                      child: sel
                          ? const Icon(Icons.check, size: 12, color: Colors.black)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.name,
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w800,
                              color: sel ? _C.cyan : _C.textPri)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(s.tagline,
                      style: GoogleFonts.inter(fontSize: 12, color: _C.textSec, height: 1.4)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: s.breakdown.map((d) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sel ? _C.cyan.withOpacity(0.12) : _C.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: sel ? _C.cyan.withOpacity(0.3) : _C.border, width: 1),
                      ),
                      child: Text(d,
                          style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: sel ? _C.cyan : _C.textSec)),
                    )).toList(),
                  ),
                ]),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selectedIdx != null
                ? () => widget.onComplete(freq, suggestions[_selectedIdx!])
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.cyan,
              disabledBackgroundColor: _C.border,
              foregroundColor: Colors.black,
              disabledForegroundColor: _C.textMut,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_rounded, size: 18),
              const SizedBox(width: 8),
              Text('Configure Training Plan',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
