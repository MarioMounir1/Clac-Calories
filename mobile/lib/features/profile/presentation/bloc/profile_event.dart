// lib/features/profile/presentation/bloc/profile_event.dart
// The Teneen — Profile Events

import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {}

class UpdateProfileEvent extends ProfileEvent {
  final String? name;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final double? targetWeightKg; // ← new: goal weight from onboarding
  final String? gender;
  final String? activityLevel;
  final String? goal;
  final int? dailyCalorieGoal;
  final int? dailyWaterGoalMl;
  final String? language;

  const UpdateProfileEvent({
    this.name,
    this.age,
    this.weightKg,
    this.heightCm,
    this.targetWeightKg,
    this.gender,
    this.activityLevel,
    this.goal,
    this.dailyCalorieGoal,
    this.dailyWaterGoalMl,
    this.language,
  });

  @override
  List<Object?> get props => [
        name,
        age,
        weightKg,
        heightCm,
        targetWeightKg,
        gender,
        activityLevel,
        goal,
        dailyCalorieGoal,
        dailyWaterGoalMl,
        language,
      ];
}

class CheckOnboardingStatus extends ProfileEvent {}

class CompleteOnboardingEvent extends ProfileEvent {}
