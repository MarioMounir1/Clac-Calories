import 'package:equatable/equatable.dart';

abstract class WorkoutEvent extends Equatable {
  const WorkoutEvent();

  @override
  List<Object?> get props => [];
}

class StartWorkoutSession extends WorkoutEvent {
  final String sessionName;
  const StartWorkoutSession(this.sessionName);

  @override
  List<Object> get props => [sessionName];
}

class LogSetEvent extends WorkoutEvent {
  final int setIndex;
  final double weightKg;
  final int reps;
  final String workoutExerciseId;

  const LogSetEvent({
    required this.setIndex,
    required this.weightKg,
    required this.reps,
    required this.workoutExerciseId,
  });

  @override
  List<Object> get props => [setIndex, weightKg, reps, workoutExerciseId];
}

class FinishWorkoutSession extends WorkoutEvent {
  const FinishWorkoutSession();
}
