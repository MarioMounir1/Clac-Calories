// lib/features/calorie_tracker/presentation/bloc/water_bloc.dart
// The Teneen — Water Tracking BLoC

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/tracker_repository.dart';
import 'water_event.dart';
import 'water_state.dart';

class WaterBloc extends Bloc<WaterEvent, WaterState> {
  final TrackerRepository repository;

  WaterBloc({required this.repository}) : super(WaterInitial()) {
    on<LoadWaterToday>(_onLoadWaterToday);
    on<LogWaterIntake>(_onLogWaterIntake);
    on<DeleteWaterLogEvent>(_onDeleteWaterLog);
  }

  Future<void> _onLoadWaterToday(
    LoadWaterToday event,
    Emitter<WaterState> emit,
  ) async {
    emit(WaterLoading());
    final dateStr = event.date ?? DateTime.now().toIso8601String().split('T')[0];
    final result = await repository.getTodayWater(date: dateStr);

    result.fold(
      (failure) => emit(WaterFailure(failure.message)),
      (data) {
        emit(WaterLoaded(
          totalMl: data['totalMl'] as int,
          goalMl: data['goalMl'] as int,
          remainingMl: data['remainingMl'] as int,
          progressPct: data['progressPct'] as int,
          logs: data['logs'] as List<dynamic>? ?? [],
          hourlyBreakdown: Map<String, dynamic>.from(data['hourlyBreakdown'] as Map? ?? {}),
          quickAddOptions: List<int>.from(data['quickAddOptions'] as List? ?? [250, 500, 750, 1000]),
          date: dateStr,
        ));
      },
    );
  }

  Future<void> _onLogWaterIntake(
    LogWaterIntake event,
    Emitter<WaterState> emit,
  ) async {
    final currentState = state;
    emit(WaterLoading());

    final result = await repository.logWater(amountMl: event.amountMl);

    await result.fold(
      (failure) async => emit(WaterFailure(failure.message)),
      (data) async {
        emit(const WaterLogSuccess('Water intake logged successfully'));
        // Automatically reload today's logs to update UI
        final dateStr = currentState is WaterLoaded ? currentState.date : DateTime.now().toIso8601String().split('T')[0];
        final freshResult = await repository.getTodayWater(date: dateStr);
        freshResult.fold(
          (failure) => emit(WaterFailure(failure.message)),
          (freshData) => emit(WaterLoaded(
            totalMl: freshData['totalMl'] as int,
            goalMl: freshData['goalMl'] as int,
            remainingMl: freshData['remainingMl'] as int,
            progressPct: freshData['progressPct'] as int,
            logs: freshData['logs'] as List<dynamic>? ?? [],
            hourlyBreakdown: Map<String, dynamic>.from(freshData['hourlyBreakdown'] as Map? ?? {}),
            quickAddOptions: List<int>.from(freshData['quickAddOptions'] as List? ?? [250, 500, 750, 1000]),
            date: dateStr,
          )),
        );
      },
    );
  }

  Future<void> _onDeleteWaterLog(
    DeleteWaterLogEvent event,
    Emitter<WaterState> emit,
  ) async {
    final currentState = state;
    emit(WaterLoading());

    final result = await repository.deleteWaterLog(event.logId);

    await result.fold(
      (failure) async => emit(WaterFailure(failure.message)),
      (_) async {
        emit(const WaterLogSuccess('Water log deleted successfully'));
        final dateStr = currentState is WaterLoaded ? currentState.date : DateTime.now().toIso8601String().split('T')[0];
        final freshResult = await repository.getTodayWater(date: dateStr);
        freshResult.fold(
          (failure) => emit(WaterFailure(failure.message)),
          (freshData) => emit(WaterLoaded(
            totalMl: freshData['totalMl'] as int,
            goalMl: freshData['goalMl'] as int,
            remainingMl: freshData['remainingMl'] as int,
            progressPct: freshData['progressPct'] as int,
            logs: freshData['logs'] as List<dynamic>? ?? [],
            hourlyBreakdown: Map<String, dynamic>.from(freshData['hourlyBreakdown'] as Map? ?? {}),
            quickAddOptions: List<int>.from(freshData['quickAddOptions'] as List? ?? [250, 500, 750, 1000]),
            date: dateStr,
          )),
        );
      },
    );
  }
}
