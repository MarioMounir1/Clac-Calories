// lib/features/calorie_tracker/data/models/workout_models.dart
// Calc-Calories — Workout Hub Data Models
//
// Models:
//   WorkoutRoutine  — a configured training program
//   ExerciseSet     — a single logged set inside a workout
//   WorkoutLog      — a full active/completed workout session

// ── WorkoutRoutine ────────────────────────────────────────────

class WorkoutRoutine {
  final String id;
  final String name;           // e.g. "Upper/Lower Split"
  final String description;    // e.g. "4-day routine focusing on..."
  final int daysPerWeek;
  final String splitType;      // e.g. "upper_lower", "ppl", "full_body"
  final List<String> exercises;
  final DateTime createdAt;

  const WorkoutRoutine({
    required this.id,
    required this.name,
    required this.description,
    required this.daysPerWeek,
    required this.splitType,
    required this.exercises,
    required this.createdAt,
  });

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) => WorkoutRoutine(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        daysPerWeek: json['daysPerWeek'] as int? ?? 3,
        splitType: json['splitType'] as String? ?? 'full_body',
        exercises: (json['exercises'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'daysPerWeek': daysPerWeek,
        'splitType': splitType,
        'exercises': exercises,
        'createdAt': createdAt.toIso8601String(),
      };

  WorkoutRoutine copyWith({
    String? id,
    String? name,
    String? description,
    int? daysPerWeek,
    String? splitType,
    List<String>? exercises,
    DateTime? createdAt,
  }) =>
      WorkoutRoutine(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        splitType: splitType ?? this.splitType,
        exercises: exercises ?? this.exercises,
        createdAt: createdAt ?? this.createdAt,
      );
}

// ── ExerciseSet ───────────────────────────────────────────────

class ExerciseSet {
  final int setIndex;           // 1-based index
  final String label;           // e.g. "Top Set", "Back-off Set"
  final double? targetWeightKg;
  final int? targetRepsMin;
  final int? targetRepsMax;

  // Mutable logging fields
  double? loggedWeightKg;
  int? loggedReps;
  bool isLogged;
  DateTime? loggedAt;

  ExerciseSet({
    required this.setIndex,
    required this.label,
    this.targetWeightKg,
    this.targetRepsMin,
    this.targetRepsMax,
    this.loggedWeightKg,
    this.loggedReps,
    this.isLogged = false,
    this.loggedAt,
  });

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
        setIndex: json['setIndex'] as int? ?? 1,
        label: json['label'] as String? ?? 'Set',
        targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
        targetRepsMin: json['targetRepsMin'] as int?,
        targetRepsMax: json['targetRepsMax'] as int?,
        loggedWeightKg: (json['loggedWeightKg'] as num?)?.toDouble(),
        loggedReps: json['loggedReps'] as int?,
        isLogged: json['isLogged'] as bool? ?? false,
        loggedAt: json['loggedAt'] != null
            ? DateTime.tryParse(json['loggedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'setIndex': setIndex,
        'label': label,
        'targetWeightKg': targetWeightKg,
        'targetRepsMin': targetRepsMin,
        'targetRepsMax': targetRepsMax,
        'loggedWeightKg': loggedWeightKg,
        'loggedReps': loggedReps,
        'isLogged': isLogged,
        'loggedAt': loggedAt?.toIso8601String(),
      };

  /// Returns the target rep range as a display string e.g. "4–6 reps"
  String get targetRepsLabel {
    if (targetRepsMin != null && targetRepsMax != null) {
      return '$targetRepsMin–$targetRepsMax reps';
    }
    if (targetRepsMin != null) return '$targetRepsMin+ reps';
    return '';
  }

  /// Returns the full target string e.g. "Target: 100 kg | 4–6 reps"
  String get targetDisplayLabel {
    final parts = <String>[];
    if (targetWeightKg != null) {
      parts.add('${targetWeightKg!.toStringAsFixed(0)} kg');
    }
    final reps = targetRepsLabel;
    if (reps.isNotEmpty) parts.add(reps);
    if (parts.isEmpty) return 'No target set';
    return 'Target: ${parts.join(' | ')}';
  }
}

// ── WorkoutLog ────────────────────────────────────────────────

class WorkoutLog {
  final String id;
  final String? routineId;
  final String exerciseName;
  final String muscleGroup;
  final List<ExerciseSet> sets;
  final String? lastWeekTopPerformance; // e.g. "100kg × 5 reps"
  final DateTime startedAt;
  DateTime? finishedAt;

  WorkoutLog({
    required this.id,
    this.routineId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
    this.lastWeekTopPerformance,
    required this.startedAt,
    this.finishedAt,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
        id: json['id'] as String? ?? '',
        routineId: json['routineId'] as String?,
        exerciseName: json['exerciseName'] as String? ?? '',
        muscleGroup: json['muscleGroup'] as String? ?? '',
        sets: (json['sets'] as List<dynamic>?)
                ?.map((s) => ExerciseSet.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        lastWeekTopPerformance:
            json['lastWeekTopPerformance'] as String?,
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        finishedAt: json['finishedAt'] != null
            ? DateTime.tryParse(json['finishedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'routineId': routineId,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'sets': sets.map((s) => s.toJson()).toList(),
        'lastWeekTopPerformance': lastWeekTopPerformance,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
      };

  bool get isFinished => finishedAt != null;

  int get loggedSetsCount => sets.where((s) => s.isLogged).length;

  /// Returns a default Push Day log for demonstration / offline use.
  static WorkoutLog defaultPushDay() => WorkoutLog(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        routineId: null,
        exerciseName: 'Barbell Bench Press',
        muscleGroup: 'Chest / Shoulders',
        lastWeekTopPerformance: '100kg × 5 reps',
        startedAt: DateTime.now(),
        sets: [
          ExerciseSet(
            setIndex: 1,
            label: 'Top Set',
            targetWeightKg: 100,
            targetRepsMin: 4,
            targetRepsMax: 6,
            loggedWeightKg: 100,
          ),
          ExerciseSet(
            setIndex: 2,
            label: 'Back-off Set',
            targetWeightKg: 90,
            targetRepsMin: 6,
            targetRepsMax: 8,
          ),
          ExerciseSet(
            setIndex: 3,
            label: 'Volume Set',
            targetWeightKg: 80,
            targetRepsMin: 8,
            targetRepsMax: 12,
          ),
        ],
      );
}

// ── Routine Catalogue ─────────────────────────────────────────
// Static lookup table for recommended routines per training frequency.

class RoutineCatalogue {
  RoutineCatalogue._();

  static List<RoutineSuggestion> forDays(int days) {
    switch (days) {
      case 3:
        return [
          const RoutineSuggestion(
            name: 'Full Body Split',
            splitType: 'full_body',
            tagline: '3 full-body sessions · All major muscle groups each day',
            breakdown: [
              'Day 1 — Full Body (Heavy)',
              'Day 2 — Rest',
              'Day 3 — Full Body (Moderate)',
              'Day 4 — Rest',
              'Day 5 — Full Body (Light/Explosive)',
            ],
          ),
          const RoutineSuggestion(
            name: 'Push / Pull / Legs',
            splitType: 'ppl_1x',
            tagline: 'Classic PPL hit once per week · 3 dedicated sessions',
            breakdown: [
              'Day 1 — Push (Chest, Shoulders, Triceps)',
              'Day 2 — Pull (Back, Biceps)',
              'Day 3 — Legs (Quads, Hamstrings, Glutes)',
            ],
          ),
        ];
      case 4:
        return [
          const RoutineSuggestion(
            name: 'Upper / Lower Split',
            splitType: 'upper_lower',
            tagline: 'Each muscle group trained 2× per week · Optimal frequency',
            breakdown: [
              'Day 1 — Upper (Heavy)',
              'Day 2 — Lower (Heavy)',
              'Day 3 — Rest',
              'Day 4 — Upper (Volume)',
              'Day 5 — Lower (Volume)',
            ],
          ),
          const RoutineSuggestion(
            name: 'Classic Bro Split',
            splitType: 'bro_split',
            tagline: 'One muscle group per day · High volume focus',
            breakdown: [
              'Day 1 — Chest',
              'Day 2 — Back',
              'Day 3 — Shoulders',
              'Day 4 — Legs & Arms',
            ],
          ),
        ];
      case 5:
        return [
          const RoutineSuggestion(
            name: 'Upper / Lower + PPL',
            splitType: 'ul_ppl',
            tagline: 'Hybrid 5-day program · Best of both worlds',
            breakdown: [
              'Day 1 — Upper (Strength)',
              'Day 2 — Lower (Strength)',
              'Day 3 — Push',
              'Day 4 — Pull',
              'Day 5 — Legs (Volume)',
            ],
          ),
          const RoutineSuggestion(
            name: 'Bro Split (Modified)',
            splitType: 'bro_split_5',
            tagline: 'Full coverage · Arms get dedicated session',
            breakdown: [
              'Day 1 — Chest',
              'Day 2 — Back',
              'Day 3 — Shoulders',
              'Day 4 — Legs',
              'Day 5 — Arms & Abs',
            ],
          ),
        ];
      case 6:
      default:
        return [
          const RoutineSuggestion(
            name: 'PPL / Rest / PPL',
            splitType: 'ppl_2x',
            tagline: 'Each muscle group 2× per week · King of hypertrophy',
            breakdown: [
              'Day 1 — Push A',
              'Day 2 — Pull A',
              'Day 3 — Legs A',
              'Day 4 — Rest',
              'Day 5 — Push B',
              'Day 6 — Pull B',
              'Day 7 — Legs B',
            ],
          ),
          const RoutineSuggestion(
            name: 'Arnold Split (Antagonist)',
            splitType: 'arnold_split',
            tagline: 'Arnold\'s original 6-day blueprint · Chest+Back superset',
            breakdown: [
              'Day 1 — Chest + Back',
              'Day 2 — Shoulders + Arms',
              'Day 3 — Legs',
              'Day 4 — Chest + Back',
              'Day 5 — Shoulders + Arms',
              'Day 6 — Legs',
            ],
          ),
        ];
    }
  }
}

class RoutineSuggestion {
  final String name;
  final String splitType;
  final String tagline;
  final List<String> breakdown;

  const RoutineSuggestion({
    required this.name,
    required this.splitType,
    required this.tagline,
    required this.breakdown,
  });
}
