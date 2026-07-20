// lib/features/calorie_tracker/domain/repositories/workout_repository.dart
// Aura — Workout Repository Interface

abstract class WorkoutRepository {
  /// Start a new gym workout session
  Future<Map<String, dynamic>> startSession(String name);

  /// Add an exercise to an ongoing session
  Future<Map<String, dynamic>> addExercise(
    String sessionId,
    String exerciseId,
    int order, {
    String? notes,
  });

  /// Log a single set (weight, reps, rpe)
  Future<Map<String, dynamic>> logSet(
    String workoutExerciseId,
    int setNumber, {
    int? reps,
    double? weightKg,
    int? rpe,
  });

  /// Finish the workout session
  Future<Map<String, dynamic>> finishSession(String sessionId, {String? notes});
}
