// lib/features/calorie_tracker/presentation/bloc/dashboard_event.dart
// The Teneen — Dashboard Events

import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboard extends DashboardEvent {
  final String? date; // format YYYY-MM-DD
  const LoadDashboard({this.date});

  @override
  List<Object?> get props => [date];
}

class RefreshDashboard extends DashboardEvent {
  final String? date;
  const RefreshDashboard({this.date});

  @override
  List<Object?> get props => [date];
}

class ResetDashboardEvent extends DashboardEvent {
  const ResetDashboardEvent();
}
