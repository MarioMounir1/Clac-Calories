// lib/features/calorie_tracker/presentation/bloc/weight_bloc.dart
// The Teneen — Weight Tracking BLoC

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/tracker_repository.dart';
import 'weight_event.dart';
import 'weight_state.dart';

class WeightBloc extends Bloc<WeightEvent, WeightState> {
  final TrackerRepository repository;

  WeightBloc({required this.repository}) : super(WeightInitial()) {
    on<LoadWeightHistory>(_onLoadWeightHistory);
    on<LogWeightMeasurement>(_onLogWeight);
    on<DeleteWeightLogEvent>(_onDeleteWeightLog);
  }

  Future<void> _onLoadWeightHistory(
    LoadWeightHistory event,
    Emitter<WeightState> emit,
  ) async {
    emit(WeightLoading());
    final result = await repository.getWeightHistory(days: event.days);

    result.fold(
      (failure) => emit(WeightFailure(failure.message)),
      (data) {
        emit(WeightLoaded(
          logs: data['logs'] as List<dynamic>? ?? [],
          currentWeight: (data['currentWeight'] as num?)?.toDouble() ?? 70.0,
          goal: data['goal'] as String? ?? 'maintain',
          stats: data['stats'] as Map<String, dynamic>?,
          coachNote: data['coachNote'] as String? ?? data['stats']?['coachNote'] as String?,
          activeDaysFilter: event.days,
        ));
      },
    );
  }

  Future<void> _onLogWeight(
    LogWeightMeasurement event,
    Emitter<WeightState> emit,
  ) async {
    final currentState = state;
    emit(WeightLoading());

    final result = await repository.logWeight(weightKg: event.weightKg);

    await result.fold(
      (failure) async => emit(WeightFailure(failure.message)),
      (data) async {
        emit(const WeightLogSuccess('Weight logged successfully'));
        // Automatically reload history
        final filterDays = currentState is WeightLoaded ? currentState.activeDaysFilter : 30;
        final freshResult = await repository.getWeightHistory(days: filterDays);
        freshResult.fold(
          (failure) => emit(WeightFailure(failure.message)),
          (freshData) => emit(WeightLoaded(
            logs: freshData['logs'] as List<dynamic>? ?? [],
            currentWeight: (freshData['currentWeight'] as num?)?.toDouble() ?? event.weightKg,
            goal: freshData['goal'] as String? ?? 'maintain',
            stats: freshData['stats'] as Map<String, dynamic>?,
            coachNote: freshData['coachNote'] as String? ?? freshData['stats']?['coachNote'] as String?,
            activeDaysFilter: filterDays,
          )),
        );
      },
    );
  }

  Future<void> _onDeleteWeightLog(
    DeleteWeightLogEvent event,
    Emitter<WeightState> emit,
  ) async {
    final currentState = state;
    emit(WeightLoading());

    final result = await repository.deleteWeightLog(event.logId);

    await result.fold(
      (failure) async => emit(WeightFailure(failure.message)),
      (_) async {
        emit(const WeightLogSuccess('Weight log deleted successfully'));
        final filterDays = currentState is WeightLoaded ? currentState.activeDaysFilter : 30;
        final freshResult = await repository.getWeightHistory(days: filterDays);
        freshResult.fold(
          (failure) => emit(WeightFailure(failure.message)),
          (freshData) => emit(WeightLoaded(
            logs: freshData['logs'] as List<dynamic>? ?? [],
            currentWeight: (freshData['currentWeight'] as num?)?.toDouble() ?? 70.0,
            goal: freshData['goal'] as String? ?? 'maintain',
            stats: freshData['stats'] as Map<String, dynamic>?,
            coachNote: freshData['coachNote'] as String? ?? freshData['stats']?['coachNote'] as String?,
            activeDaysFilter: filterDays,
          )),
        );
      },
    );
  }
}
