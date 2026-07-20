import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../data/models/workout_models.dart';
import 'workout_event.dart';
import 'workout_state.dart';

class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  final WorkoutRepository repository;

  WorkoutBloc(this.repository) : super(WorkoutInitial()) {
    on<StartWorkoutSession>(_onStartWorkoutSession);
    on<LogSetEvent>(_onLogSetEvent);
    on<FinishWorkoutSession>(_onFinishWorkoutSession);
  }

  Future<void> _onStartWorkoutSession(
    StartWorkoutSession event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoading());
    try {
      final sessionData = await repository.startSession(event.sessionName);
      final sessionId = sessionData['id'] as String;

      // Initialize a default local WorkoutLog for UI display
      // (In a real app, this would be built from the fetched session data)
      final defaultLog = WorkoutLog.defaultPushDay();

      emit(WorkoutSessionActive(
        sessionId: sessionId,
        currentLog: defaultLog,
      ));
    } catch (e) {
      emit(WorkoutError(e.toString()));
    }
  }

  Future<void> _onLogSetEvent(
    LogSetEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WorkoutSessionActive) return;

    emit(currentState.copyWith(isSubmitting: true));

    try {
      // Call repository to log set
      await repository.logSet(
        event.workoutExerciseId,
        event.setIndex,
        reps: event.reps,
        weightKg: event.weightKg,
      );

      // Update local state to reflect the set is logged
      final updatedLog = currentState.currentLog;
      final set = updatedLog.sets.firstWhere((s) => s.setIndex == event.setIndex);
      set.loggedWeightKg = event.weightKg;
      set.loggedReps = event.reps;
      set.isLogged = true;
      set.loggedAt = DateTime.now();

      emit(currentState.copyWith(
        currentLog: updatedLog,
        isSubmitting: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(
        isSubmitting: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onFinishWorkoutSession(
    FinishWorkoutSession event,
    Emitter<WorkoutState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WorkoutSessionActive) return;

    emit(currentState.copyWith(isSubmitting: true));

    try {
      await repository.finishSession(currentState.sessionId, notes: 'Great workout!');
      emit(const WorkoutSessionFinished('Workout successfully completed!'));
    } catch (e) {
      emit(currentState.copyWith(
        isSubmitting: false,
        error: e.toString(),
      ));
    }
  }
}
