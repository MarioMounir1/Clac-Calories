// lib/features/calorie_tracker/presentation/bloc/weight_state.dart
// The Teneen — Weight Tracking States

import 'package:equatable/equatable.dart';

abstract class WeightState extends Equatable {
  const WeightState();

  @override
  List<Object?> get props => [];
}

class WeightInitial extends WeightState {}

class WeightLoading extends WeightState {}

class WeightLoaded extends WeightState {
  final List<dynamic> logs;
  final double currentWeight;
  final String goal;
  final Map<String, dynamic>? stats;
  final String? coachNote;
  final int activeDaysFilter;

  const WeightLoaded({
    required this.logs,
    required this.currentWeight,
    required this.goal,
    this.stats,
    this.coachNote,
    required this.activeDaysFilter,
  });

  @override
  List<Object?> get props => [logs, currentWeight, goal, stats, coachNote, activeDaysFilter];
}

class WeightLogSuccess extends WeightState {
  final String message;
  const WeightLogSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class WeightFailure extends WeightState {
  final String message;
  const WeightFailure(this.message);

  @override
  List<Object?> get props => [message];
}
