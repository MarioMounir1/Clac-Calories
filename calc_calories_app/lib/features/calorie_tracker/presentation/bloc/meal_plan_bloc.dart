// lib/features/calorie_tracker/presentation/bloc/meal_plan_bloc.dart
// The Teneen — Meal Plan BLoC

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/tracker_repository.dart';
import 'meal_plan_event.dart';
import 'meal_plan_state.dart';

class MealPlanBloc extends Bloc<MealPlanEvent, MealPlanState> {
  final TrackerRepository repository;

  MealPlanBloc({required this.repository}) : super(MealPlanInitial()) {
    on<LoadWeeklyMealPlan>(_onLoadWeeklyMealPlan);
    on<GenerateWeeklyPlanEvent>(_onGenerateWeeklyPlan);
    on<ToggleMealEatenEvent>(_onToggleMealEaten);
  }

  Future<void> _onLoadWeeklyMealPlan(
    LoadWeeklyMealPlan event,
    Emitter<MealPlanState> emit,
  ) async {
    emit(MealPlanLoading());
    final result = await repository.getWeekMealPlan();

    result.fold(
      (failure) => emit(MealPlanFailure(failure.message)),
      (data) {
        emit(MealPlanLoaded(
          days: data['days'] as List<dynamic>? ?? [],
          hasPlan: data['hasPlan'] as bool? ?? false,
          weekStart: data['weekStart'] as String? ?? '',
        ));
      },
    );
  }

  Future<void> _onGenerateWeeklyPlan(
    GenerateWeeklyPlanEvent event,
    Emitter<MealPlanState> emit,
  ) async {
    emit(MealPlanLoading());
    final result = await repository.generateWeeklyMealPlan();

    await result.fold(
      (failure) async => emit(MealPlanFailure(failure.message)),
      (data) async {
        emit(const MealPlanOperationSuccess('Weekly plan generated successfully'));
        // Automatically reload weekly plan
        final freshResult = await repository.getWeekMealPlan();
        freshResult.fold(
          (failure) => emit(MealPlanFailure(failure.message)),
          (freshData) => emit(MealPlanLoaded(
            days: freshData['days'] as List<dynamic>? ?? [],
            hasPlan: freshData['hasPlan'] as bool? ?? false,
            weekStart: freshData['weekStart'] as String? ?? '',
          )),
        );
      },
    );
  }

  Future<void> _onToggleMealEaten(
    ToggleMealEatenEvent event,
    Emitter<MealPlanState> emit,
  ) async {
    final currentState = state;
    emit(MealPlanLoading());

    final result = await repository.toggleMealPlanEaten(
      id: event.planEntryId,
      isEaten: event.isEaten,
    );

    await result.fold(
      (failure) async => emit(MealPlanFailure(failure.message)),
      (_) async {
        emit(const MealPlanOperationSuccess('Meal plan status updated'));
        final freshResult = await repository.getWeekMealPlan();
        freshResult.fold(
          (failure) => emit(MealPlanFailure(failure.message)),
          (freshData) => emit(MealPlanLoaded(
            days: freshData['days'] as List<dynamic>? ?? [],
            hasPlan: freshData['hasPlan'] as bool? ?? false,
            weekStart: freshData['weekStart'] as String? ?? '',
          )),
        );
      },
    );
  }
}
