// lib/features/calorie_tracker/data/models/workout_models.dart
// Aura — Workout Data Models
//
// SessionExercise   → one exercise entry from the backend currentSession
// TopHistoricalSet  → contextual last-week best, keyed to the FIRST exercise
// CurrentSession    → today's full session object from backend
// RoutineCatalogue  → static set of recommended splits per frequency
// RoutineSuggestion → a selectable training split with breakdown
// WorkoutLog        → a live logging session (exercise + sets)
// ExerciseSet       → one logged set (weight, reps, locked state)

// ═══════════════════════════════════════════════════════════════
// Exercise (Database Entity)
// ═══════════════════════════════════════════════════════════════

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String? mechanic;
  
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.mechanic,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id:          j['id'] as String? ?? '',
    name:        j['name'] as String? ?? 'Exercise',
    muscleGroup: j['muscleGroup'] as String? ?? '',
    mechanic:    j['mechanic'] as String?,
  );
}

// ═══════════════════════════════════════════════════════════════
// SessionExercise
// ═══════════════════════════════════════════════════════════════

class SessionExercise {
  final String? id; // Real DB Exercise ID
  final String? workoutExerciseId; // Real DB WorkoutExercise ID if added to a session
  final String name;
  final int targetSets;
  final String muscleGroup;
  final double? lastWeekWeight;
  final int? lastWeekReps;
  final String? coachNote;

  const SessionExercise({
    this.id,
    this.workoutExerciseId,
    required this.name,
    required this.targetSets,
    required this.muscleGroup,
    this.lastWeekWeight,
    this.lastWeekReps,
    this.coachNote,
  });

  factory SessionExercise.fromJson(Map<String, dynamic> j) => SessionExercise(
        id:             j['id'] as String?,
        workoutExerciseId: j['workoutExerciseId'] as String?,
        name:           j['name'] as String? ?? 'Exercise',
        targetSets:     (j['targetSets'] as num?)?.toInt() ?? 3,
        muscleGroup:    j['muscleGroup'] as String? ?? '',
        lastWeekWeight: (j['lastWeekWeight'] as num?)?.toDouble(),
        lastWeekReps:   (j['lastWeekReps'] as num?)?.toInt(),
        coachNote:      j['coachNote'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════════
// TopHistoricalSet
// ═══════════════════════════════════════════════════════════════

class TopHistoricalSet {
  final String exerciseName;
  final double weight;
  final int reps;
  final String progressionDelta;

  const TopHistoricalSet({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.progressionDelta,
  });

  factory TopHistoricalSet.fromJson(Map<String, dynamic> j) => TopHistoricalSet(
        exerciseName:     j['exerciseName'] as String? ?? 'Exercise',
        weight:           (j['weight'] as num?)?.toDouble() ?? 0,
        reps:             (j['reps'] as num?)?.toInt() ?? 0,
        progressionDelta: j['progressionDelta'] as String? ?? '',
      );

  String get displayLabel =>
      '$exerciseName: ${weight.toStringAsFixed(0)} kg × $reps reps';
}

// ═══════════════════════════════════════════════════════════════
// CurrentSession  — today's active plan from the backend
// ═══════════════════════════════════════════════════════════════

class CurrentSession {
  final String routineName;
  final String todayDayName;
  final List<SessionExercise> exercises;
  final String? coachNote;
  final TopHistoricalSet? topHistoricalSet;

  const CurrentSession({
    required this.routineName,
    required this.todayDayName,
    required this.exercises,
    this.coachNote,
    this.topHistoricalSet,
  });

  bool get isRestDay => exercises.isEmpty;

  factory CurrentSession.fromJson(Map<String, dynamic> j) => CurrentSession(
        routineName:     j['routineName'] as String? ?? 'Workout',
        todayDayName:    j['todayDayName'] as String? ?? 'Training Day',
        exercises:       (j['exercises'] as List<dynamic>? ?? [])
            .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        coachNote:        j['coachNote'] as String?,
        topHistoricalSet: j['topHistoricalSet'] != null
            ? TopHistoricalSet.fromJson(j['topHistoricalSet'] as Map<String, dynamic>)
            : null,
      );
}

// ═══════════════════════════════════════════════════════════════
// RoutineSuggestion
// ═══════════════════════════════════════════════════════════════

class RoutineSuggestion {
  final String name;
  final String splitType;  // unique key, sent to backend
  final String tagline;
  final List<String> breakdown; // per-day labels (7 entries max)

  const RoutineSuggestion({
    required this.name,
    required this.splitType,
    required this.tagline,
    required this.breakdown,
  });

  Map<String, dynamic> toJson() => {
    'name':      name,
    'splitType': splitType,
    'tagline':   tagline,
    'breakdown': breakdown,
  };
}

// ═══════════════════════════════════════════════════════════════
// RoutineCatalogue — static catalogue keyed by daysPerWeek
// ═══════════════════════════════════════════════════════════════

class RoutineCatalogue {
  RoutineCatalogue._();

  static List<RoutineSuggestion> forDays(int days) {
    switch (days) {
      case 3:
        return _3day;
      case 4:
        return _4day;
      case 5:
        return _5day;
      case 6:
        return _6day;
      default:
        return _3day;
    }
  }

  static const List<RoutineSuggestion> _3day = [
    RoutineSuggestion(
      name: 'Full Body A/B/C',
      splitType: 'full_body',
      tagline: '3 full-body sessions — all major muscle groups hit each day.',
      breakdown: ['Full Body (Heavy)', 'Rest', 'Full Body (Moderate)', 'Rest', 'Full Body (Light)', 'Rest', 'Rest'],
    ),
    RoutineSuggestion(
      name: 'Classic PPL (1×)',
      splitType: 'ppl_1x',
      tagline: 'Push / Pull / Legs — each muscle group once per week.',
      breakdown: ['Push', 'Pull', 'Legs', 'Rest', 'Rest', 'Rest', 'Rest'],
    ),
  ];

  static const List<RoutineSuggestion> _4day = [
    RoutineSuggestion(
      name: 'Upper / Lower Split',
      splitType: 'upper_lower',
      tagline: 'Each muscle group trained twice per week — optimal frequency for hypertrophy.',
      breakdown: ['Upper (Heavy)', 'Lower (Heavy)', 'Rest', 'Upper (Volume)', 'Lower (Volume)', 'Rest', 'Rest'],
    ),
    RoutineSuggestion(
      name: 'Bro Split (4-day)',
      splitType: 'bro_split',
      tagline: 'One primary muscle group per day — maximum per-session volume.',
      breakdown: ['Chest', 'Back', 'Shoulders', 'Legs + Arms', 'Rest', 'Rest', 'Rest'],
    ),
  ];

  static const List<RoutineSuggestion> _5day = [
    RoutineSuggestion(
      name: 'Upper / Lower / PPL Hybrid',
      splitType: 'ul_ppl',
      tagline: 'Combines upper/lower efficiency with PPL frequency.',
      breakdown: ['Upper', 'Lower', 'Push', 'Pull', 'Legs', 'Rest', 'Rest'],
    ),
    RoutineSuggestion(
      name: 'Bro Split (5-day)',
      splitType: 'bro_split_5',
      tagline: 'Full weekly coverage — arms get a dedicated session.',
      breakdown: ['Chest', 'Back', 'Shoulders', 'Legs', 'Arms + Abs', 'Rest', 'Rest'],
    ),
  ];

  static const List<RoutineSuggestion> _6day = [
    RoutineSuggestion(
      name: 'PPL 2× (Classic)',
      splitType: 'ppl_2x',
      tagline: 'Each muscle group hit twice — considered the king of hypertrophy splits.',
      breakdown: ['Push A', 'Pull A', 'Legs A', 'Rest', 'Push B', 'Pull B', 'Legs B'],
    ),
    RoutineSuggestion(
      name: 'Arnold Split',
      splitType: 'arnold_split',
      tagline: "Arnold's original 6-day blueprint — antagonist supersets per session.",
      breakdown: ['Chest + Back', 'Shoulders + Arms', 'Legs', 'Chest + Back', 'Shoulders + Arms', 'Legs', 'Rest'],
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════
// ExerciseSet — one set entry in the active workout tracker
// ═══════════════════════════════════════════════════════════════

class ExerciseSet {
  String? id; // Real DB ExerciseSet ID when saved
  final int setIndex;       // 1-based display number
  final String label;       // 'Warm-up', 'Working Set', 'Top Set'
  final double? targetWeightKg;
  final int? targetReps;

  // Mutable (user input)
  double? loggedWeightKg;
  int?    loggedReps;
  bool    isLogged;
  DateTime? loggedAt;

  ExerciseSet({
    this.id,
    required this.setIndex,
    required this.label,
    this.targetWeightKg,
    this.targetReps,
    this.loggedWeightKg,
    this.loggedReps,
    this.isLogged = false,
    this.loggedAt,
  });

  String get targetDisplayLabel {
    if (targetWeightKg != null && targetReps != null) {
      return '${targetWeightKg!.toStringAsFixed(0)} kg × $targetReps reps';
    }
    if (targetReps != null) return 'Target: $targetReps reps';
    return label;
  }

  Map<String, dynamic> toJson() => {
    'id':             id,
    'setIndex':       setIndex,
    'label':          label,
    'targetWeightKg': targetWeightKg,
    'targetReps':     targetReps,
    'loggedWeightKg': loggedWeightKg,
    'loggedReps':     loggedReps,
    'isLogged':       isLogged,
    'loggedAt':       loggedAt?.toIso8601String(),
  };
}

// ═══════════════════════════════════════════════════════════════
// WorkoutLog — the full live session
// ═══════════════════════════════════════════════════════════════

class WorkoutLog {
  String? sessionId; // Real DB WorkoutSession ID
  final String exerciseName;
  final String muscleGroup;
  final List<ExerciseSet> sets;
  final String? lastWeekTopPerformance;
  final DateTime startedAt;

  WorkoutLog({
    this.sessionId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
    this.lastWeekTopPerformance,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  int get loggedSetsCount => sets.where((s) => s.isLogged).length;
  bool get isComplete => loggedSetsCount == sets.length;

  Duration get elapsed => DateTime.now().difference(startedAt);

  /// Default push day session — used when backend has not yet provided live data
  factory WorkoutLog.defaultPushDay() {
    return WorkoutLog(
      exerciseName: 'Bench Press',
      muscleGroup: 'Chest · Triceps',
      lastWeekTopPerformance: '80 kg × 5 reps',
      sets: [
        ExerciseSet(
          setIndex: 1, label: 'Warm-up',
          targetWeightKg: 60, targetReps: 10,
        ),
        ExerciseSet(
          setIndex: 2, label: 'Working Set',
          targetWeightKg: 80, targetReps: 8,
        ),
        ExerciseSet(
          setIndex: 3, label: 'Working Set',
          targetWeightKg: 80, targetReps: 8,
        ),
        ExerciseSet(
          setIndex: 4, label: 'Top Set',
          targetWeightKg: 85, targetReps: 5,
        ),
        ExerciseSet(
          setIndex: 5, label: 'Back-off Set',
          targetWeightKg: 75, targetReps: 10,
        ),
      ],
    );
  }

  /// Build a live WorkoutLog from the backend CurrentSession.
  /// Always uses the FIRST exercise in today's list.
  factory WorkoutLog.fromSession(CurrentSession session) {
    if (session.isRestDay || session.exercises.isEmpty) {
      return WorkoutLog.defaultPushDay();
    }

    final ex = session.exercises.first;
    final totalSets = ex.targetSets.clamp(3, 6);

    // Build set labels dynamically based on totalSets
    final sets = <ExerciseSet>[];
    for (int i = 0; i < totalSets; i++) {
      final setIndex = i + 1;
      String label;
      double? weight = ex.lastWeekWeight;
      int? reps = ex.lastWeekReps;

      if (i == 0) {
        label = 'Warm-up';
        weight = (ex.lastWeekWeight != null) ? ex.lastWeekWeight! * 0.7 : null;
        reps = (ex.lastWeekReps != null) ? (ex.lastWeekReps! + 2) : null;
      } else if (i == totalSets - 1 && totalSets >= 4) {
        label = 'Back-off Set';
        weight = (ex.lastWeekWeight != null) ? ex.lastWeekWeight! * 0.88 : null;
      } else if (i == totalSets - 2 && totalSets >= 4) {
        label = 'Top Set';
        weight = (ex.lastWeekWeight != null) ? ex.lastWeekWeight! + 2.5 : null;
        reps = (ex.lastWeekReps != null) ? (ex.lastWeekReps! - 2).clamp(1, 20) : null;
      } else {
        label = 'Working Set';
      }

      sets.add(ExerciseSet(
        setIndex:        setIndex,
        label:           label,
        targetWeightKg:  weight != null ? double.parse(weight.toStringAsFixed(1)) : null,
        targetReps:      reps,
      ));
    }

    final top = session.topHistoricalSet;
    final perfLabel = top != null
        ? '${top.weight.toStringAsFixed(0)} kg × ${top.reps} reps'
        : null;

    return WorkoutLog(
      exerciseName:          ex.name,
      muscleGroup:           ex.muscleGroup,
      lastWeekTopPerformance: perfLabel,
      sets:                  sets,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseName':           exerciseName,
    'muscleGroup':            muscleGroup,
    'sets':                   sets.map((s) => s.toJson()).toList(),
    'lastWeekTopPerformance': lastWeekTopPerformance,
    'startedAt':              startedAt.toIso8601String(),
  };
}
