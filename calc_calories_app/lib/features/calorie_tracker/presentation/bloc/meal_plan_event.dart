// lib/features/calorie_tracker/presentation/bloc/meal_plan_event.dart
// The Teneen — Meal Plan Events

import 'package:equatable/equatable.dart';

abstract class MealPlanEvent extends Equatable {
  const MealPlanEvent();

  @override
  List<Object?> get props => [];
}

class LoadWeeklyMealPlan extends MealPlanEvent {}

class GenerateWeeklyPlanEvent extends MealPlanEvent {}

class ToggleMealEatenEvent extends MealPlanEvent {
  final String planEntryId;
  final bool isEaten;

  const ToggleMealEatenEvent({required this.planEntryId, required this.isEaten});

  @override
  List<Object?> get props => [planEntryId, isEaten];
}
