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
import '../../profile/presentation/bloc/profile_event.dart';
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
  String? _swapSuggestionNote;
  bool _overtrainingRisk = false;
  String? _overtrainingNote;
  int? _expandedExerciseIndex;
  List<WeekDayDetail> _weekScheduleDetails = [];

  bool _isInterpretingAiCommand = false;
  bool _showAllExercises = false;

  // ── Streak & Real-Time Weekly Completion ──────────────────────
  int _streakDays = 0;
  List<bool> _completedDaysThisWeek = List.filled(7, false);

  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = ApiClient().dio;
    _loadRoutine();
  }

  @override
  void dispose() {
    _aiCommandController.dispose();
    super.dispose();
  }

  // ── Load existing routine from backend ─────────────────────
  Future<void> _loadRoutine() async {
    if (!mounted) return;
    setState(() => _state = WorkoutHubState.loading);
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final resp = await _dio.get('/workouts/routine?date=$todayStr');
      if (!mounted) return;
      final data = resp.data['data']['routine'];
      final sessionData = resp.data['data']['currentSession'];
      final swapNote = resp.data['data']?['swapSuggestionNote'] as String?;
      if (data != null) {
        // Backend returned a saved routine
        final splitType = data['splitType'] as String;
        final splitName = data['splitName'] as String? ?? data['splitType'] as String;
        final days      = data['daysPerWeek'] as int? ?? 4;
        final suggestions = RoutineCatalogue.forDays(days);
        final found = suggestions.where((s) => s.splitType == splitType).toList();
        final streak = resp.data['data']['streakDays'] as int? ?? 0;
        final completedList = (resp.data['data']['completedDaysThisWeek'] as List<dynamic>?)
                ?.map((e) => e == true)
                .toList() ??
            List.filled(7, false);

        final rawWeekDetails = data['weekScheduleDetails'] as List<dynamic>?;
        final weekDetails = rawWeekDetails != null
            ? rawWeekDetails.map((e) => WeekDayDetail.fromJson(e as Map<String, dynamic>)).toList()
            : <WeekDayDetail>[];

        final overtrainRisk = data['overtrainingRisk'] as bool? ?? false;
        final overtrainNote = data['overtrainingNote'] as String?;

        if (!mounted) return;
        setState(() {
          _streakDays = streak;
          _completedDaysThisWeek = completedList;
          _weekScheduleDetails = weekDetails;
          _swapSuggestionNote = swapNote;
          _overtrainingRisk = overtrainRisk;
          _overtrainingNote = overtrainNote;
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
        if (!mounted) return;
        setState(() => _state = WorkoutHubState.unconfigured);
      }
    } on DioException catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() => _state = WorkoutHubState.unconfigured);
    }
  }

  // ── POST setup to backend ──────────────────────────────────
  Future<void> _submitRoutine(int days, RoutineSuggestion split) async {
    if (!mounted) return;
    setState(() => _state = WorkoutHubState.loading);
    try {
      final resp = await _dio.post('/workouts/setup', data: {
        'daysPerWeek': days,
        'splitType':   split.splitType,
        'splitName':   split.name,
      });
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
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
  }

  void _showPostWorkoutSummarySheet(String summaryNote) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _C.cyan.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_rounded, color: _C.amber, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Workout Complete! 🎉',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _C.textPri,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _C.textMut),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _C.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.cyan.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _C.cyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.psychology_rounded, color: _C.cyan, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COACH SUMMARY',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _C.cyan,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            summaryNote,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.4,
                              color: _C.textPri,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
            } else if (workoutState is WorkoutSessionFinished) {
              _loadRoutine();
              _showPostWorkoutSummarySheet(workoutState.message);
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
              Row(
                children: [
                  _buildStreakBadge(),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openSetupSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _C.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _C.borderMid, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune_rounded, color: _C.cyan, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isArabic ? 'البرنامج' : 'Plan',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.textPri),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            children: [

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

                // Weekly overview label + Weekly Recap action
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            isArabic ? 'نظرة أسبوعية' : 'Weekly Overview',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700, color: _C.textPri),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _showWeeklyRecapSheet(isArabic),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _C.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _C.cyan.withValues(alpha: 0.35), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, color: _C.cyan, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    isArabic ? 'ملخص الأسبوع' : 'Weekly Recap',
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _C.cyan),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                  child: WeeklyCalendarRow(
                    weekScheduleDetails: _weekScheduleDetails,
                    completedDaysThisWeek: _completedDaysThisWeek,
                    isArabic: isArabic,
                    onDayTap: (detail) => _showDayDetailSheet(detail, isArabic),
                  ),
                ),

                if (_overtrainingRisk && _overtrainingNote != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _C.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.amber.withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _C.amber.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: _C.amber, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic ? 'تنبيه التعافي' : 'RECOVERY NOTICE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: _C.amber,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _overtrainingNote!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _C.textPri,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
    if (_streakDays <= 0) return const SizedBox.shrink();
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



  Widget _buildLocalAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _C.cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.cyan.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.memory_rounded, color: _C.cyan, size: 11),
          const SizedBox(width: 4),
          Text(
            'Local AI · offline',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _C.cyan,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _overrideSession(String dayType) async {
    Navigator.of(context).pop();
    setState(() => _state = WorkoutHubState.loading);
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await _dio.post('/workouts/session/override', data: {
        'date': todayStr,
        'dayType': dayType,
      });
      await _loadRoutine();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dayType == 'skip'
                ? 'Today marked as skipped'
                : 'Session updated to $dayType'),
            backgroundColor: _C.cyan,
          ),
        );
      }
    } catch (e) {
      setState(() => _state = WorkoutHubState.ready);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update session'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSwapSessionSheet(bool isArabic) {
    final rawBreakdown = _activeRoutine?.breakdown ?? [];
    final uniqueTypes = <String>[];
    for (final t in rawBreakdown) {
      if (!uniqueTypes.contains(t)) {
        uniqueTypes.add(t);
      }
    }

    final currentType = _currentSession?.isSkipped == true
        ? 'skip'
        : (_currentSession?.todayDayName ?? 'Rest');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'تغيير تمرين اليوم' : "Swap Today's Session",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _C.textPri,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _C.textMut),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isArabic
                    ? 'اختر نوع التمرين لليوم بدون تغيير الجدول الأساسي'
                    : 'Override today\'s target session without modifying your overall routine split.',
                style: GoogleFonts.inter(fontSize: 12, color: _C.textMut),
              ),
              const SizedBox(height: 20),

              if (_swapSuggestionNote != null && _swapSuggestionNote!.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _C.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.cyan.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_rounded, color: _C.cyan, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _swapSuggestionNote!,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _C.textPri,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ...uniqueTypes.map((type) {
                final isSelected = type == currentType;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _overrideSession(type),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? _C.cyan.withValues(alpha: 0.12) : _C.cardElev,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? _C.cyan : _C.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                type == 'Rest' ? Icons.nightlight_round : Icons.fitness_center_rounded,
                                color: isSelected ? _C.cyan : _C.textMut,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                type,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? _C.cyan : _C.textPri,
                                ),
                              ),
                            ],
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: _C.cyan, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),
              Divider(color: _C.border, height: 1),
              const SizedBox(height: 12),

              InkWell(
                onTap: () => _overrideSession('skip'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: currentType == 'skip' ? _C.amber.withValues(alpha: 0.12) : _C.cardElev,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: currentType == 'skip' ? _C.amber : _C.border,
                      width: currentType == 'skip' ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.do_not_disturb_on_rounded, color: currentType == 'skip' ? _C.amber : _C.amber.withValues(alpha: 0.8), size: 18),
                          const SizedBox(width: 12),
                          Text(
                            isArabic ? 'تخطي تمرين اليوم (راحة إضافية)' : 'Skip Today (Intentionally Rest)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: currentType == 'skip' ? FontWeight.w800 : FontWeight.w600,
                              color: currentType == 'skip' ? _C.amber : _C.textPri,
                            ),
                          ),
                        ],
                      ),
                      if (currentType == 'skip')
                        const Icon(Icons.check_circle_rounded, color: _C.amber, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDayDetailSheet(WeekDayDetail detail, bool isArabic) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (detail.isCompleted) {
      statusText = isArabic ? 'مكتمل' : 'Completed';
      statusColor = _C.cyan;
      statusIcon = Icons.check_circle_rounded;
    } else if (detail.isSkipped) {
      statusText = isArabic ? 'متخطى' : 'Skipped';
      statusColor = _C.amber;
      statusIcon = Icons.do_not_disturb_on_rounded;
    } else if (detail.isRest) {
      statusText = isArabic ? 'يوم راحة' : 'Rest Day';
      statusColor = _C.textMut;
      statusIcon = Icons.nightlight_round;
    } else if (detail.isMissed) {
      statusText = isArabic ? 'فائت' : 'Missed';
      statusColor = Colors.redAccent;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusText = isArabic ? 'مجدول' : 'Scheduled';
      statusColor = _C.textSec;
      statusIcon = Icons.schedule_rounded;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${detail.dayName} · ${detail.dateStr}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _C.textPri,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.dayType == 'skip' ? 'Skipped' : detail.dayType,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.cyan,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayCard(bool isArabic) {
    final routine = _activeRoutine!;
    final session = _currentSession;

    final todayLabel = session?.todayDayName
        ?? (() {
          final idx = DateTime.now().weekday - 1;
          final sched = routine.breakdown;
          return sched.isNotEmpty ? sched[idx % sched.length] : 'Training Day';
        })();

    final exercises = session?.exercises ?? [];
    final isRestDay = session?.isRestDay ?? exercises.isEmpty;
    final isSkipped = session?.isSkipped ?? false;
    final visibleCount = _showAllExercises ? exercises.length : (exercises.length > 2 ? 2 : exercises.length);
    final remainingCount = exercises.length - 2;

    return Column(
      children: [
        CoachInputCard(
          coachNote: _currentSession?.coachNote,
          isArabic: isArabic,
          isInterpreting: _isInterpretingAiCommand,
          onSendCommand: (msg) => _sendAiCommand(msg, isArabic),
        ),
        if (isSkipped)
          Container(
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.amber.withValues(alpha: 0.4), width: 1.2),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _C.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.amber.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Text(
                        isArabic ? 'تمرين متخطى' : 'SESSION SKIPPED',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _C.amber),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showSwapSessionSheet(isArabic),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: _C.cyan),
                      label: Text(
                        isArabic ? 'تغيير' : 'Swap Session',
                        style: GoogleFonts.inter(fontSize: 12, color: _C.cyan, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.do_not_disturb_on_rounded, color: _C.amber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'تمت إضافة هذا اليوم كراحة إضافية. سيتواصل جدول تمرينك كالمعتاد غداً.'
                            : 'You marked today as skipped for extra recovery. Regular split resumes tomorrow.',
                        style: GoogleFonts.inter(fontSize: 13, color: _C.textSec, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.border, width: 1.2),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge + Swap Button Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    InkWell(
                      onTap: () => _showSwapSessionSheet(isArabic),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.cyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _C.cyan.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz_rounded, size: 14, color: _C.cyan),
                            const SizedBox(width: 4),
                            Text(
                              isArabic ? 'تغيير' : 'Swap Session',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _C.cyan),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                ...[
                  ...List.generate(visibleCount, (i) {
                    return WorkoutExerciseRow(
                      key: ValueKey(exercises[i].id ?? exercises[i].name),
                      exercise: exercises[i],
                      index: i,
                      isFirst: i == 0,
                    );
                  }),
                  if (exercises.length > 2) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showAllExercises = !_showAllExercises;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showAllExercises
                                  ? (isArabic ? 'إخفاء التمارين' : 'Show less')
                                  : (isArabic ? '+ $remainingCount تمارين إضافية' : '+ $remainingCount more exercises'),
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.cyan),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showAllExercises ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: _C.cyan,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

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
    ),
  ],
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
    const weekDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final detail = i < _weekScheduleDetails.length ? _weekScheduleDetails[i] : null;
        final label = weekDayLabels[i];

        final isCompleted = detail?.isCompleted ?? (i < _completedDaysThisWeek.length ? _completedDaysThisWeek[i] : false);
        final isSkipped   = detail?.isSkipped ?? false;
        final isRest      = detail?.isRest ?? false;
        final isMissed    = detail?.isMissed ?? false;
        final isToday     = detail?.isToday ?? (i == todayIndex);

        Color circleBg = _C.cardElev;
        Color borderColor = _C.border;
        Widget circleChild = const SizedBox.shrink();

        if (isCompleted) {
          circleBg = isToday ? _C.cyan.withValues(alpha: 0.25) : _C.cyan.withValues(alpha: 0.15);
          borderColor = _C.cyan;
          circleChild = const Icon(Icons.check_rounded, color: _C.cyan, size: 14);
        } else if (isSkipped) {
          circleBg = _C.amber.withValues(alpha: 0.12);
          borderColor = _C.amber.withValues(alpha: 0.4);
          circleChild = const Icon(Icons.block_rounded, color: _C.amber, size: 13);
        } else if (isMissed) {
          circleBg = Colors.redAccent.withValues(alpha: 0.1);
          borderColor = Colors.redAccent.withValues(alpha: 0.4);
          circleChild = const Icon(Icons.priority_high_rounded, color: Colors.redAccent, size: 13);
        } else if (isRest) {
          circleBg = Colors.transparent;
          borderColor = _C.borderMid;
          circleChild = const Icon(Icons.nightlight_round, color: _C.textMut, size: 11);
        }

        return GestureDetector(
          onTap: () {
            if (detail != null) {
              _showDayDetailSheet(detail, isArabic);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Column(children: [
            Text(label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? _C.cyan : _C.textMut,
                )),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isToday ? _C.cyan : borderColor,
                  width: isToday ? 1.8 : 1.0,
                ),
                boxShadow: isToday
                    ? [BoxShadow(color: _C.cyan.withValues(alpha: 0.3), blurRadius: 6)]
                    : null,
              ),
              child: Center(child: circleChild),
            ),
          ]),
        );
      }),
    );
  }

  Future<void> _sendAiCommand(String messageText, bool isArabic) async {
    final msg = messageText.trim();
    if (msg.isEmpty || _isInterpretingAiCommand) return;

    setState(() => _isInterpretingAiCommand = true);
    try {
      final resp = await _dio.post('/workouts/session/interpret', data: {'message': msg});
      final data = resp.data['data'];
      final confirmationMsg = data?['confirmationMessage'] as String? ?? 'Session updated.';
      final updatedSessionJson = data?['currentSession'];

      _aiCommandController.clear();

      if (updatedSessionJson != null && mounted) {
        setState(() {
          _currentSession = CurrentSession.fromJson(updatedSessionJson as Map<String, dynamic>);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    confirmationMsg,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                ),
              ],
            ),
            backgroundColor: _C.cyan,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to process command. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInterpretingAiCommand = false);
      }
    }
  }

  Future<void> _showWeeklyRecapSheet(bool isArabic) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: FutureBuilder(
            future: _dio.get('/workouts/weekly-recap'),
            builder: (context, AsyncSnapshot<Response> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_C.cyan)),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      isArabic ? 'فشل تحميل الملخص الأسبوعي' : 'Failed to load weekly recap',
                      style: GoogleFonts.inter(color: _C.textMut),
                    ),
                  ),
                );
              }

              final data = snapshot.data!.data['data'];
              final recapNote = data['recapNote'] as String? ?? '';
              final completed = data['completedDaysCount'] as int? ?? 0;
              final streak = data['streakDays'] as int? ?? 0;
              final prs = (data['prsAchieved'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _C.cyan.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: _C.cyan, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isArabic ? 'الملخص الأسبوعي بالذكاء الاصطناعي' : 'Weekly AI Recap',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _C.textPri,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: _C.textMut, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildRecapStatBadge(
                        label: isArabic ? 'مكتمل' : 'Completed',
                        value: '$completed days',
                        color: _C.cyan,
                      ),
                      const SizedBox(width: 10),
                      _buildRecapStatBadge(
                        label: isArabic ? 'سلسلة' : 'Streak',
                        value: '$streak days',
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(width: 10),
                      _buildRecapStatBadge(
                        label: isArabic ? 'أرقام قياسية' : 'PRs',
                        value: '${prs.length}',
                        color: Colors.greenAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.cardElev,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.border, width: 1),
                    ),
                    child: Text(
                      recapNote,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _C.textPri,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        isArabic ? 'حسناً' : 'Got it',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecapStatBadge({required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _C.textMut),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
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
  int _step = 0;
  int? _selectedFreq;
  String _selectedExp = 'new'; // 'new' | 'consistent' | 'experienced'

  bool _loadingRecommend = false;
  Map<String, dynamic>? _recommendedData;

  @override
  void initState() {
    super.initState();
    final profileState = context.read<ProfileBloc>().state;
    if (profileState is ProfileLoaded) {
      final exp = profileState.user['trainingExperience'] as String?;
      if (exp != null && exp.isNotEmpty) {
        _selectedExp = exp;
      }
    }
  }

  Future<void> _fetchRecommendation() async {
    if (_selectedFreq == null) return;
    setState(() {
      _step = 1;
      _loadingRecommend = true;
    });

    // Save trainingExperience to profile
    context.read<ProfileBloc>().add(UpdateProfileEvent(trainingExperience: _selectedExp));

    try {
      final dio = ApiClient().dio;
      final resp = await dio.get('/workouts/recommend', queryParameters: {'days': _selectedFreq});
      if (mounted) {
        setState(() {
          _recommendedData = resp.data['data'] as Map<String, dynamic>?;
          _loadingRecommend = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRecommend = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
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

  // ── Step 1: Frequency & Training Experience ────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Smart Routine Planner',
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: _C.textPri, letterSpacing: -0.4)),
        const SizedBox(height: 4),
        Text('Step 1 of 2 · Training Background',
            style: GoogleFonts.inter(fontSize: 12, color: _C.textMut)),
        const SizedBox(height: 20),

        // Section A: Days/Week
        Text('How many days per week do you train?',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: _C.textPri)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [3, 4, 5, 6].map((days) {
            final sel = _selectedFreq == days;
            return GestureDetector(
              onTap: () => setState(() => _selectedFreq = days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: sel ? _C.cyan.withValues(alpha: 0.15) : _C.cardElev,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel ? _C.cyan : _C.borderMid, width: sel ? 2 : 1.2),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$days Days',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: sel ? _C.cyan : _C.textPri)),
                  Text('per week',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: sel ? _C.cyan.withValues(alpha: 0.8) : _C.textMut)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Section B: Training Experience
        Text('How long have you been lifting?',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: _C.textPri)),
        const SizedBox(height: 12),

        ...[
          {'val': 'new', 'title': 'New to lifting', 'desc': 'Under 6 months of consistent training'},
          {'val': 'consistent', 'title': 'Consistent lifter', 'desc': '6 months to 2 years of lifting history'},
          {'val': 'experienced', 'title': 'Experienced lifter', 'desc': '2+ years of structured strength training'},
        ].map((item) {
          final val = item['val']!;
          final sel = _selectedExp == val;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => setState(() => _selectedExp = val),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? _C.cyan.withValues(alpha: 0.12) : _C.cardElev,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel ? _C.cyan : _C.borderMid,
                    width: sel ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: sel ? _C.cyan : _C.textMut,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title']!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                              color: sel ? _C.cyan : _C.textPri,
                            ),
                          ),
                          Text(
                            item['desc']!,
                            style: GoogleFonts.inter(fontSize: 11, color: _C.textMut),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selectedFreq != null ? _fetchRecommendation : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.cyan,
              disabledBackgroundColor: _C.border,
              foregroundColor: Colors.black,
              disabledForegroundColor: _C.textMut,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Get Personalized Split',
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

  // ── Step 2: Intelligent Recommendation ─────────────────────
  Widget _buildStep2() {
    if (_loadingRecommend) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const CircularProgressIndicator(color: _C.cyan),
            const SizedBox(height: 20),
            Text(
              'Analyzing your profile & generating AI coach recommendation...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _C.textSec),
            ),
          ],
        ),
      );
    }

    final data = _recommendedData;
    final recommended = data?['recommended'] as Map<String, dynamic>?;
    final otherOptions = (data?['otherOptions'] as List<dynamic>?) ?? [];

    if (recommended == null) {
      return Column(
        children: [
          Text('Failed to load recommendation', style: GoogleFonts.inter(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _step = 0),
            child: const Text('Back'),
          ),
        ],
      );
    }

    final recName = recommended['name'] as String? ?? 'Recommended Split';
    final recTagline = recommended['tagline'] as String? ?? '';
    final recBreakdown = (recommended['breakdown'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final recReasonNote = recommended['reasonNote'] as String? ?? '';

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
        const SizedBox(height: 4),
        Text('Step 2 of 2 · AI Coach Recommendation',
            style: GoogleFonts.inter(fontSize: 12, color: _C.textMut)),
        const SizedBox(height: 20),

        // ── TOP RECOMMENDED CARD ────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _C.cyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.cyan, width: 2),
            boxShadow: [BoxShadow(color: _C.cyan.withValues(alpha: 0.2), blurRadius: 16)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _C.cyan,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'BEST FIT FOR YOU',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.memory_rounded, color: _C.cyan, size: 12),
                      const SizedBox(width: 4),
                      Text('AI Coach', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _C.cyan)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                recName,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _C.textPri),
              ),
              const SizedBox(height: 4),
              Text(recTagline, style: GoogleFonts.inter(fontSize: 12, color: _C.textSec)),
              const SizedBox(height: 14),

              // Reasoning Box
              if (recReasonNote.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.psychology_rounded, color: _C.cyan, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          recReasonNote,
                          style: GoogleFonts.inter(fontSize: 12, color: _C.textPri, height: 1.4, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // Breakdown Pills
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: recBreakdown.map((d) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _C.cyan.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    d,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _C.cyan),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Configure Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final split = RoutineSuggestion(
                      name: recName,
                      splitType: recommended['splitType'] as String,
                      tagline: recTagline,
                      breakdown: recBreakdown,
                    );
                    widget.onComplete(_selectedFreq!, split);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text('Configure This Plan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.cyan,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── OTHER OPTIONS ──────────────────────────────────
        if (otherOptions.isNotEmpty) ...[
          Text('Other Options for $_selectedFreq Days',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _C.textPri)),
          const SizedBox(height: 12),

          ...otherOptions.map((opt) {
            final optMap = opt as Map<String, dynamic>;
            final optName = optMap['name'] as String? ?? 'Split';
            final optTagline = optMap['tagline'] as String? ?? '';
            final optBreakdown = (optMap['breakdown'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            final optReasonTag = optMap['reasonTag'] as String? ?? 'Alternative option';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _C.cardElev,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.border, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            optName,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _C.textPri),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _C.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _C.amber.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            optReasonTag,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _C.amber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(optTagline, style: GoogleFonts.inter(fontSize: 12, color: _C.textSec)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: optBreakdown.map((d) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.card,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _C.border),
                        ),
                        child: Text(d, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _C.textSec)),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () {
                          final split = RoutineSuggestion(
                            name: optName,
                            splitType: optMap['splitType'] as String,
                            tagline: optTagline,
                            breakdown: optBreakdown,
                          );
                          widget.onComplete(_selectedFreq!, split);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _C.textPri,
                          side: const BorderSide(color: _C.borderMid),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Select This Plan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EXTRACTED COMPONENT 1: CoachInputCard (Isolated text field state)
// ══════════════════════════════════════════════════════════════

class CoachInputCard extends StatefulWidget {
  final String? coachNote;
  final bool isArabic;
  final bool isInterpreting;
  final Future<void> Function(String message) onSendCommand;

  const CoachInputCard({
    super.key,
    required this.coachNote,
    required this.isArabic,
    required this.isInterpreting,
    required this.onSendCommand,
  });

  @override
  State<CoachInputCard> createState() => _CoachInputCardState();
}

class _CoachInputCardState extends State<CoachInputCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isInterpreting) return;
    widget.onSendCommand(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final coachNote = widget.coachNote;
    final hasNote = coachNote != null && coachNote.trim().isNotEmpty;
    final isArabic = widget.isArabic;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.cyan.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasNote) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _C.cyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded, color: _C.cyan, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isArabic ? 'نصيحة مدرب الذكاء الاصطناعي' : 'AI COACH NOTE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _C.cyan,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _C.cyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _C.cyan.withValues(alpha: 0.3), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, color: _C.cyan, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  'Ollama AI',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: _C.cyan),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        coachNote!,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: _C.textPri,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: _C.border, height: 1, thickness: 0.8),
            const SizedBox(height: 10),
          ],

          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _C.cyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isInterpreting,
                  style: GoogleFonts.inter(fontSize: 12, color: _C.textPri),
                  decoration: InputDecoration(
                    hintText: isArabic ? 'اكتب أمراً.. "غير اليوم لـ Legs"' : 'Command AI coach.. e.g. "swap today for legs"',
                    hintStyle: GoogleFonts.inter(fontSize: 11, color: _C.textMut),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: widget.isInterpreting ? null : _submit,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: widget.isInterpreting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_C.cyan)),
                        )
                      : const Icon(Icons.send_rounded, color: _C.cyan, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EXTRACTED COMPONENT 2: WorkoutExerciseRow (Isolated accordion state)
// ══════════════════════════════════════════════════════════════

class WorkoutExerciseRow extends StatefulWidget {
  final SessionExercise exercise;
  final int index;
  final bool isFirst;

  const WorkoutExerciseRow({
    super.key,
    required this.exercise,
    required this.index,
    required this.isFirst,
  });

  @override
  State<WorkoutExerciseRow> createState() => _WorkoutExerciseRowState();
}

class _WorkoutExerciseRowState extends State<WorkoutExerciseRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final i = widget.index;
    final isFirst = widget.isFirst;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ex.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isFirst ? FontWeight.w700 : FontWeight.w600,
                                color: isFirst ? _C.textPri : _C.textSec,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ex.isPlateaued) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _C.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _C.amber.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.show_chart_rounded, color: _C.amber, size: 10),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Plateau',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: _C.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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
                const SizedBox(width: 6),

                // Chevron accordion indicator
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _C.textMut,
                  size: 20,
                ),
              ],
            ),

            // Accordion Expanded Coach Note Body
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.cardElev,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.borderMid),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: _C.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ex.coachNote ??
                            (ex.lastWeekWeight != null
                                ? 'Target matching ${ex.lastWeekWeight}kg × ${ex.lastWeekReps} reps.'
                                : 'First time on this exercise — start conservative and focus on form.'),
                        style: GoogleFonts.inter(fontSize: 12, color: _C.textSec, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EXTRACTED COMPONENT 3: WeeklyCalendarRow (Isolated status dots)
// ══════════════════════════════════════════════════════════════

class WeeklyCalendarRow extends StatelessWidget {
  final List<WeekDayDetail> weekScheduleDetails;
  final List<bool> completedDaysThisWeek;
  final bool isArabic;
  final Function(WeekDayDetail detail) onDayTap;

  const WeeklyCalendarRow({
    super.key,
    required this.weekScheduleDetails,
    required this.completedDaysThisWeek,
    required this.isArabic,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    const weekDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final detail = i < weekScheduleDetails.length ? weekScheduleDetails[i] : null;
        final label = weekDayLabels[i];

        final isCompleted = detail?.isCompleted ?? (i < completedDaysThisWeek.length ? completedDaysThisWeek[i] : false);
        final isSkipped   = detail?.isSkipped ?? false;
        final isRest      = detail?.isRest ?? false;
        final isMissed    = detail?.isMissed ?? false;
        final isToday     = detail?.isToday ?? (i == todayIndex);

        Color circleBg = _C.cardElev;
        Color borderColor = _C.border;
        Widget circleChild = const SizedBox.shrink();

        if (isCompleted) {
          circleBg = isToday ? _C.cyan.withValues(alpha: 0.25) : _C.cyan.withValues(alpha: 0.15);
          borderColor = _C.cyan;
          circleChild = const Icon(Icons.check_rounded, color: _C.cyan, size: 14);
        } else if (isSkipped) {
          circleBg = _C.amber.withValues(alpha: 0.12);
          borderColor = _C.amber.withValues(alpha: 0.4);
          circleChild = const Icon(Icons.block_rounded, color: _C.amber, size: 13);
        } else if (isMissed) {
          circleBg = Colors.redAccent.withValues(alpha: 0.1);
          borderColor = Colors.redAccent.withValues(alpha: 0.4);
          circleChild = const Icon(Icons.priority_high_rounded, color: Colors.redAccent, size: 13);
        } else if (isRest) {
          circleBg = Colors.transparent;
          borderColor = _C.borderMid;
          circleChild = const Icon(Icons.nightlight_round, color: _C.textMut, size: 11);
        }

        return GestureDetector(
          onTap: () {
            if (detail != null) {
              onDayTap(detail);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Column(children: [
            Text(label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? _C.cyan : _C.textMut,
                )),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isToday ? _C.cyan : borderColor,
                  width: isToday ? 1.8 : 1.0,
                ),
                boxShadow: isToday
                    ? [BoxShadow(color: _C.cyan.withValues(alpha: 0.3), blurRadius: 6)]
                    : null,
              ),
              child: Center(child: circleChild),
            ),
          ]),
        );
      }),
    );
  }
}
