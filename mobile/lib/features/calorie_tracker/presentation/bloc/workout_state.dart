import 'package:equatable/equatable.dart';
import '../../data/models/workout_models.dart';

abstract class WorkoutState extends Equatable {
  const WorkoutState();

  @override
  List<Object?> get props => [];
}

class WorkoutInitial extends WorkoutState {}

class WorkoutLoading extends WorkoutState {}

class WorkoutSessionActive extends WorkoutState {
  final String sessionId;
  final WorkoutLog currentLog;
  final bool isSubmitting;
  final String? error;

  const WorkoutSessionActive({
    required this.sessionId,
    required this.currentLog,
    this.isSubmitting = false,
    this.error,
  });

  WorkoutSessionActive copyWith({
    String? sessionId,
    WorkoutLog? currentLog,
    bool? isSubmitting,
    String? error,
  }) {
    return WorkoutSessionActive(
      sessionId: sessionId ?? this.sessionId,
      currentLog: currentLog ?? this.currentLog,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error, // overwrite with null or value
    );
  }

  @override
  List<Object?> get props => [sessionId, currentLog, isSubmitting, error];
}

class WorkoutError extends WorkoutState {
  final String message;
  const WorkoutError(this.message);

  @override
  List<Object> get props => [message];
}

class WorkoutSessionFinished extends WorkoutState {
  final String message;
  const WorkoutSessionFinished(this.message);

  @override
  List<Object> get props => [message];
}
