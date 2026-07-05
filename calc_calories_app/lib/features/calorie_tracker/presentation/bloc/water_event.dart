// lib/features/calorie_tracker/presentation/bloc/water_event.dart
// The Teneen — Water Tracking Events

import 'package:equatable/equatable.dart';

abstract class WaterEvent extends Equatable {
  const WaterEvent();

  @override
  List<Object?> get props => [];
}

class LoadWaterToday extends WaterEvent {
  final String? date;
  const LoadWaterToday({this.date});

  @override
  List<Object?> get props => [date];
}

class LogWaterIntake extends WaterEvent {
  final int amountMl;
  const LogWaterIntake(this.amountMl);

  @override
  List<Object?> get props => [amountMl];
}

class DeleteWaterLogEvent extends WaterEvent {
  final String logId;
  const DeleteWaterLogEvent(this.logId);

  @override
  List<Object?> get props => [logId];
}
