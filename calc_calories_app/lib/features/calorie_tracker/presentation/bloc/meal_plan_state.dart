// lib/features/calorie_tracker/presentation/bloc/meal_plan_state.dart
// The Teneen — Meal Plan States

import 'package:equatable/equatable.dart';

abstract class MealPlanState extends Equatable {
  const MealPlanState();

  @override
  List<Object?> get props => [];
}

class MealPlanInitial extends MealPlanState {}

class MealPlanLoading extends MealPlanState {}

class MealPlanLoaded extends MealPlanState {
  final List<dynamic> days;
  final bool hasPlan;
  final String weekStart;

  const MealPlanLoaded({
    required this.days,
    required this.hasPlan,
    required this.weekStart,
  });

  @override
  List<Object?> get props => [days, hasPlan, weekStart];
}

class MealPlanOperationSuccess extends MealPlanState {
  final String message;
  const MealPlanOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class MealPlanFailure extends MealPlanState {
  final String message;
  const MealPlanFailure(this.message);

  @override
  List<Object?> get props => [message];
}
