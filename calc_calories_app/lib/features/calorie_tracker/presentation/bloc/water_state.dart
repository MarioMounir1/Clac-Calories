// lib/features/calorie_tracker/presentation/bloc/water_state.dart
// The Teneen — Water Tracking States

import 'package:equatable/equatable.dart';

abstract class WaterState extends Equatable {
  const WaterState();

  @override
  List<Object?> get props => [];
}

class WaterInitial extends WaterState {}

class WaterLoading extends WaterState {}

class WaterLoaded extends WaterState {
  final int totalMl;
  final int goalMl;
  final int remainingMl;
  final int progressPct;
  final List<dynamic> logs;
  final Map<String, dynamic> hourlyBreakdown;
  final List<int> quickAddOptions;
  final String date;

  const WaterLoaded({
    required this.totalMl,
    required this.goalMl,
    required this.remainingMl,
    required this.progressPct,
    required this.logs,
    required this.hourlyBreakdown,
    required this.quickAddOptions,
    required this.date,
  });

  @override
  List<Object?> get props => [
        totalMl,
        goalMl,
        remainingMl,
        progressPct,
        logs,
        hourlyBreakdown,
        quickAddOptions,
        date,
      ];
}

class WaterLogSuccess extends WaterState {
  final String message;
  const WaterLogSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class WaterFailure extends WaterState {
  final String message;
  const WaterFailure(this.message);

  @override
  List<Object?> get props => [message];
}
