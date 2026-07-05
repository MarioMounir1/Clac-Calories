// lib/features/profile/presentation/bloc/profile_state.dart
// The Teneen — Profile States

import 'package:equatable/equatable.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final Map<String, dynamic> user;
  final bool isOnboardingCompleted;

  const ProfileLoaded({
    required this.user,
    required this.isOnboardingCompleted,
  });

  @override
  List<Object?> get props => [user, isOnboardingCompleted];
}

class ProfileUpdateSuccess extends ProfileState {
  final Map<String, dynamic> user;

  const ProfileUpdateSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

class ProfileFailure extends ProfileState {
  final String message;

  const ProfileFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class OnboardingStatusChecked extends ProfileState {
  final bool isCompleted;

  const OnboardingStatusChecked(this.isCompleted);

  @override
  List<Object?> get props => [isCompleted];
}
